# Query Composition

Read this after `query.md` when the task needs more than ordinary filter/order/page
chains. This file only covers the advanced composition pieces that are easy to
misremember.

## Advanced Projection

Partial entity fields:

```java
List<DocBankCard> cards = easyEntityQuery.queryable(DocBankCard.class)
    .select(card -> card.FETCHER.id().code())
    .toList();
```

DTO explicit mapping:

```java
List<CardVO> rows = easyEntityQuery.queryable(DocBankCard.class)
    .select(CardVO.class, card -> Select.of(
        card.FETCHER.allFields(),
        card.user().name().as(CardVO.Fields.userName),
        card.bank().name().as(CardVO.Fields.bankName)
    ))
    .toList();
```

Proxy result mapping:

```java
List<CardVO> rows = easyEntityQuery.queryable(DocBankCard.class)
    .select(card -> new CardVOProxy()
        .selectAll(card)
        .userName().set(card.user().name())
        .bankName().set(card.bank().name()))
    .toList();
```

Useful proxy assignment methods:

- `set`
- `setNull`
- `setSubQuery`
- `setSQL`
- `setExpression`
- `selectAll`

## Draft and Tuple Return

```java
List<Draft2<String, Integer>> rows = easyEntityQuery.queryable(SysUser.class)
    .select(user -> Select.DRAFT.of(user.name(), user.age()))
    .toList();
```

`Select.DRAFT` returns `Draft1...10`. `Select.TUPLE` returns `Tuple1...10`.

## Explicit Joins

Use joins when the project does not model a relation or when the SQL shape is
clearer with explicit tables.

```java
easyEntityQuery.queryable(Topic.class)
    .leftJoin(BlogEntity.class, (topic, blog) -> topic.id().eq(blog.id()))
    .where((topic, blog) -> blog.title().isNotNull())
    .select((topic, blog) -> blog)
    .toList();
```

Implicit and explicit relations can be mixed, but if a valid navigation already
exists, prefer the relation query form from `implicit-query.md` and keep
`relation-query.md` for relation metadata itself.

## Manual Subquery

Manual scalar subquery pattern:

```java
List<DocUserVO> rows = easyEntityQuery.queryable(DocUser.class)
    .select(DocUserVO.class, user -> Select.of(
        user.FETCHER.allFields(),
        user.expression().subQuery(
            easyEntityQuery.queryable(DocBankCard.class)
                .where(card -> card.uid().eq(user.id()))
                .selectCount()
        ).as(DocUserVO.Fields.cardCount)
    ))
    .toList();
```

If a valid navigation exists, prefer the implicit form:

```java
user.bankCards().count().as(DocUserVO.Fields.cardCount)
```

## Native SQL Fragment

Predicate fragment:

```java
user.expression().sql("{0} != {1}", c -> {
    c.expression(user.name());
    c.value("x");
});
```

Select fragment:

```java
user.expression()
    .sqlSegment("IFNULL({0}, 1)", c -> c.expression(user.age()), Integer.class)
    .as(DocUserVO.Fields.cardCount)
```

Proxy assignment:

```java
r.cardCount().setSQL("IFNULL({0},1)", c -> c.expression(user.age()));
```

Prefer typed DSL functions first. Only drop to SQL fragments for dialect-specific
behavior or APIs not covered by easy-query.

## Chunking, Streaming, Tracking

Useful large-result helpers:

```java
query.toChunk(size, rows -> { ... });
query.streamBy(stream -> stream.count(), 1000);
```

Tracking for differential update:

```java
TrackManager trackManager = easyEntityQuery.getRuntimeContext().getTrackManager();
try {
    trackManager.begin();
    User user = easyEntityQuery.queryable(User.class).asTracking().findNotNull(id);
    user.setName("new");
    easyEntityQuery.updatable(user).executeRows();
} finally {
    trackManager.release();
}
```

Spring can use `@EasyQueryTrack` where configured.
