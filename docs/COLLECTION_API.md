# Collection API - GDScript SDK Documentation

## Overview

The Collection API provides endpoints for managing collections (Base, Auth, and View types). All operations require superuser authentication and allow you to create, read, update, and delete collections along with their schemas and configurations.

**Key Features:**
- List and search collections
- View collection details
- Create collections (base, auth, view)
- Update collection schemas and rules
- Delete collections
- Truncate collections (delete all records)
- Import collections in bulk
- Get collection scaffolds (templates)

**Backend Endpoints:**
- `GET /api/collections` - List collections
- `GET /api/collections/{collection}` - View collection
- `POST /api/collections` - Create collection
- `PATCH /api/collections/{collection}` - Update collection
- `DELETE /api/collections/{collection}` - Delete collection
- `DELETE /api/collections/{collection}/truncate` - Truncate collection
- `PUT /api/collections/import` - Import collections
- `GET /api/collections/meta/scaffolds` - Get scaffolds

**Note**: All Collection API operations require superuser authentication.

## Authentication

All Collection API operations require superuser authentication:

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://127.0.0.1:8090")

# Authenticate as superuser
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return
# OR
var auth2 = await pb.collection("_superusers").auth_with_password("admin@example.com", "password")
if auth2 is ClientResponseError:
    push_error("Authentication failed: " + auth2.to_string())
    return
```

## List Collections

Returns a paginated list of collections with support for filtering and sorting.

```gdscript
# Basic list
var result = await pb.collections.get_list(1, 30)

print(result.page)        # 1
print(result.perPage)     # 30
print(result.totalItems)  # Total collections count
print(result.items)       # Array of collections
```

### Advanced Filtering and Sorting

```gdscript
# Filter by type
var auth_collections = await pb.collections.get_list(1, 100, {
    "filter": "type = \"auth\""
})

# Filter by name pattern
var matching_collections = await pb.collections.get_list(1, 100, {
    "filter": "name ~ \"user\""
})

# Sort by creation date
var sorted_collections = await pb.collections.get_list(1, 100, {
    "sort": "-created"
})

# Complex filter
var filtered = await pb.collections.get_list(1, 100, {
    "filter": "type = \"base\" && system = false && created >= \"2023-01-01\"",
    "sort": "name"
})
```

### Get Full List

```gdscript
# Get all collections at once
var all_collections = await pb.collections.get_full_list({
    "sort": "name",
    "filter": "system = false"
})
```

### Get First Matching Collection

```gdscript
# Get first auth collection
var auth_collection = await pb.collections.get_first_list_item("type = \"auth\"")
```

## View Collection

Retrieve a single collection by ID or name:

```gdscript
# By name
var collection = await pb.collections.get_one("posts")

# By ID
var collection = await pb.collections.get_one("_pbc_2287844090")

# With field selection
var collection = await pb.collections.get_one("posts", {
    "fields": "id,name,type,fields.name,fields.type"
})
```

## Create Collection

Create a new collection with schema fields and configuration.

**Note**: If the "created" and "updated" fields are not specified during collection initialization, BosBase will automatically create them. These system fields are added to all collections by default and track when records are created and last modified. You don't need to include them in your field definitions.

### Create Base Collection

```gdscript
var base_collection = await pb.collections.create({
    "name": "posts",
    "type": "base",
    "fields": [
        {
            "name": "title",
            "type": "text",
            "required": true,
            "min": 10,
            "max": 255,
        },
        {
            "name": "content",
            "type": "editor",
            "required": false,
        },
        {
            "name": "published",
            "type": "bool",
            "required": false,
        },
        {
            "name": "author",
            "type": "relation",
            "required": true,
            "options": {
                "collectionId": "_pbc_users_auth_"
            },
            "maxSelect": 1,
        },
    ],
    "listRule": "@request.auth.id != \"\"",
    "viewRule": "@request.auth.id != \"\" || published = true",
    "createRule": "@request.auth.id != \"\"",
    "updateRule": "author = @request.auth.id",
    "deleteRule": "author = @request.auth.id",
})
```

### Create Auth Collection

```gdscript
var auth_collection = await pb.collections.create({
    "name": "users",
    "type": "auth",
    "fields": [
        {
            "name": "name",
            "type": "text",
            "required": false,
        },
        {
            "name": "avatar",
            "type": "file",
            "required": false,
            "maxSelect": 1,
            "maxSize": 2097152,  # 2MB
            "mimeTypes": ["image/jpeg", "image/png"],
        },
    ],
    "listRule": null,
    "viewRule": "@request.auth.id = id",
    "createRule": null,
    "updateRule": "@request.auth.id = id",
    "deleteRule": "@request.auth.id = id",
    "manageRule": null,
    "authRule": "verified = true",  # Only verified users can authenticate
})
```

### Create View Collection

```gdscript
var view_collection = await pb.collections.create({
    "name": "published_posts",
    "type": "view",
    "listRule": "@request.auth.id != \"\"",
    "viewRule": "@request.auth.id != \"\"",
    "viewQuery": """
    SELECT 
      p.id,
      p.title,
      p.content,
      p.created,
      u.name as author_name,
      u.email as author_email
    FROM posts p
    LEFT JOIN users u ON p.author = u.id
    WHERE p.published = true
    """,
})
```

### Create from Scaffold

Use predefined scaffolds as a starting point:

```gdscript
# Get available scaffolds
var scaffolds = await pb.collections.get_scaffolds()

# Create base collection from scaffold
var base_collection = await pb.collections.create_base("my_posts", {
    "fields": [
        {
            "name": "title",
            "type": "text",
            "required": true,
        },
    ],
})

# Create auth collection from scaffold
var auth_collection = await pb.collections.create_auth("my_users", {})

# Create view collection from scaffold
var view_collection = await pb.collections.create_view("my_view", "SELECT id, title FROM posts", {
    "listRule": "@request.auth.id != \"\""
})
```

### Accessing Collection ID After Creation

When a collection is successfully created, the returned collection object includes the `id` property, which contains the unique identifier assigned by the backend. You can access it immediately after creation:

```gdscript
# Create a collection and access its ID
var collection = await pb.collections.create({
    "name": "posts",
    "type": "base",
    "fields": [
        {
            "name": "title",
            "type": "text",
            "required": true,
        },
    ],
})

# Access the collection ID
print(collection.id)  # e.g., "_pbc_2287844090"

# Use the ID for subsequent operations
await pb.collections.update(collection.id, {
    "listRule": "@request.auth.id != \"\""
})

# Store the ID for later use
var collection_id = collection.id
```

**Example: Creating multiple collections and storing their IDs**

```gdscript
func setup_collections() -> Dictionary:
    # Create posts collection
    var posts = await pb.collections.create({
        "name": "posts",
        "type": "base",
        "fields": [
            { "name": "title", "type": "text", "required": true },
            { "name": "content", "type": "editor" },
        ],
    })
    
    if posts is ClientResponseError:
        push_error("Failed to create posts: " + posts.to_string())
        return {}

    # Create categories collection
    var categories = await pb.collections.create({
        "name": "categories",
        "type": "base",
        "fields": [
            { "name": "name", "type": "text", "required": true },
        ],
    })
    
    if categories is ClientResponseError:
        push_error("Failed to create categories: " + categories.to_string())
        return {}

    # Access IDs immediately after creation
    print("Posts collection ID: ", posts.id)
    print("Categories collection ID: ", categories.id)

    # Use IDs to create relations
    var posts_updated = await pb.collections.get_one(posts.id)
    if posts_updated is ClientResponseError:
        push_error("Failed to get posts: " + posts_updated.to_string())
        return {}
    
    # Find categories field and update it
    var fields = posts_updated.fields
    for field in fields:
        if field.name == "categories":
            field.options.collectionId = categories.id
            break
    else:
        # Add categories field if it doesn't exist
        fields.append({
            "name": "categories",
            "type": "relation",
            "options": {
                "collectionId": categories.id
            },
            "maxSelect": 1,
        })
    
    await pb.collections.update(posts.id, { "fields": fields })

    return {
        "postsId": posts.id,
        "categoriesId": categories.id,
    }
```

**Note**: The `id` property is automatically generated by the backend and is available immediately after successful creation. You don't need to make a separate API call to retrieve it.

## Update Collection

Update an existing collection's schema, fields, or rules:

```gdscript
# Update collection name and rules
var updated = await pb.collections.update("posts", {
    "name": "articles",
    "listRule": "@request.auth.id != \"\" || status = \"public\"",
    "viewRule": "@request.auth.id != \"\" || status = \"public\"",
})

# Add new field
var collection = await pb.collections.get_one("posts")
if collection is ClientResponseError:
    push_error("Failed to get collection: " + collection.to_string())
    return

collection.fields.append({
    "name": "tags",
    "type": "select",
    "options": {
        "values": ["tech", "science", "art"],
    },
})
await pb.collections.update("posts", { "fields": collection.fields })

# Update field configuration
var collection2 = await pb.collections.get_one("posts")
if collection2 is ClientResponseError:
    push_error("Failed to get collection: " + collection2.to_string())
    return

for field in collection2.fields:
    if field.name == "title":
        field.max = 200
        break

await pb.collections.update("posts", { "fields": collection2.fields })
```

## Delete Collection

Delete a collection (including all records and files):

```gdscript
# Delete by name
await pb.collections.delete("old_collection")

# Delete by ID
await pb.collections.delete("_pbc_2287844090")
```

**Warning**: This operation is destructive and will:
- Delete the collection schema
- Delete all records in the collection
- Delete all associated files
- Remove all indexes

**Note**: Collections referenced by other collections cannot be deleted.

## Truncate Collection

Delete all records in a collection while keeping the collection schema:

```gdscript
# Truncate collection (delete all records)
await pb.collections.truncate("posts")

# This will:
# - Delete all records in the collection
# - Delete all associated files
# - Delete cascade-enabled relations
# - Keep the collection schema intact
```

**Warning**: This operation is destructive and cannot be undone. It's useful for:
- Clearing test data
- Resetting collections
- Bulk data removal

**Note**: View collections cannot be truncated.

## Import Collections

Bulk import multiple collections at once:

```gdscript
var collections_to_import = [
    {
        "name": "posts",
        "type": "base",
        "fields": [
            {
                "name": "title",
                "type": "text",
                "required": true,
            },
            {
                "name": "content",
                "type": "editor",
            },
        ],
        "listRule": "@request.auth.id != \"\"",
    },
    {
        "name": "categories",
        "type": "base",
        "fields": [
            {
                "name": "name",
                "type": "text",
                "required": true,
            },
        ],
    },
]

# Import without deleting existing collections
await pb.collections.import(collections_to_import, false)

# Import and delete collections not in the import list
await pb.collections.import(collections_to_import, true)
```

### Import Options

- **`deleteMissing: false`** (default): Only create/update collections in the import list
- **`deleteMissing: true`**: Delete all collections not present in the import list

**Warning**: Using `deleteMissing: true` will permanently delete collections and all their data.

## Get Scaffolds

Get collection templates for creating new collections:

```gdscript
var scaffolds = await pb.collections.get_scaffolds()

# Available scaffold types
print(scaffolds.base)   # Base collection template
print(scaffolds.auth)   # Auth collection template
print(scaffolds.view)   # View collection template

# Use scaffold as starting point
var base_template = scaffolds.base
var new_collection = base_template.duplicate(true)
new_collection.name = "my_collection"
new_collection.fields.append({
    "name": "custom_field",
    "type": "text",
})

await pb.collections.create(new_collection)
```

## Filter Syntax

Collections support filtering with the same syntax as records:

### Supported Fields

- `id` - Collection ID
- `created` - Creation date
- `updated` - Last update date
- `name` - Collection name
- `type` - Collection type ("base", "auth", "view")
- `system` - System collection flag (boolean)

### Filter Examples

```gdscript
# Filter by type
"filter": "type = \"auth\""

# Filter by name pattern
"filter": "name ~ \"user\""

# Filter non-system collections
"filter": "system = false"

# Multiple conditions
"filter": "type = \"base\" && system = false && created >= \"2023-01-01\""

# Complex filter
"filter": "(type = \"auth\" || type = \"base\") && name !~ \"test\""
```

## Sort Options

Supported sort fields:

- `@random` - Random order
- `id` - Collection ID
- `created` - Creation date
- `updated` - Last update date
- `name` - Collection name
- `type` - Collection type
- `system` - System flag

```gdscript
# Sort examples
"sort": "name"           # ASC by name
"sort": "-created"       # DESC by creation date
"sort": "type,-created"  # ASC by type, then DESC by created
```

## Complete Examples

### Example 1: Setup Blog Collections

```gdscript
func setup_blog() -> Dictionary:
    # Create posts collection
    var posts = await pb.collections.create({
        "name": "posts",
        "type": "base",
        "fields": [
            {
                "name": "title",
                "type": "text",
                "required": true,
                "min": 10,
                "max": 255,
            },
            {
                "name": "slug",
                "type": "text",
                "required": true,
                "options": {
                    "pattern": "^[a-z0-9-]+$",
                },
            },
            {
                "name": "content",
                "type": "editor",
                "required": true,
            },
            {
                "name": "featured_image",
                "type": "file",
                "maxSelect": 1,
                "maxSize": 5242880,  # 5MB
                "mimeTypes": ["image/jpeg", "image/png"],
            },
            {
                "name": "published",
                "type": "bool",
                "required": false,
            },
        ],
        "listRule": "@request.auth.id != \"\" || published = true",
        "viewRule": "@request.auth.id != \"\" || published = true",
        "createRule": "@request.auth.id != \"\"",
        "updateRule": "author = @request.auth.id",
        "deleteRule": "author = @request.auth.id",
    })
    
    if posts is ClientResponseError:
        push_error("Failed to create posts: " + posts.to_string())
        return {}

    # Create categories collection
    var categories = await pb.collections.create({
        "name": "categories",
        "type": "base",
        "fields": [
            {
                "name": "name",
                "type": "text",
                "required": true,
            },
            {
                "name": "slug",
                "type": "text",
                "required": true,
            },
            {
                "name": "description",
                "type": "text",
                "required": false,
            },
        ],
        "listRule": "@request.auth.id != \"\"",
        "viewRule": "@request.auth.id != \"\"",
    })
    
    if categories is ClientResponseError:
        push_error("Failed to create categories: " + categories.to_string())
        return {}

    # Access collection IDs immediately after creation
    print("Posts collection ID: ", posts.id)
    print("Categories collection ID: ", categories.id)

    return {
        "postsId": posts.id,
        "categoriesId": categories.id,
    }
```

## Error Handling

```gdscript
var result = await pb.collections.create({
    "name": "test",
    "type": "base",
    "fields": [],
})

if result is ClientResponseError:
    if result.status == 401:
        push_error("Not authenticated")
    elif result.status == 403:
        push_error("Not a superuser")
    elif result.status == 400:
        push_error("Validation error: ", result.data)
    else:
        push_error("Unexpected error: ", result.to_string())
```

## Best Practices

1. **Always Authenticate**: Ensure you're authenticated as a superuser before making requests
2. **Backup Before Import**: Always backup existing collections before using `import` with `deleteMissing: true`
3. **Validate Schema**: Validate collection schemas before creating/updating
4. **Use Scaffolds**: Use scaffolds as starting points for consistency
5. **Test Rules**: Test API rules thoroughly before deploying to production
6. **Index Important Fields**: Add indexes for frequently queried fields
7. **Document Schemas**: Keep documentation of your collection schemas
8. **Version Control**: Store collection schemas in version control for migration tracking

## Limitations

- **Superuser Only**: All operations require superuser authentication
- **System Collections**: System collections cannot be deleted or renamed
- **View Collections**: Cannot be truncated (they don't store records)
- **Relations**: Collections referenced by others cannot be deleted
- **Field Modifications**: Some field type changes may require data migration

## Related Documentation

- [Collections Guide](./COLLECTIONS.md) - Working with collections and records
- [API Records](./API_RECORDS.md) - Record CRUD operations
- [API Rules and Filters](./API_RULES_AND_FILTERS.md) - Understanding API rules
