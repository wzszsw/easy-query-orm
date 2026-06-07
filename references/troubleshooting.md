# Troubleshooting

Use this file as the first stop when easy-query code compiles but behaves
unexpectedly, or when a familiar API throws in a non-obvious way.

This file is a triage guide, not a full tutorial. For each issue, apply the
first fix, then read the referenced file if deeper changes are needed.

Do not open this file first for ordinary setup questions such as Kotlin `ksp`
vs `kapt`, missing `sql-processor`, missing `sql-ksp-processor`, or starter bean
registration. Use `setup-java.md`, `setup-kotlin.md`, or `setup-spring-boot.md`
first.

## Proxy and Build Issues

### `*Proxy` Not Generated

Symptoms:

- `UserProxy` / `TopicProxy` cannot be found
- proxy DSL types are unresolved in IDE or compile output

First checks:

- Java uses APT; Kotlin uses KSP, not KAPT
- entity must have `@EntityProxy`
- entity must implement `ProxyEntityAvailable<Entity, EntityProxy>`
- generated source directory must be on the compile/IDE path where required

Read next:

- `setup-java.md`
- `setup-kotlin.md`
- `entity-mapping.md`

### Generated Proxy Looks Stale

Symptoms:

- entity field changed but proxy accessors do not match
- DTO mapping or relation path still refers to removed fields

First checks:

- rebuild annotation processing / KSP output
- verify the generated proxy package is the expected one
- do not hand-edit generated proxy classes

Read next:

- `setup-java.md`
- `setup-kotlin.md`
- `entity-mapping.md`

## DTO Result and Mapping Issues

### `selectAutoInclude` Used With Entity Class

Symptom:

- exception similar to `selectAutoInclude should not use database entity objects as return results`

First fix:

```java
query.selectAutoInclude(UserDTO.class);
```

Do not suppress this unless project configuration intentionally relaxes
`autoIncludeTable`.

Read next:

- `select-auto-include.md`
- `configuration-starter.md`

### DTO Fields Missing After `select(...)` or `selectAutoInclude(...)`

Common causes:

- `select(Class<TR>)` maps by column/result name and the names do not match
- DTO nested property lacks the needed `@Navigate`
- `@NavigateFlat` path alias is missing or wrong
- generated proxies are stale

First fix:

```java
select(ResultDTO.class, o -> Select.of(
    o.FETCHER.allFields(),
    o.user().name().as(ResultDTO.Fields.userName)
))
```

Read next:

- `query.md`
- `select-auto-include.md`
- `entity-modeling-navigate.md`

### `flatElement()` Used Inside `select`

Symptom:

- source/runtime rejects `flatElement()` inside result proxy selection

First fix:

- use `flatElement()` in query/list/include path traversal
- for DTO flattening, switch to `@NavigateFlat` or `selectAutoInclude`

Read next:

- `entity-modeling-navigate.md`
- `select-auto-include.md`
- `include-structured-loading.md`

### `include` vs `selectAutoInclude` Confusion

Symptom:

- entity relations populate but DTO extra fields stay empty
- DTO graph was expected from `include(...)`

Rule:

- `include(...)` / `include2(...)` populate entity relation properties
- `selectAutoInclude(...)` builds DTO/VO result graphs

Read next:

- `include-structured-loading.md`
- `select-auto-include.md`

## Relation and Query Issues

### Implicit Join Not Generated

Common causes:

- the gated condition was skipped
- `filterConfigure(...)` filtered the value away
- relation metadata is missing or wrong
- relation path appears only in an inactive branch

Reminder:

- no active relation path means no implicit join, which is expected behavior

Read next:

- `query.md`
- `relation-query.md`
- `implicit-query.md`

### Too Many To-Many Subqueries

Symptom:

- repeated scalar subqueries
- slow to-many relation filters or aggregates

First fixes:

- query-level `.subQueryToGroupJoin(o -> o.relation())`
- annotation-level `@Navigate(subQueryToGroupJoin = true)`
- explicit join/group query for more complex shapes

Read next:

- `implicit-query.md`
- `entity-modeling-navigate.md`
- `advanced.md`

### Inner vs Left Join Surprise

Symptom:

- rows are kept when a related row is missing, or disappear unexpectedly

Rule:

- to-one implicit navigation usually behaves like left join
- `@Navigate(required = true)` can enable inner-join style semantics

Use `required = true` only when missing related rows are impossible by data
integrity.

Read next:

- `implicit-query.md`
- `entity-modeling-navigate.md`

### Partition Order Error

Symptom:

- first/top-N relation access fails around partition ordering

Cause:

- `@Navigate.partitionOrder` defaults to `PartitionOrderEnum.THROW`

First fix:

- define `orderByProps`
- or set an explicit partition-order policy

Read next:

- `implicit-query.md`
- `entity-modeling-navigate.md`

### `whereObject(...)` / `orderByObject(...)` Field Mismatch

Symptom:

- invalid operation errors because request fields or sort fields do not match the
  supported query target

First fix:

- keep real query-form fields in the `whereObject(...)` path
- move paging, transport-only, or ad hoc business-only fields out of the DTO
  query object
- switch only the hard-to-express part back to explicit DSL when needed

Reminder:

- `whereObject(...)` is for query/search form DTOs with many optional
  conditions; if the task is not actually a form, switch back to normal DSL
- the problem is usually the object shape, or using `whereObject(...)` outside
  its intended search-form scope
- `whereObject(...)` and explicit `.where(...)` can be mixed in one chain; you do
  not need to abandon `whereObject(...)` just because one or two conditions are
  easier to express in DSL

Read next:

- `dto-object-query.md`
- `query.md`

### `DEFAULT` Behaves Like `LIKE` Instead of `CONTAINS`

Symptom:

- `%` or `_` behaves like SQL wildcard in `@EasyWhereCondition(DEFAULT)`

Cause:

- starter default `defaultCondition` is often `LIKE`

First fix:

- use `CONTAINS`, `STARTS_WITH`, or `ENDS_WITH` explicitly

Read next:

- `dto-object-query.md`
- `configuration-starter.md`

## Write and Save Issues

### Physical Delete Fails

Cause:

- physical delete is intentionally guarded by logic-delete safety

Required form:

```java
deletable(entity)
    .disableLogicDelete()
    .allowDeleteStatement(true)
    .executeRows();
```

If it still fails, check global delete configuration.

Read next:

- `write.md`
- `configuration-starter.md`

### Object Update Writes Unwanted Nulls

Cause:

- object update may write all columns depending on strategy/config

First fixes:

```java
updatable(entity)
    .setSQLStrategy(SQLExecuteStrategyEnum.ONLY_NOT_NULL_COLUMNS)
    .executeRows();
```

or switch to explicit `setColumns(...)`.

Read next:

- `write.md`
- `configuration-starter.md`

### `savable(...)` Used Without Tracking or Transaction

Symptom:

- aggregate diff-save does not behave as expected

Rule:

- load tracked objects first
- execute `savable(...)` inside a transaction
- do not expect a freshly constructed request object to behave like a tracked aggregate

Read next:

- `savable-aggregate.md`
- `transaction.md`

### Upsert Missing Conflict Columns

Symptom:

- conflict columns that are null are omitted from SQL

Cause:

- starter/object insert strategy may be `ONLY_NOT_NULL_COLUMNS`

First fix:

- set `SQLExecuteStrategyEnum.ALL_COLUMNS` when the conflict column must appear

Read next:

- `write.md`
- `configuration-starter.md`

## Native SQL and Dialect Issues

### Native SQL Dialect Drift

Symptom:

- `setSQL`, `sqlSegment`, or `sqlQuery` works on one database but fails on another

Cause:

- native fragments are dialect-sensitive

First fix:

- verify the target database before using functions such as `IFNULL`
- prefer typed DSL functions whenever available

Read next:

- `functions-native-sql.md`
- `setup-spring-boot.md`
- `advanced.md`
