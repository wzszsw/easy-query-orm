# Functions and Native SQL

Use this reference when a query needs SQL functions, typed expression conversion, or raw SQL fragments.

Prefer typed DSL functions first. Use raw SQL only for dialect-specific fragments, legacy SQL, or a function not exposed by easy-query.

## Type Expression Helpers

Source interfaces expose useful typed helpers:

- `StringTypeExpression`: `asStr`, `isBlank`, `isNotBlank`, `isEmpty`, `isNotEmpty`, `startsWith`, `endsWith`, `contains`, `notStartsWith`, `notEndsWith`, `notContains`.
- `ObjectTypeExpression`: `asAny`, `valueConvert`.
- `NumberTypeExpression`: numeric function support through `ColumnNumberFunctionAvailable`.

Examples:

```java
query.where(user -> {
    user.name().isNotBlank();
    user.name().startsWith(prefix);
    user.name().notContains(blockedWord);
});
```

Use `asAny()`/`asAnyType(...)` only to satisfy compile-time typing when the SQL expression type is known but the DSL type is too narrow.

Docs note that `toStr`/`toNumber` are database-level functions, while `asAny()` and `asAnyType(...)` are compile-time type adaptation.

## valueConvert

`valueConvert` is in-memory conversion after a selected SQL value is read:

```java
List<TopicVO> rows = easyEntityQuery.queryable(Topic.class)
    .select(t -> new TopicVOProxy()
        .title().set(t.stars().valueConvert(s -> s + "-"))
        .id().set(t.createTime().format("yyyy-MM-dd HH:mm:ss").valueConvert(s -> s + ".123")))
    .toList();
```

Do not use `valueConvert` to change SQL predicate semantics. It converts result values after SQL execution.

## Date and String Functions

Docs under `easy-query-doc/src/func` show date, string, number, aggregate, and JSON functions. Prefer local function DSL such as:

```java
user.createTime().format("yyyy-MM").eq("2026-06");
user.name().toLower().eq("tom");
```

Confirm the exact method exists in the target project version before using less common functions.

## Native Predicate Segment

Predicate SQL fragment:

```java
user.expression().sql("{0} != {1}", c -> {
    c.expression(user.name());
    c.value("x");
});
```

Use placeholders and `c.value(...)` for values. Do not concatenate user input into SQL fragments.

## Native Select Segment

Select SQL fragment:

```java
query.select(UserVO.class, user -> Select.of(
    user.expression()
        .sqlSegment("IFNULL({0}, 1)", c -> c.expression(user.age()), Integer.class)
        .as(UserVO.Fields.ageOrDefault)
));
```

Proxy assignment:

```java
query.select(user -> new UserVOProxy()
    .ageOrDefault().setSQL("IFNULL({0}, 1)", c -> c.expression(user.age())));
```

Expression update:

```java
easyEntityQuery.updatable(User.class)
    .setColumns(user -> {
        user.version().setSQL("ifnull({0},0)+{1}", c -> {
            c.expression(user.version());
            c.value(1);
        });
    })
    .where(user -> user.id().eq(id))
    .executeRows();
```

State the dialect assumption when using functions like `IFNULL`, `SUBSTR`, JSON operators, or database-specific date formats.

## Native SQL Query

Main proxy client exposes:

```java
easyEntityQuery.sqlQuery(sql, Result.class);
easyEntityQuery.sqlQuery(sql, Result.class, parameters);
easyEntityQuery.sqlEasyQuery(sql, Result.class, sqlParameters);
easyEntityQuery.sqlQueryMap(sql);
easyEntityQuery.sqlExecute(sql);
```

Prefer DSL unless raw SQL is part of the requirement or the SQL already exists.
