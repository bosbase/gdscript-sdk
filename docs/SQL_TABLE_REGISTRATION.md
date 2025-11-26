# Register Existing SQL Tables with the GDScript SDK

Use the SQL table helpers to expose existing tables (or run SQL to create them) and automatically generate REST collections. Both calls are **superuser-only**.

- `register_sql_tables(tables: Array[String])` – map existing tables to collections without running SQL.
- `import_sql_tables(tables: Array[Dictionary])` – optionally run SQL to create tables first, then register them. Returns `{ "created": Array, "skipped": Array }`.

## Requirements

- Authenticate with a superuser account (via `pb.admins().auth_with_password()`).
- Each table must contain a `TEXT` primary key column named `id`.
- Missing audit columns (`created`, `updated`, `createdBy`, `updatedBy`) are automatically added so the default API rules can be applied.
- Non-system columns are mapped by best effort (text, number, bool, date/time, JSON).

## Basic Usage

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://127.0.0.1:8090")

# Authenticate as superuser
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return

var collections = await pb.collections.register_sql_tables([
    "projects",
    "accounts",
])

if collections is ClientResponseError:
    push_error("Failed to register SQL tables: " + collections.to_string())
    return

# Print collection names
for collection in collections:
    print(collection.name)
# => ["projects", "accounts"]
```

## With Request Options

You can pass standard request options (headers, query params, etc.).

```gdscript
var collections = await pb.collections.register_sql_tables(
    ["legacy_orders"],
    {
        "headers": {"x-trace-id": "12345"},
        "q": 1,  # adds ?q=1
    }
)

if collections is ClientResponseError:
    push_error("Failed to register SQL tables: " + collections.to_string())
    return
```

## Create-or-register flow

`import_sql_tables()` accepts `Array[Dictionary]` items with `{"name": String, "sql": String}` (sql is optional), runs the SQL (if provided), and registers collections. Existing collection names are reported under `skipped`.

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

# Authenticate as superuser
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return

var result = await pb.collections.import_sql_tables([
    {
        "name": "legacy_orders",
        "sql": """
            CREATE TABLE IF NOT EXISTS legacy_orders (
                id TEXT PRIMARY KEY,
                customer_email TEXT NOT NULL
            );
        """,
    },
    {"name": "reporting_view"},  # assumes table already exists
])

if result is ClientResponseError:
    push_error("Failed to import SQL tables: " + result.to_string())
    return

# Print created collection names
for collection in result.created:
    print(collection.name)  # ["legacy_orders", "reporting_view"]

print("Skipped: ", result.skipped)  # collection names that already existed
```

## What It Does

- Creates BosBase collection metadata for the provided tables.
- Generates REST endpoints for CRUD against those tables.
- Applies the standard default API rules (authenticated create; update/delete scoped to the creator).
- Ensures audit columns exist (`created`, `updated`, `createdBy`, `updatedBy`) and leaves all other existing SQL schema and data untouched; no further field mutations or table syncs are performed.
- Marks created collections with `externalTable: true` so you can distinguish them from regular BosBase-managed tables.

## Complete Example

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

func register_existing_tables() -> void:
    # Authenticate as superuser
    var auth = await pb.admins().auth_with_password("admin@example.com", "password")
    if auth is ClientResponseError:
        push_error("Authentication failed: " + auth.to_string())
        return
    
    # Register existing SQL tables
    var collections = await pb.collections.register_sql_tables([
        "projects",
        "accounts",
        "orders",
    ])
    
    if collections is ClientResponseError:
        push_error("Failed to register tables: " + collections.to_string())
        return
    
    print("Registered %d collections:" % collections.size())
    for collection in collections:
        print("  - ", collection.name)

func create_and_register_tables() -> void:
    # Authenticate as superuser
    var auth = await pb.admins().auth_with_password("admin@example.com", "password")
    if auth is ClientResponseError:
        push_error("Authentication failed: " + auth.to_string())
        return
    
    # Import SQL tables (create if needed, then register)
    var result = await pb.collections.import_sql_tables([
        {
            "name": "products",
            "sql": """
                CREATE TABLE IF NOT EXISTS products (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    price REAL,
                    created TEXT,
                    updated TEXT
                );
            """,
        },
        {
            "name": "categories",
            "sql": """
                CREATE TABLE IF NOT EXISTS categories (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    description TEXT
                );
            """,
        },
    ])
    
    if result is ClientResponseError:
        push_error("Failed to import tables: " + result.to_string())
        return
    
    print("Created collections:")
    for collection in result.created:
        print("  - ", collection.name)
    
    if result.skipped.size() > 0:
        print("Skipped (already existed):")
        for name in result.skipped:
            print("  - ", name)
```

## Working with Registered Collections

Once tables are registered, you can use them like any other BosBase collection:

```gdscript
# Authenticate as superuser first
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return

# Register the table
var collections = await pb.collections.register_sql_tables(["products"])
if collections is ClientResponseError:
    push_error("Failed to register: " + collections.to_string())
    return

# Now you can use it like a normal collection
var products = await pb.collection("products").get_list(1, 20)
if products is ClientResponseError:
    push_error("Failed to get products: " + products.to_string())
    return

for product in products.items:
    print(product.name, product.price)
```

## Troubleshooting

- **400 error**: Ensure `id` exists as `TEXT PRIMARY KEY` and the table name is not system-reserved (no leading `_`).
- **401/403**: Confirm you are authenticated as a superuser using `pb.admins().auth_with_password()`.
- Default audit fields (`created`, `updated`, `createdBy`, `updatedBy`) are auto-added if they're missing so the default owner rules validate successfully.
- **Table already exists**: Use `import_sql_tables()` and check the `skipped` array to see which tables were already registered.
- **SQL syntax errors**: Check your SQL syntax in the `sql` field when using `import_sql_tables()`.

## Error Handling

```gdscript
func safe_register_tables(table_names: Array[String]) -> Array:
    # Authenticate
    var auth = await pb.admins().auth_with_password("admin@example.com", "password")
    if auth is ClientResponseError:
        push_error("Authentication failed: " + auth.to_string())
        return []
    
    # Register tables
    var collections = await pb.collections.register_sql_tables(table_names)
    
    if collections is ClientResponseError:
        match collections.status:
            400:
                push_error("Invalid table structure or name. Ensure 'id' is TEXT PRIMARY KEY.")
            401:
                push_error("Not authenticated")
            403:
                push_error("Not a superuser")
            _:
                push_error("Failed to register tables: " + collections.to_string())
        return []
    
    return collections
```

## Best Practices

1. **Verify table structure**: Ensure your SQL tables have the required `id TEXT PRIMARY KEY` column before registering.
2. **Check existing collections**: Use `pb.collections.get_full_list()` to check if a collection already exists before registering.
3. **Use import for new tables**: Use `import_sql_tables()` when creating new tables to ensure proper setup.
4. **Handle errors**: Always check for `ClientResponseError` after registration calls.
5. **Backup data**: Before registering existing tables, consider backing up your SQL database.
6. **Test first**: Test table registration in a development environment before using in production.

## Related Documentation

- [Collection API](./COLLECTION_API.md) - Collection management operations
- [Authentication](./AUTHENTICATION.md) - Superuser authentication
