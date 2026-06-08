# DTO Object Query

Use this reference for request-object driven filtering and sorting with
`whereObject(...)` and `orderByObject(...)`.

Do not use this file as the main guide for:

- DTO result graph mapping: read `select-auto-include.md`
- `sql-search` / `EasySearch` / `@EasyCond`: read `easy-search.md`
- ordinary non-form dynamic query logic: read `query.md`

This is the query/search-form branch, not the default for all dynamic query
tasks. For the common combined shape "search/page form + stable sort + DTO
graph return", read `search-form-page.md` first.

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
optional filters.

Typical examples:

- user management search
- admin list page filters
- order list / customer list / bank-card list query forms
- controller/service `search` or `page` endpoints with many optional request fields

Use it when the request DTO is really a query form and many conditions are
optional. Otherwise prefer `query.md`.

It can be combined with DSL in the same query chain. This is often the best
shape for real business code:

```java
queryable
    .whereObject(queryForm)
    .where(queryForm.getRoleId() != null, user -> user.roles().any(role -> role.id().eq(queryForm.getRoleId())))
    .orderByObject(queryForm)
    .orderBy(user -> { user.createdTime().desc(); user.id().desc(); });
```

Use `whereObject(...)` for the broad form conditions, then add explicit DSL
only for the awkward relation/computed pieces.

## Search-Form Filters With Manual Sort

For many admin/search page endpoints, filters are form-like but sorting is only
`sortBy + asc/desc`. In that shape:

- keep filters in `whereObject(...)`
- keep sort as explicit allowlisted `.orderBy(...)`
- append stable fallback order such as `createdTime desc`, `id desc`
- then call `selectAutoInclude(ResultDTO.class)` and `toPageResult(...)`

Do not force `orderByObject(...)` if only a few sortable fields exist; manual
`orderBy(...)` is often clearer.

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

High-value condition values:

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

- relation paths in `propName` are supported
- to-one paths become implicit joins
- to-many paths become implicit subqueries
- `tableIndex` / `tablesIndex` are for explicit join tables
- `DEFAULT` follows starter `defaultCondition`

## `orderByObject` and `ObjectSort`

`orderByObject(...)` expects an `ObjectSort` (`com.easy.query.core.api.dynamic.sort`)
configuration or a project helper
that produces one.

Pattern:

```java
ObjectSort sort = request.toObjectSort();

List<SysUser> users = easyEntityQuery.queryable(SysUser.class)
    .whereObject(request)
    .orderByObject(sort)
    .toList();
```

Mismatched sort fields can fail fast.

## `ObjectSortBuilder`

Source methods from `com.easy.query.core.api.dynamic.sort.ObjectSortBuilder`:

```java
builder.orderBy(propertyName, asc);
builder.orderBy(propertyName, asc, tableIndex);
builder.orderBy(propertyName, asc, orderByMode);
builder.orderBy(propertyName, asc, orderByMode, tableIndex);
builder.allowed(propertyName);
builder.notAllowed(propertyName);
```

Use it when external sort input belongs to the same query-form workflow.

Nested to-one property paths are supported, for example:

```java
builder.orderBy("user.name", true);
```

## `anyColumn(...)`

Use `anyColumn(...)` for controlled runtime property-path access.

```java
query.where(card -> {
    card.anyColumn("code").nullOrDefault("123").eq("456");
});

query.orderBy(card -> {
    card.anyColumn("user.age").orderBy(false, OrderByModeEnum.NULLS_LAST);
});
```

Still validate property names through an allowlist.

`OrderByModeEnum` is `com.easy.query.core.func.def.enums.OrderByModeEnum`.

## Relation-Aware DTO Filters

DTO request objects can target relation paths when entity navigation metadata is
already correct.

Rules:

- use relation paths only when entity relations are already correct
- prefer explicit DSL when annotation-driven relation logic is hard to review
- repeated to-many relation hits may justify `subQueryToGroupJoin`

## When Explicit DSL Is Clearer

For small filters, one-off service methods, or query shapes that do not really
look like a form object, ordinary DSL is usually the better default:

```java
easyEntityQuery.queryable(SysUser.class)
    .filterConfigure(NotNullOrEmptyValueFilter.DEFAULT)
    .where(user -> {
        user.name().contains(request.getName());
        user.age().ge(request.getMinAge());
        user.company().name().contains(request.getCompanyName());
    });
```

`NotNullOrEmptyValueFilter` is `com.easy.query.core.expression.builder.core`.

Or gate the whole clause:

```java
query.where(request.hasName(), user -> user.name().contains(request.getName()));
```

Use explicit DSL when:

- the request object abstraction makes the query harder to understand
- the condition depends on nontrivial branching or computed business rules
- only a few fields are involved and the DSL is shorter than the metadata

Do not swing too far the other way: if the task is obviously "build a search
endpoint with many optional filters", prefer `whereObject(...)` first rather
than hand-writing a long chain of gated predicates. Outside that search-form
shape, stay with DSL.
