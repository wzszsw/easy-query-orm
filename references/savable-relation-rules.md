# Savable Relation Rules

Use this reference for:

- aggregate root vs value object classification
- one-to-one / one-to-many / many-to-many / many-to-one save behavior
- cascade behavior
- ownership change
- unsupported relation shapes
- tracked include/path requirements for navigation saves

For transaction/tracking prerequisites and save behaviors, read
`savable-execution.md`. For child key safety, read `savable-key-safety.md`.

## 1. The Core Classification Rule

Current provider logic classifies a navigation roughly like this:

- if the current entity's relation keys are its own key props:
  target is a value object
- if the target-side relation props are key props of the current entity:
  target is an aggregate root
- otherwise:
  it is a relation-other shape, not a normal value-object save path

This is the engine behind the docs' aggregate-root/value-object explanation.

## 2. Value Object vs Aggregate Root

### Value object

`savable(root)` can recursively manage it.

Depending on cascade and relation type, this can include:

- insert
- update
- delete or set-null detach

### Aggregate root

`savable(currentEntity)` does not recursively save or delete that target root.
Instead, it copies relationship key values as needed.

That is why many-to-one save is special.

## 3. One-to-One / One-to-Many

These are the main happy-path aggregate-root save shapes.

If the root owns the child through its own key relation:

- child can be treated as a true value object
- diff save can insert/update/delete it
- recursive save can continue downwards when cascade semantics allow it

This is where `savable(...)` is most natural.

## 4. Many-to-One Is Special

Docs and source agree on this boundary:

- the navigation target is an aggregate root
- `savable(valueObject)` does not recursively save/detach that aggregate root
- it mainly copies the aggregate-root key into the current entity relation
  field(s)

So for a many-to-one relation, do not teach:

- "savable(child) will also save parent"
- "savable(child) can detach/delete the parent navigation"

That is not the intended model.

## 5. Many-to-Many

This is only automatically manageable when the mapping table semantics are
clear.

### Pure mapping table

If the many-to-many mapping row is just relation data and the relation uses:

```java
@Navigate(..., mappingClass = UserRole.class, cascade = CascadeTypeEnum.DELETE)
```

then savable can automatically insert/delete mapping rows.

### Mapping table with business fields

If the mapping table has business fields:

- do not treat the many-to-many relation itself as the full save path
- use `cascade = CascadeTypeEnum.NO_ACTION` on the many-to-many navigation
- model a separate one-to-many navigation to the mapping entity and save that
  explicitly

This is one of the highest-value savable modeling rules in practice.

## 6. Cascade Rules in Savable

### `NO_ACTION`

- detach does nothing automatically
- application logic must handle it

### `AUTO` / `SET_NULL`

- detach becomes key-nulling update behavior
- for some shapes this is only valid when target props are not key props

### `DELETE`

- for true value objects, detach becomes delete
- recursive save/delete can continue downward
- for many-to-many pure mapping rows, this enables automatic mapping-table
  maintenance

Use `DELETE` only when the child is truly owned and should not survive
detachment.

## 7. Ownership Change

Source `setTargetValue(...)` enforces strict ownership by default.

If a value object currently belongs to one aggregate root and the new graph
tries to assign it to another, current behavior throws an error similar to:

- relation value not equals
- current ownership policy does not allow reassignment

Allow reassignment only when explicitly intended:

```java
easyEntityQuery.savable(list)
    .configure(c -> c.getSaveBehavior().add(SaveBehaviorEnum.ALLOW_OWNERSHIP_CHANGE))
    .executeCommand();
```

Do not recommend this as default. It changes ownership safety semantics.

## 8. Untracked Navigation Values Are Not Harmless

Current provider logic checks navigation properties that are present on the
entity but not part of the tracked/include/save-path picture.

If a navigation value is present but not being tracked in the expected way,
current save logic can throw "current navigation property ... is not being
tracked".

Practical rule:

- for update/diff saves, load the graph paths you intend to save using
  `include(...)` / `loadInclude(...)`, or constrain with `savePath(...)`
- do not attach random navigation objects to a tracked root and expect savable
  to infer the intended path safely

## 9. Unsupported / Weakly Supported Shapes

- `directMapping` relations are not supported by savable
- arbitrary non-key relation-other paths are not normal savable recursion paths
- many-to-many without a proper `mappingClass` is not the auto-managed shape

If the requirement depends on these, be explicit that the normal savable model
is not a fit.

## 10. Pairing Rules

- Need root controls / `savePath` / `IGNORE_NULL` / `IGNORE_EMPTY`:
  add `savable-execution.md`
- Need frontend child id safety:
  add `savable-key-safety.md`

## Common Mistakes

- Treating many-to-one navigation as recursively savable parent state
- Using `cascade = DELETE` on a child that is not truly owned
- Expecting many-to-many with business fields to be safely auto-managed
- Enabling ownership change without explicit business intent
- Forgetting to load or constrain the navigation paths that should participate
  in save diffing

## Sources

- docs:
  `easy-query-doc/src/savable/{README,one2one,one2many,many2many,many2one,ownership}.md`
- source:
  `AbstractSaveProvider`
- source:
  `AutoTrackSaveProvider`
