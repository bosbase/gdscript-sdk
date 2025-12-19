# API Records - GDScript SDK Documentation

## Overview

The Records API provides comprehensive CRUD (Create, Read, Update, Delete) operations for collection records, along with powerful search, filtering, and authentication capabilities.

**Key Features:**
- Paginated list and search with filtering and sorting
- Single record retrieval with expand support
- Create, update, and delete operations
- Batch operations for multiple records
- Authentication methods (password, OAuth2, OTP)
- Email verification and password reset
- Relation expansion up to 6 levels deep
- Field selection and excerpt modifiers

**Backend Endpoints:**
- `GET /api/collections/{collection}/records` - List records
- `GET /api/collections/{collection}/records/{id}` - View record
- `POST /api/collections/{collection}/records` - Create record
- `PATCH /api/collections/{collection}/records/{id}` - Update record
- `DELETE /api/collections/{collection}/records/{id}` - Delete record
- `POST /api/batch` - Batch operations

## CRUD Operations

### List/Search Records

Returns a paginated records list with support for sorting, filtering, and expansion.

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://127.0.0.1:8090")

# Basic list with pagination
var result = await pb.collection("posts").get_list(1, 50)

print(result.page)        # 1
print(result.perPage)     # 50
print(result.totalItems)  # 150
print(result.totalPages)  # 3
print(result.items)       # Array of records
```

#### Advanced List with Filtering and Sorting

```gdscript
# Filter and sort
var result = await pb.collection("posts").get_list(1, 50, {
    "filter": "created >= \"2022-01-01 00:00:00\" && status = \"published\"",
    "sort": "-created,title",  # DESC by created, ASC by title
    "expand": "author,categories"
})

# Filter with operators
var result2 = await pb.collection("posts").get_list(1, 50, {
    "filter": "title ~ \"javascript\" && views > 100",
    "sort": "-views"
})
```

#### Get Full List

Fetch all records at once (useful for small collections):

```gdscript
# Get all records
var all_posts = await pb.collection("posts").get_full_list({
    "sort": "-created",
    "filter": "status = \"published\""
})

# With batch size for large collections
var all_posts = await pb.collection("posts").get_full_list(200, {
    "sort": "-created"
})
```

#### Get First Matching Record

Get only the first record that matches a filter:

```gdscript
var post = await pb.collection("posts").get_first_list_item(
    "slug = \"my-post-slug\"",
    {
        "expand": "author,categories.tags"
    }
)
```

### View Record

Retrieve a single record by ID:

```gdscript
# Basic retrieval
var record = await pb.collection("posts").get_one("RECORD_ID")

# With expanded relations
var record = await pb.collection("posts").get_one("RECORD_ID", {
    "expand": "author,categories,tags"
})

# Nested expand
var record = await pb.collection("comments").get_one("COMMENT_ID", {
    "expand": "post.author,user"
})

# Field selection
var record = await pb.collection("posts").get_one("RECORD_ID", {
    "fields": "id,title,content,author.name"
})
```

### Create Record

Create a new record:

```gdscript
# Simple create
var record = await pb.collection("posts").create({
    "title": "My First Post",
    "content": "Lorem ipsum...",
    "status": "draft"
})

# Create with relations
var record = await pb.collection("posts").create({
    "title": "My Post",
    "author": "AUTHOR_ID",           # Single relation
    "categories": ["cat1", "cat2"]    # Multiple relation
})

# Create with file upload (multipart/form-data)
var files = {
    "image": {
        "filename": "image.jpg",
        "content_type": "image/jpeg",
        "data": file_data  # PackedByteArray
    }
}
var record = await pb.collection("posts").create({
    "title": "My Post"
}, {}, files)

# Create with expand to get related data immediately
var record = await pb.collection("posts").create({
    "title": "My Post",
    "author": "AUTHOR_ID"
}, {
    "expand": "author"
})
```

### Update Record

Update an existing record:

```gdscript
# Simple update
var record = await pb.collection("posts").update("RECORD_ID", {
    "title": "Updated Title",
    "status": "published"
})

# Update with relations
await pb.collection("posts").update("RECORD_ID", {
    "categories+": "NEW_CATEGORY_ID",  # Append
    "tags-": "OLD_TAG_ID"               # Remove
})

# Update with file upload
var files = {
    "image": {
        "filename": "new_image.jpg",
        "content_type": "image/jpeg",
        "data": new_file_data
    }
}
var record = await pb.collection("posts").update("RECORD_ID", {
    "title": "Updated Title"
}, {}, files)

# Update with expand
var record = await pb.collection("posts").update("RECORD_ID", {
    "title": "Updated"
}, {
    "expand": "author,categories"
})
```

### Delete Record

Delete a record:

```gdscript
# Simple delete
await pb.collection("posts").delete("RECORD_ID")

# Note: Returns 204 No Content on success
# Returns ClientResponseError if record doesn't exist or permission denied
```

## Filter Syntax

The filter parameter supports a powerful query syntax:

### Comparison Operators

```gdscript
# Equal
filter: "status = \"published\""

# Not equal
filter: "status != \"draft\""

# Greater than / Less than
filter: "views > 100"
filter: "created < \"2023-01-01\""

# Greater/Less than or equal
filter: "age >= 18"
filter: "price <= 99.99"
```

### String Operators

```gdscript
# Contains (like)
filter: "title ~ \"javascript\""
# Equivalent to: title LIKE "%javascript%"

# Not contains
filter: "title !~ \"deprecated\""

# Exact match (case-sensitive)
filter: "email = \"user@example.com\""
```

### Array Operators (for multiple relations/files)

```gdscript
# Any of / At least one
filter: "tags.id ?= \"TAG_ID\""         # Any tag matches
filter: "tags.name ?~ \"important\""    # Any tag name contains "important"

# All must match
filter: "tags.id = \"TAG_ID\" && tags.id = \"TAG_ID2\""
```

### Logical Operators

```gdscript
# AND
filter: "status = \"published\" && views > 100"

# OR
filter: "status = \"published\" || status = \"featured\""

# Parentheses for grouping
filter: "(status = \"published\" || featured = true) && views > 50"
```

### Special Identifiers

```gdscript
# Request context (only in API rules, not client filters)
# @request.auth.id, @request.query.*, etc.

# Collection joins
filter: "@collection.users.email = \"test@example.com\""

# Record fields
filter: "author.id = @request.auth.id"
```

### Comments

```gdscript
# Single-line comments are supported
filter: "status = \"published\" // Only published posts"
```

## Sorting

Sort records using the `sort` parameter:

```gdscript
# Single field (ASC)
sort: "created"

# Single field (DESC)
sort: "-created"

# Multiple fields
sort: "-created,title"  # DESC by created, then ASC by title

# Supported fields
sort: "@random"         # Random order
sort: "@rowid"          # Internal row ID
sort: "id"              # Record ID
sort: "fieldName"       # Any collection field

# Relation field sorting
sort: "author.name"     # Sort by related author's name
```

## Field Selection

Control which fields are returned:

```gdscript
# Specific fields
fields: "id,title,content"

# All fields at level
fields: "*"

# Nested field selection
fields: "*,author.name,author.email"

# Excerpt modifier for text fields
fields: "*,content:excerpt(200,true)"
# Returns first 200 characters with ellipsis if truncated

# Combined
fields: "*,content:excerpt(200),author.name,author.email"
```

## Expanding Relations

Expand related records without additional API calls:

```gdscript
# Single relation
expand: "author"

# Multiple relations
expand: "author,categories,tags"

# Nested relations (up to 6 levels)
expand: "author.profile,categories.tags"

# Back-relations
expand: "comments_via_post.user"
```

See [Relations Documentation](./RELATIONS.md) for detailed information.

## Pagination Options

```gdscript
# Skip total count (faster queries)
var result = await pb.collection("posts").get_list(1, 50, {
    "skipTotal": true,  # totalItems and totalPages will be -1
    "filter": "status = \"published\""
})

# Get Full List with batch processing
var all_posts = await pb.collection("posts").get_full_list(200, {
    "sort": "-created"
})
# Processes in batches of 200 to avoid memory issues
```

## Batch Operations

Execute multiple operations in a single transaction:

```gdscript
# Create a batch
var batch = pb.create_batch()

# Add operations
batch.collection("posts").create({
    "title": "Post 1",
    "author": "AUTHOR_ID"
})

batch.collection("posts").create({
    "title": "Post 2",
    "author": "AUTHOR_ID"
})

batch.collection("tags").update("TAG_ID", {
    "name": "Updated Tag"
})

batch.collection("categories").delete("CAT_ID")

# Upsert (create or update based on id)
batch.collection("posts").upsert({
    "id": "EXISTING_ID",
    "title": "Updated Post"
})

# Send batch request
var results = await batch.send()

# Results is an array matching the order of operations
for i in range(results.size()):
    var result = results[i]
    if result.status >= 400:
        push_error("Operation %d failed: %s" % [i, result.body])
    else:
        print("Operation %d succeeded: %s" % [i, result.body])
```

**Note**: Batch operations must be enabled in Dashboard > Settings > Application.

## Authentication Actions

### List Auth Methods

Get available authentication methods for a collection:

```gdscript
var methods = await pb.collection("users").list_auth_methods()

print(methods.password.enabled)      # true/false
print(methods.oauth2.enabled)        # true/false
print(methods.oauth2.providers)      # Array of OAuth2 providers
print(methods.otp.enabled)           # true/false
print(methods.mfa.enabled)           # true/false
```

### Auth with Password

```gdscript
var auth_data = await pb.collection("users").auth_with_password(
    "user@example.com",  # username or email
    "password123"
)

# Auth data is automatically stored in pb.auth_store
print(pb.auth_store.is_valid)    # true
print(pb.auth_store.token)       # JWT token
print(pb.auth_store.record.id)    # User ID

# Access the returned data
print(auth_data.token)
print(auth_data.record)

# With expand
var auth_data = await pb.collection("users").auth_with_password(
    "user@example.com",
    "password123",
    "profile"  # expand parameter
)
```

### Auth with OAuth2

```gdscript
# Step 1: Get OAuth2 URL (usually done in UI)
var methods = await pb.collection("users").list_auth_methods()
var provider = null
for p in methods.oauth2.providers:
    if p.name == "google":
        provider = p
        break

# Redirect user to provider.authURL
# In Godot, you might use OS.shell_open() or a web view

# Step 2: After redirect, exchange code for token
var auth_data = await pb.collection("users").auth_with_oauth2_code(
    "google",                    # Provider name
    "AUTHORIZATION_CODE",        # From redirect URL
    provider.codeVerifier,       # From step 1
    "https://yourapp.com/callback", # Redirect URL
    {                            # Optional data for new accounts
        "name": "John Doe"
    }
)
```

### Auth with OTP (One-Time Password)

```gdscript
# Step 1: Request OTP
var otp_request = await pb.collection("users").request_otp("user@example.com")
# Returns: { "otpId": "..." }

# Step 2: User enters OTP from email
# Step 3: Authenticate with OTP
var auth_data = await pb.collection("users").auth_with_otp(
    otp_request.otpId,
    "123456"  # OTP from email
)
```

### Auth Refresh

Refresh the current auth token and get updated user data:

```gdscript
# Refresh auth (useful on page reload)
var auth_data = await pb.collection("users").auth_refresh()

# Check if still valid
if pb.auth_store.is_valid:
    print("User is authenticated")
else:
    print("Token expired or invalid")
```

### Email Verification

```gdscript
# Request verification email
await pb.collection("users").request_verification("user@example.com")

# Confirm verification (on verification page)
await pb.collection("users").confirm_verification("VERIFICATION_TOKEN")
```

### Password Reset

```gdscript
# Request password reset email
await pb.collection("users").request_password_reset("user@example.com")

# Confirm password reset (on reset page)
# Note: This invalidates all previous auth tokens
await pb.collection("users").confirm_password_reset(
    "RESET_TOKEN",
    "newpassword123",
    "newpassword123"  # Confirm
)
```

### Email Change

```gdscript
# Must be authenticated first
await pb.collection("users").auth_with_password("user@example.com", "password")

# Request email change
await pb.collection("users").request_email_change("newemail@example.com")

# Confirm email change (on confirmation page)
# Note: This invalidates all previous auth tokens
await pb.collection("users").confirm_email_change(
    "EMAIL_CHANGE_TOKEN",
    "currentpassword"
)
```

### Impersonate (Superuser Only)

Generate a token to authenticate as another user:

```gdscript
# Must be authenticated as superuser
await pb.admins().auth_with_password("admin@example.com", "password")

# Impersonate a user
var impersonate_client = await pb.collection("users").impersonate("USER_ID", 3600)
# Returns a new client instance with impersonated user's token

# Use the impersonated client
var posts = await impersonate_client.collection("posts").get_full_list()

# Access the token
print(impersonate_client.auth_store.token)
print(impersonate_client.auth_store.record)
```

## Complete Examples

### Example 1: Blog Post Search with Filters

```gdscript
func search_posts(query: String, category_id: String, min_views: int) -> Array:
    var filter = "title ~ \"%s\" || content ~ \"%s\"" % [query, query]
    
    if category_id != "":
        filter += " && categories.id ?= \"%s\"" % category_id
    
    if min_views > 0:
        filter += " && views >= %d" % min_views
    
    var result = await pb.collection("posts").get_list(1, 20, {
        "filter": filter,
        "sort": "-created",
        "expand": "author,categories"
    })
    
    return result.items
```

### Example 2: User Dashboard with Related Content

```gdscript
func get_user_dashboard(user_id: String) -> Dictionary:
    # Get user's posts
    var posts = await pb.collection("posts").get_list(1, 10, {
        "filter": "author = \"%s\"" % user_id,
        "sort": "-created",
        "expand": "categories"
    })
    
    # Get user's comments
    var comments = await pb.collection("comments").get_list(1, 10, {
        "filter": "user = \"%s\"" % user_id,
        "sort": "-created",
        "expand": "post"
    })
    
    return {
        "posts": posts.items,
        "comments": comments.items
    }
```

### Example 3: Advanced Filtering

```gdscript
# Complex filter example
var result = await pb.collection("posts").get_list(1, 50, {
    "filter": """
        (status = "published" || featured = true) &&
        created >= "2023-01-01" &&
        (tags.id ?= "important" || categories.id = "news") &&
        views > 100 &&
        author.email != ""
    """,
    "sort": "-views,created",
    "expand": "author.profile,tags,categories",
    "fields": "*,content:excerpt(300),author.name,author.email"
})
```

### Example 4: Batch Create Posts

```gdscript
func create_multiple_posts(posts_data: Array) -> Array:
    var batch = pb.create_batch()
    
    for post_data in posts_data:
        batch.collection("posts").create(post_data)
    
    var results = await batch.send()
    
    # Check for failures
    var failures = []
    for i in range(results.size()):
        var result = results[i]
        if result.status >= 400:
            failures.append({"index": i, "result": result})
    
    if failures.size() > 0:
        push_error("Some posts failed to create: %s" % failures)
    
    var bodies = []
    for result in results:
        bodies.append(result.body)
    return bodies
```

### Example 5: Pagination Helper

```gdscript
func get_all_records_paginated(collection_name: String, options: Dictionary = {}) -> Array:
    var all_records = []
    var page = 1
    var has_more = true
    
    while has_more:
        var opts = options.duplicate()
        opts["skipTotal"] = true  # Skip count for performance
        var result = await pb.collection(collection_name).get_list(page, 500, opts)
        
        all_records.append_array(result.items)
        
        has_more = result.items.size() == 500
        page += 1
    
    return all_records
```

## Error Handling

```gdscript
var record_result = await pb.collection("posts").create({
    "title": "My Post"
})

if record_result is ClientResponseError:
    var error = record_result as ClientResponseError
    if error.status == 400:
        # Validation error
        push_error("Validation errors: %s" % error.data)
    elif error.status == 403:
        # Permission denied
        push_error("Access denied")
    elif error.status == 404:
        # Not found
        push_error("Collection or record not found")
    else:
        push_error("Unexpected error: %s" % error)
```

## Best Practices

1. **Use Pagination**: Always use pagination for large datasets
2. **Skip Total When Possible**: Use `skipTotal: true` for better performance when you don't need counts
3. **Batch Operations**: Use batch for multiple operations to reduce round trips
4. **Field Selection**: Only request fields you need to reduce payload size
5. **Expand Wisely**: Only expand relations you actually use
6. **Filter Before Sort**: Apply filters before sorting for better performance
7. **Cache Auth Tokens**: Auth tokens are automatically stored in `auth_store`, no need to manually cache
8. **Handle Errors**: Always handle authentication and permission errors gracefully

## Related Documentation

- [Collections](./COLLECTIONS.md) - Collection configuration
- [Relations](./RELATIONS.md) - Working with relations
- [API Rules and Filters](./API_RULES_AND_FILTERS.md) - Filter syntax details
- [Authentication](./AUTHENTICATION.md) - Detailed authentication guide
- [Files](./FILES.md) - File uploads and handling











