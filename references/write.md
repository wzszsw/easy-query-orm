# Write DSL

Use this reference for core mutation APIs:

- `insertable(...)`
- `updatable(...)`
- `deletable(...)`
- `onConflictThen(...)`
- `setSQLStrategy(...)`
- `setColumns(...)` / `setIgnoreColumns(...)` / `whereColumns(...)`
- `mapInsertable(...)` / `mapUpdatable(...)`
- `batch()`
- `batch(false)`

Do not use this as the main guide for:

- transaction boundaries: `transaction.md`
- aggregate graph save: `savable-aggregate.md`
- detailed soft-delete strategy design: `logic-delete.md`
- interceptor-based audit/default fill rules: `interceptor.md`

## Decision Guide

- One-row insert or simple list insert:
  `insertable(...)`
- Insert-or-update / insert-or-ignore by unique key or primary key:
  `insertable(...).onConflictThen(...)`
- Condition-driven `UPDATE ... SET ... WHERE ...`:
  `updatable(Entity.class).setColumns(...).where(...).executeRows()`
- Object-driven update by primary key or tracked diff:
  `updatable(entity)` / `updatable(entities)`
- Dangerous delete / physical delete:
  `deletable(...)`, then reason carefully about logic delete and
  `allowDeleteStatement(true)`
- Dynamic-table / raw-column write:
  `mapInsertable(...)` / `mapUpdatable(...)`
- Force JDBC batch path for insert/update/delete/save collections:
  `.batch()` / `.batch(true)`

## 1. Insert

### Single / list / chained insert

```java
Topic topic = new Topic();
topic.setStars(999);
topic.setTitle("title999");
topic.setCreateTime(LocalDateTime.now());

long row1 = easyEntityQuery.insertable(topic).executeRows();

List<Topic> topics = buildMany();
long row2 = easyEntityQuery.insertable(topics).executeRows();

long row3 = easyEntityQuery.insertable(topics.get(0))
    .insert(topics.get(1))
    .executeRows();
```

All write chains complete only after `executeRows(...)`.

### Generated-key backfill

If the primary key is database-generated, use `executeRows(true)`:

```java
TopicAuto topic = new TopicAuto();
topic.setTitle("new");

long rows = easyEntityQuery.insertable(topic).executeRows(true);
Integer id = topic.getId();
```

This relies on entity metadata such as `@Column(primaryKey = true, generatedKey = true)`.

### Insert SQL strategy

Current default insert strategy is `ONLY_NOT_NULL_COLUMNS`.

```java
easyEntityQuery.insertable(topic)
    .setSQLStrategy(SQLExecuteStrategyEnum.ALL_COLUMNS)
    .executeRows();
```

High-value strategies:

- `ONLY_NOT_NULL_COLUMNS`:
  omit null properties from `INSERT`
- `ALL_COLUMNS`:
  force all columns into `INSERT`
- `ONLY_NULL_COLUMNS`:
  niche case; usually mention only when the project already uses it

Use `ALL_COLUMNS` when a conflict-key column or required generated SQL shape
must still appear even if the current value is null.

### Insert `columnConfigure(...)`

Use `columnConfigure(...)` when one inserted column needs custom SQL rather
than a normal bound value:

```java
easyEntityQuery.insertable(topic)
    .columnConfigure((t, cfg) -> cfg.column(
        t.stars(),
        "ifnull({0},0)+{1}",
        (context, sqlParameter) -> context.expression(t.stars()).value(sqlParameter)
    ))
    .executeRows();
```

Prefer plain property values first. Use `columnConfigure(...)` only when the
insert column needs a SQL expression shape.

### `onConflictThen(...)` for upsert / ignore

This is the current insert-or-update / insert-or-ignore API.

Update specific fields on conflict:

```java
easyEntityQuery.insertable(user)
    .onConflictThen(o -> o.FETCHER.updateTime().title())
    .executeRows();
```

Ignore on conflict:

```java
easyEntityQuery.insertable(user)
    .onConflictThen(null, o -> o.FETCHER.id())
    .executeRows();
```

Rules:

- first parameter:
  fields to update when conflict happens
- first parameter `null`:
  do nothing on conflict
- second parameter:
  conflict constraint columns; omitted means primary key

Important source-backed caveats:

- if the chosen conflict property value may be null, that column may be
  omitted from insert SQL unless you force `ALL_COLUMNS`
- current docs say MySQL ignores the second-parameter custom constraint
  selection
- if no constraint selector is supplied and the table has no primary key, the
  operation is invalid

## 2. Update

### Expression update: condition + explicit `SET`

This is the default answer for service-layer update commands.

```java
long rows = easyEntityQuery.updatable(Topic.class)
    .setColumns(t -> {
        t.stars().set(12);
        t.title().set("new title");
    })
    .where(t -> t.id().eq("5"))
    .executeRows();
```

Use expression update when:

- the update condition is explicit
- only some columns should change
- SQL-side increments, functions, or custom expressions are needed

### Atomic increment / decrement

```java
easyEntityQuery.updatable(Topic.class)
    .setColumns(t -> t.stars().increment())
    .whereById("5")
    .executeRows();

easyEntityQuery.updatable(Topic.class)
    .setColumns(t -> t.stars().decrement(2))
    .where(t -> t.id().eq("5"))
    .executeRows();
```

This is safer than read-modify-write in Java when the column should change in
SQL atomically.

### Custom SQL in update set

```java
easyEntityQuery.updatable(User.class)
    .setColumns(u -> u.version().setSQL(
        "ifnull({0},0)+{1}",
        ctx -> ctx.expression(u.version()).value(1)
    ))
    .where(u -> u.id().eq(1))
    .executeRows();
```

### Object update by primary key

```java
Topic topic = new Topic();
topic.setId("5");
topic.setTitle("updated");

long rows = easyEntityQuery.updatable(topic).executeRows();
```

Default object-update behavior:

- update by the entity primary key
- update strategy defaults to `ALL_COLUMNS`
- null fields are written unless strategy is changed

### Object update strategy

```java
easyEntityQuery.updatable(topic)
    .setSQLStrategy(SQLExecuteStrategyEnum.ONLY_NOT_NULL_COLUMNS)
    .executeRows();
```

Use this when request objects may contain nulls that must not overwrite
existing data.

### `setColumns(...)`, `setIgnoreColumns(...)`, `whereColumns(...)` on object update

These are high-value but easy to misstate.

Update only selected columns from the entity object:

```java
easyEntityQuery.updatable(user)
    .setColumns(o -> o.FETCHER.updateTime())
    .whereColumns(o -> o.FETCHER.id())
    .executeRows();
```

Ignore selected columns from the `SET` list:

```java
easyEntityQuery.updatable(user)
    .setIgnoreColumns(o -> o.FETCHER.createTime().createBy())
    .executeRows();
```

Source-backed nuance:

- `setIgnoreColumns(...)` only affects `SET`, not `WHERE`
- after calling `setColumns(...)` on entity update, key columns are not
  magically guaranteed to stay in `WHERE`; specify `whereColumns(...)` when
  the condition must be explicit
- in tracking context, `whereColumns(...)` uses original values as conditions
  while new values go to `SET`

This is the correct tool when you have an entity object but still need precise
column-level update semantics.

### Update `columnConfigure(...)`

Use this when a specific updated column needs custom SQL generation:

```java
easyEntityQuery.updatable(user)
    .columnConfigure((t, cfg) -> cfg.column(
        t.version(),
        "ifnull({0},0)+{1}",
        (context, sqlParameter) -> context.expression(t.version()).value(sqlParameter)
    ))
    .setColumns(o -> o.FETCHER.version())
    .whereColumns(o -> o.FETCHER.id())
    .executeRows();
```

### Update collections and `batch()`

```java
List<User> users = loadUsers();
long rows1 = easyEntityQuery.updatable(users).executeRows();
long rows2 = easyEntityQuery.updatable(users).batch().executeRows();
```

Use `batch()` for throughput, not for trustworthy row-count semantics.

## 3. Delete

### By id / by condition / by entity / batch

```java
easyEntityQuery.deletable(Topic.class).whereById("999").executeRows();

easyEntityQuery.deletable(Topic.class)
    .where(t -> t.title().eq("title998"))
    .executeRows();

easyEntityQuery.deletable(topic).executeRows();

easyEntityQuery.deletable(topics).batch().executeRows();
```

### Physical delete safety

If logic delete is active, delete becomes update. For real `DELETE`, you need a
conscious opt-in:

```java
easyEntityQuery.deletable(BlogEntity.class)
    .where(o -> o.id().eq("id123"))
    .disableLogicDelete()
    .allowDeleteStatement(true)
    .executeRows();
```

Meaning:

- `disableLogicDelete()`:
  bypass soft delete behavior
- `allowDeleteStatement(true)`:
  remove the delete guard

Current starter defaults also commonly keep `deleteThrow = true`, so do not
teach physical delete as casual or default behavior.

## 4. Map Write

### `mapInsertable(...)`

Map keys are column names, not entity property names:

```java
Map<String, Object> row = new LinkedHashMap<>();
row.put("id", 123);
row.put("name", "小明");
row.put("name2", null);

easyEntityQuery.mapInsertable(row)
    .asTable("sys_table")
    .setSQLStrategy(SQLExecuteStrategyEnum.ONLY_NOT_NULL_COLUMNS)
    .executeRows();
```

### `mapUpdatable(...)`

```java
Map<String, Object> row = new LinkedHashMap<>();
row.put("id", 1);
row.put("update_time", LocalDateTime.now());

easyEntityQuery.mapUpdatable(row)
    .asTable("user")
    .setSQLStrategy(SQLExecuteStrategyEnum.ONLY_NOT_NULL_COLUMNS)
    .whereColumns("id")
    .executeRows();
```

Use map writes when:

- table name is dynamic
- the project is not working with an entity class for this write
- the payload is already a column-value map

## 5. Batch Semantics

`batch()` is not just a vague "bulk mode". Current source shows:

- `batch()` is a default method that calls `batch(true)`
- `batch(boolean use)` toggles execution behavior flags on the current
  expression
- when batch execution is active, the JDBC path uses
  `PreparedStatement.addBatch()` plus `PreparedStatement.executeBatch()`

So for mutation answers, you can state precisely:

- `batch()` and `batch(true)` enable the JDBC batch execution path
- `batch(false)` explicitly disables that path for the current chain

### What happens underneath

Source-backed execution shape:

1. `AbstractSQLExecuteRows.batch(boolean use)` sets expression behavior to
   `EXECUTE_BATCH` or `EXECUTE_NO_BATCH`
2. execution creation can group compatible units by datasource + SQL text
3. `EasyJdbcExecutorUtil.execute(...)` calls `ps.addBatch()`
4. batched groups flush via `ps.executeBatch()`

This means batch is closer to "use JDBC batch API for this write chain" than
to "always rewrite to one multi-values SQL statement".

Practical rules:

- treat `batch()` as an execution-mode switch, not a promise about exact SQL
  text shape
- inserts/updates with mixed SQL shapes may still be split into several batch
  groups
- compatible SQL can be grouped before batch execution; incompatible shapes do
  not magically merge
- do not rely on exact returned affected-row counts under batch mode unless the
  driver is known to provide them
- on MySQL, `rewriteBatchedStatements=true` is a common prerequisite for real
  `executeBatch()`-backed performance; without it, docs warn MySQL may still
  execute effectively one by one
- when mixed null/non-null shapes exist and strategy is not `ALL_COLUMNS`,
  easy-query can group compatible SQL shapes for batch execution

### Why row counts get weird

JDBC batch results are driver-dependent. In practice you may see totals derived
from special `executeBatch()` return codes such as "success but count unknown".

So:

- do not use batch row counts as strong business invariants
- do not combine `batch()` with `executeRows(expectRows, ...)` unless the
  driver behavior is already verified for that path
- use batch primarily for throughput, not concurrency assertions

## 6. Optimistic Lock and Row-Count Semantics

### `withVersion(...)` / `ignoreVersion()`

For versioned rows:

```java
easyEntityQuery.updatable(SysUserVersionLong.class)
    .setColumns(s -> s.phone().set("123"))
    .where(o -> o.id().eq(id))
    .withVersion(1L)
    .executeRows();

easyEntityQuery.deletable(SysUserVersionLong.class)
    .whereById(id)
    .ignoreVersion()
    .executeRows();
```

Guidance:

- `withVersion(...)` expresses the expected current version
- `ignoreVersion()` is an escape hatch, not a default
- `executeRows() == 0` usually means not found, stale version, or state drift

### Expected-row assertion

```java
easyEntityQuery.updatable(Topic.class)
    .setColumns(o -> o.title().set("x"))
    .where(o -> o.id().eq("5"))
    .executeRows(1, "更新失败");
```

This is the clean mutation-side invariant check for "must affect exactly one
row".

## 7. How To Choose the Mutation Form

- Simple condition update:
  `updatable(Entity.class).setColumns(...).where(...)`
- Request object update but only some fields should write:
  `updatable(entity).setColumns(...).whereColumns(...)`
- Request object update where nulls should not overwrite:
  `updatable(entity).setSQLStrategy(ONLY_NOT_NULL_COLUMNS)`
- Graph diff / nested child add-remove-update:
  `savable(...)`
- One-row existence conflict:
  `insertable(...).onConflictThen(...)`
- Dynamic table/columns:
  map write

## Common Mistakes

- Treating `updatable(entity)` and `updatable(Entity.class).setColumns(...)` as
  the same mutation shape
- Forgetting that object update default strategy is usually full-column update
- Calling `setColumns(...)` on entity update and assuming key columns still
  automatically define `WHERE`
- Using `onConflictThen(...)` without considering null conflict columns or the
  MySQL second-parameter caveat
- Trusting batch affected-row counts as exact business truth
- Treating `batch()` as "one SQL" instead of "JDBC batch API execution mode"
- Using map write with property names instead of column names
- Treating `executeRows() == 0` as success
- Calling physical delete without both a real condition and
  `allowDeleteStatement(true)`

## Sources

- 官方文档:
  `easy-query-doc/src/ability/{insert,update,delete,batch,insertOrUpdate}.md`
- 源码:
  `ClientInsertable`, `ClientEntityUpdatable`, `EntityUpdatable`,
  `MapClientInsertable`, `MapClientUpdatable`,
  `ProxyEntityConflictThenable`,
  `SQLConflictThenable`,
  `SQLExecuteStrategyEnum`,
  `SQLBatchExecute`,
  `AbstractSQLExecuteRows`,
  `EasyJdbcExecutorUtil`,
  `BaseExecutionCreator`,
  `Deletable`,
  `WithVersionable`,
  `ConfigureVersionable`
- 测试:
  `sql-test/.../InsertTest.java`, `InsertTest1.java`, `UpdateTest.java`,
  `VersionTest.java`
