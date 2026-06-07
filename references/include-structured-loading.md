# Include and Structured Loading

Use this reference when returning object graphs, loading relations after a query, or choosing between `include`, `include2`, `fillOne/fillMany`, and `selectAutoInclude`.

## Decision Guide

- Use `selectAutoInclude(ResultDTO.class)` for structured DTO/VO result graphs. It is the strongest structured return path and can infer relation loading from DTO shape.
- Use `include(...)` when the root query returns database entity objects and the relation fields on those entities should be populated.
- Use `include2(...)` for complex nested include paths, especially when paths cross collection elements and need per-path filters.
- Use `fillOne/fillMany` for arbitrary programmatic nesting when include/DTO metadata is not a good fit. The returned objects must contain the relation keys needed to match records.
- Use `loadInclude(...)` when entities are already loaded and relation fields should be populated later.

Doc evidence: `easy-query-doc/src/include/README.md`, `easy-query-doc/src/include/fetcher.md`.

## include

Proxy include signatures support:

```java
query.include(root -> root.relation());
query.include(root -> root.relation(), relationQuery -> {
    relationQuery.where(r -> r.name().contains(name));
    relationQuery.orderBy(r -> r.createTime().desc());
    relationQuery.limit(5);
});
query.include(root -> root.relation(), 100);
query.include(root -> root.relation(), relationQuery -> {
    relationQuery.asTracking().disableLogicDelete();
}, 100);
```

`groupSize` controls how many relation ids are fetched per relation query group. Starter default `relationGroupSize` is `512`.

Important behavior:

- `include` runs independent relation queries, not one big joined result.
- If differential update/tracking matters, configure tracking on relation subqueries too, for example `asTracking()`.
- Relation subqueries can use `where`, `orderBy`, `limit`, `asTracking/asNoTracking`, and `disableLogicDelete`.
- `include` is for returning database object instances. For DTO object graphs, prefer `selectAutoInclude`.

## include2

`include2` is available in the proxy API and the docs describe it as the preferred replacement for complex nested include cases in `3.1.47+`.

Pattern:

```java
List<SchoolClass> rows = easyEntityQuery.queryable(SchoolClass.class)
    .include2((ctx, schoolClass) -> {
        ctx.query(schoolClass.schoolTeachers().flatElement().schoolClasses())
            .where(c -> c.name().contains("science"));
        ctx.query(schoolClass.schoolStudents())
            .where(s -> s.name().ne("test"))
            .orderBy(s -> s.createTime().asc())
            .limit(5);
        ctx.query(schoolClass.schoolStudents().flatElement().schoolClass());
    })
    .toList();
```

Rules:

- `ctx.query(...)` accepts a navigation path from the root proxy. The path may be a to-one object, a to-many collection, or a collection path traversed with `flatElement()`.
- Conditions after `ctx.query(path)` apply to the final relation query on that path.
- Prefer `include2` over old `includes(...)`; source comments on `EntityIncludesable1` point users to `EntityIncludeable1#include2(...)`.

Source evidence: `EntityIncludeable1`, `EntityIncludesable1`.

## loadInclude

Use `loadInclude` when the root objects were already loaded:

```java
List<User> users = easyEntityQuery.queryable(User.class)
    .where(u -> u.status().eq(UserStatus.ACTIVE))
    .toList();

easyEntityQuery.loadInclude(users, u -> u.bankCards());
```

This is useful in service flows where the root set is produced by another branch, then relation loading is conditional.

## fillOne/fillMany

Docs describe `fillOne/fillMany` as able to handle arbitrary programmatic nesting, with one critical requirement: both sides must expose enough key columns to match parent and child rows.

Use this when:

- Relation metadata is unavailable or intentionally not modeled.
- A query returns a custom DTO shape but still needs in-memory relation assembly.
- Relation selection is too custom for `include`.

Avoid it when `selectAutoInclude` or `include2` can express the same graph with existing navigation metadata.

## Relation Null Values

Relation include skips relation queries when relation key values are null or blank by default. Docs show `RelationNullValueValidator` can be replaced if application-specific placeholder values like `"-"` or `"/"` should also be treated as null relation keys.

## Troubleshooting

- If an included relation is not populated, check `@Navigate` direction and key fields first.
- If a to-one relation maps only one of several matching rows, verify relation type. Many rows pointing to the same target is usually `ManyToOne`, not `OneToOne`.
- If include results are not tracked, add `asTracking()` in the include adapter or enable default tracking.
- If DTO fields are missing, use `selectAutoInclude` or explicit `Select.of(...)`; `include` populates entity relation properties, not arbitrary DTO extra fields.
