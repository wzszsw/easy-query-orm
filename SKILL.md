---
name: easy-query-orm
description: >-
  Use when Java/Kotlin code uses easy-query (`EasyEntityQuery`,
  `EasyQueryClient`, proxy DSL), when the user shows easy-query proxy syntax,
  or when migrating JPA/MyBatis to easy-query. Covers setup, proxy generation,
  missing `*Proxy` troubleshooting, AP / OLAP-style analytics,
  `groupBy` / `having`, conditional aggregate filters, implicit
  `subQueryToGroupJoin`, CTE / UNION / window functions, Maven APT / Kotlin
  KSP diagnosis, `annotationProcessorPaths`, generated-sources visibility, ValueConverter / ValueAutoConverter / TypeHandler, Interceptor, LogicDelete, Spring Boot, CRUD/query/page/transaction code, implicit relation APIs
  (`any`/`all`/`none`, `subQueryToGroupJoin`, `subQueryConfigure`,
  `flatElement`, `first`/`element`/`elements`, `joining`,
  `anyValue`/`noneValue`, `notEmptyAll`), `@Navigate`/`@NavigateFlat`/`include`/`include2`/
  `selectAutoInclude`, `EXTRA_AUTO_INCLUDE_CONFIGURE`, proxy VO relation
  `.set(...)`, `whereObject`/`orderByObject`, `EasySearch`, `savable`,
  sharding, code-first DDL, and troubleshooting. Do not use for unrelated
  ORMs.
---

# Easy Query ORM

Write compilable easy-query code from verified patterns.

Use this file only as the router. Open one primary reference first. Add at
most one secondary reference when a boundary rule below says it is needed.

## Operating Rules

1. Default to `EasyEntityQuery` and proxy DSL unless the project clearly uses
   weak-typed `EasyQueryClient`.
2. Missing `*Proxy` usually means setup or compile-chain trouble first. Java
   uses APT; Kotlin uses KSP, not KAPT.
3. `@EntityProxy` is the generation trigger. `ProxyEntityAvailable` helps with
   typed proxy usage but is not the switch that makes APT/KSP generate the
   class.
4. For proxy-generation failures, diagnose by layer: generation mode,
   processor wiring, generated output path, then the first real compile error.
   Do not stop at `package xxx.proxy does not exist`.
5. Never invent easy-query API names. Search `references/api-map.md` or
   `scripts/search_references.py` first.
6. For AP/reporting work, keep dimensions, grouped aggregates, partition
   ranks, and union branches in SQL DSL. Prefer explicit `groupBy` / `having`
   first; switch to `subQueryToGroupJoin` when repeated to-many relation
   metrics would otherwise emit many correlated subqueries.
7. easy-query leans heavily on relation metadata. If the requirement can be
   derived from an existing relation path, prefer the relation-driven form
   first: implicit navigation, `flatElement`, relation aggregate/predicate.
   For tree answers, express the real root rule first, then apply recursive
   filtering or ancestor backfill only where needed. Fall back to explicit
   join, junction-table query, or post-query assembly only when the needed
   `@Navigate` path is missing or clearly insufficient.
8. Prefer gated DSL for optional filters. Use `whereObject(...)` only for
   search-form DTOs.
9. Keep paging stable with explicit `orderBy(...)` and a tie-breaker.
10. Treat row count `0` as meaningful.
11. Distinguish entity relation metadata from DTO/VO auto-include metadata.
12. If the project version differs from the reference version, prefer the
    project and say which API or behavior may have moved.

## Triage

1. Classify first: setup/runtime, mapping/modeling, query/search,
   relation/implicit, write/cross-cutting, AP/reporting, troubleshooting, or
   review.
2. Open one primary reference from `Routing by Area`.
3. Add one secondary reference only when a `Pair with ...` clause applies.
4. Use `references/api-map.md` only when the exact symbol or package name is
   unclear.
5. Use `references/troubleshooting.md` only after a primary feature reference
   is already known, or when code compiles but behaves differently from the
   expected feature semantics.

## Canonical Boundaries

- Spring Boot stack:
  `setup-spring-boot.md` is for dependency/basic wiring and bean injection;
  `spring-boot-starter.md` is for auto-configuration topology, collected
  extension beans, `StarterConfigurer`, `@EasyQueryTrack`, and
  multi-datasource starter limits; `configuration-starter.md` is for property
  defaults and behavior drift.
- Query stack:
  `query.md` is for ordinary root DSL; `query-composition.md` is for explicit
  joins, manual subqueries, advanced projection, and proxy VO relation
  `.set(...)`; `functions-native-sql.md` is only for function helpers or raw
  SQL fragments.
- Relation metadata vs result loading:
  `relation-query.md` is for `@Navigate` direction/cardinality;
  `entity-modeling-navigate.md` is for advanced navigate metadata,
  DTO-side navigation, and `@NavigateFlat`;
  `include-structured-loading.md` is for entity relation loading;
  `select-auto-include.md` is for DTO/VO structured return.
- Implicit relation stack:
  `implicit-query.md` is for capabilities such as implicit join, group join,
  ranked child, and tree;
  `implicit-controls.md` is for quantifiers and control knobs such as
  `any/all/none/notEmptyAll/filter/configure/mode/subQueryConfigure/flatElement`.
- Search-form stack:
  `search-form-page.md` is for end-to-end page endpoints;
  `dto-object-query.md` is for
  `whereObject/orderByObject/@EasyWhereCondition` semantics;
  `easy-search.md` is only for `sql-search` / `EasySearch` / `@EasyCond`.

## Routing By Area

### Setup & Runtime

- Missing `*Proxy`, `package ...proxy does not exist`, APT/KSP not firing,
  generated-sources visibility, `annotationProcessorPaths`, `javacTree`,
  Lombok/JDK processor crashes:
  `references/proxy-generation-troubleshooting.md`.
  Pair with `references/setup-java.md`, `references/setup-kotlin.md`, or
  `references/setup-spring-boot.md`.
- Plain Java + Maven/APT wiring and manual bootstrap:
  `references/setup-java.md`.
- Kotlin + Gradle + KSP wiring:
  `references/setup-kotlin.md`.
- Spring Boot dependency/basic wiring/client injection:
  `references/setup-spring-boot.md`.
  Pair with `references/spring-boot-starter.md` only for starter internals.
- Spring Boot starter topology, `EasyQueryInitializeOption`,
  `StarterConfigurer`, collected extension beans, `@EasyQueryTrack`,
  multi-datasource starter limits:
  `references/spring-boot-starter.md`.
  Pair with `references/configuration-starter.md` only for property impact.
- Starter defaults, `easy-query.enable` / `easy-query.build`, or behavior
  drift from code:
  `references/configuration-starter.md`.
- Code-first DDL, sharding, multi-datasource runtime scope:
  `references/advanced.md`.

### Mapping & Result Shape

- Entity annotations, `@EntityProxy`, `@Column`, `@Version`, `@LogicDelete`:
  `references/entity-mapping.md`.
- Fix `@Navigate` cardinality/direction or a missing relation path:
  `references/relation-query.md`.
- Advanced relation metadata, DTO-side navigation, `@NavigateFlat`,
  navigate extras:
  `references/entity-modeling-navigate.md`.
- Entity graph loading with `include`, `include2`, `loadInclude`,
  `fillOne/fillMany`:
  `references/include-structured-loading.md`.
- DTO/VO structured return with `selectAutoInclude`, extras, and include
  override precedence:
  `references/select-auto-include.md`.

### Read Query & Search

- Ordinary filter/order/select/page/terminal query chains:
  `references/query.md`.
- Explicit joins, advanced projection, draft/tuple, manual subquery, or proxy
  VO relation `.set(...)`:
  `references/query-composition.md`.
- SQL functions, expression helpers, or native SQL fragments:
  `references/functions-native-sql.md`.
- Implicit relation capabilities: implicit join, scalar subquery, group join,
  ranked child, tree:
  `references/implicit-query.md`.
- Quantifiers and relation control knobs such as
  `any/all/none/notEmptyAll/subQueryConfigure/filter/configure/mode/flatElement/valueOf`:
  `references/implicit-controls.md`.
  Pair with `references/implicit-query.md` when partition/tree/group-join
  behavior matters.
- AP/reporting, grouped aggregates, conditional metrics, CTE/window, UNION:
  `references/ap-analytics.md`.
  Pair with `references/implicit-query.md` for repeated to-many relation
  metrics or relation-derived dimensions.
- Search/page form endpoints with optional filters, stable sort, and DTO graph
  return:
  `references/search-form-page.md`.
- `whereObject(...)`, `orderByObject(...)`, `@EasyWhereCondition`,
  relation-path filters, `ObjectSortBuilder`, `WhereObjectQueryExecutor`:
  `references/dto-object-query.md`.
- `EasySearch`, `@EasyCond`, `sql-search` operator inference:
  `references/easy-search.md`.

### Write & Cross-Cutting

- Insert/update/delete semantics, optimistic lock, physical delete safety:
  `references/write.md`.
- Plain transaction API or Spring `@Transactional`:
  `references/transaction.md`.
- Aggregate graph save with `savable(...)`:
  `references/savable-aggregate.md`.
- Value conversion, auto conversion, enum/json mapping, `JdbcTypeHandler`,
  PostgreSQL `jsonb`:
  `references/value-conversion-type-handler.md`.
- Interceptors, tenant/audit/data-permission,
  `useInterceptor(...)` / `noInterceptor(...)`:
  `references/interceptor.md`.
- Logic delete strategies, toggles, table-local disable, physical delete
  escape hatch:
  `references/logic-delete.md`.

### Support

- Exact symbol/package lookup or "does this API name exist":
  `references/api-map.md`.
- Unit test shapes for repositories/services or SQL-shape assertions:
  `references/testing.md`.
- Common non-obvious failure modes after the primary feature path is already
  known:
  `references/troubleshooting.md`.

## Review Checks

- Reject non-easy-query syntax unless the task is explicit migration.
- Prefer relation-driven answers before explicit join or link-table queries when
  an existing `@Navigate` path can express the requirement.
- For tree answers, express the real root predicate first instead of teaching a
  default `query ids first -> .in(...) -> build tree` template.
- Prefer `singleOrNull()` for unique business keys.
- Push filter/sort/page/aggregate work into DSL.
- Use DTO/VO result types for `selectAutoInclude`.
- Prefer `include2` for more complex nested relation loading.
- Do not claim `ProxyEntityAvailable` is required for proxy generation unless
  the project specifically requires interface mode for usage style.
- For AP/reporting answers, prefer DSL aggregation / CTE / UNION / partition
  APIs over Java Stream regrouping, manual SQL strings, or post-query
  in-memory metrics.
- Keep grouped projections group-aware: non-key fields should come from
  aggregate expressions, grouped proxy access, or explicit window outputs.
- Do not recommend `JdbcTypeHandler` when an in-memory `ValueConverter` is
  sufficient.
- Do not recommend `ValueConverter` alone when the real problem is JDBC
  binding/driver behavior such as PostgreSQL `jsonb` `PGobject` writes.
- Prefer interceptor abstraction for cross-cutting tenant, audit, and
  data-permission rules instead of repeating ad hoc where/set logic in every
  service.
- State `useInterceptor(...)` / `noInterceptor(...)` semantics precisely:
  `useInterceptor(name)` does not mean “only this one”, and
  `ProtectedInterceptor` survives global `noInterceptor()` unless removed by
  `noInterceptor(name)`.
- Separate soft-delete semantics from physical delete semantics; do not teach
  `disableLogicDelete()` as a harmless default.
- Mention `tableLogicDelete(...)` and relation
  `.configure(q -> q.disableLogicDelete())` when only part of a query graph
  should ignore logical delete.
- For Spring Boot starter answers, do not claim `easy-query.enable: true` is
  mandatory unless the project version proves a different condition
  implementation.
- For Spring Boot extension registration, do not claim a plain
  `JdbcTypeHandler` bean auto-binds globally; mention
  `JdbcTypeHandlerReplaceConfigurer`.
- For Spring Boot multi-datasource answers, remember that the default starter
  build path injects a single `DataSource`; recommend `@Primary` only when one
  default client is acceptable, otherwise use custom beans or
  `easy-query.build=false`.
## Evidence Policy

Order of truth:

1. Current project state.
2. Verified patterns in these references.
3. If neither covers the case, say so plainly instead of inventing API.

If the project version differs from the reference version, prefer the project
and flag APIs that may have moved.

## Output

Lead with working code. For troubleshooting, lead with the first failing layer
and the next concrete check or fix. For AP/reporting, state the
`dimension -> metric -> filter -> rank/union/cte` shape before dropping into
code when that framing prevents wrong SQL structure. Cite a reference only for
non-obvious API, SQL-shape, or version caveat.

