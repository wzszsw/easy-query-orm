# Delete

Use this reference for:

- `deletable(...)`
- object delete vs condition delete
- batch delete
- version-aware delete controls
- physical delete safety

For detailed soft-delete strategy design, add `logic-delete.md`. For
transaction boundaries, add `transaction.md`.

## 1. Basic Delete Shapes

### By id / by condition / by entity / by collection

```java
easyEntityQuery.deletable(Topic.class)
    .whereById("999")
    .executeRows();

easyEntityQuery.deletable(Topic.class)
    .where(t -> t.title().eq("title998"))
    .executeRows();

easyEntityQuery.deletable(topic)
    .executeRows();

easyEntityQuery.deletable(topics)
    .batch()
    .executeRows();
```

### Object delete

`deletable(entity)` is the object-driven form. Like object update, it is not
the same thing as a fully explicit condition delete.

## 2. Version Controls on Delete

```java
easyEntityQuery.deletable(SysUserVersionLong.class)
    .whereById(id)
    .ignoreVersion()
    .executeRows();
```

If the entity uses optimistic lock semantics, version rules can also affect
delete paths. Do not answer `ignoreVersion()` casually.

## 3. Physical Delete Safety

If logic delete is active, delete may become update instead of real `DELETE`.

True physical delete needs explicit opt-in:

```java
easyEntityQuery.deletable(BlogEntity.class)
    .where(o -> o.id().eq("id123"))
    .disableLogicDelete()
    .allowDeleteStatement(true)
    .executeRows();
```

Meaning:

- `disableLogicDelete()`:
  bypass soft-delete behavior
- `allowDeleteStatement(true)`:
  remove the delete guard

This is a guard-removal API, not proof that the business condition is safe.

## 4. What To Say About `allowDeleteStatement(true)`

State it precisely:

- it allows physical delete SQL to execute
- it does not make a weak condition safe
- it should not be taught as default cleanup boilerplate

If the project also has starter `deleteThrow = true`, mention that the runtime
default is intentionally conservative.

## 5. Row-Count Semantics

Treat `executeRows() == 0` as meaningful:

- row not found
- version mismatch
- logic-delete visibility/state mismatch

Do not silently treat it as success unless the business flow really accepts
"already absent" behavior.

## 6. Pairing Rules

- Need soft-delete strategy, query-time toggles, or table-local disable:
  add `logic-delete.md`
- Need exact transaction boundary:
  add `transaction.md`
- Need batch execution-mode detail:
  add `write.md`

## Common Mistakes

- Calling physical delete without both a real condition and
  `allowDeleteStatement(true)`
- Teaching `disableLogicDelete()` as harmless default boilerplate
- Treating object delete and explicit condition delete as interchangeable
- Treating zero affected rows as silent success

## Sources

- docs:
  `easy-query-doc/src/ability/delete.md`
- source:
  `Deletable`
- source:
  `ClientEntityDeletable`
- source:
  `AbstractClientEntityDeletable`
