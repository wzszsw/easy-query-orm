# API Map

Use this file only to confirm symbol names and decide which reference to read
 next. Do not treat it as the main coding guide.

## Entry Points

| Symbol | Purpose | Read Next |
|--------|---------|-----------|
| `EasyEntityQuery` | Default strong-typed proxy DSL client (`com.easy.query.api.proxy.client`) | `query.md` |
| `DefaultEasyEntityQuery` | Concrete `EasyEntityQuery` implementation (`com.easy.query.api.proxy.client`) | `setup-java.md`, `setup-kotlin.md` |
| `EasyQueryClient` | Weak-typed core client (`com.easy.query.core.api.client`) | local project first |
| `EasyQueryBootstrapper` | Bootstrap/build the client | `setup-java.md`, `setup-kotlin.md`, `setup-spring-boot.md` |

Common top-level methods:

- `queryable(...)`
- `insertable(...)`
- `updatable(...)`
- `deletable(...)`
- `savable(...)`
- `beginTransaction()`
- `sqlQuery(...)`
- `sqlQueryMap(...)`
- `sqlExecute(...)`

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

Normal query chain:

- `where(...)`
- `where(condition, ...)`
- `whereById(...)`
- `whereByIds(...)`
- `orderBy(...)`
- `orderByAsc(...)`
- `orderByDesc(...)`
- `select(...)`
- `toList()`
- `firstOrNull()`
- `singleOrNull()`
- `findNotNull(...)`
- `toPageResult(...)`
- `toChunk(...)`
- `streamBy(...)`

Read `query.md` first for normal query writing.

## Predicate Symbols

Common operators:

- Compare: `eq` `ne` `gt` `ge` `lt` `le`
- Like/text: `like` `notLike` `startsWith` `endsWith` `contains`
- Null/empty: `isNull` `isNotNull` `isEmpty` `isNotEmpty` `isBlank` `isNotBlank`
- Set: `in` `notIn`
- Range: `rangeOpenClosed` `rangeOpen` `rangeClosedOpen` `rangeClosed`
- Composition: `or(() -> ...)` `and(() -> ...)`

Read `query.md` for ordinary conditions. Read `functions-native-sql.md` only if
 you need `sqlSegment`, raw SQL fragments, or typed expression helpers.

## DTO Query Symbols

| Symbol | Purpose | Read Next |
|--------|---------|-----------|
| `whereObject(request)` | Query-form / request-object driven filters; preferred for large search forms | `dto-object-query.md` |
| `orderByObject(sort)` | DTO-driven sort | `dto-object-query.md` |
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

- `whereObject(search)`
- `orderByObject(search)`

For ordinary backend search/list pages, prefer `whereObject(queryForm)` before
writing a long manual gated DSL chain.

## Relation and Include Symbols

| Symbol | Purpose | Read Next |
|--------|---------|-----------|
| `.include(...)` | Load entity relations | `include-structured-loading.md` |
| `.include2(...)` | Complex nested include paths | `include-structured-loading.md` |
| `loadInclude(...)` | Load relations after query | `include-structured-loading.md` |
| `.subQueryToGroupJoin(...)` | To-many subquery group join | `implicit-query.md` |
| `.asTreeCTE()` | Recursive tree query | `implicit-query.md` |
| `.leftJoin(...)` / `.innerJoin(...)` | Explicit join | `query-composition.md` |

If the result target is a DTO graph, prefer `selectAutoInclude(...)` before
 `include(...)`.

## Select and Projection Symbols

Useful projection helpers:

- `Select.of(...)` (`com.easy.query.core.proxy.sql`)
- `Select.DRAFT` (`com.easy.query.core.proxy.sql`)
- `Select.TUPLE` (`com.easy.query.core.proxy.sql`)
- `Select.PART`
- `Select.aggregateOf(...)`
- `FETCHER`

Read `query.md` for normal select, `query-composition.md` for draft/tuple or
 explicit advanced projection, and `select-auto-include.md` for DTO graphs.

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

- `insertStrategy = ONLY_NOT_NULL_COLUMNS`
- `updateStrategy = ALL_COLUMNS`
- `defaultCondition = LIKE`
- `autoIncludeTable = THROW`
- `relationGroupSize = 512`
- `includeLimitMode = PARTITION`

Read `configuration-starter.md` when behavior seems different from the written
 query code.

## Source Hints

These are provenance hints for local/source lookup only:

- `Selectable1`
- `Filterable1`
- `Orderable1`
- `Navigate`
- `NavigateFlat`
- `ObjectSortBuilder`
- `EasyWhereCondition`
- `EntityIncludeable1`
- `EntitySavable`
- `EasySearch`
- `EasyCond`

If a needed symbol is not listed here or in the task-specific references, check
 the target project before emitting code.
