# API Map

Use this file only to confirm symbol names and choose the next reference.

## Entry Points

| Symbol | Purpose | Read Next |
|--------|---------|-----------|
| `EasyEntityQuery` | Default strong-typed proxy DSL client (`com.easy.query.api.proxy.client`) | `query.md` |
| `DefaultEasyEntityQuery` | Concrete `EasyEntityQuery` implementation (`com.easy.query.api.proxy.client`) | `setup-java.md`, `setup-kotlin.md` |
| `EasyQueryClient` | Weak-typed core client (`com.easy.query.core.api.client`) | local project first |
| `EasyQueryBootstrapper` | Bootstrap/build the client | `setup-java.md`, `setup-kotlin.md`, `setup-spring-boot.md` |

Common top-level methods:

`queryable(...)`, `insertable(...)`, `updatable(...)`, `deletable(...)`,
`savable(...)`, `beginTransaction()`, `sqlQuery(...)`, `sqlQueryMap(...)`,
`sqlExecute(...)`

## Entity and Mapping Symbols

| Symbol | Purpose | Read Next |
|--------|---------|-----------|
| `@Table` | Table mapping | `entity-mapping.md` |
| `@EntityProxy` | Generate `*Proxy` | `entity-mapping.md` |
| `@Column` | Column mapping options | `entity-mapping.md` |
| `@Version` | Optimistic lock | `write.md` |
| `@LogicDelete` | Logic delete | `write.md` |
| `@Navigate` | Relation metadata | `relation-query.md`, `entity-modeling-navigate.md` |
| `@NavigateFlat` | DTO/VO path flattening | `entity-modeling-navigate.md` |
| `ProxyEntityAvailable<TEntity, TProxy>` | Proxy-enabled entity contract (`com.easy.query.core.proxy`) | `entity-mapping.md` |
| `RelationTypeEnum` | Relation kind enum (`com.easy.query.core.enums`) | `relation-query.md` |
| `@ShardingTableKey` | Sharding route key | `advanced.md` |

## Query Chain Symbols

Normal query chain: `where(...)`, `where(condition, ...)`, `whereById(...)`,
`whereByIds(...)`, `orderBy(...)`, `select(...)`, `toList()`,
`firstOrNull()`, `singleOrNull()`, `findNotNull(...)`, `toPageResult(...)`,
`toChunk(...)`, `streamBy(...)`

## Predicate Symbols

Common operators:

- compare: `eq` `ne` `gt` `ge` `lt` `le`
- text: `like` `notLike` `startsWith` `endsWith` `contains`
- null/empty: `isNull` `isNotNull` `isBlank` `isNotBlank`
- set/range: `in` `notIn` `rangeClosed` and related range helpers
- composition: `or(() -> ...)` `and(() -> ...)`

## DTO Query Symbols

| Symbol | Purpose | Read Next |
|--------|---------|-----------|
| `whereObject(request)` | Query/search-form DTO filters; use for many optional form fields, not as a general query default | `dto-object-query.md` |
| `orderByObject(sort)` | Search-form DTO sort / request-driven sort | `dto-object-query.md` |
| `selectAutoInclude(ResultDTO.class)` | DTO graph result | `select-auto-include.md` |
| `@EasyWhereCondition` | Query-form filter metadata | `dto-object-query.md` |
| `ObjectSortBuilder` | Sort allowlist / builder API (`com.easy.query.core.api.dynamic.sort`) | `dto-object-query.md` |
| `anyColumn(...)` | Dynamic property path sort/filter helper | `dto-object-query.md` |

## EasySearch Symbols

| Symbol | Purpose | Read Next |
|--------|---------|-----------|
| `EasySearch.of(...)` | Search object factory (`com.easy.query.search`) | `easy-search.md` |
| `@EasyCond` | Search/filter/sort metadata (`com.easy.query.search.annotation`) | `easy-search.md` |

Typical chain:

`whereObject(search)` + `orderByObject(search)`

For non-form dynamic query composition, read `query.md` instead.

## Relation and Include Symbols

| Symbol | Purpose | Read Next |
|--------|---------|-----------|
| `.include(...)` | Load entity relations | `include-structured-loading.md` |
| `.include2(...)` | Complex nested include paths | `include-structured-loading.md` |
| `loadInclude(...)` | Load relations after query | `include-structured-loading.md` |
| `.subQueryToGroupJoin(...)` | To-many subquery group join | `implicit-query.md` |
| `.subQueryConfigure(...)` | Root-level baseline configuration for later relation subqueries | `implicit-controls.md` |
| `.asTreeCTE()` / `.asTreeCTECustom(...)` | Recursive tree query | `implicit-query.md` |
| `TreeCTEConfigurer.setUp(true)` | Upward recursion / ancestor backfill | `implicit-query.md` |
| `TreeCTEConfigurer.setChildFilter(...)` | Filter the recursive member, not just the seed rows | `implicit-query.md` |
| `TreeCTEConfigurer.setLimitDeep(...)` | Limit recursion depth | `implicit-query.md` |
| `TreeCTEConfigurer.setUnionAll(false)` | Use `UNION` instead of `UNION ALL` | `implicit-query.md` |
| `TreeCTEConfigurer.setDeepColumnName(...)` / `setDeepInCustomSelect(true)` | Control or retain depth column in tree results | `implicit-query.md` |
| `.leftJoin(...)` / `.innerJoin(...)` | Explicit join | `query-composition.md` |

If the result target is a DTO graph, prefer `selectAutoInclude(...)` before
`include(...)`.

## Implicit Control Symbols

| Symbol | Purpose | Read Next |
|--------|---------|-----------|
| `.filter(...)` on relation path | To-many baseline filter or to-one `JOIN ON` filter | `implicit-controls.md` |
| `.configure(...)` on relation path | Relation subquery-level options such as alias or logic-delete behavior | `implicit-controls.md` |
| `.mode(SubQueryModeEnum...)` | Force local subquery strategy | `implicit-controls.md` |
| `SubQueryModeEnum.DEFAULT` | Leave default strategy | `implicit-controls.md` |
| `SubQueryModeEnum.SUB_QUERY_ONLY` | Force subquery | `implicit-controls.md` |
| `SubQueryModeEnum.GROUP_JOIN` | Force group join | `implicit-controls.md` |
| `.any()` / `.any(...)` | Exists / any matched related row | `implicit-controls.md` |
| `.none()` / `.none(...)` | No related row / no matched related row | `implicit-controls.md` |
| `.all(...)` | Every row in the current relation slice passes | `implicit-controls.md` |
| `.first()` | First ranked child in a relation slice | `implicit-query.md` |
| `.element(index)` | Zero-based nth ranked child | `implicit-query.md` |
| `.elements(start,end)` | Zero-based inclusive ranked child window | `implicit-query.md` |
| `.joining(...)` on relation chain | Concatenate relation rows, often after `orderBy(...)` / `elements(...)` | `implicit-query.md` |
| `.flatElement()` | Flatten to-many path for traversal or `toList(...)` | `implicit-controls.md` |
| `.notEmptyAll(...)` | Non-empty and every matched row passes | `implicit-controls.md` |
| `.distinct()` on relation chain | Keep distinctness inside implicit subquery | `implicit-controls.md` |
| `expression().valueOf(...)` | Project arbitrary predicate as boolean column | `implicit-controls.md` |

## Select and Projection Symbols

Useful projection helpers:

`Select.of(...)`, `Select.DRAFT`, `Select.TUPLE`, `Select.PART`,
`Select.aggregateOf(...)`, `FETCHER`

Read `query.md` for normal select, `query-composition.md` for advanced
projection, and `select-auto-include.md` for DTO graphs.

## Write, Transaction, and Save Symbols

| Symbol | Purpose | Read Next |
|--------|---------|-----------|
| `insertable(...)` | Insert rows | `write.md` |
| `updatable(...)` | Update rows | `write.md` |
| `deletable(...)` | Delete rows | `write.md` |
| `withVersion(...)` / `ignoreVersion()` | Version handling | `write.md` |
| `disableLogicDelete()` / `allowDeleteStatement(true)` | Physical delete opt-in | `write.md` |
| `beginTransaction()` | Plain transaction API returning `Transaction` (`com.easy.query.core.basic.jdbc.tx`) | `transaction.md` |
| `@Transactional` | Spring transaction boundary | `transaction.md` |
| `savable(...)` | Aggregate graph save | `savable-aggregate.md` |

## Advanced Symbols

| Symbol | Purpose | Read Next |
|--------|---------|-----------|
| `groupBy(...)` / `GroupKeys.of(...)` | Group query (`com.easy.query.core.proxy.sql.GroupKeys`) | `advanced.md` |
| `getDatabaseCodeFirst()` | Code-first DDL | `advanced.md` |
| `applyShardingInitializer(...)` | Sharding registration | `advanced.md` |
| `EasyMultiEntityQuery.executeScope(...)` | Multi-datasource scope | `advanced.md` |

## Starter and Config Symbols

High-impact defaults often referenced in code review:

`insertStrategy = ONLY_NOT_NULL_COLUMNS`, `updateStrategy = ALL_COLUMNS`,
`defaultCondition = LIKE`, `autoIncludeTable = THROW`,
`relationGroupSize = 512`, `includeLimitMode = PARTITION`

Read `configuration-starter.md` when behavior seems different from the written
query code.
