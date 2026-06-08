# Implicit Relation Controls

Use this for the control knobs around implicit relation paths:

- root-level `subQueryConfigure(...)`
- relation `.filter(...)`
- relation `.distinct()`
- relation `.configure(...)`
- relation `.mode(SubQueryModeEnum...)`
- `flatElement(...)`
- `notEmptyAll(...)`
- `expression().valueOf(...)`

Read `implicit-query.md` only for the broader feature set.

Global heuristic:

- if existing `@Navigate` metadata already exposes the business path, answer
  with the relation path first
- try `flatElement`, relation `any/count/sum`, relation `filter/configure`,
  or tree anchoring from relation-derived ids before switching to explicit
  joins or junction-table queries

## Fast Patterns

If the request looks like one of these, answer with the matching shape first:

- shared to-many baseline + several `any(...)` checks:
  `.subQueryConfigure(root -> root.relation(), q -> q.where(...))`
- force relation strategy locally:
  `.mode(SubQueryModeEnum.GROUP_JOIN)` or `.mode(SubQueryModeEnum.SUB_QUERY_ONLY)`
- keep condition on a to-one join target:
  `root.toOne().filter(target -> { ... })`
- flatten to-many traversal:
  `root.toMany().flatElement().nextPath()`
- relation aggregate must stay distinct internally:
  `root.toMany().distinct().sum(...)`
- boolean select column from relation-aware predicate:
  `root.expression().valueOf(() -> { ... })`

## 1. Root-Level `subQueryConfigure(...)`

Use this when later uses of one relation should inherit a shared baseline.

```java
easyEntityQuery.queryable(SysUser.class)
    .subQueryConfigure(s -> s.bankCards(), q -> q.where(card -> card.code().eq("1")))
    .where(user -> {
        user.bankCards().any(card -> card.type().eq("11"));
        user.bankCards().any(card -> card.type().eq("22"));
    })
    .toList();
```

Verified uses: shared `where`, `orderBy`, `filterConfigure`, nested
`subQueryToGroupJoin`.

Treat this as the first copyable answer shape for "same relation reused several
times in one query".

## 2. Relation `.filter(...)`

Relation `.filter(...)` is not the same as `.where(...)`.

### To-many relation `.filter(...)`

For a to-many path, it installs an independent baseline relation condition that
later subquery expressions can reuse.

```java
user.bankCards().filter(card -> {
    card.bank().name().eq("银行");
    card.type().like("45678");
});
```

Source behavior:

- It can include relation joins plus ordinary predicates.
- Multiple calls are not a general composition tool; only the last baseline is
  meant to stick.
- Useful before repeated `sum/max/min/joining/count`.

### To-one relation `.filter(...)`

For a to-one relation proxy, `.filter(...)` can push predicates into join `ON`.

```java
easyEntityQuery.queryable(DocBankCard.class)
    .where(card -> {
        card.bank().filter(bank -> {
            bank.name().contains("工商银行");
        });
    })
    .toList();
```

What source code does:

- relation table -> push to join `ON`
- otherwise -> behave like current-context predicate logic

This is the first-choice answer shape for "keep the filter on the implicit
relation, don't handwrite join".

## 3. Relation `.distinct()`

Relation subquery chains can apply `distinct()` before aggregate or count
operators.

```java
easyEntityQuery.queryable(SysUser.class)
    .select(user -> Select.DRAFT.of(
        user.bankCards().where(card -> card.type().eq("123")).distinct().count()
    ))
    .toList();
```

Source tests also show deeper aggregate shapes such as:

```java
easyEntityQuery.queryable(SubJoinUser.class)
    .select(user -> Select.DRAFT.of(
        user.books().distinct().sum(book -> book.author().age())
    ))
    .toList();
```

Use relation `distinct()` when distinctness belongs inside the implicit
subquery. Do not rewrite it to an outer `select distinct` unless the SQL
requirement is root-row distinctness.

This is the first-choice answer shape for relation-internal aggregate
distinctness.

## 4. Relation `.configure(...)`

Use relation `.configure(...)` for queryable-level options, not row predicates.

```java
user.roles().configure(roleQuery -> {
    roleQuery.asAlias("myRole");
}).any(role -> {
    role.name().like("查询的角色名");
});
```

Another verified shape:

```java
user.bankCards()
    .configure(q -> q.disableLogicDelete())
    .where(card -> card.type().eq("123"))
    .sum(card -> card.code().toNumber(Integer.class))
    .eq(123);
```

Use it for `asAlias(...)`, `disableLogicDelete()`, and similar verified
subquery options.

Do not confuse it with root-level `subQueryConfigure(...)`: that sets a
baseline from the root, while relation `.configure(...)` mutates the current
relation path itself.

## 5. Relation `.mode(SubQueryModeEnum)`

Use `mode(...)` when the relation execution strategy must be forced locally.

`SubQueryModeEnum` values from source:

- `DEFAULT`
- `SUB_QUERY_ONLY`
- `GROUP_JOIN`

Use the fully qualified enum import when writing example code:

```java
import com.easy.query.core.enums.SubQueryModeEnum;
```

Example:

```java
easyEntityQuery.queryable(SysUser.class)
    .where(user -> {
        user.roles().mode(SubQueryModeEnum.GROUP_JOIN);
        user.roles().flatElement().menus().any(menu -> {
            menu.route().eq("/admin");
        });
    })
    .toList();
```

Use this when a local override is safer than a broader behavior flag.

## 6. `flatElement(...)`

`flatElement()` temporarily treats a to-many path as flattened.

Common `where` shape:

```java
easyEntityQuery.queryable(Province.class)
    .where(p -> {
        p.cities().flatElement().areas().flatElement().name().eq("上城区");
    })
    .toList();
```

Permission-path shape:

```java
easyEntityQuery.queryable(SysMenu.class)
    .where(menu -> {
        menu.roles().flatElement().users().flatElement().id().eq(userId);
    })
    .toList();
```

Common `toList(...)` flattening shape:

```java
List<String> paths = easyEntityQuery.queryable(SysUser.class)
    .toList(user -> user.roles().flatElement().menus().flatElement().path());
```

Verified uses:

- one-level shorthand
- multi-level to-many traversal
- flattened `toList(...)` rows
- partial flattened fetch
- permission filters such as `user -> roles -> menus` or `menu -> roles -> users`

Critical restriction from proxy source:

- `flatElement` is not allowed inside `select(...)`.
- If the user wants flattened relation rows, prefer `toList(...)` with
  `flatElement(...)` instead of forcing it into `select(...)`.

Mental model:

- in `where(...)`: implicit any-style traversal
- in `toList(...)`: flatten returned relation rows

Practical rule:

- If relation metadata already exposes the business path, prefer
  `flatElement()` + navigation over hand-writing `SysUserRole` /
  `SysRoleMenu` junction-table subqueries.
- For a permission tree, that usually means filtering `SysMenu` by
  `menu.roles().flatElement().users()...` when reverse relations exist, or
  collecting menu ids from `SysUser.roles().flatElement().menus()...` when only
  the forward path exists.

## 7. `notEmptyAll(...)`

Use `notEmptyAll(...)` for "non-empty and every matched row passes".

```java
easyEntityQuery.queryable(SysUser.class)
    .where(user -> {
        user.bankCards()
            .where(card -> card.type().eq("储蓄卡"))
            .notEmptyAll(card -> card.code().startsWith("33123"));
    })
    .toList();
```

Source tests show `EXISTS(...)` plus a negated `EXISTS(...)` for violating
rows.

## 8. Predicate-to-Boolean Projection with `expression().valueOf(...)`

Use `expression().valueOf(...)` when `anyValue()` / `noneValue()` are too
narrow and the select column must be an arbitrary boolean predicate.

```java
List<Draft1<Boolean>> rows = easyEntityQuery.queryable(M8Province.class)
    .select(m -> Select.DRAFT.of(
        m.expression().valueOf(() -> {
            m.id().le(
                m.cities().where(c -> {
                    c.name().isNotNull();
                    c.id().isNotNull();
                }).count()
            );
        })
    ))
    .toList();
```

This is the verified escape hatch for relation-aware boolean projection.

## Selection Guide

- Need normal implicit join/subquery/group/partition/tree behavior:
  `implicit-query.md`
- Need relation baseline controls, flattening, or local strategy overrides:
  this file
- Need custom proxy VO projection with relation collections:
  `query-composition.md`
