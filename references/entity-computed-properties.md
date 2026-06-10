# Computed and Derived Properties

Use this reference for advanced entity properties that are not plain table
columns:

- transient business fields
- simple SQL computed properties via `sqlExpression`
- advanced computed properties via `sqlConversion`
- cross-table derived properties
- `autoSelect=false`

For broader advanced table/column annotation choices, read
`entity-modeling-advanced.md`.

## 1. Choose the Right Kind of Non-Plain Property

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

## 3. Advanced Computed Property: `sqlConversion`

Use `ColumnValueSQLConverter` when the property needs full lifecycle control.

High-value methods:

- `isRealColumn()`
- `isMergeSubQuery()`
- `selectColumnConvert(...)`
- `propertyColumnConvert(...)`
- `valueConvert(...)`

Meaning:

- `selectColumnConvert(...)`: how it appears in `SELECT`
- `propertyColumnConvert(...)`: how it behaves in `where/orderBy/groupBy`
- `valueConvert(...)`: how comparison/store values are translated

## 4. Composite Same-Table Derived Property

Docs show this for fields like:

- full name from `firstName + lastName`
- age from `birthday`

These can participate in:

- `where`
- `orderBy`
- `groupBy`
- projection

if the converter implements both select and property conversion correctly.

## 5. Cross-Table Derived Property

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

## 6. `autoSelect = false`

For heavy computed properties:

- `toList()` may not fetch them
- `FETCHER.allFields()` may still not fetch them
- explicit fetch/projection is needed

If a computed property comes back null unexpectedly, check `autoSelect` early.

## 7. `isRealColumn()` and `isMergeSubQuery()`

### `isRealColumn()`

Use `false` when the property is not a physical database column.

### `isMergeSubQuery()`

Use this to indicate whether the generated SQL interacts with other tables in a
way that affects alias/subquery behavior. Docs use `true` in cross-table
computed-property examples.

## 8. Query Capabilities of Computed Properties

Well-modeled computed properties can participate in:

- filter
- sort
- group
- projection

That is the difference between a plain transient field and a true ORM-modeled
derived property.

## 9. Inserts and Updates

For computed SQL properties, docs consistently pair them with:

- `@InsertIgnore`
- `@UpdateIgnore`

That is usually the right default because the field is derived, not stored.

## 10. Portability Guidance

Use `sqlExpression` when:

- the expression is simple
- DB-specific syntax is acceptable

Use `sqlConversion` when:

- the team wants more explicit control
- the expression should work through ORM hooks rather than one inline template
- portability or richer behavior matters

## 11. Common Mistakes

- Using `@Column(exist = false)` when the field really needs filter/sort/group
  SQL behavior
- Using `sqlExpression` for a complex cross-table metric that needed a full
  converter
- Forgetting `@InsertIgnore` / `@UpdateIgnore` on derived fields
- Forgetting `autoSelect = false` when wondering why a heavy computed field was
  not returned
- Modeling a UI-only label as a database-derived property

## Read next

- advanced table/column modeling: `entity-modeling-advanced.md`
- basic entity mapping: `entity-mapping.md`
- relation metadata: `entity-modeling-navigate.md`

## Sources

- docs: `easy-query-doc/src/prop/{simple-sql-prop,combine-prop,cross-table-prop,sql-column-prop}.md`
- source: `com.easy.query.core.annotation.{Column,ColumnSQLExpression,ExpressionArg}`
- tests: `sql-test/.../entity/{UserExtra,UserExtra2,school/SchoolClassAggregateProp}.java`
