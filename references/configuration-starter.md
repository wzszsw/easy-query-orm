# Starter Configuration and Defaults

Use this reference when easy-query behavior differs from expected code because of Spring Boot starter properties.

Source evidence: `EasyQueryProperties` annotated with `@ConfigurationProperties(prefix = "easy-query")`.

## High-Impact Defaults

Important defaults from source:

```text
easy-query.enable = false
easy-query.build = true
easy-query.deleteThrow = true
easy-query.sharding = false
easy-query.database = UNKNOWN
easy-query.nameConversion = UNDERLINED
easy-query.insertStrategy = ONLY_NOT_NULL_COLUMNS
easy-query.updateStrategy = ALL_COLUMNS
easy-query.includeLimitMode = PARTITION
easy-query.maxInClauseSize = 9999999
easy-query.relationGroupSize = 512
easy-query.printSql = true
easy-query.printNavSql = true
easy-query.mapToBeanStrict = true
easy-query.mappingStrategy = PROPERTY_FIRST
easy-query.defaultCondition = LIKE
easy-query.autoIncludeTable = THROW
```

## Coding Implications

- Object insert omits null columns by default. Use `setSQLStrategy(SQLExecuteStrategyEnum.ALL_COLUMNS)` (`com.easy.query.core.enums`) when nulls must be inserted, for example when upsert conflict columns may be null.
- Object update writes all columns by default. Use explicit expression update or `ONLY_NOT_NULL_COLUMNS` when request objects may contain null fields that should not overwrite data.
- Physical delete can be blocked by `deleteThrow` and logic-delete guards. Use documented delete APIs intentionally.
- `whereObject` default string condition is controlled by `defaultCondition`; source default is `LIKE`.
- `selectAutoInclude` rejects entity return classes by default because `autoIncludeTable = THROW`.
- `include` relation key batching defaults to `relationGroupSize = 512`.
- To-many include `limit` uses `includeLimitMode = PARTITION` by default.
- Result mapping is strict by default via `mapToBeanStrict = true`.

## Query Diagnostics

Defaults `printSql = true` and `printNavSql = true` mean query and navigation SQL may be printed by starter logging. In production or tests, check the project config before assuming SQL logging is enabled/disabled.

## Sharding Notes

Defaults matter if sharding is enabled:

- `connectionMode = SYSTEM_AUTO`
- `shardingQueryInTransaction = SERIALIZABLE`
- `maxShardingQueryLimit = 5`
- `maxShardingRouteCount = 128`
- `throwIfRouteNotMatch = true`
- `shardingExecuteTimeoutMillis = 60000`

Do not add sharding-specific route assumptions to normal repository code unless local sharding annotations/configuration prove the route behavior.

## When to Mention Configuration

Mention starter configuration in code review or implementation notes when:

- An update can write nulls.
- A where-object `LIKE` vs `CONTAINS` distinction changes behavior for `%` or `_`.
- `selectAutoInclude` is attempted with a database entity return type.
- Relation include batching or to-many limits affect performance.
- Strict mapping causes missing fields or mapping exceptions.
