---
name: easy-query-orm
description: >-
  Write, modify, review, debug, or test Java/Kotlin code that uses the
  easy-query ORM (`com.easy-query`) through `EasyEntityQuery`,
  `EasyQueryClient`, or the generated proxy DSL. Use when tasks involve
  easy-query setup, proxy generation, Spring Boot integration, queries, CRUD,
  pagination, transactions, implicit relation queries (`subQueryToGroupJoin`,
  `subQueryConfigure`, `flatElement`, `first`/`element`/`elements`, `joining`,
  `anyValue`/`noneValue`, `notEmptyAll`),
  `@Navigate`/`@NavigateFlat`/`include`/`include2`/`selectAutoInclude`,
  `EXTRA_AUTO_INCLUDE_CONFIGURE`, proxy DTO relation projection with
  `.set(user.relation(), ...)`, `whereObject`, `orderByObject`, `EasySearch`,
  `savable`, native SQL, sharding, multi-datasource, code-first DDL, or
  troubleshooting easy-query-specific API/build issues. Trigger even when the
  user does not name easy-query but the code clearly uses its proxy DSL or asks
  to migrate MyBatis/JPA code to easy-query. Do not use for other ORMs or
  query builders unless converting them to easy-query.
---

# Easy Query ORM

Write compilable, idiomatic easy-query code from verified patterns. Prefer the
bundled references over inference, and prefer the user's project over the
bundled references when they disagree.

This file is the index. Load only the one or two references that match the
task; do not read the whole `references/` tree by default.

## Core Rules

1. Default to `EasyEntityQuery` and the generated proxy DSL unless the project
   is clearly on the weak-typed `EasyQueryClient` path.
2. Treat missing `*Proxy` classes as build/config problems first. Java uses
   APT; Kotlin uses KSP, not KAPT.
3. Do not invent easy-query API names from generic ORM habits. Look them up in
   `references/api-map.md` or `scripts/search_references.py`.
4. Use gated overloads for optional filters such as `.eq(condition, value)` or
   `where(condition, o -> ...)`; never build string SQL conditions for normal
   dynamic filters.
5. Treat `whereObject(...)` as a search-form tool, not a general query default.
   Use it when the task is clearly a query/search form with many optional
   request fields. For non-form dynamic query logic, stay with gated DSL first.
6. For search-form page endpoints, filters may use `whereObject(...)` while
   sorting stays explicit `orderBy(...)`. Do not force `orderByObject(...)`
   unless the request already implements `ObjectSort` or the project already
   has a sort helper.
7. If the user asks for example code and does not point to a concrete target
   project path/file, do not recursively scan the whole workspace looking for
   placeholder types such as `PageResult`, `UserListDTO`, or sort helpers.
   Answer from bundled references and clearly mark project-local wrapper/helper
   substitutions.
8. Keep pagination stable with `orderBy(...)` plus a tie-breaker when the sort
   key is not unique.
9. Treat update/delete row count `0` as a meaningful signal, not silent
   success.
10. For advanced relation loading, DTO projection, and aggregate persistence,
    follow the dedicated references instead of guessing from the base query DSL.
11. Separate entity-side relation metadata from DTO/VO-side auto-include
    metadata. `selectAutoInclude` may use DTO `@Navigate`/`@NavigateFlat`, but
    non-entity proxy navigation in query DSL needs verified `supportNonEntity`
    behavior instead of assumption.
12. For to-many implicit partition APIs such as `first()`, `element(...)`, and
    `elements(...)`, require deterministic ordering from `orderBy(...)`,
    `orderByProps`, or an explicit `partitionOrder` policy.

## Workflow

1. Classify the task first: setup, entity mapping, query, relation loading,
   write/transaction, advanced business query, troubleshooting, or review.
2. Read one core reference first. Read one advanced reference only when the
   task actually needs it.
3. For search-form page endpoints that combine optional filters, sorting,
   pagination, and DTO graph return, read `references/search-form-page.md`
   first. Do not open `api-map.md`, `include-structured-loading.md`,
   `entity-modeling-navigate.md`, or `troubleshooting.md` first for that shape.
4. For setup or proxy-generation problems, read only the matching setup file
   first:
   - Kotlin / `ksp` / `kapt` / missing `*Proxy`: `references/setup-kotlin.md`
   - Plain Java / Maven / APT / missing `*Proxy`: `references/setup-java.md`
   - Spring Boot bean/config/starter issues: `references/setup-spring-boot.md`
   Read `entity-mapping.md` only if the entity annotations themselves look wrong.
   Do not open `troubleshooting.md` first for setup questions.
5. If the exact symbol is unclear, search before emitting code:
   `python scripts/search_references.py include2 selectAutoInclude`.
6. If the bundled references still do not cover a method, inspect the target
   project or source before using it.

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
| Advanced query composition: explicit joins, manual subquery, proxy `.set(...)` relation projection, draft/tuple, native fragments, tracking | `references/query-composition.md` |
| Implicit relation queries, `flatElement`, group joins, nested `subQueryConfigure`, `filter`/`mode`, `first/element/elements`, `joining`, tree/partition/case patterns | `references/implicit-query.md` |
| Search/page form endpoint: optional filters + stable sort + DTO graph result | `references/search-form-page.md` |
| Query/search-form DTO filters/sorts via `whereObject` and `orderByObject` | `references/dto-object-query.md` |
| User-management / admin-search / multi-condition search form endpoint | `references/dto-object-query.md` first, then add DSL only where needed |
| `EasySearch` and `@EasyCond`-driven search/sort | `references/easy-search.md` |
| `selectAutoInclude`, DTO-side `@Navigate`/`@NavigateFlat`, `EXTRA_AUTO_INCLUDE_CONFIGURE`, explicit-include precedence | `references/select-auto-include.md` |
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

- Reject MyBatis-Plus `QueryWrapper`, JPA `CriteriaBuilder`, QueryDSL, jOOQ,
  or other non-easy-query syntax unless the task is explicit migration.
- Prefer `singleOrNull()` over `firstOrNull()` when the business key is unique.
- Push filtering, sorting, paging, and aggregation into the DSL instead of
  doing them in memory.
- Do not return persistence entities directly from controller/API boundaries
  when DTO/VO shapes are expected.
- Do not pass entity classes to `selectAutoInclude`; use DTO/VO result types.
- Prefer `include2` for more complex nested relation loading.
- For `savable`, update tracked aggregates inside a transaction; do not diff-save
  freshly constructed request payloads.
- For physical deletes, require an explicit, complete `where` and the needed
  opt-in flags.

## Evidence Policy

Order of truth:

1. The user's current project: build file, easy-query version, generated proxy
   setup, entities, failing code, and errors.
2. Verified patterns in these references.
3. If neither covers the case, say so plainly instead of inventing API.

Reference coverage is based on easy-query source, tests, and official docs. If
the project version differs from the reference version, prefer the project and
flag any API that may have moved.

## Output

Lead with working code. Mention the relevant reference only when it helps
justify a non-obvious API choice, SQL-shape consequence, or version caveat.
