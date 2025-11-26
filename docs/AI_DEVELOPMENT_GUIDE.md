# AI Development Guide - GDScript SDK

This guide provides a comprehensive, fast reference for AI systems to quickly develop applications using the BosBase GDScript SDK. All examples are production-ready and follow best practices.

## Table of Contents

1. [Authentication](#authentication)
2. [Initialize Collections](#initialize-collections)
3. [Define Collection Fields](#define-collection-fields)
4. [Add Data to Collections](#add-data-to-collections)
5. [Modify Collection Data](#modify-collection-data)
6. [Delete Data from Collections](#delete-data-from-collections)
7. [Query Collection Contents](#query-collection-contents)
8. [Add and Delete Fields from Collections](#add-and-delete-fields-from-collections)
9. [Query Collection Field Information](#query-collection-field-information)
10. [Upload Files](#upload-files)
11. [Query Logs](#query-logs)
12. [Send Emails](#send-emails)

---

## Authentication

### Initialize Client

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")
```

### Password Authentication

```gdscript
# Authenticate with email/username and password
var auth_data = await pb.collection("users").auth_with_password(
    "user@example.com",
    "password123"
)

if auth_data is ClientResponseError:
    push_error("Authentication failed: " + auth_data.to_string())
    return

# Auth data is automatically stored
print(pb.auth_store.is_valid)  # true
print(pb.auth_store.token)    # JWT token
print(pb.auth_store.record)   # User record
```

### OAuth2 Authentication

```gdscript
# Get OAuth2 providers
var methods = await pb.collection("users").list_auth_methods()
if methods is ClientResponseError:
    push_error("Failed to get auth methods: " + methods.to_string())
    return

print(methods.oauth2.providers)  # Available providers

# Authenticate with OAuth2 (implementation depends on provider)
# Note: OAuth2 flow in GDScript requires custom implementation
```

### OTP Authentication

```gdscript
# Request OTP
var otp_response = await pb.collection("users").request_verification("user@example.com")
if otp_response is ClientResponseError:
    push_error("Failed to request OTP: " + otp_response.to_string())
    return

# Authenticate with OTP
var auth_data = await pb.collection("users").auth_with_otp(
    otp_response.otpId,
    "123456"  # OTP code
)
```

### Check Authentication Status

```gdscript
if pb.auth_store.is_valid:
    print("Authenticated as: ", pb.auth_store.record.email)
else:
    print("Not authenticated")
```

### Logout

```gdscript
pb.auth_store.clear()
```

---

## Initialize Collections

### Create Base Collection

```gdscript
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

if collection is ClientResponseError:
    push_error("Failed to create collection: " + collection.to_string())
    return

print("Collection ID: ", collection.id)
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
    ],
    "passwordAuth": {
        "enabled": true,
        "identityFields": ["email", "username"],
    },
})
```

### Create View Collection

```gdscript
var view_collection = await pb.collections.create({
    "name": "published_posts",
    "type": "view",
    "viewQuery": "SELECT * FROM posts WHERE published = true",
})
```

### Get Collection by ID or Name

```gdscript
var collection = await pb.collections.get_one("posts")
# or by ID
var collection = await pb.collections.get_one("_pbc_2287844090")
```

---

## Define Collection Fields

### Add Field to Collection

```gdscript
var updated_collection = await pb.collections.add_field("posts", {
    "name": "content",
    "type": "editor",
    "required": false,
})
```

### Common Field Types

```gdscript
# Text field
{
    "name": "title",
    "type": "text",
    "required": true,
    "min": 10,
    "max": 255,
}

# Number field
{
    "name": "views",
    "type": "number",
    "required": false,
    "min": 0,
}

# Boolean field
{
    "name": "published",
    "type": "bool",
    "required": false,
}

# Date field
{
    "name": "published_at",
    "type": "date",
    "required": false,
}

# File field
{
    "name": "avatar",
    "type": "file",
    "required": false,
    "maxSelect": 1,
    "maxSize": 2097152,  # 2MB
    "mimeTypes": ["image/jpeg", "image/png"],
}

# Relation field
{
    "name": "author",
    "type": "relation",
    "required": true,
    "options": {
        "collectionId": "_pbc_users_auth_",
    },
    "maxSelect": 1,
}

# Select field
{
    "name": "status",
    "type": "select",
    "required": true,
    "options": {
        "values": ["draft", "published", "archived"],
    },
}
```

### Update Field

```gdscript
var updated_collection = await pb.collections.update_field("posts", "title", {
    "max": 500,
    "required": true,
})
```

### Remove Field

```gdscript
var updated_collection = await pb.collections.remove_field("posts", "old_field")
```

---

## Add Data to Collections

### Create Single Record

```gdscript
var record = await pb.collection("posts").create({
    "title": "My First Post",
    "content": "This is the content",
    "published": true,
})

if record is ClientResponseError:
    push_error("Failed to create record: " + record.to_string())
    return

print("Created record ID: ", record.id)
```

### Create Record with File Upload

```gdscript
# Read file
var file_path = "res://image.jpg"
var file = FileAccess.open(file_path, FileAccess.READ)
if file == null:
    push_error("Failed to open file")
    return

var file_data = file.get_buffer(file.get_length())
file.close()

var files = {
    "image": {
        "filename": "image.jpg",
        "content_type": "image/jpeg",
        "data": file_data
    }
}

var record = await pb.collection("posts").create({
    "title": "Post with Image",
}, {}, files)
```

### Create Record with Relations

```gdscript
var record = await pb.collection("posts").create({
    "title": "My Post",
    "author": "user_record_id",  # Related record ID
    "categories": ["cat1_id", "cat2_id"],  # Multiple relations
})
```

### Batch Create Records

```gdscript
var records = await pb.batch([
    {
        "method": "POST",
        "url": "/api/collections/posts/records",
        "body": {"title": "Post 1"},
    },
    {
        "method": "POST",
        "url": "/api/collections/posts/records",
        "body": {"title": "Post 2"},
    },
])
```

---

## Modify Collection Data

### Update Single Record

```gdscript
var updated = await pb.collection("posts").update("record_id", {
    "title": "Updated Title",
    "content": "Updated content",
})
```

### Update Record with File

```gdscript
# Read new file
var file = FileAccess.open("res://new_image.jpg", FileAccess.READ)
var file_data = file.get_buffer(file.get_length())
file.close()

var files = {
    "image": {
        "filename": "new_image.jpg",
        "content_type": "image/jpeg",
        "data": file_data
    }
}

var updated = await pb.collection("posts").update("record_id", {
    "title": "Updated Title",
}, {}, files)
```

### Partial Update

```gdscript
# Only update specific fields
var updated = await pb.collection("posts").update("record_id", {
    "views": 100,  # Only update views
})
```

---

## Delete Data from Collections

### Delete Single Record

```gdscript
var result = await pb.collection("posts").delete("record_id")
if result is ClientResponseError:
    push_error("Failed to delete: " + result.to_string())
```

### Delete Multiple Records

```gdscript
# Using batch
await pb.batch([
    {
        "method": "DELETE",
        "url": "/api/collections/posts/records/record_id_1",
    },
    {
        "method": "DELETE",
        "url": "/api/collections/posts/records/record_id_2",
    },
])
```

### Delete All Records (Truncate)

```gdscript
var result = await pb.collections.truncate("posts")
if result is ClientResponseError:
    push_error("Failed to truncate: " + result.to_string())
```

---

## Query Collection Contents

### List Records with Pagination

```gdscript
var result = await pb.collection("posts").get_list(1, 50)

if result is ClientResponseError:
    push_error("Failed to get list: " + result.to_string())
    return

print(result.page)        # 1
print(result.perPage)     # 50
print(result.totalItems)  # Total count
print(result.items)       # Array of records
```

### Filter Records

```gdscript
var result = await pb.collection("posts").get_list(1, 50, {
    "filter": "published = true && views > 100",
    "sort": "-created",
})
```

### Filter Operators

```gdscript
# Equality
"filter": "status = \"published\""

# Comparison
"filter": "views > 100"
"filter": "created >= \"2023-01-01\""

# Text search
"filter": "title ~ \"javascript\""

# Multiple conditions
"filter": "status = \"published\" && views > 100"
"filter": "status = \"draft\" || status = \"pending\""

# Relation filter
"filter": "author.id = \"user_id\""
```

### Sort Records

```gdscript
# Single field
"sort": "-created"  # DESC
"sort": "title"     # ASC

# Multiple fields
"sort": "-created,title"  # DESC by created, then ASC by title
```

### Expand Relations

```gdscript
var result = await pb.collection("posts").get_list(1, 50, {
    "expand": "author,categories",
})

if not result is ClientResponseError:
    # Access expanded data
    for post in result.items:
        var author = post.get("expand", {}).get("author", {})
        print(author.get("name", ""))
        print(post.get("expand", {}).get("categories", []))
```

### Get Single Record

```gdscript
var record = await pb.collection("posts").get_one("record_id", {
    "expand": "author",
})
```

### Get First Matching Record

```gdscript
var record = await pb.collection("posts").get_first_list_item(
    "slug = \"my-post-slug\"",
    {
        "expand": "author",
    }
)
```

### Get All Records

```gdscript
var all_records = await pb.collection("posts").get_full_list({
    "filter": "published = true",
    "sort": "-created",
})
```

---

## Add and Delete Fields from Collections

### Add Field

```gdscript
var collection = await pb.collections.add_field("posts", {
    "name": "tags",
    "type": "select",
    "options": {
        "values": ["tech", "science", "art"],
    },
})
```

### Update Field

```gdscript
var collection = await pb.collections.update_field("posts", "tags", {
    "options": {
        "values": ["tech", "science", "art", "music"],
    },
})
```

### Remove Field

```gdscript
var collection = await pb.collections.remove_field("posts", "old_field")
```

### Get Field Information

```gdscript
var field = await pb.collections.get_field("posts", "title")
if not field is ClientResponseError:
    print(field.type, field.required, field.options)
```

---

## Query Collection Field Information

### Get All Fields for a Collection

```gdscript
var collection = await pb.collections.get_one("posts")
if not collection is ClientResponseError:
    for field in collection.fields:
        print(field.name, field.type, field.required)
```

### Get Collection Schema (Simplified)

```gdscript
var schema = await pb.collections.get_schema("posts")
if not schema is ClientResponseError:
    print(schema.fields)  # Array of field info
```

### Get All Collection Schemas

```gdscript
var schemas = await pb.collections.get_all_schemas()
if not schemas is ClientResponseError:
    for collection in schemas.collections:
        print(collection.name, collection.fields)
```

### Query Field Information for Single Collection

```gdscript
# Method 1: Get full collection
var collection = await pb.collections.get_one("posts")
if not collection is ClientResponseError:
    for field in collection.fields:
        if field.name == "title":
            print("Found title field")

# Method 2: Get specific field
var field = await pb.collections.get_field("posts", "title")

# Method 3: Get schema
var schema = await pb.collections.get_schema("posts")
if not schema is ClientResponseError:
    for f in schema.fields:
        if f.name == "title":
            print("Found title field info")
```

---

## Upload Files

### Upload File with Record Creation

```gdscript
var file = FileAccess.open("res://image.jpg", FileAccess.READ)
var file_data = file.get_buffer(file.get_length())
file.close()

var files = {
    "image": {
        "filename": "image.jpg",
        "content_type": "image/jpeg",
        "data": file_data
    }
}

var record = await pb.collection("posts").create({
    "title": "Post Title",
}, {}, files)
```

### Upload File with Record Update

```gdscript
var file = FileAccess.open("res://new_image.jpg", FileAccess.READ)
var file_data = file.get_buffer(file.get_length())
file.close()

var files = {
    "image": {
        "filename": "new_image.jpg",
        "content_type": "image/jpeg",
        "data": file_data
    }
}

var updated = await pb.collection("posts").update("record_id", {}, {}, files)
```

### Get File URL

```gdscript
var record = await pb.collection("posts").get_one("record_id")
if not record is ClientResponseError:
    var file_url = pb.files.get_url(record, record.get("image", ""))
    print("File URL: ", file_url)
```

### Get File URL with Options

```gdscript
var file_url = pb.files.get_url(record, record.get("image", ""), {
    "thumb": "100x100",  # Thumbnail
    "download": true,    # Force download
})
```

### Get Private File Token

```gdscript
# For accessing private files
var token = await pb.files.get_token()
if not token is ClientResponseError:
    # Use token in file URL query params
    print("Token: ", token)
```

---

## Query Logs

### List Logs

```gdscript
var logs = await pb.logs.get_list(1, 50)
if not logs is ClientResponseError:
    print(logs.items)  # Array of log entries
```

### Filter Logs

```gdscript
var logs = await pb.logs.get_list(1, 50, {
    "filter": "level >= 400",  # Error level and above
    "sort": "-created",
})
```

### Get Single Log

```gdscript
var log = await pb.logs.get_one("log_id")
if not log is ClientResponseError:
    print(log.message, log.data)
```

### Get Log Statistics

```gdscript
var stats = await pb.logs.get_stats({
    "filter": "level >= 400",
})

if not stats is ClientResponseError:
    for stat in stats:
        print(stat.date, stat.total)
```

### Log Levels

- `0` - Debug
- `1` - Info
- `2` - Warning
- `3` - Error
- `4` - Fatal

---

## Send Emails

**Note**: Email sending is typically handled server-side via hooks or backend code. The SDK doesn't provide direct email sending methods, but you can trigger email-related operations.

### Trigger Email Verification

```gdscript
# Request verification email
var result = await pb.collection("users").request_verification("user@example.com")
if result is ClientResponseError:
    push_error("Failed to request verification: " + result.to_string())
```

### Trigger Password Reset Email

```gdscript
# Request password reset email
var result = await pb.collection("users").request_password_reset("user@example.com")
if result is ClientResponseError:
    push_error("Failed to request password reset: " + result.to_string())
```

### Email Change Request

```gdscript
# Request email change
var result = await pb.collection("users").request_email_change("newemail@example.com")
if result is ClientResponseError:
    push_error("Failed to request email change: " + result.to_string())
```

### Server-Side Email Sending

Email sending is configured in the backend settings and triggered automatically by:
- User registration (verification email)
- Password reset requests
- Email change requests
- Custom hooks

To send custom emails, you would typically:
1. Create a backend hook that uses `app.NewMailClient()`
2. Or use the admin API to configure email templates
3. Or trigger email-related record operations that automatically send emails

---

## Complete Example: Full Application Flow

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

func setup_application() -> void:
    # 1. Authenticate
    var auth = await pb.collection("users").auth_with_password("admin@example.com", "password")
    if auth is ClientResponseError:
        push_error("Authentication failed: " + auth.to_string())
        return
    
    # 2. Create collection
    var collection = await pb.collections.create({
        "name": "posts",
        "type": "base",
        "fields": [
            {"name": "title", "type": "text", "required": true},
            {"name": "content", "type": "text"},
            {"name": "published", "type": "bool"},
        ],
    })
    
    if collection is ClientResponseError:
        push_error("Failed to create collection: " + collection.to_string())
        return
    
    # 3. Add more fields
    await pb.collections.add_field("posts", {
        "name": "views",
        "type": "number",
        "min": 0,
    })
    
    # 4. Create records
    var post = await pb.collection("posts").create({
        "title": "Hello World",
        "content": "My first post",
        "published": true,
        "views": 0,
    })
    
    # 5. Query records
    var posts = await pb.collection("posts").get_list(1, 10, {
        "filter": "published = true",
        "sort": "-created",
    })
    
    # 6. Update record
    if not post is ClientResponseError:
        await pb.collection("posts").update(post.id, {
            "views": 100,
        })
    
    # 7. Query logs
    var logs = await pb.logs.get_list(1, 20, {
        "filter": "level >= 400",
    })
    
    print("Application setup complete!")
```

---

## Quick Reference

### Common Patterns

```gdscript
# Check if authenticated
if pb.auth_store.is_valid:
    # Do authenticated operations
    pass

# Get current user
var user = pb.auth_store.record

# Refresh auth token
var refresh = await pb.collection("users").auth_refresh()

# Error handling
var result = await pb.collection("posts").create({"title": "Test"})
if result is ClientResponseError:
    if result.status == 400:
        push_error("Validation error: ", result.data)
    elif result.status == 401:
        push_error("Not authenticated")
```

### Field Types Reference

- `text` - Text input
- `number` - Numeric value
- `bool` - Boolean
- `email` - Email address
- `url` - URL
- `date` - Date
- `select` - Single select
- `json` - JSON data
- `file` - File upload
- `relation` - Relation to another collection
- `editor` - Rich text editor

---

## Best Practices

1. **Always handle errors**: Check for `ClientResponseError` after API calls
2. **Check authentication**: Verify `pb.auth_store.is_valid` before operations
3. **Use pagination**: Don't fetch all records at once for large collections
4. **Validate data**: Ensure required fields are provided
5. **Use filters**: Filter data on the server, not client-side
6. **Expand relations wisely**: Only expand what you need
7. **Handle file uploads**: Use file dictionaries for file fields
8. **Refresh tokens**: Use `auth_refresh()` to maintain sessions

---

## LangChaingo Recipes

### Quick Completion

```gdscript
var result = await pb.langchaingo.completions({
    "model": {"provider": "openai", "model": "gpt-4"},
    "messages": [
        {"role": "system", "content": "You are a helpful assistant"},
        {"role": "user", "content": "Hello"}
    ],
    "temperature": 0.4
})

if not result is ClientResponseError:
    print(result.content)
```

### Retrieval-Augmented Answering

```gdscript
var rag = await pb.langchaingo.rag({
    "collection": "knowledge-base",
    "question": "Why is the sky blue?",
    "topK": 3,
    "returnSources": true,
})

if not rag is ClientResponseError:
    print(rag.answer)
    print(rag.sources)
```

---

This guide provides all essential operations for building applications with the BosBase GDScript SDK. For more detailed information, refer to the specific API documentation files.
