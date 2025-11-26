# Built-in Users Collection Guide - GDScript SDK

This guide explains how to use the built-in "users" collection for authentication, registration, and API rules. **The "users" collection is automatically created when BosBase is initialized and does not need to be created manually.**

## Table of Contents

1. [Overview](#overview)
2. [Users Collection Structure](#users-collection-structure)
3. [User Registration](#user-registration)
4. [User Login/Authentication](#user-loginauthentication)
5. [API Rules and Filters with Users](#api-rules-and-filters-with-users)
6. [Using Users with Other Collections](#using-users-with-other-collections)
7. [Complete Examples](#complete-examples)

---

## Overview

The "users" collection is a **built-in auth collection** that is automatically created when BosBase starts. It has:

- **Collection ID**: "_pb_users_auth_"
- **Collection Name**: "users"
- **Type**: "auth" (authentication collection)
- **Purpose**: User accounts, authentication, and authorization

**Important**: 
- ✅ **DO NOT** create a new "users" collection manually
- ✅ **DO** use the existing built-in "users" collection
- ✅ The collection already has proper API rules configured
- ✅ It supports password, OAuth2, and OTP authentication

### Getting Users Collection Information

```gdscript
# Get the users collection details
var users_collection = await pb.collections.get_one("users")
# or by ID
var users_collection = await pb.collections.get_one("_pb_users_auth_")

if users_collection is ClientResponseError:
    push_error("Failed to get users collection: " + users_collection.to_string())
    return

print("Collection ID: ", users_collection.id)
print("Collection Name: ", users_collection.name)
print("Collection Type: ", users_collection.type)
print("Fields: ", users_collection.fields)
print("API Rules: ", {
    "listRule": users_collection.listRule,
    "viewRule": users_collection.viewRule,
    "createRule": users_collection.createRule,
    "updateRule": users_collection.updateRule,
    "deleteRule": users_collection.deleteRule,
})
```

---

## Users Collection Structure

### System Fields (Automatically Created)

These fields are automatically added to all auth collections (including "users"):

| Field Name | Type | Description | Required | Hidden |
|------------|------|-------------|----------|--------|
| `id` | text | Unique record identifier | Yes | No |
| `email` | email | User email address | Yes* | No |
| `username` | text | Username (optional, if enabled) | No* | No |
| `password` | password | Hashed password | Yes* | Yes |
| `tokenKey` | text | Token key for auth tokens | Yes | Yes |
| `emailVisibility` | bool | Whether email is visible to others | No | No |
| `verified` | bool | Whether email is verified | No | No |
| `created` | date | Record creation timestamp | Yes | No |
| `updated` | date | Last update timestamp | Yes | No |

*Required based on authentication method configuration (password auth, username auth, etc.)

### Custom Fields (Pre-configured)

The built-in "users" collection includes these custom fields:

| Field Name | Type | Description | Required |
|------------|------|-------------|----------|
| `name` | text | User's display name | No (max: 255 characters) |
| `avatar` | file | User avatar image | No (max: 1 file, images only) |

### Default API Rules

The "users" collection comes with these default API rules:

```gdscript
{
    "listRule": "id = @request.auth.id",    # Users can only list themselves
    "viewRule": "id = @request.auth.id",   # Users can only view themselves
    "createRule": "",                       # Anyone can register (public)
    "updateRule": "id = @request.auth.id", # Users can only update themselves
    "deleteRule": "id = @request.auth.id"  # Users can only delete themselves
}
```

**Understanding the Rules:**

1. **`listRule: "id = @request.auth.id"`**
   - Users can only see their own record when listing
   - If not authenticated, returns empty list (not an error)
   - Superusers can see all users

2. **`viewRule: "id = @request.auth.id"`**
   - Users can only view their own record
   - If trying to view another user, returns 404
   - Superusers can view any user

3. **`createRule: ""`** (empty string)
   - **Public registration** - Anyone can create a user account
   - No authentication required
   - This enables self-registration

4. **`updateRule: "id = @request.auth.id"`**
   - Users can only update their own record
   - Prevents users from modifying other users' data
   - Superusers can update any user

5. **`deleteRule: "id = @request.auth.id"`**
   - Users can only delete their own account
   - Prevents users from deleting other users
   - Superusers can delete any user

**Note**: These rules ensure user privacy and security. Users can only access and modify their own data unless they are superusers.

---

## User Registration

### Basic Registration

Users can register by creating a record in the "users" collection. The `createRule` is set to `""` (empty string), meaning **anyone can register**.

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

# Register a new user
var new_user = await pb.collection("users").create({
    "email": "user@example.com",
    "password": "securepassword123",
    "passwordConfirm": "securepassword123",
    "name": "John Doe",
})

if new_user is ClientResponseError:
    push_error("Registration failed: " + new_user.to_string())
    return

print("User registered: ", new_user.id)
print("Email: ", new_user.email)
```

### Registration with Email Verification

```gdscript
# Register user (verification email sent automatically if configured)
var new_user = await pb.collection("users").create({
    "email": "user@example.com",
    "password": "securepassword123",
    "passwordConfirm": "securepassword123",
    "name": "John Doe",
})

if new_user is ClientResponseError:
    push_error("Registration failed: " + new_user.to_string())
    return

# User will receive verification email
# After clicking link, verified field becomes true
print("Verified status: ", new_user.verified)  # false initially
```

### Registration with Username

If username authentication is enabled in the collection settings:

```gdscript
var new_user = await pb.collection("users").create({
    "email": "user@example.com",
    "username": "johndoe",
    "password": "securepassword123",
    "passwordConfirm": "securepassword123",
    "name": "John Doe",
})

if new_user is ClientResponseError:
    push_error("Registration failed: " + new_user.to_string())
    return
```

### Registration with Avatar Upload

```gdscript
# Read avatar file
var file_path = "res://avatar.jpg"
var file = FileAccess.open(file_path, FileAccess.READ)
if file == null:
    push_error("Failed to open avatar file")
    return

var file_data = file.get_buffer(file.get_length())
file.close()

# Create user with avatar
var files = {
    "avatar": {
        "filename": "avatar.jpg",
        "content_type": "image/jpeg",
        "data": file_data
    }
}

var new_user = await pb.collection("users").create({
    "email": "user@example.com",
    "password": "securepassword123",
    "passwordConfirm": "securepassword123",
    "name": "John Doe",
}, {}, files)

if new_user is ClientResponseError:
    push_error("Registration failed: " + new_user.to_string())
    return
```

### Check if Email Exists

```gdscript
var existing = await pb.collection("users").get_first_list_item("email = \"user@example.com\"")

if existing is ClientResponseError:
    if existing.status == 404:
        print("Email is available")
    else:
        push_error("Error checking email: " + existing.to_string())
else:
    print("Email already exists")
```

---

## User Login/Authentication

### Password Authentication

```gdscript
# Login with email and password
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

### Login with Username

If username authentication is enabled:

```gdscript
var auth_data = await pb.collection("users").auth_with_password(
    "johndoe",  # username instead of email
    "password123"
)

if auth_data is ClientResponseError:
    push_error("Authentication failed: " + auth_data.to_string())
    return
```

### OAuth2 Authentication

```gdscript
# Login with OAuth2 (e.g., Google)
# Note: OAuth2 implementation may vary in GDScript
# Check AUTHENTICATION.md for OAuth2 details
```

### OTP Authentication

```gdscript
# Step 1: Request OTP
var otp_result = await pb.collection("users").request_otp("user@example.com")
if otp_result is ClientResponseError:
    push_error("Failed to request OTP: " + otp_result.to_string())
    return

# Step 2: Authenticate with OTP code from email
var auth_data = await pb.collection("users").auth_with_otp(
    otp_result.otpId,
    "123456"  # OTP code from email
)

if auth_data is ClientResponseError:
    push_error("OTP authentication failed: " + auth_data.to_string())
    return
```

### Check Current Authentication

```gdscript
if pb.auth_store.is_valid:
    var user = pb.auth_store.record
    print("Logged in as: ", user.email)
    print("User ID: ", user.id)
    print("Name: ", user.name)
else:
    print("Not authenticated")
```

### Refresh Auth Token

```gdscript
# Refresh the authentication token
var refresh_result = await pb.collection("users").auth_refresh()
if refresh_result is ClientResponseError:
    push_error("Token refresh failed: " + refresh_result.to_string())
    pb.auth_store.clear()
```

### Logout

```gdscript
pb.auth_store.clear()
```

### Get Current User

```gdscript
var current_user = pb.auth_store.record
if current_user:
    print("Current user: ", current_user.email)
    print("User ID: ", current_user.id)
    print("Name: ", current_user.name)
    print("Verified: ", current_user.verified)
```

### Accessing User Fields

```gdscript
# After authentication, access user fields
var user = pb.auth_store.record

# System fields
print(user.id)                    # User ID
print(user.email)                 # Email
print(user.get("username", ""))   # Username (if enabled)
print(user.verified)              # Email verification status
print(user.emailVisibility)       # Email visibility setting
print(user.created)               # Creation date
print(user.updated)               # Last update date

# Custom fields (from users collection)
print(user.name)                  # Display name
print(user.get("avatar", ""))     # Avatar filename
```

---

## API Rules and Filters with Users

### Understanding @request.auth

The `@request.auth` identifier provides access to the currently authenticated user's data in API rules and filters.

**Available Properties:**
- `@request.auth.id` - User's record ID
- `@request.auth.email` - User's email
- `@request.auth.username` - User's username (if enabled)
- `@request.auth.*` - Any field from the user record

### Common API Rule Patterns

#### 1. Require Authentication

```
# Only authenticated users can access
listRule: '@request.auth.id != ""'
viewRule: '@request.auth.id != ""'
createRule: '@request.auth.id != ""'
```

#### 2. Owner-Based Access

```
# Users can only access their own records
viewRule: 'author = @request.auth.id'
updateRule: 'author = @request.auth.id'
deleteRule: 'author = @request.auth.id'
```

#### 3. Public with User-Specific Data

```
# Public can see published, users can see their own
listRule: '@request.auth.id != "" && author = @request.auth.id || status = "published"'
viewRule: '@request.auth.id != "" && author = @request.auth.id || status = "published"'
```

#### 4. Role-Based Access (if you add a role field)

```
# Assuming you add a 'role' select field to users collection
listRule: '@request.auth.id != "" && @request.auth.role = "admin"'
updateRule: '@request.auth.role = "admin" || author = @request.auth.id'
```

#### 5. Verified Users Only

```
# Only verified users can create
createRule: '@request.auth.id != "" && @request.auth.verified = true'
```

### Setting API Rules for Other Collections

When creating collections that relate to users:

```gdscript
# Create posts collection with user-based rules
var posts_collection = await pb.collections.create({
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
        {
            "name": "author",
            "type": "relation",
            "options": {
                "collectionId": "_pb_users_auth_",  # Reference to users collection
            },
            "maxSelect": 1,
            "required": true,
        },
        {
            "name": "status",
            "type": "select",
            "options": {
                "values": ["draft", "published"],
            },
        },
    ],
    # Public can see published posts, users can see their own
    "listRule": "@request.auth.id != \"\" && author = @request.auth.id || status = \"published\"",
    "viewRule": "@request.auth.id != \"\" && author = @request.auth.id || status = \"published\"",
    # Only authenticated users can create
    "createRule": "@request.auth.id != \"\"",
    # Only authors can update their posts
    "updateRule": "author = @request.auth.id",
    # Only authors can delete their posts
    "deleteRule": "author = @request.auth.id",
})
```

### Using Filters with Users

```gdscript
# Get posts by current user
var my_posts = await pb.collection("posts").get_list(1, 20, {
    "filter": "author = @request.auth.id"
})

if my_posts is ClientResponseError:
    push_error("Failed to get posts: " + my_posts.to_string())
    return

# Get posts by verified users only
var verified_posts = await pb.collection("posts").get_list(1, 20, {
    "filter": "author.verified = true",
    "expand": "author"
})

if verified_posts is ClientResponseError:
    push_error("Failed to get verified posts: " + verified_posts.to_string())
    return

# Get posts where author name contains "John"
var posts = await pb.collection("posts").get_list(1, 20, {
    "filter": "author.name ~ \"John\"",
    "expand": "author"
})

if posts is ClientResponseError:
    push_error("Failed to get posts: " + posts.to_string())
    return
```

---

## Using Users with Other Collections

### Creating Relations to Users

When creating collections that need to reference users:

```gdscript
# Create a posts collection with author relation
var posts_collection = await pb.collections.create({
    "name": "posts",
    "type": "base",
    "fields": [
        {
            "name": "title",
            "type": "text",
            "required": true,
        },
        {
            "name": "author",
            "type": "relation",
            "options": {
                "collectionId": "_pb_users_auth_",  # Users collection ID
            },
            "maxSelect": 1,
            "required": true,
        },
    ],
})
```

### Creating Records with User Relations

```gdscript
# Authenticate first
var auth = await pb.collection("users").auth_with_password("user@example.com", "password")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return

# Create a post with current user as author
var post = await pb.collection("posts").create({
    "title": "My First Post",
    "author": pb.auth_store.record.id,  # Current user's ID
})

if post is ClientResponseError:
    push_error("Failed to create post: " + post.to_string())
    return
```

### Querying with User Relations

```gdscript
# Get posts with author information
var posts = await pb.collection("posts").get_list(1, 20, {
    "expand": "author",  # Expand the author relation
})

if posts is ClientResponseError:
    push_error("Failed to get posts: " + posts.to_string())
    return

for post in posts.items:
    print("Post: ", post.title)
    var author = post.get("expand", {}).get("author", {})
    print("Author: ", author.get("name", ""))
    print("Author Email: ", author.get("email", ""))

# Filter posts by author
var user_posts = await pb.collection("posts").get_list(1, 20, {
    "filter": "author = \"USER_ID\"",
    "expand": "author"
})

if user_posts is ClientResponseError:
    push_error("Failed to get user posts: " + user_posts.to_string())
    return
```

### Updating User Profile

```gdscript
# Users can update their own profile
var result = await pb.collection("users").update(pb.auth_store.record.id, {
    "name": "Updated Name"
})

if result is ClientResponseError:
    push_error("Failed to update profile: " + result.to_string())
    return

# Update with avatar
var file = FileAccess.open("res://new_avatar.jpg", FileAccess.READ)
if file == null:
    push_error("Failed to open avatar file")
    return

var file_data = file.get_buffer(file.get_length())
file.close()

var files = {
    "avatar": {
        "filename": "new_avatar.jpg",
        "content_type": "image/jpeg",
        "data": file_data
    }
}

var update_result = await pb.collection("users").update(pb.auth_store.record.id, {
    "name": "New Name"
}, {}, files)

if update_result is ClientResponseError:
    push_error("Failed to update profile with avatar: " + update_result.to_string())
```

---

## Complete Examples

### Example 1: User Registration and Login Flow

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

func register_and_login() -> Dictionary:
    # 1. Register new user
    var new_user = await pb.collection("users").create({
        "email": "newuser@example.com",
        "password": "securepassword123",
        "passwordConfirm": "securepassword123",
        "name": "New User",
    })
    
    if new_user is ClientResponseError:
        push_error("Registration error: " + new_user.to_string())
        if new_user.data:
            push_error("Validation errors: ", new_user.data)
        return {}
    
    print("Registration successful: ", new_user.id)
    
    # 2. Login with credentials
    var auth_data = await pb.collection("users").auth_with_password(
        "newuser@example.com",
        "securepassword123"
    )
    
    if auth_data is ClientResponseError:
        push_error("Login error: " + auth_data.to_string())
        return {}
    
    print("Login successful")
    print("Token: ", auth_data.token)
    print("User: ", auth_data.record)
    
    return auth_data
```

### Example 2: User Creates and Manages Their Posts

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

func user_post_management() -> void:
    # 1. User logs in
    var auth = await pb.collection("users").auth_with_password("user@example.com", "password")
    if auth is ClientResponseError:
        push_error("Authentication failed: " + auth.to_string())
        return
    
    var user_id = pb.auth_store.record.id
    
    # 2. User creates a post
    var post = await pb.collection("posts").create({
        "title": "My First Post",
        "content": "This is my content",
        "author": user_id,
        "status": "draft",
    })
    
    if post is ClientResponseError:
        push_error("Failed to create post: " + post.to_string())
        return
    
    print("Post created: ", post.id)
    
    # 3. User lists their own posts
    var my_posts = await pb.collection("posts").get_list(1, 20, {
        "filter": "author = \"" + user_id + "\"",
        "sort": "-created"
    })
    
    if my_posts is ClientResponseError:
        push_error("Failed to get posts: " + my_posts.to_string())
        return
    
    print("My posts: ", my_posts.items.size())
    
    # 4. User updates their post
    var update_result = await pb.collection("posts").update(post.id, {
        "title": "Updated Title",
        "status": "published",
    })
    
    if update_result is ClientResponseError:
        push_error("Failed to update post: " + update_result.to_string())
        return
    
    # 5. User views their post with author info
    var updated_post = await pb.collection("posts").get_one(post.id, {
        "expand": "author"
    })
    
    if updated_post is ClientResponseError:
        push_error("Failed to get post: " + updated_post.to_string())
        return
    
    var author = updated_post.get("expand", {}).get("author", {})
    print("Post author: ", author.get("name", ""))
    
    # 6. User deletes their post
    var delete_result = await pb.collection("posts").delete(post.id)
    
    if delete_result is ClientResponseError:
        push_error("Failed to delete post: " + delete_result.to_string())
        return
    
    print("Post deleted")
```

### Example 3: Public Posts with User Information

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

func view_public_posts() -> void:
    # No authentication required for public posts
    
    # Get published posts with author information
    var posts = await pb.collection("posts").get_list(1, 20, {
        "filter": "status = \"published\"",
        "expand": "author",
        "sort": "-created"
    })
    
    if posts is ClientResponseError:
        push_error("Failed to get posts: " + posts.to_string())
        return
    
    for post in posts.items:
        print("Title: ", post.title)
        var author = post.get("expand", {}).get("author", {})
        print("Author: ", author.get("name", ""))
        # Email visibility depends on author's emailVisibility setting
        if author.get("emailVisibility", false):
            print("Author Email: ", author.get("email", ""))
```

### Example 4: Email Verification Flow

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

func email_verification_flow() -> void:
    # 1. User registers
    var new_user = await pb.collection("users").create({
        "email": "user@example.com",
        "password": "password123",
        "passwordConfirm": "password123",
        "name": "User Name",
    })
    
    if new_user is ClientResponseError:
        push_error("Registration failed: " + new_user.to_string())
        return
    
    print("User registered, verification email sent")
    print("Verified status: ", new_user.verified)  # false
    
    # 2. User clicks verification link in email
    # (This is handled by the backend automatically)
    
    # 3. Check verification status
    var user = await pb.collection("users").get_one(new_user.id)
    if user is ClientResponseError:
        push_error("Failed to get user: " + user.to_string())
        return
    
    print("Verified: ", user.verified)
    
    # 4. Request new verification email if needed
    var result = await pb.collection("users").request_verification("user@example.com")
    if result is ClientResponseError:
        push_error("Failed to request verification: " + result.to_string())
```

### Example 5: Password Reset Flow

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

func password_reset_flow() -> void:
    # 1. User requests password reset
    var result = await pb.collection("users").request_password_reset("user@example.com")
    if result is ClientResponseError:
        push_error("Failed to request password reset: " + result.to_string())
        return
    
    print("Password reset email sent")
    
    # 2. User clicks link in email and gets reset token
    # (Token is in the URL query parameter)
    
    # 3. User confirms password reset with token
    var reset_result = await pb.collection("users").confirm_password_reset(
        "RESET_TOKEN_FROM_EMAIL",
        "newpassword123",
        "newpassword123"  # passwordConfirm
    )
    
    if reset_result is ClientResponseError:
        push_error("Failed to reset password: " + reset_result.to_string())
        return
    
    print("Password reset successful")
    
    # 4. User can now login with new password
    var auth = await pb.collection("users").auth_with_password(
        "user@example.com",
        "newpassword123"
    )
    
    if auth is ClientResponseError:
        push_error("Login failed: " + auth.to_string())
    else:
        print("Login successful with new password")
```

---

## Best Practices

1. **Always use the built-in "users" collection** - Don't create a new one
2. **Use "_pb_users_auth_" as collectionId** when creating relations
3. **Check authentication** before user-specific operations
4. **Use "@request.auth.id"** in API rules for user-based access control
5. **Expand user relations** when you need user information
6. **Respect emailVisibility** - Don't expose emails unless user allows it
7. **Handle verification** - Check "verified" field for email verification status
8. **Use proper error handling** for registration/login failures

---

## Common Patterns

### Pattern 1: Owner-Only Access

```
# Users can only access their own records
updateRule: 'author = @request.auth.id'
deleteRule: 'author = @request.auth.id'
```

### Pattern 2: Public Read, Authenticated Write

```
listRule: 'status = "published" || author = @request.auth.id'
viewRule: 'status = "published" || author = @request.auth.id'
createRule: '@request.auth.id != ""'
```

### Pattern 3: Verified Users Only

```
createRule: '@request.auth.id != "" && @request.auth.verified = true'
```

### Pattern 4: Filter by Current User

```gdscript
var my_records = await pb.collection("posts").get_list(1, 20, {
    "filter": "author = @request.auth.id"
})
```

---

This guide covers all essential operations with the built-in "users" collection. Remember: **always use the existing "users" collection, never create a new one manually.**
