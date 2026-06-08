# Implicit Query Capabilities

easy-query's strongest "hidden" feature set is relation-driven implicit SQL.
The proxy path itself decides whether the framework emits an implicit join,
correlated subquery, group-join rewrite, partition window, boolean projection,
or tree query.

Use this file when the question depends on relation navigation behavior rather
than plain `where/orderBy/select` chaining.

## What Triggers Implicit SQL

- To-one navigation like `card.user().name()` triggers implicit join SQL.
- To-many navigation methods like `any/none/all/count/sum/max/joining` trigger
  implicit subquery or group-join SQL.
- Ranked child access like `first()`, `element(index)`, and
  `elements(start,end)` triggers implicit partition/window SQL.
- Boolean relation projection like `anyValue()` and `noneValue()` triggers
  `CASE WHEN EXISTS ...` style SQL.
- Tree APIs like `asTreeCTE()` trigger recursive SQL generation.

If a relation is not modeled correctly, these APIs do not degrade gracefully;
they produce wrong SQL or runtime failures. Verify `@Navigate` first.

## Relation Modeling Required

The examples below use `Fields.xxx` constants. Those come from Lombok
`@FieldNameConstants` on the related entity classes. If the project does not
use that Lombok annotation, replace the `Fields` constants with string literals.

```java
@Navigate(
    value = RelationTypeEnum.ManyToOne,
    selfProperty = Fields.uid,
    targetProperty = DocUser.Fields.id
)
private DocUser user;

@Navigate(
    value = RelationTypeEnum.OneToMany,
    selfProperty = Fields.id,
    targetProperty = DocBankCard.Fields.uid
)
private List<DocBankCard> bankCards;
```

See `relation-query.md` for basic relation shapes and
`entity-modeling-navigate.md` for advanced `@Navigate` options.

## 1. Implicit Join

Use object navigation on to-one relation properties. The join appears only when
the navigated path is actually referenced by `where`, `select`, `orderBy`, and
similar clauses.

```java
List<DocBankCard> cards = easyEntityQuery.queryable(DocBankCard.class)
    .where(card -> {
        card.user().name().eq(queryName);
        card.bank().name().contains(bankName);
    })
    .toList();
```

Common select pattern:

```java
List<Draft3<String, String, String>> rows = easyEntityQuery.queryable(DocBankCard.class)
    .where(card -> card.user().name().eq("x"))
    .select(card -> Select.DRAFT.of(
        card.code(),
        card.user().name(),
        card.bank().name()
    ))
    .toList();
```

Join semantics from source:

- `@Navigate(required = true)` changes eligible `ManyToOne` and `OneToOne`
  implicit joins to inner joins.
- Without `required = true`, to-one implicit navigation generally uses left
  join semantics.
- Explicit joins and implicit joins can be mixed in the same query.

```java
easyEntityQuery.queryable(DocBankCard.class)
    .leftJoin(DocBank.class, (card, bank) -> card.bankId().eq(bank.id()))
    .where((card, bank) -> {
        card.user().name().eq("x");
    })
    .select((card, bank) -> Select.DRAFT.of(
        card.code(),
        card.user().name(),
        bank.name()
    ));
```

## 2. Implicit Subquery and Scalar Relation Operators

Use to-many navigation to produce `EXISTS`, scalar subqueries, aggregate
subqueries, or boolean relation projections.

```java
easyEntityQuery.queryable(SysBank.class)
    .where(bank -> {
        bank.bankCards().any(card -> card.type().eq("DEBIT"));
        bank.bankCards().none(card -> card.type().eq("DISABLED"));
    });
```

High-value to-many operators verified in source/tests:

- `any()`, `any(predicate)`
- `none(predicate)`
- `all(predicate)`
- `count()`, `count(column)`
- `sum(column)`, `avg(column)`, `max(column)`, `min(column)`
- `where(predicate)`
- `distinct()`
- `orderBy(orderExpression)`
- `first()`
- `element(index)`
- `elements(start,end)`
- `joining(column)` and `joining(column, separator)`
- `anyValue()`
- `noneValue()`

`joining(...)` is more capable than the public docs suggest. Source tests show
it can be combined with:

- `where(...)`
- `orderBy(...)`
- `elements(...)`
- nested to-one navigation in the joined projection, for example
  `joining(role -> role.m8SaveA().name(), ",")`

Example:

```java
List<Draft2<String, String>> list = easyEntityQuery.queryable(M8User.class)
    .subQueryToGroupJoin(user -> user.roles())
    .select(user -> Select.DRAFT.of(
        user.id(),
        user.roles()
            .where(role -> role.name().startsWith("管理员"))
            .orderBy(role -> role.name().asc())
            .elements(0, 5)
            .joining(role -> role.name(), ",")
    ))
    .toList();
```

Boolean projection example:

```java
List<Draft2<Boolean, Boolean>> list = easyEntityQuery.queryable(SysUser.class)
    .select(user -> Select.DRAFT.of(
        user.bankCards().anyValue(),
        user.bankCards().noneValue()
    ))
    .toList();
```

Practical rules:

- `first()` is the partition-style "first ranked child" operator.
- Source tests show `element(index)` is zero-based.
- Source tests show `elements(start,end)` uses a zero-based, end-inclusive
  window. For example `elements(0, 5)` becomes row numbers `1..6`.
- For partition-style operators, require deterministic ordering from
  `orderBy(...)`, `orderByProps`, or `partitionOrder`; do not assume database
  natural order.

Select scalar relation aggregate:

```java
List<DocUserVO> users = easyEntityQuery.queryable(DocUser.class)
    .select(DocUserVO.class, user -> Select.of(
        user.FETCHER.allFields(),
        user.bankCards().count().as(DocUserVO.Fields.cardCount)
    ))
    .toList();
```

Performance note: repeated to-many subqueries can get expensive. Convert hot
paths to implicit Group when the same relation is filtered or aggregated more
than once.

## 3. Implicit Group / Group Join Conversion

Use group-join conversion when many-to-many or one-to-many relation subqueries
would otherwise repeat correlated SQL.

Available switches:

```java
queryable.subQueryToGroupJoin(o -> o.bankCards());
queryable.subQueryToGroupJoin(condition, o -> o.bankCards());
```

Annotation-level default:

```java
@Navigate(
    value = RelationTypeEnum.OneToMany,
    selfProperty = Fields.id,
    targetProperty = SysBankCard.Fields.uid,
    subQueryToGroupJoin = true
)
private List<SysBankCard> bankCards;
```

Global query behavior from source/tests:

```java
queryable.configure(op ->
    op.getBehavior().add(EasyBehaviorEnum.ALL_SUB_QUERY_GROUP_JOIN)
);
```

Pattern:

```java
easyEntityQuery.queryable(SysUser.class)
    .subQueryToGroupJoin(user -> user.bankCards())
    .where(user -> {
        user.bankCards().any(card -> card.type().eq("DEBIT"));
        user.bankCards().count().gt(2L);
    })
    .toList();
```

Advanced source behaviors:

- Eligible group-join expressions may be auto-merged into one grouped SQL
  block.
- If that merge changes the SQL shape in a way the task cares about, source
  tests use `EasyBehaviorEnum.GROUP_JOIN_NOT_ALLOW_AUTO_MERGE`.
- Deep nested to-many paths can be configured per branch with
  `subQueryConfigure(parentPath, query -> query.subQueryToGroupJoin(childPath))`.

Use group-join conversion when:

- the same to-many relation is referenced multiple times in one query
- the query combines `where + orderBy + aggregate + joining`
- source/test evidence shows correlated subqueries are too slow

## 4. Implicit Partition / Ranked Child Access

Use partition operators when you need first child, nth child, top-N child
window, or relation-level limit/offset semantics.

Relevant `@Navigate` fields:

- `orderByProps`
- `offset`
- `limit`
- `partitionOrder`

`PartitionOrderEnum` choices from source:

- `THROW`
- `IGNORE`
- `NAVIGATE`
- `KEY_ASC`
- `KEY_DESC`

`THROW` is the default. If the query shape needs ranked child access and there
is no explicit order, decide intentionally:

- add `orderBy(...)` in the query
- add `orderByProps` on the relation
- set a non-throw `partitionOrder`

Entity example:

```java
@Navigate(
    value = RelationTypeEnum.OneToMany,
    selfProperty = Fields.id,
    targetProperty = Child.Fields.parentId,
    orderByProps = @OrderByProperty(property = Child.Fields.createTime, asc = false),
    limit = 1,
    partitionOrder = PartitionOrderEnum.NAVIGATE
)
private List<Child> latestChildren;
```

Important join semantics from the annotation comment:

- For `OneToMany` and `ManyToMany`, `required = true` makes implicit group join
  use inner join semantics.
- For implicit partition, `required = true` makes `first()` / `element(0)`
  style access eligible for inner join semantics.
- Other cases remain left join oriented.

For DTO flattening through to-many relation paths, see `@NavigateFlat` in
`entity-modeling-navigate.md`.

## 5. Implicit CaseWhen and Boolean/Aggregate Filters

Aggregate filters are the documented proxy-style entry point for implicit
`CASE WHEN` behavior:

```java
group.groupTable().id().count().filter(() -> {
    group.groupTable().birthday().ge(LocalDateTime.of(2024, 1, 1, 0, 0));
});
```

Non-group aggregate filters also appear in source README examples:

```java
user.id().count().filter(() -> {
    user.address().eq("Beijing");
});
```

Source also contains lower-level case-when builders:

- `SQLClientFunc.caseWhenBuilder(...)`
- `CaseWhenClientBuilder.caseWhen(...).elseEnd(...)`
- `CaseWhenBuilder.caseWhen(...)`
- `CaseWhenBuilderExpression.caseWhen(...)`

Use the documented aggregate-filter style first. Drop to explicit builders only
after checking project code or source tests.

## 6. Recursive Tree

Tree CTE APIs:

```java
queryable.asTreeCTE();
queryable.asTreeCTE(op -> { ... });
queryable.asTreeCTECustom(codeProperty, parentCodeProperty);
queryable.asTreeCTECustom(codeProperty, parentCodeProperty, op -> { ... });
```

Source comments note that `selectAutoInclude` ignores the configured tree
navigation to avoid treating `children` as an ordinary one-to-many include.

```java
List<MyCommentDTO> tree = easyEntityQuery.queryable(Comment.class)
    .asTreeCTE()
    .selectAutoInclude(MyCommentDTO.class)
    .toList();
```

If the DTO or VO has a tree child relation, mark that navigation with
`@Navigate(ignoreAutoInclude = true)` when the auto-include path would conflict
with tree semantics.
