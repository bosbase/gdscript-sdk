# Working with Relations - GDScript SDK Documentation

## Overview

Relations allow you to link records between collections. BosBase supports both single and multiple relations, and provides powerful features for expanding related records and working with back-relations.

**Key Features:**
- Single and multiple relations
- Expand related records without additional requests
- Nested relation expansion (up to 6 levels)
- Back-relations for reverse lookups
- Field modifiers for append/prepend/remove operations

**Relation Field Types:**
- **Single Relation**: Links to one record (MaxSelect <= 1)
- **Multiple Relation**: Links to multiple records (MaxSelect > 1)

**Backend Behavior:**
- Relations are stored as record IDs or arrays of IDs
- Expand only includes relations the client can view (satisfies View API Rule)
- Back-relations use format: `collectionName_via_fieldName`
- Back-relation expand limited to 1000 records per field

## Setting Up Relations

### Creating a Relation Field

```gdscript
var collection = await pb.collections.get_one("posts")

collection.fields.append({
    "name": "user",
    "type": "relation",
    "options": {
        "collectionId": "users"  # ID of related collection
    },
    "maxSelect": 1,  # Single relation
    "required": true
})

# Multiple relation field
collection.fields.append({
    "name": "tags",
    "type": "relation",
    "options": {
        "collectionId": "tags"
    },
    "maxSelect": 10,  # Multiple relation (max 10)
    "minSelect": 1    # Minimum 1 required
})

await pb.collections.update("posts", { "fields": collection.fields })
```

## Creating Records with Relations

### Single Relation

```gdscript
# Create a post with a single user relation
var post = await pb.collection("posts").create({
    "title": "My Post",
    "user": "USER_ID"
})
```

### Multiple Relations

```gdscript
# Create a post with multiple tags
var post = await pb.collection("posts").create({
    "title": "My Post",
    "tags": ["TAG_ID1", "TAG_ID2", "TAG_ID3"]  # Array of IDs
})
```

### Mixed Relations

```gdscript
# Create a comment with both single and multiple relations
var comment = await pb.collection("comments").create({
    "message": "Great post!",
    "post": "POST_ID",        # Single relation
    "user": "USER_ID",        # Single relation
    "tags": ["TAG1", "TAG2"]  # Multiple relation
})
```

## Updating Relations

### Replace All Relations

```gdscript
# Replace all tags
await pb.collection("posts").update("POST_ID", {
    "tags": ["NEW_TAG1", "NEW_TAG2"]
})
```

### Append Relations (Using + Modifier)

```gdscript
# Append tags to existing ones
await pb.collection("posts").update("POST_ID", {
    "tags+": "TAG_ID"  # Append single tag
})

# Append multiple tags
await pb.collection("posts").update("POST_ID", {
    "tags+": ["TAG_ID1", "TAG_ID2"]  # Append multiple tags
})
```

### Prepend Relations (Using + Prefix)

```gdscript
# Prepend tags (tags will appear first)
await pb.collection("posts").update("POST_ID", {
    "+tags": "TAG_ID"  # Prepend single tag
})

# Prepend multiple tags
await pb.collection("posts").update("POST_ID", {
    "+tags": ["TAG1", "TAG2"]  # Prepend multiple tags
})
```

### Remove Relations (Using - Modifier)

```gdscript
# Remove single tag
await pb.collection("posts").update("POST_ID", {
    "tags-": "TAG_ID"
})

# Remove multiple tags
await pb.collection("posts").update("POST_ID", {
    "tags-": ["TAG1", "TAG2"]
})
```

### Complete Example

```gdscript
# Get existing post
var post = await pb.collection("posts").get_one("POST_ID")
print(post.tags)  # ['tag1', 'tag2']

# Remove one tag, add two new ones
await pb.collection("posts").update("POST_ID", {
    "tags-": "tag1",           # Remove
    "tags+": ["tag3", "tag4"]  # Append
})

var updated = await pb.collection("posts").get_one("POST_ID")
print(updated.tags)  # ['tag2', 'tag3', 'tag4']
```

## Expanding Relations

The `expand` parameter allows you to fetch related records in a single request, eliminating the need for multiple API calls.

### Basic Expand

```gdscript
# Get comment with expanded user
var comment = await pb.collection("comments").get_one("COMMENT_ID", {
    "expand": "user"
})

print(comment.get("expand", {}).get("user", {}).get("name"))  # "John Doe"
print(comment.user)  # Still the ID: "USER_ID"
```

### Expand Multiple Relations

```gdscript
# Expand multiple relations (comma-separated)
var comment = await pb.collection("comments").get_one("COMMENT_ID", {
    "expand": "user,post"
})

print(comment.get("expand", {}).get("user", {}).get("name"))   # "John Doe"
print(comment.get("expand", {}).get("post", {}).get("title"))  # "My Post"
```

### Nested Expand (Dot Notation)

You can expand nested relations up to 6 levels deep using dot notation:

```gdscript
# Expand post and its tags, and user
var comment = await pb.collection("comments").get_one("COMMENT_ID", {
    "expand": "user,post.tags"
})

# Access nested expands
var post_expand = comment.get("expand", {}).get("post", {})
print(post_expand.get("expand", {}).get("tags", []))
# Array of tag records

# Expand even deeper
var post = await pb.collection("posts").get_one("POST_ID", {
    "expand": "user,comments.user"
})

# Access: post.get("expand", {}).get("comments", [])[0].get("expand", {}).get("user", {})
```

### Expand with List Requests

```gdscript
# List comments with expanded users
var comments = await pb.collection("comments").get_list(1, 20, {
    "expand": "user"
})

for comment in comments.items:
    print(comment.message)
    var user = comment.get("expand", {}).get("user", {})
    if user.has("name"):
        print(user.name)
```

### Expand Single vs Multiple Relations

```gdscript
# Single relation - expand.user is a dictionary
var post = await pb.collection("posts").get_one("POST_ID", {
    "expand": "user"
})
var user_expand = post.get("expand", {}).get("user", {})
print(user_expand is Dictionary)  # true

# Multiple relation - expand.tags is an array
var post_with_tags = await pb.collection("posts").get_one("POST_ID", {
    "expand": "tags"
})
var tags_expand = post_with_tags.get("expand", {}).get("tags", [])
print(tags_expand is Array)  # true
```

### Expand Permissions

**Important**: Only relations that satisfy the related collection's `viewRule` will be expanded. If you don't have permission to view a related record, it won't appear in the expand.

```gdscript
# If you don't have view permission for user, expand.user will be null or missing
var comment = await pb.collection("comments").get_one("COMMENT_ID", {
    "expand": "user"
})

var user_expand = comment.get("expand", {}).get("user", null)
if user_expand != null:
    print(user_expand.get("name", ""))
else:
    print("User not accessible or not found")
```

## Back-Relations

Back-relations allow you to query and expand records that reference the current record through a relation field.

### Back-Relation Syntax

The format is: `collectionName_via_fieldName`

- `collectionName`: The collection that contains the relation field
- `fieldName`: The name of the relation field that points to your record

### Example: Posts with Comments

```gdscript
# Get a post and expand all comments that reference it
var post = await pb.collection("posts").get_one("POST_ID", {
    "expand": "comments_via_post"
})

# comments_via_post is always an array (even if original field is single)
print(post.get("expand", {}).get("comments_via_post", []))
# Array of comment records
```

### Back-Relation with Nested Expand

```gdscript
# Get post with comments, and expand each comment's user
var post = await pb.collection("posts").get_one("POST_ID", {
    "expand": "comments_via_post.user"
})

# Access nested expands
var comments = post.get("expand", {}).get("comments_via_post", [])
for comment in comments:
    print(comment.get("message", ""))
    var user = comment.get("expand", {}).get("user", {})
    if user.has("name"):
        print(user.name)
```

### Filtering with Back-Relations

```gdscript
# List posts that have at least one comment containing "hello"
var posts = await pb.collection("posts").get_list(1, 20, {
    "filter": "comments_via_post.message ?~ \"hello\"",
    "expand": "comments_via_post.user"
})

for post in posts.items:
    print(post.get("title", ""))
    var comments = post.get("expand", {}).get("comments_via_post", [])
    for comment in comments:
        var message = comment.get("message", "")
        var user = comment.get("expand", {}).get("user", {})
        var user_name = user.get("name", "Unknown")
        print("  - " + message + " by " + user_name)
```

### Sorting with Back-Relations

```gdscript
# Sort posts by number of comments (requires aggregation or custom logic)
var posts = await pb.collection("posts").get_list(1, 20, {
    "expand": "comments_via_post",
    "sort": "-created"
})
```

### Back-Relation Caveats

1. **Always Multiple**: Back-relations are always treated as arrays, even if the original relation field is single. This is because one record can be referenced by multiple records.

   ```gdscript
   # Even if comments.post is single, comments_via_post is always an array
   var post = await pb.collection("posts").get_one("POST_ID", {
       "expand": "comments_via_post"
   })
   
   # Always an array
   var comments = post.get("expand", {}).get("comments_via_post", [])
   print(comments is Array)  # true
   ```

2. **UNIQUE Index Exception**: If the relation field has a UNIQUE index constraint, the back-relation will be treated as a single object (not an array).

   ```gdscript
   # If there's a UNIQUE constraint, it might be single
   # Check your schema to confirm
   ```

3. **1000 Record Limit**: Back-relation expand is limited to 1000 records per field. For larger datasets, use separate paginated requests:

   ```gdscript
   # Instead of expanding all comments (if > 1000)
   var post = await pb.collection("posts").get_one("POST_ID")
   
   # Fetch comments separately with pagination
   var comments = await pb.collection("comments").get_list(1, 100, {
       "filter": "post = \"" + post.id + "\"",
       "expand": "user",
       "sort": "-created"
   })
   ```

## Complete Examples

### Example 1: Blog Post with Author and Tags

```gdscript
# Create a blog post with relations
var post = await pb.collection("posts").create({
    "title": "Getting Started with BosBase",
    "content": "Lorem ipsum...",
    "author": "AUTHOR_ID",           # Single relation
    "tags": ["tag1", "tag2", "tag3"] # Multiple relation
})

# Retrieve with all relations expanded
var full_post = await pb.collection("posts").get_one(post.id, {
    "expand": "author,tags"
})

print(full_post.get("title", ""))
var author = full_post.get("expand", {}).get("author", {})
print("Author: ", author.get("name", ""))

print("Tags:")
var tags = full_post.get("expand", {}).get("tags", [])
for tag in tags:
    print("  - ", tag.get("name", ""))
```

### Example 2: Comment System with Nested Relations

```gdscript
# Create a comment on a post
var comment = await pb.collection("comments").create({
    "message": "Great article!",
    "post": "POST_ID",
    "user": "USER_ID"
})

# Get post with all comments and their authors
var post = await pb.collection("posts").get_one("POST_ID", {
    "expand": "author,comments_via_post.user"
})

print("Post: ", post.get("title", ""))
var author = post.get("expand", {}).get("author", {})
print("Author: ", author.get("name", ""))

var comments = post.get("expand", {}).get("comments_via_post", [])
print("Comments (", comments.size(), "):")
for comment in comments:
    var user = comment.get("expand", {}).get("user", {})
    print("  ", user.get("name", ""), ": ", comment.get("message", ""))
```

### Example 3: Dynamic Tag Management

```gdscript
class_name PostManager

var pb  # BosBase client

func add_tag(post_id: String, tag_id: String) -> void:
    await pb.collection("posts").update(post_id, {
        "tags+": tag_id
    })

func remove_tag(post_id: String, tag_id: String) -> void:
    await pb.collection("posts").update(post_id, {
        "tags-": tag_id
    })

func set_priority_tags(post_id: String, tag_ids: Array) -> void:
    # Clear existing and set priority tags first
    var post = await pb.collection("posts").get_one(post_id)
    await pb.collection("posts").update(post_id, {
        "tags": tag_ids
    })

func get_post_with_tags(post_id: String) -> Dictionary:
    return await pb.collection("posts").get_one(post_id, {
        "expand": "tags"
    })

# Usage
var manager = PostManager.new()
manager.pb = pb
await manager.add_tag("POST_ID", "NEW_TAG_ID")
var post = await manager.get_post_with_tags("POST_ID")
```

### Example 4: Filtering Posts by Tag

```gdscript
# Get all posts with a specific tag
var posts = await pb.collection("posts").get_list(1, 50, {
    "filter": "tags.id ?= \"TAG_ID\"",
    "expand": "author,tags",
    "sort": "-created"
})

for post in posts.items:
    var title = post.get("title", "")
    var author = post.get("expand", {}).get("author", {})
    var author_name = author.get("name", "Unknown")
    print(title, " by ", author_name)
```

### Example 5: User Dashboard with Related Content

```gdscript
func get_user_dashboard(user_id: String) -> void:
    # Get user with all related content
    var user = await pb.collection("users").get_one(user_id, {
        "expand": "posts_via_author,comments_via_user.post"
    })
    
    print("Dashboard for ", user.get("name", ""))
    
    var posts = user.get("expand", {}).get("posts_via_author", [])
    print("\nPosts (", posts.size(), "):")
    for post in posts:
        print("  - ", post.get("title", ""))
    
    var comments = user.get("expand", {}).get("comments_via_user", [])
    print("\nRecent Comments:")
    var recent_comments = comments.slice(0, 5)
    for comment in recent_comments:
        var post_expand = comment.get("expand", {}).get("post", {})
        var post_title = post_expand.get("title", "Unknown Post")
        print("  On \"", post_title, "\": ", comment.get("message", ""))
```

### Example 6: Complex Nested Expand

```gdscript
# Get a post with author, tags, comments, comment authors, and comment reactions
var post = await pb.collection("posts").get_one("POST_ID", {
    "expand": "author,tags,comments_via_post.user,comments_via_post.reactions_via_comment"
})

# Access deeply nested data
var comments = post.get("expand", {}).get("comments_via_post", [])
for comment in comments:
    var user = comment.get("expand", {}).get("user", {})
    var user_name = user.get("name", "Unknown")
    print(user_name, ": ", comment.get("message", ""))
    
    var reactions = comment.get("expand", {}).get("reactions_via_comment", null)
    if reactions != null:
        print("  Reactions: ", reactions)
```

## Best Practices

1. **Use Expand Wisely**: Only expand relations you actually need to reduce response size and improve performance.

2. **Handle Missing Expands**: Always check if expand data exists before accessing:

   ```gdscript
   var expand = record.get("expand", {})
   var user = expand.get("user", null)
   if user != null:
       print(user.get("name", ""))
   ```

3. **Pagination for Large Back-Relations**: If you expect more than 1000 related records, fetch them separately with pagination.

4. **Cache Expansion**: Consider caching expanded data on the client side to reduce API calls.

5. **Error Handling**: Handle cases where related records might not be accessible due to API rules.

6. **Nested Limit**: Remember that nested expands are limited to 6 levels deep.

## Performance Considerations

- **Expand Cost**: Expanding relations doesn't require additional round trips, but increases response payload size
- **Back-Relation Limit**: The 1000 record limit for back-relations prevents extremely large responses
- **Permission Checks**: Each expanded relation is checked against the collection's `viewRule`
- **Nested Depth**: Limit nested expands to avoid performance issues (max 6 levels supported)

## Related Documentation

- [Collections](./COLLECTIONS.md) - Collection and field configuration
- [API Rules and Filters](./API_RULES_AND_FILTERS.md) - Filtering and querying related records
