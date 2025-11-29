# SQL Execution API - GDScript SDK

## Overview

The SQL Execution API lets superusers run ad-hoc SQL statements against the BosBase database and retrieve the results. Use it for controlled maintenance or diagnostics tasks—never expose it to untrusted users.

**Key Points**
- Superuser authentication is required for every request.
- Supports both read and write statements.
- Returns column names, rows, and `rowsAffected` for writes.
- Respects the SDK's regular request hooks, headers, and timeouts.

**Endpoint**
- `POST /api/sql/execute`
- Body: `{ "query": "<your SQL statement>" }`

## Authentication

Authenticate as a superuser before calling `pb.sql.execute`:

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")
var ClientResponseError = preload("res://gdscript-sdk/src/client_response_error.gd")

var pb = BosBase.new("http://127.0.0.1:8090")
var auth = await pb.collection("_superusers").auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error(auth.to_string())
    return
```

## Executing a SELECT

```gdscript
var result = await pb.sql.execute("SELECT id, text FROM demo1 ORDER BY id LIMIT 5")
if result is ClientResponseError:
    push_error(result.to_string())
    return

print(result.get("columns"))
print(result.get("rows"))
```

## Executing a Write Statement

```gdscript
var update = await pb.sql.execute("UPDATE demo1 SET text='updated via api' WHERE id='84nmscqy84lsi1t'")
if update is ClientResponseError:
    push_error(update.to_string())
    return

print(update.get("rowsAffected")) # 1
print(update.get("columns"))      # ["rows_affected"]
print(update.get("rows"))         # [["1"]]
```

## Inserts and Deletes

```gdscript
# Insert
var insert = await pb.sql.execute("INSERT INTO demo1 (id, text) VALUES ('new-id', 'hello from SQL API')")
if insert is ClientResponseError:
    push_error(insert.to_string())
    return
print(insert.get("rowsAffected")) # 1

# Delete
var removed = await pb.sql.execute("DELETE FROM demo1 WHERE id='new-id'")
if removed is ClientResponseError:
    push_error(removed.to_string())
    return
print(removed.get("rowsAffected")) # 1
```

## Response Shape

```jsonc
{
  "columns": ["col1", "col2"], // omitted when empty
  "rows": [["v1", "v2"]],      // omitted when empty
  "rowsAffected": 3            // only present for write operations
}
```

## Error Handling

- Empty queries are rejected before sending a request.
- Database or syntax errors are returned as `ClientResponseError` instances.
- You can pass custom `headers`, `query`, and `timeout` values through the standard `client.send` options used by the SDK.

## Safety Tips

- Never pass user-controlled SQL into this API.
- Prefer explicit statements over multi-statement payloads.
- Audit who has superuser credentials and rotate them regularly.
