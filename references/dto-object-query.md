# DTO Object Query

Use this reference for request-object driven filtering and sorting with
`whereObject(...)` and `orderByObject(...)`.

Do not use this file as the main guide for:

- DTO result graph mapping: read `select-auto-include.md`
- `sql-search` / `EasySearch` / `@EasyCond`: read `easy-search.md`

## Core APIs

Source signatures:

```java
default ClientQueryable<T1> whereObject(Object object)
ClientQueryable<T1> whereObject(boolean condition, Object object)

default ClientQueryable<T1> orderByObject(ObjectSort configuration)
ClientQueryable<T1> orderByObject(boolean condition, ObjectSort objectSort)
```

Standard pattern:

```java
List<SysUser> users = easyEntityQuery.queryable(SysUser.class)
    .whereObject(request)
    .orderByObject(sort)
    .toList();
```

This is usually the preferred approach for frontend/admin query forms with many
optional filters. When the request object already models the search form,
`whereObject(...)` avoids long repetitive gated DSL chains and keeps filtering
rules declarative.

Use this approach when:

- the request DTO is essentially a query form
- many conditions are optional
- the filter shape is stable enough to describe with metadata
- list/search pages need the same condition logic repeatedly

## `@EasyWhereCondition`

Source fields:

```java
@EasyWhereCondition(
    tableIndex = 0,
    allowEmptyStrings = false,
    propName = "",
    propNames = {},
    tablesIndex = {},
    mode = EasyWhereCondition.Mode.SINGLE,
    type = EasyWhereCondition.Condition.DEFAULT
)
```

Important condition values:

```text
DEFAULT, EQUAL, NOT_EQUAL, GREATER_THAN, LESS_THAN,
LIKE, LIKE_MATCH_LEFT, LIKE_MATCH_RIGHT,
GREATER_THAN_EQUAL, LESS_THAN_EQUAL,
IN, NOT_IN,
RANGE_LEFT_OPEN, RANGE_LEFT_CLOSED,
RANGE_RIGHT_OPEN, RANGE_RIGHT_CLOSED,
COLLECTION_EQUAL_OR,
RANGE_OPEN, RANGE_CLOSED, RANGE_CLOSED_OPEN, RANGE_OPEN_CLOSED,
CONTAINS, STARTS_WITH, ENDS_WITH
```

Modes:

- `SINGLE`: one request field maps to one property path
- `MULTI_OR`: one request field maps to multiple properties joined by OR

Examples:

```java
@EasyWhereCondition(propName = "bankCards.code", type = EasyWhereCondition.Condition.STARTS_WITH)
private String bankCardCode;

@EasyWhereCondition(mode = EasyWhereCondition.Mode.MULTI_OR, propNames = {"name", "phone"})
private String keyword;

@EasyWhereCondition(type = EasyWhereCondition.Condition.RANGE_LEFT_CLOSED, propName = "createTime")
private LocalDateTime createTimeBegin;

@EasyWhereCondition(type = EasyWhereCondition.Condition.RANGE_RIGHT_CLOSED, propName = "createTime")
private LocalDateTime createTimeEnd;
```

Notes:

- Relation paths in `propName` are supported.
- To-one paths become implicit joins.
- To-many paths become implicit subqueries.
- `tableIndex` / `tablesIndex` are for explicit join tables, not implicit joins.
- `DEFAULT` follows starter config `defaultCondition`; the default behavior may be
  `LIKE` rather than `CONTAINS`.
- This style works especially well for frontend query forms where many inputs map
  one-to-one onto entity fields or relation paths.

## `orderByObject` and `ObjectSort`

`orderByObject(...)` expects an `ObjectSort` configuration or a project helper
that produces one.

Pattern:

```java
ObjectSort sort = request.toObjectSort();

List<SysUser> users = easyEntityQuery.queryable(SysUser.class)
    .whereObject(request)
    .orderByObject(sort)
    .toList();
```

Source docs are strict about mismatched sort fields. If the configured sort field
does not exist on the supported query/sort object shape, the query may fail fast.

## `ObjectSortBuilder`

Source methods:

```java
builder.orderBy(propertyName, asc);
builder.orderBy(propertyName, asc, tableIndex);
builder.orderBy(propertyName, asc, orderByMode);
builder.orderBy(propertyName, asc, orderByMode, tableIndex);
builder.allowed(propertyName);
builder.notAllowed(propertyName);
```

Use it for frontend-driven or external sort input:

- `allowed(...)`: declare sortable fields explicitly
- `notAllowed(...)`: deny specific fields that still exist on the object shape
- `tableIndex`: target explicit join tables
- `orderByMode`: configure null ordering when supported

Nested to-one property paths are supported, for example:

```java
builder.orderBy("user.name", true);
```

## `anyColumn(...)`

Use `anyColumn(...)` for controlled dynamic property access when a property path
must be chosen at runtime.

```java
query.where(card -> {
    card.anyColumn("code").nullOrDefault("123").eq("456");
});

query.orderBy(card -> {
    card.anyColumn("user.age").orderBy(false, OrderByModeEnum.NULLS_LAST);
});
```

Still validate user-provided property names through an allowlist.

## Relation-Aware DTO Filters

DTO request objects can target relation paths when entity navigation metadata is
already correct.

Rules:

- use relation paths in `propName` only when the entity relation is already modeled correctly
- prefer explicit DSL when the relation logic is hard to review from annotations alone
- if the same to-many relation is hit repeatedly, evaluate
  `@Navigate(subQueryToGroupJoin = true)` or query-level
  `.subQueryToGroupJoin(...)`

## When Explicit DSL Is Clearer

For small filters, one-off service methods, or query shapes that do not really
look like a form object, ordinary DSL can still be easier to review:

```java
easyEntityQuery.queryable(SysUser.class)
    .filterConfigure(NotNullOrEmptyValueFilter.DEFAULT)
    .where(user -> {
        user.name().contains(request.getName());
        user.age().ge(request.getMinAge());
        user.company().name().contains(request.getCompanyName());
    });
```

Or gate the whole clause:

```java
query.where(request.hasName(), user -> user.name().contains(request.getName()));
```

Use explicit DSL when:

- the request object abstraction makes the query harder to understand
- the condition depends on nontrivial branching or computed business rules
- only a few fields are involved and the DSL is shorter than the metadata
