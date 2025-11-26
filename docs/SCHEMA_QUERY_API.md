# Schema Query API - GDScript SDK Documentation

## Overview

The Schema Query API provides lightweight interfaces to retrieve collection field information without fetching full collection definitions. This is particularly useful for AI systems that need to understand the structure of collections and the overall system architecture.

**Key Features:**
- Get schema for a single collection by name or ID
- Get schemas for all collections in the system
- Lightweight response with only essential field information
- Support for all collection types (base, auth, view)
- Fast and efficient queries

**Backend Endpoints:**
- `GET /api/collections/{collection}/schema` - Get single collection schema
- `GET /api/collections/schemas` - Get all collection schemas

**Note**: All Schema Query API operations require superuser authentication.

## Authentication

All Schema Query API operations require superuser authentication:

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://127.0.0.1:8090")

# Authenticate as superuser
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return
```

## Type Definitions

### CollectionFieldSchemaInfo

Simplified field information returned by schema queries:

```gdscript
{
    "name": String,        # Field name
    "type": String,        # Field type (e.g., "text", "number", "email", "relation")
    "required": bool,      # Whether the field is required (optional)
    "system": bool,        # Whether the field is a system field (optional)
    "hidden": bool         # Whether the field is hidden (optional)
}
```

### CollectionSchemaInfo

Schema information for a single collection:

```gdscript
{
    "name": String,        # Collection name
    "type": String,        # Collection type ("base", "auth", "view")
    "fields": Array        # Array of CollectionFieldSchemaInfo
}
```

## Get Single Collection Schema

Retrieves the schema (fields and types) for a single collection by name or ID.

### Basic Usage

```gdscript
# Get schema for a collection by name
var schema = await pb.collections.get_schema("demo1")

if schema is ClientResponseError:
    push_error("Failed to get schema: " + schema.to_string())
    return

print(schema.name)    # "demo1"
print(schema.type)    # "base"
print(schema.fields)  # Array of field information

# Iterate through fields
for field in schema.fields:
    var required_text = " (required)" if field.get("required", false) else ""
    print(field.name + ": " + field.type + required_text)
```

### Using Collection ID

```gdscript
# Get schema for a collection by ID
var schema = await pb.collections.get_schema("_pbc_base_123")

if schema is ClientResponseError:
    push_error("Failed to get schema: " + schema.to_string())
    return

print(schema.name)  # "demo1"
```

### Handling Different Collection Types

```gdscript
# Base collection
var base_schema = await pb.collections.get_schema("demo1")
if not base_schema is ClientResponseError:
    print(base_schema.type)  # "base"

# Auth collection
var auth_schema = await pb.collections.get_schema("users")
if not auth_schema is ClientResponseError:
    print(auth_schema.type)  # "auth"

# View collection
var view_schema = await pb.collections.get_schema("view1")
if not view_schema is ClientResponseError:
    print(view_schema.type)  # "view"
```

### Error Handling

```gdscript
var schema = await pb.collections.get_schema("nonexistent")

if schema is ClientResponseError:
    if schema.status == 404:
        print("Collection not found")
    else:
        push_error("Error: " + schema.to_string())
```

## Get All Collection Schemas

Retrieves the schema (fields and types) for all collections in the system.

### Basic Usage

```gdscript
# Get schemas for all collections
var result = await pb.collections.get_all_schemas()

if result is ClientResponseError:
    push_error("Failed to get schemas: " + result.to_string())
    return

print(result.collections)  # Array of all collection schemas

# Iterate through all collections
for collection in result.collections:
    print("Collection: " + collection.name + " (" + collection.type + ")")
    print("Fields: ", collection.fields.size())
    
    # List all fields
    for field in collection.fields:
        print("  - " + field.name + ": " + field.type)
```

### Filtering Collections by Type

```gdscript
var result = await pb.collections.get_all_schemas()

if result is ClientResponseError:
    push_error("Failed to get schemas: " + result.to_string())
    return

# Filter to only base collections
var base_collections = []
for c in result.collections:
    if c.type == "base":
        base_collections.append(c)

# Filter to only auth collections
var auth_collections = []
for c in result.collections:
    if c.type == "auth":
        auth_collections.append(c)

# Filter to only view collections
var view_collections = []
for c in result.collections:
    if c.type == "view":
        view_collections.append(c)
```

### Building a Field Index

```gdscript
# Build a map of all field names and types across all collections
var result = await pb.collections.get_all_schemas()

if result is ClientResponseError:
    push_error("Failed to get schemas: " + result.to_string())
    return

var field_index = {}

for collection in result.collections:
    for field in collection.fields:
        var key = collection.name + "." + field.name
        field_index[key] = {
            "collection": collection.name,
            "collectionType": collection.type,
            "fieldName": field.name,
            "fieldType": field.type,
            "required": field.get("required", false),
            "system": field.get("system", false),
            "hidden": field.get("hidden", false),
        }

# Use the index
print(field_index.get("demo1.title", {}))  # Field information
```

## Complete Examples

### Example 1: AI System Understanding Collection Structure

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://127.0.0.1:8090")
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return

# Get all collection schemas for system understanding
var result = await pb.collections.get_all_schemas()

if result is ClientResponseError:
    push_error("Failed to get schemas: " + result.to_string())
    return

# Create a comprehensive system overview
var system_overview = []
for collection in result.collections:
    var fields = []
    for field in collection.fields:
        fields.append({
            "name": field.name,
            "type": field.type,
            "required": field.get("required", false),
        })
    
    system_overview.append({
        "name": collection.name,
        "type": collection.type,
        "fields": fields,
    })

print("System Collections Overview:")
for collection in system_overview:
    print("\n" + collection.name + " (" + collection.type + "):")
    for field in collection.fields:
        var required_text = " [required]" if field.required else ""
        print("  " + field.name + ": " + field.type + required_text)
```

### Example 2: Validating Field Existence Before Query

```gdscript
# Check if a field exists before querying
func check_field_exists(collection_name: String, field_name: String) -> bool:
    var schema = await pb.collections.get_schema(collection_name)
    
    if schema is ClientResponseError:
        return false
    
    for field in schema.fields:
        if field.name == field_name:
            return true
    
    return false

# Usage
var has_title_field = await check_field_exists("demo1", "title")
if has_title_field:
    # Safe to query the field
    var records = await pb.collection("demo1").get_list(1, 20, {
        "fields": "id,title"
    })
```

### Example 3: Dynamic Form Generation

```gdscript
# Generate form fields based on collection schema
func generate_form_fields(collection_name: String) -> Array:
    var schema = await pb.collections.get_schema(collection_name)
    
    if schema is ClientResponseError:
        push_error("Failed to get schema: " + schema.to_string())
        return []
    
    var form_fields = []
    
    for field in schema.fields:
        # Exclude system/hidden fields
        if field.get("system", false) or field.get("hidden", false):
            continue
        
        var label = field.name.capitalize()
        form_fields.append({
            "name": field.name,
            "type": field.type,
            "required": field.get("required", false),
            "label": label,
        })
    
    return form_fields

# Usage
var form_fields = await generate_form_fields("demo1")
print("Form Fields: ", form_fields)
# Output: [
#   { "name": "title", "type": "text", "required": true, "label": "Title" },
#   { "name": "description", "type": "text", "required": false, "label": "Description" },
#   ...
# ]
```

### Example 4: Schema Comparison

```gdscript
# Compare schemas between two collections
func compare_schemas(collection1: String, collection2: String) -> Dictionary:
    var schema1 = await pb.collections.get_schema(collection1)
    var schema2 = await pb.collections.get_schema(collection2)
    
    if schema1 is ClientResponseError or schema2 is ClientResponseError:
        push_error("Failed to get schemas")
        return {}
    
    var fields1 = []
    var fields2 = []
    
    for field in schema1.fields:
        fields1.append(field.name)
    
    for field in schema2.fields:
        fields2.append(field.name)
    
    var common = []
    var only_in_1 = []
    var only_in_2 = []
    
    # Find common fields
    for field_name in fields1:
        if field_name in fields2:
            common.append(field_name)
        else:
            only_in_1.append(field_name)
    
    # Find fields only in collection2
    for field_name in fields2:
        if not field_name in fields1:
            only_in_2.append(field_name)
    
    return {
        "common": common,
        "onlyIn1": only_in_1,
        "onlyIn2": only_in_2,
    }

# Usage
var comparison = await compare_schemas("demo1", "demo2")
print("Common fields: ", comparison.common)
print("Only in demo1: ", comparison.onlyIn1)
print("Only in demo2: ", comparison.onlyIn2)
```

## Response Structure

### Single Collection Schema Response

```json
{
  "name": "demo1",
  "type": "base",
  "fields": [
    {
      "name": "id",
      "type": "text",
      "required": true,
      "system": true,
      "hidden": false
    },
    {
      "name": "title",
      "type": "text",
      "required": true,
      "system": false,
      "hidden": false
    },
    {
      "name": "description",
      "type": "text",
      "required": false,
      "system": false,
      "hidden": false
    }
  ]
}
```

### All Collections Schemas Response

```json
{
  "collections": [
    {
      "name": "demo1",
      "type": "base",
      "fields": [...]
    },
    {
      "name": "users",
      "type": "auth",
      "fields": [...]
    },
    {
      "name": "view1",
      "type": "view",
      "fields": [...]
    }
  ]
}
```

## Use Cases

### 1. AI System Design
AI systems can query all collection schemas to understand the overall database structure and design queries or operations accordingly.

### 2. Code Generation
Generate client-side code, TypeScript types, or form components based on collection schemas.

### 3. Documentation Generation
Automatically generate API documentation or data dictionaries from collection schemas.

### 4. Schema Validation
Validate queries or operations before execution by checking field existence and types.

### 5. Migration Planning
Compare schemas between environments or versions to plan migrations.

### 6. Dynamic UI Generation
Create dynamic forms, tables, or interfaces based on collection field definitions.

## Performance Considerations

- **Lightweight**: Schema queries return only essential field information, not full collection definitions
- **Efficient**: Much faster than fetching full collection objects
- **Cached**: Results can be cached for better performance
- **Batch**: Use `get_all_schemas()` to get all schemas in a single request

## Error Handling

```gdscript
var schema = await pb.collections.get_schema("demo1")

if schema is ClientResponseError:
    match schema.status:
        401:
            push_error("Authentication required")
        403:
            push_error("Superuser access required")
        404:
            push_error("Collection not found")
        _:
            push_error("Unexpected error: " + schema.to_string())
```

## Best Practices

1. **Cache Results**: Schema information rarely changes, so cache results when appropriate
2. **Error Handling**: Always handle 404 errors for non-existent collections
3. **Filter System Fields**: When building UI, filter out system and hidden fields
4. **Batch Queries**: Use `get_all_schemas()` when you need multiple collection schemas
5. **Type Safety**: Validate field types when working with dynamic schemas

## Related Documentation

- [Collection API](./COLLECTION_API.md) - Full collection management API
- [Records API](./API_RECORDS.md) - Record CRUD operations
