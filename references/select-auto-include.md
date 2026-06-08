# selectAutoInclude

`selectAutoInclude` is a core DTO result API. It combines select mapping with include-style relation loading to build nested DTO/VO result shapes.

Source tests show it is not "just select": the root query runs first, then
easy-query issues include-like follow-up relation queries keyed by hidden
relation columns such as `__relation__id`.

## Core Signatures

Client source:

```java
default <TR> Query<TR> selectAutoInclude(Class<TR> resultClass)
<TR> Query<TR> selectAutoInclude(
    Class<TR> resultClass,
    SQLActionExpression1<ColumnAsSelector<T1, TR>> selectExpression,
    boolean replace
)
```

Proxy source:

```java
selectAutoInclude(ResultDTO.class)
selectAutoInclude(ResultDTO.class, proxy -> Select.of(...))
selectAutoInclude(ResultDTO.class, proxy -> Select.of(...), replace)
```

For joins, arity-specific overloads exist through `Selectable2...10` and `EntitySelectable2...10`.

## Basic Pattern

```java
List<SysBankDTO> list = easyEntityQuery.queryable(SysBank.class)
    .selectAutoInclude(SysBankDTO.class)
    .toList();
```

The DTO describes the returned object graph. It can include nested objects and lists when the shape has matching navigation metadata.

## Execution Shape

What source/tests show:

- The root query selects DTO scalar columns plus relation key columns needed for
  later assembly.
- Nested relation data is fetched by separate include-style batched queries.
- Deep DTO graphs can therefore produce multiple SQL statements; this is normal.
- Relation batching follows starter `relationGroupSize`, whose default is `512`.

Use `include-structured-loading.md` if you need to compare this execution model
against handwritten `include/include2/loadInclude/fillMany`.

## Extra Select Pattern

Use extra select when the DTO needs additional fields beyond automatic relation mapping.

```java
List<PostDTO> list = easyEntityQuery.queryable(Post.class)
    .selectAutoInclude(PostDTO.class, post -> Select.of(
        post.user().name().as(PostDTO.Fields.userName)
    ))
    .toList();
```

`replace = false` keeps auto-selected fields and appends extra select. `replace = true` replaces the automatic select behavior for the select expression.

## Critical Constraint

Do not pass a database entity class as the result class:

```java
// Bad
query.selectAutoInclude(SysUser.class);

// Good
query.selectAutoInclude(SysUserDTO.class);
```

Source has `SelectAutoIncludeTableEnum.THROW/WARNING/IGNORE`; default option is `THROW`. The implementation throws: "selectAutoInclude should not use database entity objects as return results".

Reason: passing database entities can pull the whole relation tree.

## DTO Navigation

For nested DTO fields, define relation metadata on DTO properties when the result shape cannot be inferred by simple property mapping.

```java
public class UserDTO {
    private String id;
    private String name;

    @Navigate(value = RelationTypeEnum.OneToMany)
    private List<BankCardDTO> bankCards;
}
```

Important distinction from source:

- For DTO/VO metadata used only by `selectAutoInclude`, the `@Navigate`
  annotation comment says defining `RelationTypeEnum` is the essential part and
  extra relation fields on non-entity objects may be ignored.
- If the DTO/VO proxy itself is navigated inside query DSL rather than only
  used as result metadata, verify `supportNonEntity = true` behavior in
  `entity-modeling-navigate.md`; otherwise runtime may throw
  `entityRelationToImplicitProvider is null...`.

If the DTO relation property has different field names or a path through entity
relations, use the patterns from `entity-modeling-navigate.md`.

## Flattened Paths with NavigateFlat

`@NavigateFlat` lets DTOs pull fields through relation paths, including to-many paths.

```java
private static final MappingPath MENU_IDS_PATH =
    SysUserProxy.TABLE.roles().flatElement().menus().flatElement().id();

@NavigateFlat(pathAlias = "MENU_IDS_PATH")
private List<String> menuIds;
```

Source constraints:

- `@NavigateFlat` is for non-table DTO/VO use.
- Target must be a collection unless the single value is a basic type or database entity.
- Field type must match the entity path value because the include processor uses the entity as data container.
- If a `@NavigateFlat` VO and a same-level id are requested together incorrectly, source comments say it can error.
- `prefix = true` lets the alias act as a reusable path prefix instead of the full terminal path.

## Extra Auto Include Configure

Source interface:

```java
EntityExtraAutoIncludeConfigure<TProxy, TEntity>
    .configure(queryable -> { ... })
    .where(proxy -> { ... })
    .select(proxy -> Select.of(...))
    .ignoreNavigateConfigure();
```

Core interface comment: this is for `selectAutoInclude` from the second level onward, to compensate for class-based DSL limitations. It applies to non-table DTO/VO. `@NavigateFlat` properties cannot have extra filters, but `@NavigateFlat` objects can.

Pattern seen in docs/tests uses static config on generated proxy table:

```java
private static final ExtraAutoIncludeConfigure EXTRA_AUTO_INCLUDE_CONFIGURE =
    PostProxy.TABLE.EXTRA_AUTO_INCLUDE_CONFIGURE()
        .where(post -> post.status().eq(1))
        .select(post -> Select.of(post.title().as("title")));
```

Additional source-backed behavior:

- `.configure(queryable -> { ... })` can apply query-level behaviors such as
  `orderBy(...)` or `ALL_SUB_QUERY_GROUP_JOIN`.
- `.ignoreNavigateConfigure()` tells auto include to ignore relation settings
  inherited from `@Navigate`, such as `orderByProps`, `limit`, or `offset`.
- This hook is most useful from the second level onward, where DTO class DSL is
  otherwise too limited.

Use this when nested DTO relation includes need custom filtering, custom sort,
`subQueryToGroupJoin`, or extra selected values.

## Tree CTE Interaction

When using tree CTE plus `selectAutoInclude`, source comments say the configured tree navigation is ignored during auto include to avoid querying children as a normal one-to-many relation.

```java
List<MyCommentDTO> tree = easyEntityQuery.queryable(Comment.class)
    .asTreeCTE()
    .selectAutoInclude(MyCommentDTO.class)
    .toList();
```

Use `@Navigate(ignoreAutoInclude = true)` on tree child relation if the DTO shape risks being treated as ordinary include.

## Include Override Rule

Docs say `selectAutoInclude` automatically performs include according to DTO information. If explicit include is already written, the handwritten include wins.

Source tests confirm this precedence. Use explicit `include(...)` first when
you need handcrafted `where/orderBy/limit` on a relation and still want
`selectAutoInclude` to assemble the DTO graph.

## Practical Checklist

Before writing `selectAutoInclude`:

- Result class is a DTO/VO, not a database entity.
- Entity and DTO have matching column/property mapping or explicit `@Navigate`/`@NavigateFlat`.
- To-many lists have enough key metadata for association.
- Extra nested filters or nested extra projections use
  `EXTRA_AUTO_INCLUDE_CONFIGURE`, not ad hoc post-processing.
- Tree child relation is ignored appropriately when using `asTreeCTE`.
- Expect multiple SQL statements for deep graphs; this is include-style
  structured loading, not one joined mega-select.
