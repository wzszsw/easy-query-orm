# Entity Navigation Metadata

Read this after `entity-mapping.md` when the task depends on advanced relation
metadata rather than plain mapping.

Boundary:

- plain `@Navigate` direction/cardinality: `relation-query.md`
- relation-driven predicates/subqueries/tree behavior: `implicit-query.md`
- DTO/VO structured return assembly: `select-auto-include.md`

## Relation Shapes

Examples use `Fields.xxx` constants from Lombok `@FieldNameConstants`, for
example:

```java
import lombok.experimental.FieldNameConstants;

@FieldNameConstants
public class Company { ... }
```

If the project does not use Lombok `@FieldNameConstants`, replace those
constants with string literals.

Common relation forms:

```java
@Navigate(
    value = RelationTypeEnum.ManyToOne,
    selfProperty = Fields.companyId,
    targetProperty = Company.Fields.id
)
private Company company;

@Navigate(
    value = RelationTypeEnum.OneToMany,
    selfProperty = Fields.id,
    targetProperty = UserBook.Fields.userId
)
private List<UserBook> books;

@Navigate(
    value = RelationTypeEnum.ManyToMany,
    mappingClass = UserRole.class,
    selfProperty = Fields.id,
    selfMappingProperty = UserRole.Fields.userId,
    targetMappingProperty = UserRole.Fields.roleId,
    targetProperty = Role.Fields.id
)
private List<Role> roles;
```

`selfProperty` / `targetProperty` define direct relation columns.
`mappingClass` plus the two `*MappingProperty` arrays are required for
many-to-many.

## Entity vs DTO/VO Navigation

Treat these as two different use cases:

- Entity/table-object navigation: full `@Navigate` metadata matters. Key arrays,
  `mappingClass`, `required`, `subQueryToGroupJoin`, `orderByProps`, `limit`,
  and `partitionOrder` are all behavior-bearing.
- DTO/VO result metadata for `selectAutoInclude`: source comment on
  `@Navigate` says non-entity objects mainly need `RelationTypeEnum`; extra
  relation fields may be ignored.
- Non-entity proxy navigation inside query DSL is stricter. Source code can
  throw `entityRelationToImplicitProvider is null,Navigate property in non
  entity plz set supportNonEntity = true.` if the DTO/VO path is used like a
  queryable relation without verified support.

Use DTO/VO `@Navigate` to describe result graphs, not to replace entity-side
relation modeling.

## High-Value `@Navigate` Options

High-value fields:

```java
RelationTypeEnum value();
String[] selfProperty() default {};
String[] targetProperty() default {};
Class<?> mappingClass() default Object.class;
String[] selfMappingProperty() default {};
String[] targetMappingProperty() default {};
OrderByProperty[] orderByProps() default {};
long offset() default 0;
long limit() default 0;
String[] directMapping() default {};
boolean required() default false;
boolean subQueryToGroupJoin() default false;
boolean supportNonEntity() default false;
PartitionOrderEnum partitionOrder() default PartitionOrderEnum.THROW;
boolean ignoreAutoInclude() default false;
```

Use them deliberately:

- `required = true`: inner-join oriented relation semantics
- `subQueryToGroupJoin = true`: hot to-many filter/aggregate path
- `orderByProps` / `limit` / `offset`: to-many load / partition shaping
- `supportNonEntity = true`: only when non-entity proxy navigation itself is
  used in DSL
- `partitionOrder`: `THROW`, `IGNORE`, `NAVIGATE`, `KEY_ASC`, `KEY_DESC`
- `ignoreAutoInclude = true`: keep tree-like relations out of auto include

## Query-Level Relation Tuning

Query-level override for a hot to-many relation:

```java
query.subQueryToGroupJoin(user -> user.bankCards());
```

Ordered limited relation example:

```java
@Navigate(
    value = RelationTypeEnum.OneToMany,
    selfProperty = Fields.id,
    targetProperty = Comment.Fields.parentId,
    orderByProps = @OrderByProperty(property = Comment.Fields.createTime, asc = false),
    limit = 10
)
private List<Comment> latestComments;
```

If partition-like access has no order, default `THROW` may fail fast.

## DTO Navigation

DTO/VO relation fields can carry navigation metadata when simple naming is not
enough.

```java
public class UserDTO {
    private String id;
    private String name;

    @Navigate(value = RelationTypeEnum.OneToMany, supportNonEntity = true)
    private List<BankCardDTO> bankCards;
}
```

Refine that example before copying it:

- result metadata only -> start with plain `RelationTypeEnum`
- DTO/VO path used in DSL -> `supportNonEntity = true` becomes relevant

Do not use DTO-side `@Navigate` as a generic substitute for missing entity
relations.

## `@NavigateFlat`

Use `@NavigateFlat` when a DTO field maps through one or more entity relations.

```java
private static final MappingPath MENU_IDS_PATH =
    SysUserProxy.TABLE.roles().flatElement().menus().flatElement().id();

@NavigateFlat(pathAlias = "MENU_IDS_PATH")
private List<String> menuIds;
```

Rules:

- DTO/VO traversal only, not ordinary entity table objects
- final target must match the DTO field type
- collection target unless the final single value is a basic type or entity
- same-level flatten + id misuse can throw
- mapped field type must match the entity-path value type
- `prefix = true` only for reusable path prefixes

## `directMapping`, `@EasyTree`, `@Encryption`

`directMapping` is for x-to-one traversal through intermediate properties when the
project already uses a documented path:

```java
@Navigate(value = RelationTypeEnum.ManyToOne, directMapping = {"comUser", "myCompany"})
private Company company;
```

`@EasyTree("children")` selects which self relation should be treated as the tree
children path for tree result APIs.

Treat it as a disambiguation annotation, not as the thing that creates the tree
relation. The real tree modeling still comes from self `@Navigate` metadata.

Practical rule:

- exactly one self `List<SelfType>` one-to-many path -> usually no `@EasyTree`
  needed
- multiple self `List<SelfType>` one-to-many paths -> add `@EasyTree("...")`
  on the entity to point at the real child collection used by tree APIs

Tree entity prompts should usually produce:

- `id`
- `parentId`
- self `ManyToOne parent` when upward traversal matters
- self `OneToMany children`
- optional `@EasyTree("children")` only for ambiguity resolution

`@Encryption(...)` belongs on encrypted fields only when the entity or result path
already uses the matching encryption strategy. Do not infer fuzzy-query support
without source evidence.

## Mapping Reminder

`select(Class<TR>)` still maps by column/result name, not by relation intent. If a
DTO field cannot be filled by ordinary naming or documented navigation metadata,
switch to explicit `Select.of(...)` or another verified DTO mapping pattern.
