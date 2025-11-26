# Collections - GDScript SDK Documentation

This document provides comprehensive documentation for working with Collections and Fields in the BosBase GDScript SDK. This documentation is designed to be AI-readable and includes practical examples for all operations.

## Table of Contents

- [Overview](#overview)
- [Collection Types](#collection-types)
- [Collections API](#collections-api)
- [Records API](#records-api)
- [Field Types](#field-types)
- [Examples](#examples)

## Overview

**Collections** represent your application data. Under the hood they are backed by plain SQLite tables that are generated automatically with the collection **name** and **fields** (columns).

A single entry of a collection is called a **record** (a single row in the SQL table).

You can manage your **collections** from the Dashboard, or with the GDScript SDK using the `collections` service.

Similarly, you can manage your **records** from the Dashboard, or with the GDScript SDK using the `collection(name)` method which returns a `RecordService` instance.

## Collection Types

Currently there are 3 collection types: **Base**, **View** and **Auth**.

### Base Collection

**Base collection** is the default collection type and it could be used to store any application data (articles, products, posts, etc.).

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error(auth.to_string())
    return

# Create a base collection
var collection = await pb.collections.create_base("articles", {
    "fields": [
        {
            "name": "title",
            "type": "text",
            "required": true,
            "min": 6,
            "max": 100
        },
        {
            "name": "description",
            "type": "text"
        }
    ],
    "listRule": "@request.auth.id != '' || status = 'public'",
    "viewRule": "@request.auth.id != '' || status = 'public'"
})
```

### View Collection

**View collection** is a read-only collection type where the data is populated from a plain SQL `SELECT` statement, allowing users to perform aggregations or any other custom queries.

For example, the following query will create a read-only collection with 3 _posts_ fields - _id_, _name_ and _totalComments_:

```gdscript
# Create a view collection
var view_collection = await pb.collections.create_view("post_stats", 
    "SELECT posts.id, posts.name, count(comments.id) as totalComments " +
    "FROM posts " +
    "LEFT JOIN comments on comments.postId = posts.id " +
    "GROUP BY posts.id"
)
```

**Note**: View collections don't receive realtime events because they don't have create/update/delete operations.

### Auth Collection

**Auth collection** has everything from the **Base collection** but with some additional special fields to help you manage your app users and also provide various authentication options.

Each Auth collection has the following special system fields: `email`, `emailVisibility`, `verified`, `password` and `tokenKey`. They cannot be renamed or deleted but can be configured using their specific field options.

```gdscript
# Create an auth collection
var users_collection = await pb.collections.create_auth("users", {
    "fields": [
        {
            "name": "name",
            "type": "text",
            "required": true
        },
        {
            "name": "role",
            "type": "select",
            "options": {
                "values": ["employee", "staff", "admin"]
            }
        }
    ]
})
```

You can have as many Auth collections as you want (users, managers, staffs, members, clients, etc.) each with their own set of fields, separate login and records managing endpoints.

## Collections API

### Initialize Client

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

# Authenticate as superuser (required for collection management)
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error(auth.to_string())
    return
```

### List Collections

```gdscript
# Get paginated list
var result = await pb.collections.get_list(1, 50)

# Get all collections
var all_collections = await pb.collections.get_full_list()
```

### Get Collection

```gdscript
# By ID or name
var collection = await pb.collections.get_one("articles")
# or
var collection = await pb.collections.get_one("COLLECTION_ID")
```

### Create Collection

#### Using Scaffolds (Recommended)

```gdscript
# Create base collection
var base = await pb.collections.create_base("articles", {
    "fields": [
        {
            "name": "title",
            "type": "text",
            "required": true
        }
    ]
})

# Create auth collection
var auth = await pb.collections.create_auth("users")

# Create view collection
var view = await pb.collections.create_view("stats", 
    "SELECT id, name FROM posts"
)
```

#### Manual Creation

```gdscript
var collection = await pb.collections.create({
    "type": "base",
    "name": "articles",
    "fields": [
        {
            "name": "title",
            "type": "text",
            "required": true,
            "min": 6,
            "max": 100
        },
        {
            "name": "description",
            "type": "text"
        },
        {
            "name": "published",
            "type": "bool",
            "required": true
        },
        {
            "name": "views",
            "type": "number",
            "min": 0
        },
        # Note: created and updated fields must be explicitly added if you want to use them
        {
            "name": "created",
            "type": "autodate",
            "required": false,
            "onCreate": true,
            "onUpdate": false
        },
        {
            "name": "updated",
            "type": "autodate",
            "required": false,
            "onCreate": true,
            "onUpdate": true
        }
    ],
    "listRule": "@request.auth.id != '' || published = true",
    "viewRule": "@request.auth.id != '' || published = true",
    "createRule": "@request.auth.id != ''",
    "updateRule": "@request.auth.id != ''",
    "deleteRule": "@request.auth.id != ''"
})
```

### Update Collection

```gdscript
var collection = await pb.collections.update("articles", {
    "listRule": "@request.auth.id != '' || published = true"
})
```

### Delete Collection

```gdscript
# Warning: This will delete the collection and all its records
await pb.collections.delete("articles")
```

### Truncate Collection

Deletes all records but keeps the collection structure:

```gdscript
await pb.collections.truncate("articles")
```

### Import Collections

```gdscript
var collections_to_import = [
    {
        "type": "base",
        "name": "articles",
        "fields": []
    },
    {
        "type": "auth",
        "name": "users",
        "fields": []
    }
]

# Import collections (deleteMissing will delete collections not in the import list)
await pb.collections.import(collections_to_import, false)
```

### Get Scaffolds

```gdscript
var scaffolds = await pb.collections.get_scaffolds()
# Returns: { "base": {...}, "auth": {...}, "view": {...} }
```

## Records API

### Get Record Service

```gdscript
# Get a RecordService instance for a collection
var articles = pb.collection("articles")
```

### List Records

**Important Note:** Bosbase does not initialize `created` and `updated` fields by default. To use these fields, you must explicitly add them when initializing the collection with the proper options:

```gdscript
# Paginated list 
var result = await pb.collection("articles").get_list(1, 20, {
    "filter": "published = true",
    "sort": "-created",
    "expand": "author",
    "fields": "id,title,description"
})

print(result.items)      # Array of records
print(result.page)       # Current page number
print(result.perPage)    # Items per page
print(result.totalItems) # Total items count
print(result.totalPages) # Total pages count

# Get all records (automatically paginates)
var all_records = await pb.collection("articles").get_full_list({
    "filter": "published = true",
    "sort": "-created"
})
```

### Get Single Record

```gdscript
var record = await pb.collection("articles").get_one("RECORD_ID", {
    "expand": "author,category",
    "fields": "id,title,description,author"
})
```

### Get First Matching Record

```gdscript
var record = await pb.collection("articles").get_first_list_item(
    "title ~ \"example\" && published = true",
    {
        "expand": "author"
    }
)
```

### Create Record

```gdscript
# Simple create
var record = await pb.collection("articles").create({
    "title": "My First Article",
    "description": "This is a test article",
    "published": true,
    "views": 0
})

# With file upload
var files = {
    "cover": {
        "filename": "image.jpg",
        "content_type": "image/jpeg",
        "data": file_data  # PackedByteArray
    }
}
var record = await pb.collection("articles").create({
    "title": "My Article"
}, {}, files)

# With field modifiers
var record = await pb.collection("articles").create({
    "title": "My Article",
    "views+": 1  # Increment views by 1
})
```

### Update Record

```gdscript
# Simple update
var record = await pb.collection("articles").update("RECORD_ID", {
    "title": "Updated Title",
    "published": true
})

# With field modifiers
var record = await pb.collection("articles").update("RECORD_ID", {
    "views+": 1,           # Increment views
    "tags+": "new-tag"     # Append tag
})

# Remove tag
await pb.collection("articles").update("RECORD_ID", {
    "tags-": "old-tag"
})

# With file upload
var files = {
    "cover": {
        "filename": "new-image.jpg",
        "content_type": "image/jpeg",
        "data": file_data
    }
}
var record = await pb.collection("articles").update("RECORD_ID", {
    "title": "Updated Title"
}, {}, files)
```

### Delete Record

```gdscript
await pb.collection("articles").delete("RECORD_ID")
```

### Batch Operations

```gdscript
var batch_result = await pb.batch.send([
    {
        "method": "POST",
        "url": "/api/collections/articles/records",
        "body": { "title": "Article 1" }
    },
    {
        "method": "POST",
        "url": "/api/collections/articles/records",
        "body": { "title": "Article 2" }
    },
    {
        "method": "PATCH",
        "url": "/api/collections/articles/records/RECORD_ID",
        "body": { "published": true }
    }
])
```

## Field Types

All collection fields (with exception of the `JSONField`) are **non-nullable and use a zero-default** for their respective type as fallback value when missing (empty string for `text`, 0 for `number`, etc.).

### BoolField

Stores a single `false` (default) or `true` value.

```gdscript
# Create field
{
    "name": "published",
    "type": "bool",
    "required": true
}

# Usage
await pb.collection("articles").create({
    "published": true
})
```

### NumberField

Stores numeric/float64 value: `0` (default), `2`, `-1`, `1.5`.

**Available modifiers:**
- `fieldName+` - adds number to the existing record value
- `fieldName-` - subtracts number from the existing record value

```gdscript
# Create field
{
    "name": "views",
    "type": "number",
    "min": 0,
    "max": 1000000,
    "onlyInt": false
}

# Usage
await pb.collection("articles").create({
    "views": 0
})

# Increment
await pb.collection("articles").update("RECORD_ID", {
    "views+": 1
})

# Decrement
await pb.collection("articles").update("RECORD_ID", {
    "views-": 5
})
```

### TextField

Stores string values: `""` (default), `"example"`.

**Available modifiers:**
- `fieldName:autogenerate` - autogenerate a field value if the `AutogeneratePattern` field option is set.

```gdscript
# Create field
{
    "name": "title",
    "type": "text",
    "required": true,
    "min": 6,
    "max": 100,
    "pattern": "^[A-Z]",  # Must start with uppercase
    "autogeneratePattern": "[a-z0-9-]{10,}"  # Auto-generate pattern
}

# Usage
await pb.collection("articles").create({
    "title": "My Article"
})

# Auto-generate
await pb.collection("articles").create({
    "slug:autogenerate": "article-"
    # Results in: "article-abc123def"
})
```

### EmailField

Stores a single email string address: `""` (default), `"john@example.com"`.

```gdscript
# Create field
{
    "name": "email",
    "type": "email",
    "required": true
}

# Usage
await pb.collection("users").create({
    "email": "user@example.com"
})
```

### URLField

Stores a single URL string value: `""` (default), `"https://example.com"`.

```gdscript
# Create field
{
    "name": "website",
    "type": "url",
    "required": false
}

# Usage
await pb.collection("users").create({
    "website": "https://example.com"
})
```

### EditorField

Stores HTML formatted text: `""` (default), `<p>example</p>`.

```gdscript
# Create field
{
    "name": "content",
    "type": "editor",
    "required": true,
    "maxSize": 10485760  # 10MB
}

# Usage
await pb.collection("articles").create({
    "content": "<p>This is HTML content</p>"
})
```

### DateField

Stores a single datetime string value: `""` (default), `"2022-01-01 00:00:00.000Z"`.

All BosBase dates follow the RFC3339 format `Y-m-d H:i:s.uZ` (e.g. `2024-11-10 18:45:27.123Z`).

```gdscript
# Create field
{
    "name": "published_at",
    "type": "date",
    "required": false
}

# Usage
await pb.collection("articles").create({
    "published_at": "2024-11-10 18:45:27.123Z"
})

# Filter by date
var records = await pb.collection("articles").get_list(1, 20, {
    "filter": "created >= '2024-11-19 00:00:00.000Z' && created <= '2024-11-19 23:59:59.999Z'"
})
```

### AutodateField

Similar to DateField but its value is auto set on record create/update. Usually used for timestamp fields like `created` and `updated`.

**Important Note:** Bosbase does not initialize `created` and `updated` fields by default. To use these fields, you must explicitly add them when initializing the collection with the proper options:

```gdscript
# Create field with proper structure
{
    "name": "created",
    "type": "autodate",
    "required": false,
    "onCreate": true,  # Set on record creation (direct property)
    "onUpdate": false  # Don't update on record update (direct property)
}

# For updated field
{
    "name": "updated",
    "type": "autodate",
    "required": false,
    "onCreate": true,  # Set on record creation (direct property)
    "onUpdate": true   # Update on record update (direct property)
}

# The value is automatically set by the backend based on onCreate and onUpdate properties
```

### SelectField

Stores single or multiple string values from a predefined list.

For **single** `select` (the `MaxSelect` option is <= 1) the field value is a string: `""`, `"optionA"`.

For **multiple** `select` (the `MaxSelect` option is >= 2) the field value is an array: `[]`, `["optionA", "optionB"]`.

**Available modifiers:**
- `fieldName+` - appends one or more values
- `+fieldName` - prepends one or more values
- `fieldName-` - subtracts/removes one or more values

```gdscript
# Single select
{
    "name": "status",
    "type": "select",
    "options": {
        "values": ["draft", "published", "archived"]
    },
    "maxSelect": 1
}

# Multiple select
{
    "name": "tags",
    "type": "select",
    "options": {
        "values": ["tech", "design", "business", "marketing"]
    },
    "maxSelect": 5
}

# Usage - Single
await pb.collection("articles").create({
    "status": "published"
})

# Usage - Multiple
await pb.collection("articles").create({
    "tags": ["tech", "design"]
})

# Modify - Append
await pb.collection("articles").update("RECORD_ID", {
    "tags+": "marketing"
})

# Modify - Remove
await pb.collection("articles").update("RECORD_ID", {
    "tags-": "tech"
})
```

### FileField

Manages record file(s). BosBase stores in the database only the file name. The file itself is stored either on the local disk or in S3.

For **single** `file` (the `MaxSelect` option is <= 1) the stored value is a string: `""`, `"file1_Ab24ZjL.png"`.

For **multiple** `file` (the `MaxSelect` option is >= 2) the stored value is an array: `[]`, `["file1_Ab24ZjL.png", "file2_Frq24ZjL.txt"]`.

**Available modifiers:**
- `fieldName+` - appends one or more files
- `+fieldName` - prepends one or more files
- `fieldName-` - deletes one or more files

```gdscript
# Single file
{
    "name": "cover",
    "type": "file",
    "maxSelect": 1,
    "maxSize": 5242880,  # 5MB
    "mimeTypes": ["image/jpeg", "image/png"]
}

# Multiple files
{
    "name": "documents",
    "type": "file",
    "maxSelect": 10,
    "maxSize": 10485760,  # 10MB
    "mimeTypes": ["application/pdf", "application/docx"]
}

# Usage - Upload file
var files = {
    "cover": {
        "filename": "image.jpg",
        "content_type": "image/jpeg",
        "data": file_data  # PackedByteArray
    }
}
var record = await pb.collection("articles").create({
    "title": "My Article"
}, {}, files)

# Modify - Add file
var new_files = {
    "documents": {
        "filename": "document.pdf",
        "content_type": "application/pdf",
        "data": file_data
    }
}
await pb.collection("articles").update("RECORD_ID", {}, {}, new_files)

# Modify - Remove file
await pb.collection("articles").update("RECORD_ID", {
    "documents-": "file1_Ab24ZjL.png"
})
```

### RelationField

Stores single or multiple collection record references.

For **single** `relation` (the `MaxSelect` option is <= 1) the field value is a string: `""`, `"RECORD_ID"`.

For **multiple** `relation` (the `MaxSelect` option is >= 2) the field value is an array: `[]`, `["RECORD_ID1", "RECORD_ID2"]`.

**Available modifiers:**
- `fieldName+` - appends one or more ids
- `+fieldName` - prepends one or more ids
- `fieldName-` - subtracts/removes one or more ids

```gdscript
# Single relation
{
    "name": "author",
    "type": "relation",
    "options": {
        "collectionId": "users",
        "cascadeDelete": false
    },
    "maxSelect": 1
}

# Multiple relation
{
    "name": "categories",
    "type": "relation",
    "options": {
        "collectionId": "categories"
    },
    "maxSelect": 5
}

# Usage - Single
await pb.collection("articles").create({
    "title": "My Article",
    "author": "USER_RECORD_ID"
})

# Usage - Multiple
await pb.collection("articles").create({
    "title": "My Article",
    "categories": ["CAT_ID1", "CAT_ID2"]
})

# Modify - Add relation
await pb.collection("articles").update("RECORD_ID", {
    "categories+": "CAT_ID3"
})

# Modify - Remove relation
await pb.collection("articles").update("RECORD_ID", {
    "categories-": "CAT_ID1"
})

# Expand relations when fetching
var record = await pb.collection("articles").get_one("RECORD_ID", {
    "expand": "author,categories"
})
# record["expand"]["author"] - full author record
# record["expand"]["categories"] - array of category records
```

### JSONField

Stores any serialized JSON value, including `null` (default). This is the only nullable field type.

```gdscript
# Create field
{
    "name": "metadata",
    "type": "json",
    "required": false
}

# Usage
await pb.collection("articles").create({
    "title": "My Article",
    "metadata": {
        "seo": {
            "title": "SEO Title",
            "description": "SEO Description"
        },
        "custom": {
            "tags": ["tag1", "tag2"],
            "priority": 10
        }
    }
})

# Can also store arrays
await pb.collection("articles").create({
    "title": "My Article",
    "metadata": [1, 2, 3, { "nested": "object" }]
})
```

### GeoPointField

Stores geographic coordinates (longitude, latitude) as a serialized json object.

The default/zero value of a `geoPoint` is the "Null Island", aka. `{"lon":0,"lat":0}`.

```gdscript
# Create field
{
    "name": "location",
    "type": "geoPoint",
    "required": false
}

# Usage
await pb.collection("places").create({
    "name": "Tokyo Tower",
    "location": {
        "lon": 139.6917,
        "lat": 35.6586
    }
})
```

## Examples

### Complete Example: Blog System

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error(auth.to_string())
    return

# 1. Create users (auth) collection
var users_collection = await pb.collections.create_auth("users", {
    "fields": [
        {
            "name": "name",
            "type": "text",
            "required": true
        },
        {
            "name": "avatar",
            "type": "file",
            "maxSelect": 1,
            "mimeTypes": ["image/jpeg", "image/png"]
        }
    ]
})

# 2. Create categories (base) collection
var categories_collection = await pb.collections.create_base("categories", {
    "fields": [
        {
            "name": "name",
            "type": "text",
            "required": true
        },
        {
            "name": "slug",
            "type": "text",
            "required": true
        }
    ]
})

# 3. Create articles (base) collection
var articles_collection = await pb.collections.create_base("articles", {
    "fields": [
        {
            "name": "title",
            "type": "text",
            "required": true,
            "min": 6,
            "max": 100
        },
        {
            "name": "slug",
            "type": "text",
            "required": true,
            "autogeneratePattern": "[a-z0-9-]{10,}"
        },
        {
            "name": "content",
            "type": "editor",
            "required": true
        },
        {
            "name": "excerpt",
            "type": "text",
            "max": 500
        },
        {
            "name": "cover",
            "type": "file",
            "maxSelect": 1,
            "mimeTypes": ["image/jpeg", "image/png"]
        },
        {
            "name": "author",
            "type": "relation",
            "options": {
                "collectionId": users_collection.id
            },
            "maxSelect": 1,
            "required": true
        },
        {
            "name": "categories",
            "type": "relation",
            "options": {
                "collectionId": categories_collection.id
            },
            "maxSelect": 5
        },
        {
            "name": "tags",
            "type": "select",
            "options": {
                "values": ["tech", "design", "business", "marketing", "lifestyle"]
            },
            "maxSelect": 10
        },
        {
            "name": "status",
            "type": "select",
            "options": {
                "values": ["draft", "published", "archived"]
            },
            "maxSelect": 1,
            "required": true
        },
        {
            "name": "published",
            "type": "bool",
            "required": true
        },
        {
            "name": "views",
            "type": "number",
            "min": 0,
            "onlyInt": true
        },
        {
            "name": "published_at",
            "type": "date"
        },
        {
            "name": "metadata",
            "type": "json"
        }
    ],
    "listRule": "@request.auth.id != '' || (published = true && status = 'published')",
    "viewRule": "@request.auth.id != '' || (published = true && status = 'published')",
    "createRule": "@request.auth.id != ''",
    "updateRule": "author = @request.auth.id || @request.auth.role = 'admin'",
    "deleteRule": "author = @request.auth.id || @request.auth.role = 'admin'"
})

# 4. Create a user
var user = await pb.collection("users").create({
    "email": "author@example.com",
    "emailVisibility": true,
    "password": "securepassword123",
    "passwordConfirm": "securepassword123",
    "name": "John Doe"
})

# 5. Authenticate as the user
await pb.collection("users").auth_with_password("author@example.com", "securepassword123")

# 6. Create a category
var category = await pb.collection("categories").create({
    "name": "Technology",
    "slug": "technology"
})

# 7. Create an article
var article = await pb.collection("articles").create({
    "title": "Getting Started with BosBase",
    "slug:autogenerate": "getting-started-",
    "content": "<p>This is my first article about BosBase...</p>",
    "excerpt": "Learn how to get started with BosBase...",
    "author": user.id,
    "categories": [category.id],
    "tags": ["tech", "tutorial"],
    "status": "published",
    "published": true,
    "views": 0,
    "published_at": "2024-11-10 18:45:27.123Z",
    "metadata": {
        "seo": {
            "title": "Getting Started with BosBase - SEO Title",
            "description": "SEO Description"
        }
    }
})

# 8. Update article views
await pb.collection("articles").update(article.id, {
    "views+": 1
})

# 9. Add a tag to the article
await pb.collection("articles").update(article.id, {
    "tags+": "beginner"
})

# 10. Fetch article with expanded relations
var full_article = await pb.collection("articles").get_one(article.id, {
    "expand": "author,categories"
})

print(full_article["expand"]["author"]["name"])  # John Doe
print(full_article["expand"]["categories"][0]["name"])  # Technology

# 11. List published articles
var published_articles = await pb.collection("articles").get_list(1, 20, {
    "filter": "published = true && status = 'published'",
    "sort": "-created",
    "expand": "author,categories"
})

# 12. Search articles
var search_results = await pb.collection("articles").get_list(1, 20, {
    "filter": "title ~ \"BosBase\" || content ~ \"BosBase\"",
    "sort": "-created"
})
```

### Realtime Subscriptions

```gdscript
# Subscribe to all changes in a collection
var unsubscribe_all = await pb.collection("articles").subscribe("*", func(e):
    print("Action:", e.action)  # 'create', 'update', or 'delete'
    print("Record:", e.record)
)

# Subscribe to changes in a specific record
var unsubscribe_record = await pb.collection("articles").subscribe("RECORD_ID", func(e):
    print("Record updated:", e.record)
)

# Unsubscribe
await pb.collection("articles").unsubscribe("RECORD_ID")
await pb.collection("articles").unsubscribe("*")
await pb.collection("articles").unsubscribe()  # Unsubscribe from all
```

### Authentication with Auth Collections

```gdscript
# Create an auth collection
var customers_collection = await pb.collections.create_auth("customers", {
    "fields": [
        {
            "name": "name",
            "type": "text",
            "required": true
        },
        {
            "name": "phone",
            "type": "text"
        }
    ]
})

# Register a new customer
var customer = await pb.collection("customers").create({
    "email": "customer@example.com",
    "emailVisibility": true,
    "password": "password123",
    "passwordConfirm": "password123",
    "name": "Jane Doe",
    "phone": "+1234567890"
})

# Authenticate
var auth = await pb.collection("customers").auth_with_password(
    "customer@example.com",
    "password123"
)

print(auth.token)  # Auth token
print(auth.record)  # Customer record

# Check if authenticated
if pb.auth_store.is_valid:
    print("Current user:", pb.auth_store.record)

# Logout
pb.auth_store.clear()
```
