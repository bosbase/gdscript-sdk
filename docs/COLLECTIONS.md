# Collections - GDScript SDK Documentation

## Overview

**Collections** represent your application data. Under the hood they are backed by plain SQLite tables that are generated automatically with the collection **name** and **fields** (columns).

A single entry of a collection is called a **record** (a single row in the SQL table).

## Collection Types

### Base Collection

Default collection type for storing any application data.

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error(auth.to_string())
    return

var collection = await pb.collections.create_base("articles", {
    "fields": [
        { "name": "title", "type": "text", "required": true },
        { "name": "description", "type": "text" }
    ]
})
```

### View Collection

Read-only collection populated from a SQL SELECT statement.

```gdscript
var view = await pb.collections.create_view("post_stats", 
    "SELECT posts.id, posts.name, count(comments.id) as totalComments " +
    "FROM posts LEFT JOIN comments on comments.postId = posts.id " +
    "GROUP BY posts.id"
)
```

### Auth Collection

Base collection with authentication fields (email, password, etc.).

```gdscript
var users = await pb.collections.create_auth("users", {
    "fields": [{ "name": "name", "type": "text", "required": true }]
})
```

## Collections API

### List Collections

```gdscript
var result = await pb.collections.get_list(1, 50)
var all = await pb.collections.get_full_list()
```

### Get Collection

```gdscript
var collection = await pb.collections.get_one("articles")
```

### Create Collection

```gdscript
# Using scaffolds
var base = await pb.collections.create_base("articles")
var auth = await pb.collections.create_auth("users")
var view = await pb.collections.create_view("stats", "SELECT * FROM posts")

# Manual
var collection = await pb.collections.create({
    "type": "base",
    "name": "articles",
    "fields": [
        { "name": "title", "type": "text", "required": true },
        # Note: created and updated fields must be explicitly added if you want to use them
        # For autodate fields, onCreate and onUpdate must be direct properties, not nested in options
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
    ]
})
```

### Update Collection

```gdscript
# Update collection rules
await pb.collections.update("articles", { "listRule": "published = true" })

# Update collection name
await pb.collections.update("articles", { "name": "posts" })
```

### Add Fields to Collection

To add a new field to an existing collection, fetch the collection, add the field to the fields array, and update:

```gdscript
# Get existing collection
var collection = await pb.collections.get_one("articles")

# Add new field to existing fields
collection.fields.append({
    "name": "views",
    "type": "number",
    "min": 0,
    "onlyInt": true
})

# Update collection with new field
await pb.collections.update("articles", {
    "fields": collection.fields
})

# Or add multiple fields at once
collection.fields.append({
    "name": "excerpt",
    "type": "text",
    "max": 500
})
collection.fields.append({
    "name": "cover",
    "type": "file",
    "maxSelect": 1,
    "mimeTypes": ["image/jpeg", "image/png"]
})

await pb.collections.update("articles", {
    "fields": collection.fields
})

# Adding created and updated autodate fields to existing collection
# Note: onCreate and onUpdate must be direct properties, not nested in options
collection.fields.append({
    "name": "created",
    "type": "autodate",
    "required": false,
    "onCreate": true,
    "onUpdate": false
})
collection.fields.append({
    "name": "updated",
    "type": "autodate",
    "required": false,
    "onCreate": true,
    "onUpdate": true
})

await pb.collections.update("articles", {
    "fields": collection.fields
})
```

### Delete Fields from Collection

To delete a field, fetch the collection, remove the field from the fields array, and update:

```gdscript
# Get existing collection
var collection = await pb.collections.get_one("articles")

# Remove field by filtering it out
var filtered_fields = []
for field in collection.fields:
    if field.name != "oldFieldName":
        filtered_fields.append(field)
collection.fields = filtered_fields

# Update collection without the deleted field
await pb.collections.update("articles", {
    "fields": collection.fields
})

# Or remove multiple fields
var fields_to_keep = ["title", "content", "author", "status"]
var filtered_fields2 = []
for field in collection.fields:
    if fields_to_keep.has(field.name) or field.get("system", false):
        filtered_fields2.append(field)
collection.fields = filtered_fields2

await pb.collections.update("articles", {
    "fields": collection.fields
})
```

### Modify Fields in Collection

To modify an existing field (e.g., change its type, add options, etc.), fetch the collection, update the field object, and save:

```gdscript
# Get existing collection
var collection = await pb.collections.get_one("articles")

# Find and modify a field
for field in collection.fields:
    if field.name == "title":
        field.max = 200  # Change max length
        field.required = true  # Make required
        break

# Update the field type
for field in collection.fields:
    if field.name == "status":
        # Note: Changing field types may require data migration
        field.type = "select"
        field.options = {
            "values": ["draft", "published", "archived"]
        }
        field.maxSelect = 1
        break

# Save changes
await pb.collections.update("articles", {
    "fields": collection.fields
})
```

### Complete Example: Managing Collection Fields

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error(auth.to_string())
    return

# Get existing collection
var collection = await pb.collections.get_one("articles")

# Add new fields
collection.fields.append({
    "name": "tags",
    "type": "select",
    "options": {
        "values": ["tech", "design", "business"]
    },
    "maxSelect": 5
})
collection.fields.append({
    "name": "published_at",
    "type": "date"
})

# Remove an old field
var filtered_fields = []
for field in collection.fields:
    if field.name != "oldField":
        filtered_fields.append(field)
collection.fields = filtered_fields

# Modify existing field
for field in collection.fields:
    if field.name == "views":
        field.max = 1000000  # Increase max value
        break

# Save all changes at once
await pb.collections.update("articles", {
    "fields": collection.fields
})
```

### Delete Collection

```gdscript
await pb.collections.delete("articles")
```

## Records API

### List Records

```gdscript
var result = await pb.collection("articles").get_list(1, 20, {
    "filter": "published = true",
    "sort": "-created",
    "expand": "author"
})
```

### Get Record

```gdscript
var record = await pb.collection("articles").get_one("RECORD_ID", {
    "expand": "author,category"
})
```

### Create Record

```gdscript
var record = await pb.collection("articles").create({
    "title": "My Article",
    "views+": 1  # Field modifier
})
```

### Update Record

```gdscript
await pb.collection("articles").update("RECORD_ID", {
    "title": "Updated",
    "views+": 1,
    "tags+": "new-tag"
})
```

### Delete Record

```gdscript
await pb.collection("articles").delete("RECORD_ID")
```

## Field Types

### BoolField

```gdscript
# Field definition: { "name": "published", "type": "bool", "required": true }
await pb.collection("articles").create({ "published": true })
```

### NumberField

```gdscript
# Field definition: { "name": "views", "type": "number", "min": 0 }
await pb.collection("articles").update("ID", { "views+": 1 })
```

### TextField

```gdscript
# Field definition: { "name": "title", "type": "text", "required": true, "min": 6, "max": 100 }
await pb.collection("articles").create({ "slug:autogenerate": "article-" })
```

### EmailField

```gdscript
# Field definition: { "name": "email", "type": "email", "required": true }
```

### URLField

```gdscript
# Field definition: { "name": "website", "type": "url" }
```

### EditorField

```gdscript
# Field definition: { "name": "content", "type": "editor", "required": true }
await pb.collection("articles").create({ "content": "<p>HTML content</p>" })
```

### DateField

```gdscript
# Field definition: { "name": "published_at", "type": "date" }
await pb.collection("articles").create({ 
    "published_at": "2024-11-10 18:45:27.123Z" 
})
```

### AutodateField

**Important Note:** Bosbase does not initialize `created` and `updated` fields by default. To use these fields, you must explicitly add them when initializing the collection. For autodate fields, `onCreate` and `onUpdate` must be direct properties of the field object, not nested in an `options` object:

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

```gdscript
# Single select
# Field definition: { "name": "status", "type": "select", "options": { "values": ["draft", "published"] }, "maxSelect": 1 }
await pb.collection("articles").create({ "status": "published" })

# Multiple select
# Field definition: { "name": "tags", "type": "select", "options": { "values": ["tech", "design"] }, "maxSelect": 5 }
await pb.collection("articles").update("ID", { "tags+": "marketing" })
```

### FileField

```gdscript
# Single file
# Field definition: { "name": "cover", "type": "file", "maxSelect": 1, "mimeTypes": ["image/jpeg"] }
var files = {
    "cover": {
        "filename": "image.jpg",
        "content_type": "image/jpeg",
        "data": file_data  # PackedByteArray
    }
}
await pb.collection("articles").create({ "title": "My Article" }, {}, files)
```

### RelationField

```gdscript
# Field definition: { "name": "author", "type": "relation", "options": { "collectionId": "users" }, "maxSelect": 1 }
await pb.collection("articles").create({ "author": "USER_ID" })
var record = await pb.collection("articles").get_one("ID", { "expand": "author" })
```

### JSONField

```gdscript
# Field definition: { "name": "metadata", "type": "json" }
await pb.collection("articles").create({ 
    "metadata": { "seo": { "title": "SEO Title" } } 
})
```

### GeoPointField

```gdscript
# Field definition: { "name": "location", "type": "geoPoint" }
await pb.collection("places").create({ 
    "location": { "lon": 139.6917, "lat": 35.6586 } 
})
```

## Complete Example

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error(auth.to_string())
    return

# Create collections
var users = await pb.collections.create_auth("users")
var articles = await pb.collections.create_base("articles", {
    "fields": [
        { "name": "title", "type": "text", "required": true },
        { "name": "author", "type": "relation", "options": { "collectionId": users.id }, "maxSelect": 1 }
    ]
})

# Create and authenticate user
var user = await pb.collection("users").create({
    "email": "user@example.com",
    "password": "password123",
    "passwordConfirm": "password123"
})
await pb.collection("users").auth_with_password("user@example.com", "password123")

# Create article
var article = await pb.collection("articles").create({
    "title": "My Article",
    "author": user.id
})

# Subscribe to changes
await pb.collection("articles").subscribe("*", func(e):
    print(e.action, e.record)
)
```


