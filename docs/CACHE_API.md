# Cache API - GDScript SDK

BosBase caches combine in-memory [FreeCache](https://github.com/coocood/freecache) storage with persistent database copies. Each cache instance is safe to use in single-node or multi-node (cluster) mode: nodes read from FreeCache first, fall back to the database if an item is missing or expired, and then reload FreeCache automatically.

The GDScript SDK exposes the cache endpoints through `pb.caches`. Typical use cases include:

- Caching AI prompts/responses that must survive restarts.
- Quickly sharing feature flags and configuration between workers.
- Preloading expensive vector search results for short periods.

> **Timeouts & TTLs:** Each cache defines a default TTL (in seconds). Individual entries may provide their own `ttlSeconds`. A value of `0` keeps the entry until it is manually deleted.

## List Available Caches

The `list()` function allows you to query and retrieve all currently available caches, including their names and capacities. This is particularly useful for AI systems to discover existing caches before creating new ones, avoiding duplicate cache creation.

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://127.0.0.1:8090")

# Authenticate as superuser
var auth = await pb.admins().auth_with_password("root@example.com", "hunter2")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return

# Query all available caches
var caches = await pb.caches.list()

if caches is ClientResponseError:
    push_error("Failed to list caches: " + caches.to_string())
    return

# Each cache object contains:
# - name: String - The cache identifier
# - sizeBytes: int - The cache capacity in bytes
# - defaultTTLSeconds: int - Default expiration time
# - readTimeoutMs: int - Read timeout in milliseconds
# - created: String - Creation timestamp (RFC3339)
# - updated: String - Last update timestamp (RFC3339)

# Example: Find a cache by name and check its capacity
var target_cache = null
for cache in caches:
    if cache.name == "ai-session":
        target_cache = cache
        break

if target_cache:
    print("Cache \"%s\" has capacity of %d bytes" % [target_cache.name, target_cache.sizeBytes])
    # Use the existing cache directly
else:
    print("Cache not found, create a new one if needed")
```

## Manage Cache Configurations

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://127.0.0.1:8090")

# Authenticate as superuser
var auth = await pb.admins().auth_with_password("root@example.com", "hunter2")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return

# List all available caches (including name and capacity).
# This is useful for AI to discover existing caches before creating new ones.
var caches = await pb.caches.list()
if not caches is ClientResponseError:
    print("Available caches: ", caches)
    # Output example:
    # [
    #   {
    #     "name": "ai-session",
    #     "sizeBytes": 67108864,
    #     "defaultTTLSeconds": 300,
    #     "readTimeoutMs": 25,
    #     "created": "2024-01-15T10:30:00Z",
    #     "updated": "2024-01-15T10:30:00Z",
    #   },
    #   {
    #     "name": "query-cache",
    #     "sizeBytes": 33554432,
    #     "defaultTTLSeconds": 600,
    #     "readTimeoutMs": 50,
    #     "created": "2024-01-14T08:00:00Z",
    #     "updated": "2024-01-14T08:00:00Z",
    #   }
    # ]

# Find an existing cache by name
var existing_cache = null
for cache in caches:
    if cache.name == "ai-session":
        existing_cache = cache
        break

if existing_cache:
    print("Found cache \"%s\" with capacity %d bytes" % [existing_cache.name, existing_cache.sizeBytes])
    # Use the existing cache directly without creating a new one
else:
    # Create a new cache only if it doesn't exist
    var create_result = await pb.caches.create({
        "name": "ai-session",
        "sizeBytes": 64 * 1024 * 1024,  # 64 MB
        "defaultTTLSeconds": 300,
        "readTimeoutMs": 25,  # optional concurrency guard
    })
    
    if create_result is ClientResponseError:
        push_error("Failed to create cache: " + create_result.to_string())
        return

# Update limits later (e.g., shrink TTL to 2 minutes).
var update_result = await pb.caches.update("ai-session", {
    "defaultTTLSeconds": 120,
})

if update_result is ClientResponseError:
    push_error("Failed to update cache: " + update_result.to_string())
    return

# Delete the cache (DB rows + FreeCache).
var delete_result = await pb.caches.delete("ai-session")
if delete_result is ClientResponseError:
    push_error("Failed to delete cache: " + delete_result.to_string())
    return
```

**Field Reference:**

| Field | Description |
|-------|-------------|
| `sizeBytes` | Approximate FreeCache size. Values too small (<512KB) or too large (>512MB) are clamped. |
| `defaultTTLSeconds` | Default expiration for entries. `0` means no expiration. |
| `readTimeoutMs` | Optional lock timeout while reading FreeCache. When exceeded, the value is fetched from the database instead. |

## Work with Cache Entries

```gdscript
# Store an object in cache. The same payload is serialized into the DB.
var set_result = await pb.caches.set_entry("ai-session", "dialog:42", {
    "prompt": "describe Saturn",
    "embedding": [0.1, 0.2, 0.3],  # vector array
}, 90)  # per-entry TTL in seconds

if set_result is ClientResponseError:
    push_error("Failed to set cache entry: " + set_result.to_string())
    return

# Read from cache. "source" indicates where the hit came from.
var entry = await pb.caches.get_entry("ai-session", "dialog:42")

if entry is ClientResponseError:
    push_error("Failed to get cache entry: " + entry.to_string())
    return

print(entry.source)   # "cache" or "database"
print(entry.expiresAt) # RFC3339 timestamp or null
print(entry.value)     # The cached value

# Renew an entry's TTL without changing its value.
# This extends the expiration time by the specified TTL (or uses the cache's default TTL if omitted).
var renewed = await pb.caches.renew_entry("ai-session", "dialog:42", 120)  # extend by 120 seconds

if not renewed is ClientResponseError:
    print(renewed.expiresAt)  # new expiration time

# Delete an entry.
var delete_result = await pb.caches.delete_entry("ai-session", "dialog:42")
if delete_result is ClientResponseError:
    push_error("Failed to delete entry: " + delete_result.to_string())
```

## Complete Example

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://127.0.0.1:8090")

class_name CacheManager

var pb: BosBase

func setup_cache() -> void:
    # Authenticate as superuser
    var auth = await pb.admins().auth_with_password("admin@example.com", "password")
    if auth is ClientResponseError:
        push_error("Authentication failed: " + auth.to_string())
        return
    
    # Check if cache exists
    var caches = await pb.caches.list()
    if caches is ClientResponseError:
        push_error("Failed to list caches: " + caches.to_string())
        return
    
    var cache_exists = false
    for cache in caches:
        if cache.name == "ai-session":
            cache_exists = true
            break
    
    # Create cache if it doesn't exist
    if not cache_exists:
        var create_result = await pb.caches.create({
            "name": "ai-session",
            "sizeBytes": 64 * 1024 * 1024,  # 64 MB
            "defaultTTLSeconds": 300,  # 5 minutes
            "readTimeoutMs": 25,
        })
        
        if create_result is ClientResponseError:
            push_error("Failed to create cache: " + create_result.to_string())
            return

func cache_ai_response(key: String, prompt: String, response: String, ttl: int = 300) -> void:
    var result = await pb.caches.set_entry("ai-session", key, {
        "prompt": prompt,
        "response": response,
        "timestamp": Time.get_unix_time_from_system(),
    }, ttl)
    
    if result is ClientResponseError:
        push_error("Failed to cache response: " + result.to_string())
        return
    
    print("Response cached with key: ", key)

func get_cached_response(key: String) -> Dictionary:
    var entry = await pb.caches.get_entry("ai-session", key)
    
    if entry is ClientResponseError:
        if entry.status == 404:
            print("Cache entry not found")
        else:
            push_error("Failed to get cache entry: " + entry.to_string())
        return {}
    
    print("Cache hit from: ", entry.source)
    return entry.value

func clear_cache() -> void:
    var result = await pb.caches.delete("ai-session")
    if result is ClientResponseError:
        push_error("Failed to delete cache: " + result.to_string())
        return
    
    print("Cache cleared")
```

## Cluster-Aware Behavior

1. **Write-through persistence** – every `set_entry` writes to FreeCache and the `_cache_entries` table so other nodes (or a restarted node) can immediately reload values.
2. **Read path** – FreeCache is consulted first. If a lock cannot be acquired within `readTimeoutMs` or if the entry is missing/expired, BosBase queries the database copy and repopulates FreeCache in the background.
3. **Automatic cleanup** – expired entries are ignored and removed from the database when fetched, preventing stale data across nodes.

Use caches whenever you need fast, transient data that must still be recoverable or shareable across BosBase nodes.

## Error Handling

```gdscript
func safe_cache_operation() -> void:
    # Set entry
    var set_result = await pb.caches.set_entry("ai-session", "key1", {"data": "value"}, 300)
    if set_result is ClientResponseError:
        match set_result.status:
            400:
                push_error("Invalid cache name or entry data")
            404:
                push_error("Cache not found")
            _:
                push_error("Failed to set entry: " + set_result.to_string())
        return
    
    # Get entry
    var entry = await pb.caches.get_entry("ai-session", "key1")
    if entry is ClientResponseError:
        if entry.status == 404:
            print("Entry not found")
        else:
            push_error("Failed to get entry: " + entry.to_string())
        return
    
    print("Entry found: ", entry.value)
```

## Best Practices

1. **Cache Discovery**: Always check existing caches before creating new ones
2. **TTL Management**: Set appropriate TTLs based on your use case
3. **Error Handling**: Always check for `ClientResponseError` after cache operations
4. **Size Limits**: Keep cache sizes reasonable (between 512KB and 512MB)
5. **Entry Cleanup**: Use `delete_entry` to remove unused entries
6. **Cluster Safety**: Cache operations are safe in multi-node setups

## Related Documentation

- [Management API](./MANAGEMENT_API.md) - Other management operations
- [Vector API](./VECTOR_API.md) - Vector database for semantic search
