# Built-in Functions

Use this reference when the requirement is still inside easy-query's typed
database-function layer: string/number/date/JSON functions, general typed
helpers, or `valueConvert` boundaries.

Do not use this file for raw SQL fragments, `sqlQuery(...)`, `sqlExecute(...)`,
`queryable(rawSql, ...)`, or custom native-function wrappers. Those belong in
`native-sql.md`.

This is still SQL-side capability, not an abstraction away from the database.
The difference from `native-sql.md` is not "no SQL involved", but "easy-query
already gives you a typed function surface". Dialect and version support can
still matter here, for example when one database exposes a function only on a
newer version.

## Fast Routing

Use this file when the request mentions any of these:

- string formatting / concatenation / trimming / case conversion / padding
- numeric math functions such as abs, round, floor, ceiling, log, pow, sqrt
- date formatting / date math / date properties / duration
- JSON object or JSON array field access
- `valueConvert` vs SQL-side function conversion
- lesser-known typed helpers such as `equalsWith`, `nullOrDefault`,
  `maxColumns/minColumns`

If the user is asking for a SQL fragment, whole SQL string, or unsupported
dialect function fallback, switch to `native-sql.md`.

## Type Expression Helpers

Source interfaces expose useful typed helpers:

- `StringTypeExpression`: `asStr`, `isBlank`, `isNotBlank`, `isEmpty`,
  `isNotEmpty`, `startsWith`, `endsWith`, `contains`, `notStartsWith`,
  `notEndsWith`, `notContains`
- `ObjectTypeExpression`: `asAny`, `valueConvert`
- `NumberTypeExpression`: numeric function support through
  `ColumnNumberFunctionAvailable`

Examples:

```java
query.where(user -> {
    user.name().isNotBlank();
    user.name().startsWith(prefix);
    user.name().notContains(blockedWord);
});
```

Use `asAny()` / `asAnyType(...)` only to satisfy compile-time typing when the
SQL expression type is known but the DSL type is too narrow.

Docs note that `toStr` / `toNumber` are database-level functions, while
`asAny()` and `asAnyType(...)` are compile-time type adaptation.

## valueConvert

`valueConvert` is in-memory conversion after a selected SQL value is read:

```java
List<TopicVO> rows = easyEntityQuery.queryable(Topic.class)
    .select(t -> new TopicVOProxy()
        .title().set(t.stars().valueConvert(s -> s + "-"))
        .id().set(t.createTime().format("yyyy-MM-dd HH:mm:ss").valueConvert(s -> s + ".123")))
    .toList();
```

Do not use `valueConvert` to change SQL predicate semantics. It converts result
values after SQL execution.

## Function Families

Docs under `easy-query-doc/src/func` show date, string, number, aggregate, and
JSON functions. Prefer local function DSL such as:

```java
user.createTime().format("yyyy-MM").eq("2026-06");
user.name().toLower().eq("tom");
```

High-value verified shapes:

- string concat / stringFormat: `code().concat("x")`,
  `expression().stringFormat(...)`
- string case / trim / length / compare:
  `toLower()`, `toUpper()`, `trim()`, `ltrim()`, `rtrim()`, `length()`,
  `compareTo(...)`
- string slice / pad:
  `subString(begin, length)`, `leftPad(...)`, `rightPad(...)`
- date format / add / extract:
  `format(...)`, `plusDays(...)`, `plusMonths(...)`, `year()`, `month()`,
  `day()`, `hour()`, `minute()`, `second()`, `dayOfYear()`, `dayOfWeek()`,
  `dayOfWeekSunDayIsLastDay()`,
  `duration(...).toDays()/toHours()/toMinutes()/toSeconds()`
- numeric math:
  `abs()`, `sign()`, `floor()`, `ceiling()`, `round()`, `round(decimals)`,
  `log()`, `log10()`, `pow(...)`, `sqrt()`, `cos()`, `sin()`, `tan()`,
  `acos()`, `asin()`, `atan()`, `atan2(...)`, `truncate()`
- JSON object / array:
  `asJSONObject()`, `asJSONArray()`, `getJSONObject(...)`,
  `getJSONArray(...)`, `getString(...)`, `getBoolean(...)`,
  `getInteger(...)`, `getLong(...)`, `getBigDecimal(...)`, `containsKey(...)`

Confirm the exact method exists in the target project version before using less
common functions.

## String Functions

`concat` and `stringFormat` are first-choice answers for string concatenation
and template-style composition.

```java
easyEntityQuery.queryable(DocBankCard.class)
    .where(card -> {
        card.code().concat("nextCode").eq("aaaa");
        card.code().concat(card.type()).eq("123");
        card.expression().constant("这张银行卡编号:").concat(card.code()).eq("123");
        card.expression().stringFormat("这张银行卡编号:{0},类型为:{1}", card.code(), card.type())
            .eq("这张银行卡编号:123,类型为:456");
    })
    .selectColumn(card -> card.expression().stringFormat("这张银行卡编号:{0},类型为:{1}", card.code(), card.type()))
    .toList();
```

Use `toLower()`, `toUpper()`, `trim()` / `ltrim()` / `rtrim()`,
`subString(...)`, `leftPad(...)`, `rightPad(...)`, `length()`, and
`compareTo(...)` as verified string DSL.

If the user asks specifically about left-trim / right-trim naming, mention
that current source also has lower-level `trimStart()` / `trimEnd()` helpers,
while the user-facing docs/examples usually show `ltrim()` / `rtrim()`.

## Number Functions

Use math helpers on numeric columns when the query needs derivation rather than
raw SQL fragments.

```java
easyEntityQuery.queryable(BlogEntity.class)
    .select(b -> Select.DRAFT.of(
        b.score().abs(),
        b.score().floor(),
        b.score().ceiling(),
        b.score().round(),
        b.score().round(2),
        b.score().log(),
        b.score().pow(BigDecimal.valueOf(3)),
        b.score().sqrt()
    ))
    .toList();
```

The tested source also covers `sign()`, `log10()`, `cos()`, `sin()`, `tan()`,
`acos()`, `asin()`, `atan()`, `atan2(...)`, and `truncate()`.

## Date Functions

Use date functions when the requirement is a formatted date string, a date
bucket, or an interval comparison.

```java
easyEntityQuery.queryable(BlogEntity.class)
    .select(b -> Select.DRAFT.of(
        b.createTime(),
        b.createTime().format("yyyy-MM"),
        b.createTime().plusDays(1),
        b.createTime().year(),
        b.createTime().dayOfYear(),
        b.createTime().duration(LocalDateTime.of(2025, 1, 1, 0, 0, 0)).toDays()
    ))
    .toList();
```

State the dialect assumption when using date formats, because the SQL emitted
for `format(...)` varies by database.

## JSON Functions

Use JSON DSL when the field is mapped as JSON object / array and the user wants
typed access rather than raw string parsing.

```java
easyEntityQuery.queryable(TopicJson.class)
    .where(t -> {
        t.extraJsonArray().asJSONArray().getJSONObject(0).getString("name").eq("Jack");
    })
    .toList();
```

Prefer this over raw SQL JSON operators when the current project version
already exposes the typed JSON surface.

If the user asks for JSON array length specifically, note the boundary:
current source contains `JSONArrayLengthSQLFunction`, but unless the current
project or nearby verified example proves the surfaced DSL method name, answer
conservatively instead of inventing the exact chain.

## Additional General Functions

Some source-backed function helpers live outside the obvious string/date/math
grouping and are easy to miss:

- `nullOrDefault(...)`: cross-type SQL-side null fallback
- `equalsWith(...)`: compare two values and return a boolean expression
- `maxColumns(...)` / `minColumns(...)`: greatest/least style multi-column
  comparison where supported

Example:

```java
easyEntityQuery.queryable(DocBankCard.class)
    .select(card -> Select.DRAFT.of(
        card.id().equalsWith("123"),
        card.code().nullOrDefault("noCode")
    ))
    .toList();
```

Use these before dropping to raw SQL for simple null/default or equality
expression cases.

## Lesser-Known but Real

Additional source-backed items worth knowing:

- `cast(..., TargetClass.class)` for SQL-side type cast in lower-level `fx()`
  usage
- `trimStart()` / `trimEnd()` exist in current source; user-facing DSL often
  appears as `ltrim()` / `rtrim()`
- offset/window functions also expose `firstValue()` / `lastValue()` /
  `nthValue(...)`, but they belong to the offset/window branch rather than the
  ordinary string/date/math branch

These are worth surfacing as supplement, but they are not the mainstream first
answer for ordinary function questions.
