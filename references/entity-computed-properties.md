# Computed and Derived Properties

Use this reference for advanced entity properties that are not plain table
columns:

- transient business fields
- simple SQL computed properties via `sqlExpression`
- advanced computed properties via `sqlConversion`
- cross-table derived properties
- `autoSelect=false`
- model-level recurring metrics such as "book store book count"

For broader advanced table/column annotation choices, read
`entity-modeling-advanced.md`.

## 1. Choose the Right Kind of Non-Plain Property

Before writing code, classify the requirement:

- UI-only label or transport-only helper:
  `@ColumnIgnore` or `@Column(exist = false)`
- one-off query metric for a single endpoint/report:
  keep it in query DSL/projection first
- recurring business meaning that belongs to the domain model:
  prefer an entity computed property

This matters because easy-query is strongest when repeated business semantics
are modeled once and then reused through DSL. If "book count on a store" is a
real domain concept rather than a one-off page field, it should usually be
modeled on the entity side instead of being rebuilt in every VO projection.

### Pure business/transient field

Prefer:

- `@ColumnIgnore` when ORM should not know the field exists
- `@Column(exist = false)` when the field should stay in entity/proxy shape but
  not be persisted

### Simple computed SQL field

Use `@Column(sqlExpression = @ColumnSQLExpression(...))` when:

- the expression is straightforward
- one-database specificity is acceptable
- you do not need a fully custom converter class

### Advanced computed field

Use `@Column(sqlConversion = MyConverter.class)` when:

- the expression affects select + predicate + order/group usage
- cross-table derived logic is involved
- multi-dialect or SQLFunc-based control matters

### One-off query metric instead of entity modeling

If the requirement is not really reusable model knowledge, prefer ordinary DSL:

```java
easyEntityQuery.queryable(BookStore.class)
    .select(BookStoreListVO.class, s -> Select.of(
        s.id(),
        s.name(),
        s.books().count().as(BookStoreListVO::getBookCount)
    ))
    .toList();
```

That is often better than introducing a permanent computed property for a
single report/list page.

## 2. Simple Computed Property: `sqlExpression`

Example:

```java
@Data
@Table("t_user_extra")
@EntityProxy
public class UserExtra2 implements ProxyEntityAvailable<UserExtra2, UserExtra2Proxy> {
    @Column(primaryKey = true)
    private String id;
    private String firstName;
    private String lastName;

    @InsertIgnore
    @UpdateIgnore
    @Column(sqlExpression = @ColumnSQLExpression(
        sql = "CONCAT({0},{1})",
        args = {
            @ExpressionArg(prop = "firstName"),
            @ExpressionArg(prop = "lastName")
        }
    ))
    private String fullName;
}
```

Practical boundary:

- convenient
- docs explicitly recommend `sqlConversion` / `ColumnValueSQLConverter` for
  richer control or portability
- good for same-table simple expressions
- not the preferred path for reusable cross-table aggregates

## 3. `ColumnValueSQLConverter` Lifecycle

Current inspected source interface is:

```java
public interface ColumnValueSQLConverter {
    boolean isRealColumn();
    void selectColumnConvert(...);
    default void propertyColumnConvert(...) { ... }
    void valueConvert(..., boolean isCompareValue);
}
```

Use `ColumnValueSQLConverter` when the property needs full lifecycle control.

High-value methods:

- `isRealColumn()`
- `selectColumnConvert(...)`
- `propertyColumnConvert(...)`
- `valueConvert(...)`

Meaning:

- `selectColumnConvert(...)`: how it appears in `SELECT`
- `propertyColumnConvert(...)`: how it behaves in `where/orderBy/groupBy`
- `valueConvert(...)`: how comparison/store values are translated; current
  source passes `isCompareValue` so the converter can distinguish
  `where bookCount = ?` from write-time value handling when relevant

Important source-vs-doc correction:

- older docs mention `isMergeSubQuery()`
- the current inspected `ColumnValueSQLConverter` interface does not expose
  that method
- prefer the project/source interface over older docs when they drift

## 4. Same-Table `sqlConversion`

Docs show this for fields like:

- full name from `firstName + lastName`
- age from `birthday`

These can participate in:

- `where`
- `orderBy`
- `groupBy`
- projection

if the converter implements both select and property conversion correctly.

Source-backed pattern:

- `FullNameColumnValueSQLConverter` uses `runtimeContext.fx().concat(...)`
- `UserAgeColumnValueSQLConverter` uses `SQLFunc` composition for date
  arithmetic

These are good examples when the property should behave like a first-class DSL
field, not just a returned alias.

## 5. Cross-Table Aggregate Property

This is the branch behind prompts like:

- store book count
- class student count
- user certificate count
- parent aggregate child total

If the relation is stable and the metric is reused, modeling it once on the
entity is high-value.

Bookstore/books example:

```java
@Data
@Table("book_store")
@EntityProxy
public class BookStore implements ProxyEntityAvailable<BookStore, BookStoreProxy> {
    @Column(primaryKey = true)
    private String id;
    private String name;

    @Navigate(value = RelationTypeEnum.OneToMany, targetProperty = "storeId")
    private List<Book> books;

    @Column(sqlConversion = BookCountColumnValueSQLConverter.class, autoSelect = false)
    @InsertIgnore
    @UpdateIgnore
    private Long bookCount;
}
```

Converter:

```java
import com.easy.query.core.api.SQLClientApiFactory;
import com.easy.query.core.basic.api.select.ClientQueryable;
import com.easy.query.core.basic.extension.conversion.ColumnValueSQLConverter;
import com.easy.query.core.basic.extension.conversion.SQLPropertyConverter;
import com.easy.query.core.basic.jdbc.parameter.SQLParameter;
import com.easy.query.core.context.QueryRuntimeContext;
import com.easy.query.core.expression.parser.core.available.TableAvailable;
import com.easy.query.core.expression.parser.core.base.SimpleEntitySQLTableOwner;
import com.easy.query.core.metadata.ColumnMetadata;

public class BookCountColumnValueSQLConverter implements ColumnValueSQLConverter {
    @Override
    public boolean isRealColumn() {
        return false;
    }

    @Override
    public void selectColumnConvert(TableAvailable table,
                                    ColumnMetadata columnMetadata,
                                    SQLPropertyConverter sqlPropertyConverter,
                                    QueryRuntimeContext runtimeContext) {
        ClientQueryable<Long> countQuery = createCountQuery(table, runtimeContext);
        sqlPropertyConverter.sqlNativeSegment("{0}", context -> {
            context.expression(countQuery);
            context.setAlias(columnMetadata.getName());
        });
    }

    @Override
    public void propertyColumnConvert(TableAvailable table,
                                      ColumnMetadata columnMetadata,
                                      SQLPropertyConverter sqlPropertyConverter,
                                      QueryRuntimeContext runtimeContext) {
        ClientQueryable<Long> countQuery = createCountQuery(table, runtimeContext);
        sqlPropertyConverter.sqlNativeSegment("{0}", context -> {
            context.expression(countQuery);
        });
    }

    private ClientQueryable<Long> createCountQuery(TableAvailable table,
                                                   QueryRuntimeContext runtimeContext) {
        SQLClientApiFactory factory = runtimeContext.getSQLClientApiFactory();
        return factory.createQueryable(Book.class, runtimeContext)
            .where(t -> t.eq(new SimpleEntitySQLTableOwner<>(table), "storeId", "id"))
            .select(Long.class, s -> s.columnCount("id"));
    }

    @Override
    public void valueConvert(TableAvailable table,
                             ColumnMetadata columnMetadata,
                             SQLParameter sqlParameter,
                             SQLPropertyConverter sqlPropertyConverter,
                             QueryRuntimeContext runtimeContext,
                             boolean isCompareValue) {
        sqlPropertyConverter.sqlNativeSegment("{0}", context -> {
            context.value(sqlParameter);
        });
    }
}
```

This is the same source-backed shape used by current `StudentSize` examples:

- correlated subquery in `selectColumnConvert(...)`
- same correlated subquery in `propertyColumnConvert(...)`
- pass-through value handling in `valueConvert(...)`

Example shape:

```java
@Table("school_class")
@EntityProxy
public class SchoolClassAggregateProp implements ProxyEntityAvailable<SchoolClassAggregateProp, SchoolClassAggregatePropProxy> {
    @Column(primaryKey = true)
    private String id;
    private String name;

    @Navigate(value = RelationTypeEnum.OneToMany, targetProperty = "classId")
    private List<SchoolStudent> schoolStudents;

    @Column(sqlConversion = StudentSizeColumnValueSQLConverter.class, autoSelect = false)
    @InsertIgnore
    @UpdateIgnore
    private Long studentSize;
}
```

Implications:

- cross-table derived property is usually not a real DB column
- `autoSelect = false` is common because it may be expensive
- you must explicitly fetch it when needed
- the entity-side `@Navigate` path is usually the modeling prerequisite

If the user asks "书店上如何用计算属性表达书本数量", this is the correct
branch, not `@Column(exist=false)` and not a plain VO-only field.

## 6. `autoSelect = false`

For heavy computed properties:

- `toList()` may not fetch them
- `FETCHER.allFields()` may still not fetch them
- explicit fetch/projection is needed
- `select(MyVO.class)` can still bring them in when the projection explicitly
  maps that property
- `FETCHER.allFields().bookCount().fetchProxy()` is the explicit entity/proxy
  fetch pattern

If a computed property comes back null unexpectedly, check `autoSelect` early.

## 7. `isRealColumn()` and `valueConvert(...)`

### `isRealColumn()`

Use `false` when the property is not a physical database column, for example:

- `fullName`
- `age`
- `bookCount`
- `studentSize`
- computed status fields

Use `true` only when the property still maps to a real column but needs
function-based read/write behavior, for example encryption/decryption style
converters.

### `valueConvert(...)`

Think of it as the value-side companion to `propertyColumnConvert(...)`:

- `propertyColumnConvert(...)` rewrites the left side
- `valueConvert(...)` rewrites the right side

Encryption-style properties are the clearest example:

- `selectColumnConvert(...)`: decrypt in select
- `propertyColumnConvert(...)`: keep/property-side SQL shape
- `valueConvert(...)`: encrypt incoming comparison/store value

For count/age/full-name style computed properties, value conversion is often
just pass-through.

## 8. Query Capabilities of Computed Properties

Well-modeled computed properties can participate in:

- filter
- sort
- group
- projection

That is the difference between a plain transient field and a true ORM-modeled
derived property.

This is why a reusable `bookCount` model property is valuable: the same field
can participate in:

```java
easyEntityQuery.queryable(BookStore.class)
    .where(s -> s.bookCount().gt(100L))
    .orderBy(s -> s.bookCount().desc())
    .select(BookStoreListVO.class)
    .toList();
```

## 9. Registration

### Manual bootstrap

```java
QueryRuntimeContext runtimeContext = easyEntityQuery.getRuntimeContext();
QueryConfiguration configuration = runtimeContext.getQueryConfiguration();

configuration.applyColumnValueSQLConverter(new BookCountColumnValueSQLConverter());
configuration.applyColumnValueSQLConverter(new FullNameColumnValueSQLConverter());
```

### Spring Boot starter

Current starter source auto-collects `ColumnValueSQLConverter` beans and
applies them through `EasyQueryInitializeOption`.

So under starter, plain `@Component` on the converter is enough.

## 10. Inserts and Updates

For computed SQL properties, docs consistently pair them with:

- `@InsertIgnore`
- `@UpdateIgnore`

That is usually the right default because the field is derived, not stored.

## 11. Portability Guidance

Use `sqlExpression` when:

- the expression is simple
- DB-specific syntax is acceptable

Use `sqlConversion` when:

- the team wants more explicit control
- the expression should work through ORM hooks rather than one inline template
- portability or richer behavior matters

## 12. One-Off Query vs Model Property

Prefer query-time relation aggregate when:

- the metric is only used in one screen/report
- the business does not really name it as part of the model
- adding a permanent entity field would create noise

Prefer entity computed property when:

- the metric is reused across multiple services/endpoints
- the business treats it like a stable concept (`bookCount`, `studentSize`,
  `certStatus`, `fullName`, `age`)
- filters/sorts/grouping should consistently reuse the same SQL definition

## 13. Common Mistakes

- Using `@Column(exist = false)` when the field really needs filter/sort/group
  SQL behavior
- Using `sqlExpression` for a complex cross-table metric that needed a full
  converter
- Treating every list-page aggregate as a permanent model field when it was
  really a one-off projection
- Forgetting `@InsertIgnore` / `@UpdateIgnore` on derived fields
- Forgetting `autoSelect = false` when wondering why a heavy computed field was
  not returned
- Repeating the same `books().count()` logic in many VOs/services instead of
  modeling a stable reusable property once
- Modeling a UI-only label as a database-derived property
- Trusting older docs about `isMergeSubQuery()` when the current project source
  no longer exposes that method

## Read next

- advanced table/column modeling: `entity-modeling-advanced.md`
- basic entity mapping: `entity-mapping.md`
- relation metadata: `entity-modeling-navigate.md`
- query-time alternative for one-off aggregates: `implicit-query.md`

## Sources

- docs:
  `easy-query-doc/src/prop/{simple-sql-prop,combine-prop,cross-table-prop,sql-column-prop,status-prop}.md`
- source:
  `com.easy.query.core.annotation.{Column,ColumnSQLExpression,ExpressionArg}`
- source:
  `com.easy.query.core.basic.extension.conversion.ColumnValueSQLConverter`
- tests:
  `sql-test/.../conversion/{FullName,UserAge,StudentSize}ColumnValueSQLConverter.java`
- tests:
  `sql-test/.../entity/{UserExtra,UserExtra2,school/SchoolClassAggregate,school/SchoolClassAggregateProp}.java`
