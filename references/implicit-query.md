# Implicit Query Capabilities

easy-query's core advantage is relation-driven implicit SQL generation. In docs this includes implicit Join, Subquery, Group, Partition, CaseWhen, and recursive tree queries.

## Relation Modeling Required

Implicit relation APIs require navigation metadata on entity or DTO fields:

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

Use object navigation on to-one relation properties. The framework creates the join only when the condition or select path is active.

```java
List<DocBankCard> cards = easyEntityQuery.queryable(DocBankCard.class)
    .filterConfigure(NotNullOrEmptyValueFilter.DEFAULT)
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

`@Navigate(required = true)` changes eligible to-one implicit joins to inner joins; otherwise to-one navigation generally uses left join for accuracy.

Explicit and implicit joins can be mixed:

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

## 2. Implicit Subquery

Use to-many navigation methods to produce `EXISTS`, scalar subqueries, or aggregate subqueries.

```java
easyEntityQuery.queryable(SysBank.class)
    .where(bank -> {
        bank.bankCards().any(card -> card.type().eq("DEBIT"));
        bank.bankCards().none(card -> card.type().eq("DISABLED"));
    });
```

Single-condition shorthand:

```java
bank.bankCards().flatElement().type().eq("DEBIT");
```

Documented to-many methods:

- `any(predicate)`
- `none(predicate)`
- `all(predicate)`
- `count()`, `count(column)`
- `sum(column)`, `avg(column)`, `max(column)`, `min(column)`
- `joining(column)`
- `where(predicate)`
- `distinct()`
- `first()`
- `element(index)`
- `elements(range)`
- `anyValue()`
- `noneValue()`
- `orderBy(orderExpression)`

Select scalar relation aggregate:

```java
List<DocUserVO> users = easyEntityQuery.queryable(DocUser.class)
    .select(DocUserVO.class, user -> Select.of(
        user.FETCHER.allFields(),
        user.bankCards().count().as(DocUserVO.Fields.cardCount)
    ))
    .toList();
```

Performance note: repeated to-many subqueries can be expensive. Consider implicit Group when many conditions or large tables are involved.

## 3. Implicit Group

Use `subQueryToGroupJoin` to rewrite eligible to-many subqueries into group join style SQL.

Client signature:

```java
queryable.subQueryToGroupJoin(o -> o.bankCards());
queryable.subQueryToGroupJoin(condition, o -> o.bankCards());
```

Proxy DSL source confirms overloads on `EntitySubQueryToGroupJoinable1/2/3`.

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

Use when a to-many relation is queried repeatedly or docs/tests show subquery SQL becoming slow on large data.

## 4. Implicit Partition

Use to-many element access or relation limit/order settings when you need ranked child rows such as first child, top N children, or offset/limit relation fetch. `@Navigate` exposes:

- `offset`
- `limit`
- `orderByProps`
- `partitionOrder`

`PartitionOrderEnum.THROW` is the default in source. If using partition without order, configure an order or an explicit partition order policy.

Common shape:

```java
@Navigate(
    value = RelationTypeEnum.OneToMany,
    selfProperty = Fields.id,
    targetProperty = Child.Fields.parentId,
    orderByProps = @OrderByProperty(property = Child.Fields.createTime, asc = false),
    limit = 1
)
private List<Child> latestChildren;
```

For DTO flattening through to-many, see `@NavigateFlat` in `entity-modeling-navigate.md`.

## 5. Implicit CaseWhen

Docs describe implicit CaseWhen for aggregate functions with filters:

```java
o.age().sum().filter(() -> o.name().like("x"))
```

Source also contains case-when builders:

- `SQLClientFunc.caseWhenBuilder(...)`
- `CaseWhenClientBuilder.caseWhen(...).elseEnd(...)`
- `CaseWhenBuilder.caseWhen(...)`
- `CaseWhenBuilderExpression.caseWhen(...)`

Use documented aggregate filter style when operating in proxy DSL; use explicit case-when builders only after checking project examples.

## 6. Recursive Tree

Tree CTE APIs:

```java
queryable.asTreeCTE();
queryable.asTreeCTE(op -> { ... });
queryable.asTreeCTECustom(codeProperty, parentCodeProperty);
queryable.asTreeCTECustom(codeProperty, parentCodeProperty, op -> { ... });
```

`asTreeCTE` supports database objects. Source comments note `selectAutoInclude` ignores the configured tree navigation to avoid treating `children` as a normal one-to-many include.

Pattern:

```java
List<MyCommentDTO> tree = easyEntityQuery.queryable(Comment.class)
    .asTreeCTE()
    .selectAutoInclude(MyCommentDTO.class)
    .toList();
```

For DTO child property, mark tree child navigation with `@Navigate(ignoreAutoInclude = true)` when needed.
