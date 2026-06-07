# Savable Aggregate Root

Use this reference when saving object graphs with `easyEntityQuery.savable(...)`.

## When to Use

Use `savable` when a create/update flow needs to persist an aggregate root and its value-object relations as one object graph. It is especially valuable for one-to-many and many-to-many changes where manual diffing would otherwise require finding inserted, updated, and deleted children.

Do not use `savable` as a generic replacement for simple insert/update. For one-row changes, ordinary `insertable` or `updatable` is easier to reason about.

Doc evidence: `easy-query-doc/src/savable/README.md`, `one2one.md`, `one2many.md`, `many2many.md`, `ownership.md`, `remove-root.md`, `set-save-key.md`.

## Core API

Source signatures from `EntitySavable`:

```java
easyEntityQuery.savable(entity).executeCommand();
easyEntityQuery.savable(entities).executeCommand();

easyEntityQuery.savable(entity)
    .savePath(root -> Include.path(root.children()))
    .executeCommand();

easyEntityQuery.savable(entity)
    .ignoreRoot()
    .executeCommand();

easyEntityQuery.savable(entity)
    .removeRoot()
    .executeCommand();

easyEntityQuery.savable(entity)
    .disableLogicDelete()
    .executeCommand();

easyEntityQuery.savable(entity)
    .configure(c -> c.getSaveBehavior().add(SaveBehaviorEnum.ALLOW_OWNERSHIP_CHANGE))
    .executeCommand();
```

Source evidence: `EntitySavable`, `SaveConfigurer`, `Include.path(...)`.

## Required Context

For update/diff saves:

- Load the aggregate root in a tracking context.
- Include or load the relations that should participate in the diff.
- Execute `savable(...).executeCommand()` inside a transaction.

Typical Spring shape:

```java
@Transactional(rollbackFor = Exception.class)
@EasyQueryTrack
public void update(String id, UpdateRequest request) {
    SaveUser user = easyEntityQuery.queryable(SaveUser.class)
        .include(u -> u.addresses())
        .whereById(id)
        .singleNotNull();

    mergeRequestIntoTrackedEntity(user, request);

    easyEntityQuery.savable(user).executeCommand();
}
```

Manual tracking shape:

```java
TrackManager trackManager = easyEntityQuery.getRuntimeContext().getTrackManager();
try {
    trackManager.begin();
    SaveRoot root = easyEntityQuery.queryable(SaveRoot.class)
        .include(r -> r.items())
        .findNotNull(id);

    mutate(root);

    try (Transaction tx = easyEntityQuery.beginTransaction()) {
        easyEntityQuery.savable(root).executeCommand();
        tx.commit();
    }
} finally {
    trackManager.release();
}
```

Docs warn that a modified object must be tracked; do not build a fresh object from the request and expect diff update semantics.

## Aggregate and Value Object Rules

Docs define ownership from relation keys:

- If table `A` is related to table `B` by `A` primary key, `A` is the aggregate root and `B` is the value object.
- If current navigation target property is the target table primary key, the current object is a value object of the target aggregate root.
- Many-to-one save is special: saving the value object does not save/detach the aggregate root navigation; it mainly uses the aggregate root id to set relation keys.

For many-to-many:

- `cascade = CascadeTypeEnum.DELETE` lets `savable` automatically insert/delete the mapping table when it is pure relation data.
- If the mapping table has business fields, use `cascade = CascadeTypeEnum.NO_ACTION` for the many-to-many relation and model a separate one-to-many relation to the mapping entity.

## cascade Choices

`@Navigate(cascade = ...)` controls detach behavior:

- `AUTO`: default behavior; often set-null for detach, but many-to-many mapping handling may be ambiguous.
- `NO_ACTION`: detach does nothing; application handles it.
- `SET_NULL`: detach clears relation key on the target row.
- `DELETE`: detach deletes the value object. This is the usual choice for true value objects and pure many-to-many mapping rows.

Use `DELETE` only when the child row is owned by the aggregate root and should not survive detachment.

## savePath

Use `savePath` to limit saved value-object paths:

```java
easyEntityQuery.savable(root)
    .savePath(r -> Include.path(r.items(), r.profile()))
    .executeCommand();
```

`savePath` is for value-object paths. Source/tests reject aggregate-root paths with an error like: value type is aggregate root, save path limit only supports value object.

## removeRoot

Use `removeRoot()` to remove the aggregate root and its included graph:

```java
easyEntityQuery.savable(root)
    .removeRoot()
    .executeCommand();
```

Docs say `removeRoot` sets navigation properties to null and deletes paths loaded for this operation. Treat it as a deletion workflow and wrap it in a transaction.

## Save Key Safety

Docs include `set-save-key` guidance because child primary keys from clients can be wrong or unsafe. For request-driven child collections, validate or derive child keys before merging into tracked collections. Do not trust arbitrary child ids from the frontend.

## Common Failure Modes

- Missing `@EasyQueryTrack` or manual `TrackManager.begin()` around the loaded entity.
- Calling `savable` without a transaction.
- Mutating a newly constructed request object instead of a tracked database object.
- Expecting `ManyToOne` navigation saves to recursively save/detach the aggregate root.
- Using `cascade = DELETE` on a child that can exist independently.
- Using `savePath` on aggregate-root navigation instead of value-object navigation.
