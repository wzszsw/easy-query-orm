---
name: easy-query-orm
description: >-
  Use when Java/Kotlin code uses easy-query (`EasyEntityQuery`,
  `EasyQueryClient`, proxy DSL), when the user shows easy-query proxy syntax,
  or when migrating JPA/MyBatis to easy-query. Covers setup, proxy generation,
  Spring Boot, CRUD/query/page/transaction code, implicit relation APIs
  (`subQueryToGroupJoin`, `subQueryConfigure`, `flatElement`,
  `first`/`element`/`elements`, `joining`, `anyValue`/`noneValue`,
  `notEmptyAll`), `@Navigate`/`@NavigateFlat`/`include`/`include2`/
  `selectAutoInclude`, `EXTRA_AUTO_INCLUDE_CONFIGURE`, proxy VO relation
  `.set(...)`, `whereObject`/`orderByObject`, `EasySearch`, `savable`,
  sharding, code-first DDL, and troubleshooting. Do not use for unrelated
  ORMs.
---

# Easy Query ORM

Write compilable easy-query code from verified patterns.

This file is the index. Load only the one or two references that match the
task; do not read the whole `references/` tree by default.

## Core Rules

1. Default to `EasyEntityQuery` and proxy DSL unless the project clearly uses
   weak-typed `EasyQueryClient`.
2. Missing `*Proxy` usually means setup trouble first. Java uses APT; Kotlin
   uses KSP, not KAPT.
3. Never invent easy-query API names. Search `references/api-map.md` or
   `scripts/search_references.py` first.
4. Prefer gated DSL for optional filters. Use `whereObject(...)` only for
   search-form DTOs.
5. Keep paging stable with explicit `orderBy(...)` and a tie-breaker.
6. Treat row count `0` as meaningful.
7. Distinguish entity relation metadata from DTO/VO auto-include metadata.

## Workflow

1. Classify first: setup, mapping, query, relation loading, write, control
   API, troubleshooting, or review.
2. Read one core reference first. Add a second only when needed.
3. For `flatElement`, relation `filter/configure/mode`,
   `subQueryConfigure`, `notEmptyAll`, or `valueOf`, read
   `references/implicit-controls.md` first. If the request names an exact
   control symbol or enum such as `SubQueryModeEnum`, also open
   `references/api-map.md`.
4. For search-form page endpoints with filters + sort + paging + DTO graph,
   read `references/search-form-page.md` first.
5. For setup or proxy-generation problems, read only the matching setup file
   first:
   - Kotlin / `ksp` / `kapt` / missing `*Proxy`: `references/setup-kotlin.md`
   - Plain Java / Maven / APT / missing `*Proxy`: `references/setup-java.md`
   - Spring Boot bean/config/starter issues: `references/setup-spring-boot.md`
6. Search before emitting code when the exact symbol is unclear.

## Routing Table

| Task | Read |
|------|------|
| Set up Kotlin + KSP + entity/proxy generation | `references/setup-kotlin.md` |
| Set up plain Java + Maven/APT + proxy generation | `references/setup-java.md` |
| Integrate with Spring Boot starter or fix bean/config registration | `references/setup-spring-boot.md` |
| Check starter defaults and behavior-affecting config | `references/configuration-starter.md` |
| Define entity annotations and proxy model | `references/entity-mapping.md` |
| Declare entity relations and fix `@Navigate` direction/cardinality | `references/relation-query.md` |
| Model advanced `@Navigate` options, `@NavigateFlat`, DTO-side navigation | `references/entity-modeling-navigate.md` |
| Basic query chain: `where`, order, projection, pagination, terminals | `references/query.md` |
| Advanced projection / manual subquery / proxy relation `.set(...)` | `references/query-composition.md` |
| Implicit relation basics: group, partition, joining, tree | `references/implicit-query.md` |
| Implicit controls: `subQueryConfigure`, `filter/configure/mode`, `flatElement`, `notEmptyAll`, `valueOf`, `SubQueryModeEnum` | `references/implicit-controls.md` |
| Search/page form endpoint: optional filters + stable sort + DTO graph result | `references/search-form-page.md` |
| Query/search-form DTO filters/sorts via `whereObject` and `orderByObject` | `references/dto-object-query.md` |
| User-management / admin-search / multi-condition search form endpoint | `references/dto-object-query.md` first, then add DSL only where needed |
| `EasySearch` and `@EasyCond`-driven search/sort | `references/easy-search.md` |
| `selectAutoInclude`, DTO-side `@Navigate`/`@NavigateFlat`, extras, include precedence | `references/select-auto-include.md` |
| Structured loading with `include`, `include2`, `loadInclude`, `fillOne/fillMany` | `references/include-structured-loading.md` |
| Insert/update/delete and write safety semantics | `references/write.md` |
| Transactions in plain Java or Spring Boot | `references/transaction.md` |
| Aggregate root save with `savable` | `references/savable-aggregate.md` |
| SQL functions, expressions, native SQL fragments | `references/functions-native-sql.md` |
| GroupBy, code-first DDL, sharding, multi-datasource | `references/advanced.md` |
| Unit tests for repositories/services and SQL behavior | `references/testing.md` |
| Exact symbol/package lookup | `references/api-map.md` |
| Common easy-query pitfalls and constraints | `references/troubleshooting.md` |

## Review Checks

- Reject non-easy-query syntax unless the task is explicit migration.
- Prefer `singleOrNull()` for unique business keys.
- Push filter/sort/page/aggregate work into DSL.
- Use DTO/VO result types for `selectAutoInclude`.
- Prefer `include2` for more complex nested relation loading.

## Evidence Policy

Order of truth:

1. Current project state.
2. Verified patterns in these references.
3. If neither covers the case, say so plainly instead of inventing API.

If the project version differs from the reference version, prefer the project
and flag APIs that may have moved.

## Output

Lead with working code. Cite a reference only for non-obvious API, SQL-shape,
or version caveat.
