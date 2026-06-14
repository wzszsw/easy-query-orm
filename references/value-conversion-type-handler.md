# Value Conversion and Type Handler

Use this for enum storage, JSON/object mapping, global auto conversion,
`@Column(conversion=...)`, `@Column(typeHandler=...)`, PostgreSQL `jsonb`, or
when the user is mixing up `ValueConverter` and `JdbcTypeHandler`.

## Core Split

There are three related but different layers:

- `ValueConverter<TProperty, TProvider>`: convert between the entity/DTO
  property value and the database-side Java value in memory
- `ValueAutoConverter<TProperty, TProvider>`: a global auto-applied
  `ValueConverter` selected by `apply(...)`
- `JdbcTypeHandler`: read/write JDBC values from `ResultSet` /
  `PreparedStatement`

Practical rule:

- use `ValueConverter` when the issue is object <-> database-value mapping
- use `ValueAutoConverter` when many fields should get that conversion without
  repeating `@Column(conversion=...)`
- use `JdbcTypeHandler` when the problem is the driver/JDBC binding itself,
  such as PostgreSQL `jsonb`, `PGobject`, UUID/binary specifics, or special
  parameter/result handling

## 1. `ValueConverter`

Source interface:

```java
public interface ValueConverter<TProperty, TProvider> {
    @Nullable TProvider serialize(@Nullable TProperty property, @NotNull ColumnMetadata columnMetadata);
    @Nullable TProperty deserialize(@Nullable TProvider provider, @NotNull ColumnMetadata columnMetadata);
}
```

Attach it through `@Column(conversion = XxxConverter.class)`.

```java
public class EnumConverter implements ValueConverter<IEnum<?>, Number> {
    @Override
    public Number serialize(IEnum<?> value, ColumnMetadata columnMetadata) {
        return value == null ? null : value.getCode();
    }

    @Override
    public IEnum<?> deserialize(Number dbValue, ColumnMetadata columnMetadata) {
        if (dbValue == null) {
            return null;
        }
        return EnumDeserializer.deserialize(
            EasyObjectUtil.typeCast(columnMetadata.getPropertyType()),
            dbValue.intValue()
        );
    }
}

@Table("t_topic_type")
public class TopicTypeTest1 {
    @Column(primaryKey = true)
    private String id;

    @Column(value = "topic_type", conversion = EnumConverter.class)
    private TopicTypeEnum topicType;
}
```

Use cases:

- enum code/int <-> enum object
- JSON string <-> object/list/map
- VO/DTO projection where one selected column should be deserialized into a
  richer Java type

Important note from `@Column` source comment:

- if a VO/DTO also has that property and expects converted values from a raw
  selected column, annotate that VO/DTO property too with the same conversion

For JSON/object values used in tracked updates, docs explicitly warn that the
converted object should implement stable `equals` / `hashCode`.

## 2. `ValueAutoConverter`

Source interface:

```java
public interface ValueAutoConverter<TProperty, TProvider> extends ValueConverter<TProperty, TProvider> {
    boolean apply(@NotNull Class<?> entityClass, @NotNull Class<TProperty> propertyType, String property);
}
```

Register it through `QueryConfiguration.applyValueConverter(...)` or as a
Spring bean.

```java
public class EnumConverter implements ValueAutoConverter<IEnum<?>, Number> {
    @Override
    public boolean apply(@NotNull Class<?> entityClass, @NotNull Class<IEnum<?>> propertyType, String property) {
        return IEnum.class.isAssignableFrom(propertyType);
    }

    @Override
    public Number serialize(IEnum<?> value, ColumnMetadata columnMetadata) {
        return value == null ? null : value.getCode();
    }

    @Override
    public IEnum<?> deserialize(Number dbValue, ColumnMetadata columnMetadata) {
        if (dbValue == null) {
            return null;
        }
        return EnumDeserializer.deserialize(
            EasyObjectUtil.typeCast(columnMetadata.getPropertyType()),
            dbValue.intValue()
        );
    }
}
```

Selection rules from source:

- `QueryConfiguration.applyValueConverter(...)` stores all converters and also
  collects `ValueAutoConverter`s into `valueAutoConverters`
- entity metadata only tries auto conversion when the column conversion is still
  the default (`DefaultValueConverter`)
- if more than one auto converter matches one property, source throws an error
- explicit `@Column(conversion = Xxx.class)` wins over auto conversion

Source-level support gate:

- `DefaultValueAutoConverterProvider` only considers auto converters for enum
  types or non-basic types by default

So do not assume every primitive/wrapper/string field will participate in auto
conversion.

## 3. Built-in Auto Enum Path: `@Enumerated`

Source shows `QueryConfiguration` registers
`NamedEnumValueAutoConverter.INSTANCE` by default.

That converter applies when the enum type itself has `@Enumerated`.

```java
@Enumerated
public enum NamedEnum {
    CREATED,
    PAID,
    CLOSED
}
```

Meaning:

- database stores enum `name()` strings
- read path converts string back to the enum constant
- this is global/automatic for that enum type; no field-level
  `@Column(conversion=...)` is required

This is a different pattern from code-value enums. For `1/2/3` style storage,
use a custom `ValueConverter` or `ValueAutoConverter`.

## 4. `JdbcTypeHandler`

Source interface:

```java
public interface JdbcTypeHandler {
    Object getValue(JdbcProperty jdbcProperty, StreamResultSet streamResultSet) throws SQLException;
    void setParameter(EasyParameter parameter) throws SQLException;
}
```

Use it when JDBC read/write itself needs special handling.

Examples:

- PostgreSQL `jsonb` needs `PGobject`
- custom database UUID/binary binding
- dialect/driver-specific parameter logic based on `jdbcType`

Column-level attachment:

```java
public class User {
    @Column(typeHandler = CustomPropertyTypeHandler.class)
    private CustomPropertyType name;
}
```

Manager-level replacement:

```java
JdbcTypeHandlerManager jdbcTypeHandlerManager = easyQuery.getRuntimeContext().getJdbcTypeHandlerManager();
jdbcTypeHandlerManager.appendHandler(CustomPropertyType.class, new CustomPropertyTypeHandler(), true);
```

## 5. Spring Boot Auto Registration for Type Handlers

Spring Boot starter can auto-register JDBC handlers that also implement
`JdbcTypeHandlerReplaceConfigurer`.

```java
@Component
public class CustomPropertyTypeHandler implements JdbcTypeHandler, JdbcTypeHandlerReplaceConfigurer {
    @Override
    public boolean replace() {
        return true;
    }

    @Override
    public Set<Class<?>> allowTypes() {
        return Set.of(CustomPropertyType.class);
    }
}
```

Source behavior from `EasyQueryInitializeOption`:

- Spring bean `ValueConverter`s are fed into `configuration.applyValueConverter(...)`
- Spring bean `JdbcTypeHandler`s are only auto-appended when they also implement
  `JdbcTypeHandlerReplaceConfigurer`

## 6. `@Column` Fields That Matter Here

Relevant `@Column` fields from source:

- `conversion = ...`
- `typeHandler = ...`
- `complexPropType = ...`
- `jdbcType = ...`
- `dbType = ...`

Practical split:

- `conversion`: object/value conversion in Java memory
- `typeHandler`: JDBC parameter/result handling
- `jdbcType` / `dbType`: hint the database/JDBC side, often important for
  custom handlers such as `jsonb`
- `complexPropType`: helps the framework understand complex property type
  shape; often appears together with JSON conversion examples

## 7. PostgreSQL `jsonb`: Typical Combined Solution

This is the classic case where converter and type handler solve different
problems together.

Entity-side hints:

```java
@Table("t_test_json")
@EntityProxy
public class PgTopicJson implements ProxyEntityAvailable<PgTopicJson, PgTopicJsonProxy> {
    @Column(primaryKey = true)
    private String id;

    @Column(dbType = "jsonb", jdbcType = JDBCType.JAVA_OBJECT)
    private String extraJson;
}
```

JDBC handler override:

```java
public class PgSQLStringSupportJsonbTypeHandler implements JdbcTypeHandler {
    @Override
    public Object getValue(JdbcProperty jdbcProperty, StreamResultSet streamResultSet) throws SQLException {
        return streamResultSet.getString(jdbcProperty.getJdbcIndex());
    }

    @Override
    public void setParameter(EasyParameter parameter) throws SQLException {
        JDBCType jdbcType = parameter.getSQLParameter().getJdbcType();
        if (jdbcType == JDBCType.JAVA_OBJECT) {
            PGobject pGobject = new PGobject();
            pGobject.setType("jsonb");
            pGobject.setValue((String) parameter.getValue());
            parameter.getPs().setObject(parameter.getIndex(), pGobject);
        } else {
            parameter.getPs().setString(parameter.getIndex(), (String) parameter.getValue());
        }
    }
}
```

Then runtime registration can look like:

```java
configuration.applyValueConverter(new JsonObjectAutoConverter());
runtimeContext.getJdbcTypeHandlerManager()
    .appendHandler(String.class, PgSQLStringSupportJsonbTypeHandler.INSTANCE, true);
```

Interpretation:

- converter handles Java object <-> JSON string/object
- type handler handles JDBC `jsonb` binding
- `jdbcType`/`dbType` tell the handler when to switch behavior

If the problem is “my object does not deserialize from JSON”, start with the
converter. If the problem is “PostgreSQL writes/reads `jsonb` incorrectly”,
start with the type handler.

## 8. Registration Patterns

Plain Java / console:

```java
QueryConfiguration configuration = easyQuery.getRuntimeContext().getQueryConfiguration();
configuration.applyValueConverter(new JsonConverter());
```

Spring Boot:

- `ValueConverter` bean -> starter injects it and applies it
- `JdbcTypeHandler` bean + `JdbcTypeHandlerReplaceConfigurer` -> starter
  appends it to allowed Java types

## 9. Decision Rules

Choose `ValueConverter` when:

- database Java value is fine, but the entity property type should differ
- enum code/string or JSON object mapping is the problem
- you need conversion on both write and read without changing JDBC binding

Choose `ValueAutoConverter` when:

- many fields should receive the same conversion automatically
- you want global enum/object conversion without repeating field annotations
- the default provider support and `apply(...)` matching are acceptable

Choose `JdbcTypeHandler` when:

- the database driver needs special parameter binding or result extraction
- `jdbcType`/`dbType` specific handling is required
- PostgreSQL `jsonb`, UUID, binary, or vendor-specific object binding is the
  real issue

Use both when:

- the Java object needs conversion and the JDBC driver also needs special
  binding, especially for `jsonb`

## 10. Common Mistakes

- Using `JdbcTypeHandler` to solve a plain enum/object mapping problem that a
  `ValueConverter` already handles.
- Using only `ValueConverter` for PostgreSQL `jsonb` writes when the actual
  problem is `PGobject` binding.
- Assuming auto converters apply to every field type; default provider limits
  that.
- Registering multiple matching `ValueAutoConverter`s for the same property
  type/path and expecting deterministic precedence.
- Forgetting that explicit `@Column(conversion = ...)` overrides auto
  conversion.
- Forgetting `equals` / `hashCode` on JSON/complex objects used with tracked
  updates.
- Expecting a Spring `JdbcTypeHandler` bean to auto-apply without also
  implementing `JdbcTypeHandlerReplaceConfigurer`.

## Read next

- SQL-side column transformations such as encryption/database functions:
  `native-sql.md`
- entity annotation surface and column metadata basics: `entity-mapping.md`
- PostgreSQL JSON examples in docs: `easy-query-doc/src/prop/json-prop.md`
