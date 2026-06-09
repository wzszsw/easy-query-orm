# Update

Use this reference for:

- expression update
- object update
- `setColumns(...)`
- `setIgnoreColumns(...)`
- `whereColumns(...)`
- `setSQLStrategy(...)` on update
- update `columnConfigure(...)`
- `mapUpdatable(...)`
- optimistic lock controls on update

For diff update tracking, add `write-tracking.md`. For delete semantics, read
`write-delete.md`. For batch execution-mode detail, read `write.md`.

## 1. Expression Update

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
- SQL-side increment/decrement or custom expressions are needed

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

## 2. Object Update

```java
Topic topic = new Topic();
topic.setId("5");
topic.setTitle("updated");

long rows = easyEntityQuery.updatable(topic).executeRows();
```

Default object-update behavior:

- update by entity primary key
- default strategy is full-column update
- null fields are written unless strategy is changed

This is why `updatable(entity).executeRows()` is not interchangeable with
expression update.

## 3. Update SQL Strategy

```java
easyEntityQuery.updatable(topic)
    .setSQLStrategy(SQLExecuteStrategyEnum.ONLY_NOT_NULL_COLUMNS)
    .executeRows();
```

Use this when request objects may contain nulls that must not overwrite
existing data.

## 4. `setColumns(...)`, `setIgnoreColumns(...)`, `whereColumns(...)`

These are the core object-update precision controls.

### Narrow the `SET` list

```java
easyEntityQuery.updatable(user)
    .setColumns(o -> o.FETCHER.updateTime())
    .whereColumns(o -> o.FETCHER.id())
    .executeRows();
```

### Exclude columns from `SET`

```java
easyEntityQuery.updatable(user)
    .setIgnoreColumns(o -> o.FETCHER.createTime().createBy())
    .executeRows();
```

### Why `whereColumns(...)` matters

Source-backed nuance:

- `setIgnoreColumns(...)` only affects `SET`, not `WHERE`
- after custom `setColumns(...)`, key columns are not something you should
  assume implicitly from the update intent
- `whereColumns(...)` is the precise way to state which original columns form
  the update condition for object-driven update

In tracking context, `whereColumns(...)` uses original values for conditions
while new values go into `SET`.

## 5. Update `columnConfigure(...)`

Use this when a selected updated column needs custom SQL generation:

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

## 6. `mapUpdatable(...)`

Map keys are database column names:

```java
Map<String, Object> row = new LinkedHashMap<>();
row.put("id", 1);
row.put("update_time", LocalDateTime.now());

easyEntityQuery.mapUpdatable(row)
    .asTable("user_archive_2024")
    .setSQLStrategy(SQLExecuteStrategyEnum.ONLY_NOT_NULL_COLUMNS)
    .whereColumns("id")
    .executeRows();
```

Use this when:

- table name is dynamic
- the write is already column-shaped
- no entity class is the right abstraction for this update

## 7. Optimistic Lock on Update

```java
easyEntityQuery.updatable(SysUserVersionLong.class)
    .setColumns(s -> s.phone().set("123"))
    .where(o -> o.id().eq(id))
    .withVersion(1L)
    .executeRows();
```

Guidance:

- `withVersion(...)` states the expected current version
- `ignoreVersion()` is an escape hatch, not the default answer
- `executeRows() == 0` under version control usually means stale version or
  state drift

## 8. Expected-Row Assertion

```java
easyEntityQuery.updatable(Topic.class)
    .setColumns(o -> o.title().set("x"))
    .where(o -> o.id().eq("5"))
    .executeRows(1, "更新失败");
```

Use this for "must affect exactly one row" mutation invariants.

## 9. Batch and Tracking Pairing

- Need batch execution details:
  add `write.md`
- Need diff update / `asTracking` / `addTracking` / `@EasyQueryTrack`:
  add `write-tracking.md`

## Common Mistakes

- Treating object update and expression update as the same shape
- Forgetting object update default is full-column update
- Calling `setColumns(...)` and then assuming the update condition stayed
  obvious without `whereColumns(...)`
- Using map update with property names instead of column names
- Treating `ignoreVersion()` as a harmless default

## Sources

- docs:
  `easy-query-doc/src/ability/update.md`
- source:
  `ClientEntityUpdatable`
- source:
  `EntityUpdatable`
- source:
  `MapClientUpdatable`
- source:
  `WithVersionable`
- source:
  `ConfigureVersionable`
