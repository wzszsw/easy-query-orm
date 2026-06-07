# Entity Navigation Metadata

Read this after `entity-mapping.md` when the task depends on advanced relation
metadata instead of plain table/column mapping. This file focuses on `@Navigate`,
DTO-side navigation, and path-based mapping.

## Relation Shapes

Examples below use `Fields.xxx` constants. Those come from Lombok
`@FieldNameConstants` on the entity or mapping class, for example:

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

`selfProperty` / `targetProperty` define the direct relation columns.
`mappingClass` plus the two `*MappingProperty` arrays are required for many-to-many.

## High-Value `@Navigate` Options

Source fields that most often affect behavior:

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

- `required = true`: allows inner-join style semantics where the related row must exist.
- `subQueryToGroupJoin = true`: useful for hot to-many filters/aggregates that repeatedly translate to subquery group joins.
- `orderByProps` / `limit` / `offset`: shape to-many relation loading and partition-style element access.
- `supportNonEntity = true`: enables DTO/VO-side relation metadata.
- `ignoreAutoInclude = true`: prevents tree-like relations from being treated as ordinary auto include paths.

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

If partition-like access is needed and no order is declared, the default
`PartitionOrderEnum.THROW` may fail fast. Add an explicit order.

## DTO Navigation

DTO/VO relation fields can carry navigation metadata when the result graph cannot
be inferred from simple field naming alone.

```java
public class UserDTO {
    private String id;
    private String name;

    @Navigate(value = RelationTypeEnum.OneToMany, supportNonEntity = true)
    private List<BankCardDTO> bankCards;
}
```

Use DTO-side `@Navigate` with `selectAutoInclude`, documented DTO query
patterns, or `@NavigateFlat`. Do not use it as a generic substitute for missing
entity relations.

## `@NavigateFlat`

Use path-based flattening when a DTO field maps through one or more entity
relations.

```java
private static final MappingPath MENU_IDS_PATH =
    SysUserProxy.TABLE.roles().flatElement().menus().flatElement().id();

@NavigateFlat(pathAlias = "MENU_IDS_PATH")
private List<String> menuIds;
```

Rules:

- It is for DTO/VO traversal paths, not ordinary entity table objects.
- The final target must align with the DTO field type.
- Use `prefix = true` only when the alias is a reusable path prefix.

## `directMapping`, `@EasyTree`, `@Encryption`

`directMapping` is for x-to-one traversal through intermediate properties when the
project already uses a documented path:

```java
@Navigate(value = RelationTypeEnum.ManyToOne, directMapping = {"comUser", "myCompany"})
private Company company;
```

`@EasyTree("children")` selects which self relation should be treated as the tree
children path for tree result APIs.

`@Encryption(...)` belongs on encrypted fields only when the entity or result path
already uses the matching encryption strategy. Do not infer fuzzy-query support
without source evidence.

## Mapping Reminder

`select(Class<TR>)` still maps by column/result name, not by relation intent. If a
DTO field cannot be filled by ordinary naming or documented navigation metadata,
switch to explicit `Select.of(...)` or another verified DTO mapping pattern.
