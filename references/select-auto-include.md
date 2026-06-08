# selectAutoInclude

`selectAutoInclude` is the main DTO/VO structured-return API. Think
"auto-select root + include-style relation assembly", not "single joined
select".

## Basic Pattern

```java
List<SysBankDTO> list = easyEntityQuery.queryable(SysBank.class)
    .selectAutoInclude(SysBankDTO.class)
    .toList();
```

The DTO describes the returned object graph. It can include nested objects and lists when the shape has matching navigation metadata.

Execution shape:

- Root query selects DTO scalar fields plus hidden relation keys.
- Nested data is fetched by separate include-style relation queries.
- Deep graphs normally mean multiple SQL statements.
- Batching follows starter `relationGroupSize` default `512`.

## Extra Select Pattern

Use extra select when the DTO needs additional fields beyond automatic relation mapping.

```java
List<PostDTO> list = easyEntityQuery.queryable(Post.class)
    .selectAutoInclude(PostDTO.class, post -> Select.of(
        post.user().name().as(PostDTO.Fields.userName)
    ))
    .toList();
```

`replace = false` appends to auto select. `replace = true` replaces it.

## Critical Constraint

Do not pass a database entity class as the result class:

```java
// Bad
query.selectAutoInclude(SysUser.class);

// Good
query.selectAutoInclude(SysUserDTO.class);
```

Source has `SelectAutoIncludeTableEnum.THROW/WARNING/IGNORE`; default is
`THROW`.

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

Important distinction:

- For DTO/VO metadata used only by `selectAutoInclude`, the `@Navigate`
  annotation comment says defining `RelationTypeEnum` is the essential part and
  extra relation fields on non-entity objects may be ignored.
- If the DTO/VO proxy itself is navigated inside query DSL rather than only
  used as result metadata, verify `supportNonEntity = true` behavior in
  `entity-modeling-navigate.md`; otherwise runtime may throw
  `entityRelationToImplicitProvider is null...`.

If names or paths do not line up, use `entity-modeling-navigate.md`.

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
- Target should be a collection unless the final value is a basic type or
  entity.
- Field type must match the entity-path value.
- `prefix = true` turns the alias into a reusable path prefix.

## Extra Auto Include Configure

Source interface:

```java
EntityExtraAutoIncludeConfigure<TProxy, TEntity>
    .configure(queryable -> { ... })
    .where(proxy -> { ... })
    .select(proxy -> Select.of(...))
    .ignoreNavigateConfigure();
```

This hook is mainly for second-level-and-deeper DTO/VO relation tuning.
`@NavigateFlat` properties cannot have extra filters, but `@NavigateFlat`
objects can.

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
- `.ignoreNavigateConfigure()` ignores relation settings inherited from
  `@Navigate`.

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

If explicit `include(...)` is already written, it wins over auto include on the
same path.

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
