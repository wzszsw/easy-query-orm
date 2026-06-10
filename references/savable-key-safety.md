# Savable Key Safety

Use this reference for:

- request-built child collections
- frontend child ids
- `saveEntitySetPrimaryKey(...)`
- `PrimaryKeyGenerator`
- `SaveEntitySetPrimaryKeyGenerator`

This file exists because savable diff logic can otherwise trust a wrong child
id and turn it into a dangerous insert/update decision.

For the broader choice among `generatedKey`, `generatedSQLColumnGenerator`,
`primaryKeyGenerator`, and general registration/timing, read
`primary-key-generation.md`.

## The Problem

In request-driven one-to-many update flows, frontend payloads often contain
child ids.

If you naively map request items into new child entities:

```java
SaveBankCard bankCard = new SaveBankCard();
bankCard.setId(requestItem.getId());
bankCard.setType(requestItem.getType());
bankCard.setCode(requestItem.getCode());
```

then an unknown id may be treated as "insert this row with that id".

That can:

- trust arbitrary client ids
- break monotonic id assumptions
- fragment indexes
- corrupt aggregate diff meaning

## Source-Backed Safe API

Current `EasyQueryClient` exposes:

```java
easyEntityQuery.saveEntitySetPrimaryKey(entity);
```

Source behavior:

- checks current track context for the entity
- if the entity is not currently tracked, it is treated as a would-be insert
- then key columns are assigned by either:
  - the entity column's `PrimaryKeyGenerator`, or
  - runtime `SaveEntitySetPrimaryKeyGenerator`

So this is not "always generate a new key". It is "if this child is not a
tracked existing row, assign a proper backend key for insert".

## 1. Safe One-to-Many Merge Shape

```java
@Transactional(rollbackFor = Exception.class)
@EasyQueryTrack
public void update(BankUpdateRequest request) {
    SaveBank saveBank = easyEntityQuery.queryable(SaveBank.class)
        .include(b -> b.saveBankCards())
        .whereById(request.getId())
        .singleNotNull();

    saveBank.setName(request.getName());
    saveBank.setAddress(request.getAddress());

    List<SaveBankCard> requestCards = new ArrayList<>();
    for (BankUpdateRequest.InternalSaveBankCards item : request.getSaveBankCards()) {
        SaveBankCard card = new SaveBankCard();
        card.setId(item.getId());
        card.setType(item.getType());
        card.setCode(item.getCode());

        easyEntityQuery.saveEntitySetPrimaryKey(card);

        requestCards.add(card);
    }

    saveBank.setSaveBankCards(requestCards);
    easyEntityQuery.savable(saveBank).executeCommand();
}
```

This is the canonical safe answer when request children may contain unknown or
unsafe ids.

## 2. Prerequisite Boundary

`saveEntitySetPrimaryKey(...)` depends on current track context access. Without
an active tracking scope, current source throws because it cannot inspect the
track state.

So do not teach this API outside:

- `@EasyQueryTrack`
- or manual `TrackManager.begin()`

## 3. Generator Paths

If the entity key column already has a `PrimaryKeyGenerator`, that generator is
used.

Otherwise runtime falls back to `SaveEntitySetPrimaryKeyGenerator`.

If no save-key generator support is configured, current default source can
throw an unsupported-operation style error.

## 4. When `null` Id Is Enough vs Not Enough

In some simple cases, leaving a new child id as `null` may be acceptable if
backend key generation is already wired.

But docs point out that more complex nested object graphs may still need
explicit backend key assignment discipline, especially when additional
redundant relation fields depend on generated ids at deeper levels.

Practical rule:

- for simple cases, `null` may be acceptable if the project's key-generation
  strategy is well-defined
- for complex request-built nested graphs, explicit save-key handling is safer

## 5. Manual Alternative

If the project needs custom logic rather than the default helper, current track
state can be checked directly:

```java
EntityState trackEntityState = easyEntityQuery.getTrackEntityState(bankCard);
if (trackEntityState == null) {
    bankCard.setId(UUID.randomUUID().toString());
}
```

Use this only when project-specific key semantics require custom handling.
Prefer `saveEntitySetPrimaryKey(...)` when the standard behavior is enough.

## 6. Pairing Rules

- Need aggregate save execution prerequisites:
  add `savable-execution.md`
- Need relation ownership/cascade modeling:
  add `savable-relation-rules.md`

## Common Mistakes

- Trusting frontend child ids in a savable update flow
- Calling `saveEntitySetPrimaryKey(...)` without an active tracking context
- Assuming it always generates a new id regardless of track state
- Forgetting that unsupported generator configuration can still fail

## Sources

- docs:
  `easy-query-doc/src/savable/set-save-key.md`
- source:
  `EasyQueryClient`
- source:
  `DefaultEasyQueryClient.saveEntitySetPrimaryKey(...)`
- source:
  `SaveEntitySetPrimaryKeyGenerator`
