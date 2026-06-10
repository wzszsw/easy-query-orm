# Symbol Imports

Use this reference when easy-query code, docs, or user snippets mention a type
name but omit the import.

This is the package/FQCN branch, not the semantic feature guide. Resolve the
type here first, then jump back to `api-map.md` or the feature reference for
behavior.

## Workflow

1. Resolve the type from easy-query source, not from blog/demo snippets.
2. Run `python scripts/search_symbols.py EasyWhereCondition StarterConfigurer`
   for the exact type names you need.
3. Prefer `src/main/java` / `src/main/kotlin` declarations over tests or docs.
4. If the current project already imports one of several matches, prefer the
   project import.
5. When answering with non-obvious easy-query types, include the explicit
   `import ...;` line or the FQCN on first mention.

## Nested Type Rule

Import the owner type, not the nested member:

- `EasyWhereCondition.Condition` ->
  `import com.easy.query.core.annotation.EasyWhereCondition;`
- `Select.DRAFT` / `Select.TUPLE` ->
  `import com.easy.query.core.proxy.sql.Select;`

If the missing symbol is really a method/field rather than a type, switch to
`api-map.md` or the feature reference instead of forcing an import lookup.

## Source Lookup Command

Examples:

```text
python scripts/search_symbols.py EasyWhereCondition WhereConditionProvider
python scripts/search_symbols.py EasyEntityQuery ProxyEntityAvailable
python scripts/search_symbols.py --root D:\develop\SOURCE_CODE\easy-query EasySearch EasyCond
```

The script reads top-level declarations from easy-query source and prints:

- symbol kind
- fully qualified class name
- ready-to-copy Java import line
- declaring file path

## High-Frequency Imports

### Entry Points

| Symbol | Import |
|--------|--------|
| `EasyEntityQuery` | `import com.easy.query.api.proxy.client.EasyEntityQuery;` |
| `DefaultEasyEntityQuery` | `import com.easy.query.api.proxy.client.DefaultEasyEntityQuery;` |
| `EasyQueryClient` | `import com.easy.query.core.api.client.EasyQueryClient;` |
| `EasyQueryBootstrapper` | `import com.easy.query.core.bootstrapper.EasyQueryBootstrapper;` |
| `ProxyEntityAvailable` | `import com.easy.query.core.proxy.ProxyEntityAvailable;` |
| `Transaction` | `import com.easy.query.core.basic.jdbc.tx.Transaction;` |

### Mapping / Annotation

Most core entity annotations come from `com.easy.query.core.annotation`:

```java
import com.easy.query.core.annotation.Table;
import com.easy.query.core.annotation.EntityProxy;
import com.easy.query.core.annotation.EntityFileProxy;
import com.easy.query.core.annotation.EasyAlias;
import com.easy.query.core.annotation.Column;
import com.easy.query.core.annotation.ColumnIgnore;
import com.easy.query.core.annotation.InsertIgnore;
import com.easy.query.core.annotation.UpdateIgnore;
import com.easy.query.core.annotation.ProxyProperty;
import com.easy.query.core.annotation.Version;
import com.easy.query.core.annotation.LogicDelete;
import com.easy.query.core.annotation.Navigate;
import com.easy.query.core.annotation.NavigateFlat;
import com.easy.query.core.annotation.ShardingTableKey;
import com.easy.query.core.annotation.EasyQueryTrack;
import com.easy.query.core.annotation.EasyWhereCondition;
```

Related enums that commonly pair with those annotations:

```java
import com.easy.query.core.enums.RelationTypeEnum;
import com.easy.query.core.enums.SQLExecuteStrategyEnum;
import com.easy.query.core.enums.SubQueryModeEnum;
import com.easy.query.core.basic.extension.logicdel.LogicDeleteStrategyEnum;
```

### Search Form / Dynamic Query

| Symbol | Import |
|--------|--------|
| `WhereConditionProvider` | `import com.easy.query.core.api.dynamic.executor.query.WhereConditionProvider;` |
| `WhereObjectQueryExecutor` | `import com.easy.query.core.api.dynamic.executor.query.WhereObjectQueryExecutor;` |
| `ObjectSortBuilder` | `import com.easy.query.core.api.dynamic.sort.ObjectSortBuilder;` |
| `OrderByModeEnum` | `import com.easy.query.core.func.def.enums.OrderByModeEnum;` |
| `NotNullOrEmptyValueFilter` | `import com.easy.query.core.expression.builder.core.NotNullOrEmptyValueFilter;` |

### Projection / Analytics

| Symbol | Import |
|--------|--------|
| `Select` | `import com.easy.query.core.proxy.sql.Select;` |
| `GroupKeys` | `import com.easy.query.core.proxy.sql.GroupKeys;` |

### Conversion / Interceptor

```java
import com.easy.query.core.configuration.QueryConfiguration;
import com.easy.query.core.basic.extension.conversion.ValueConverter;
import com.easy.query.core.basic.extension.conversion.ValueAutoConverter;
import com.easy.query.core.basic.jdbc.types.handler.JdbcTypeHandler;
import com.easy.query.core.basic.extension.interceptor.Interceptor;
import com.easy.query.core.basic.extension.interceptor.EntityInterceptor;
import com.easy.query.core.basic.extension.interceptor.PredicateFilterInterceptor;
import com.easy.query.core.basic.extension.interceptor.UpdateSetInterceptor;
import com.easy.query.core.basic.extension.interceptor.UpdateEntityColumnInterceptor;
import com.easy.query.core.basic.extension.interceptor.ProtectedInterceptor;
```

### Spring Boot / Search Extension

```java
import com.easy.query.sql.starter.config.EasyQueryProperties;
import com.easy.query.sql.starter.config.EasyQueryInitializeOption;
import com.easy.query.sql.starter.config.JdbcTypeHandlerReplaceConfigurer;
import com.easy.query.core.bootstrapper.StarterConfigurer;
import com.easy.query.search.EasySearch;
import com.easy.query.search.annotation.EasyCond;
```

## Ambiguity Rules

- Do not infer a package from the docs alone when the source declaration can be
  checked.
- Prefer the symbol owner in source even if tests/examples use wildcard imports.
- If multiple source matches remain, report that fact instead of silently
  picking one.
- For compile-ready answers, do not leave non-obvious easy-query types
  unimported just because the original snippet omitted them.
