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
- Back-relations use format: "collectionName_via_fieldName"
- Back-relation expand limited to 1000 records per field

## Setting Up Relations

### Creating a Relation Field

``"javascript
const collection = await pb.collections.getOne('posts');

collection.fields.push({
  "name": 'user',
  "type": 'relation',
  "collectionId": 'users',  # ID of related collection
  "maxSelect": 1,           # Single relation
  required});

# Multiple relation field
collection.fields.push({
  "name": 'tags',
  "type": 'relation',
  "collectionId": 'tags',
  "maxSelect": 10,          # Multiple relation (max 10)
  "minSelect": 1,           # Minimum 1 required
  cascadeDelete});

await pb.collections.update('posts', { fields});
"`"

## Creating Records with Relations

### Single Relation

"`"javascript
# Create a post with a single user relation
const post = await pb.collection('posts').create({
  "title": 'My Post',
  user});
"`"

### Multiple Relations

"`"javascript
# Create a post with multiple tags
const post = await pb.collection('posts').create({
  title: 'My Post',
  tags: ['TAG_ID1', 'TAG_ID2', 'TAG_ID3']  # Array of IDs
});
"`"

### Mixed Relations

"`"javascript
# Create a comment with both single and multiple relations
const comment = await pb.collection('comments').create({
  message: 'Great post!',
  post: 'POST_ID',        # Single relation
  user: 'USER_ID',        # Single relation
  tags: ['TAG1', 'TAG2']  # Multiple relation
});
"`"

## Updating Relations

### Replace All Relations

"`"javascript
# Replace all tags
await pb.collection('posts').update('POST_ID', {
  tags: ['NEW_TAG1', 'NEW_TAG2']
});
"`"

### Append Relations (Using + Modifier)

"`"javascript
# Append tags to existing ones
await pb.collection('posts').update('POST_ID', {
  'tags+'});

# Append multiple tags
await pb.collection('posts').update('POST_ID', {
  'tags+': ['TAG_ID1', 'TAG_ID2']  # Append multiple tags
});
"`"

### Prepend Relations (Using + Prefix)

"`"javascript
# Prepend tags (tags will appear first)
await pb.collection('posts').update('POST_ID', {
  '+tags'});

# Prepend multiple tags
await pb.collection('posts').update('POST_ID', {
  '+tags': ['TAG1', 'TAG2']  # Prepend multiple tags
});
"`"

### Remove Relations (Using - Modifier)

"`"javascript
# Remove single tag
await pb.collection('posts').update('POST_ID', {
  'tags-'});

# Remove multiple tags
await pb.collection('posts').update('POST_ID', {
  'tags-': ['TAG1', 'TAG2']
});
"`"

### Complete Example

"`"javascript
# Get existing post
const post = await pb.collection('posts').getOne('POST_ID');
print(post.tags);  # ['tag1', 'tag2']

# Remove one tag, add two new ones
await pb.collection('posts').update('POST_ID', {
  'tags-': 'tag1',           # Remove
  'tags+': ['tag3', 'tag4']  # Append
});

const updated = await pb.collection('posts').getOne('POST_ID');
print(updated.tags);  # ['tag2', 'tag3', 'tag4']
"`"

## Expanding Relations

The "expand" parameter allows you to fetch related records in a single request, eliminating the need for multiple API calls.

### Basic Expand

"`"javascript
# Get comment with expanded user
const comment = await pb.collection('comments').getOne('COMMENT_ID', {
  expand});

print(comment.expand.user.name);  # "John Doe"
print(comment.user);              # Still the ID: "USER_ID"
"`"

### Expand Multiple Relations

"`"javascript
# Expand multiple relations (comma-separated)
const comment = await pb.collection('comments').getOne('COMMENT_ID', {
  expand: 'user,post'
});

print(comment.expand.user.name);   # "John Doe"
print(comment.expand.post.title);  # "My Post"
"`"

### Nested Expand (Dot Notation)

You can expand nested relations up to 6 levels deep using dot notation:

"`"javascript
# Expand post and its tags, and user
const comment = await pb.collection('comments').getOne('COMMENT_ID', {
  expand: 'user,post.tags'
});

# Access nested expands
print(comment.expand.post.expand.tags);
# Array of tag records

# Expand even deeper
const post = await pb.collection('posts').getOne('POST_ID', {
  expand: 'user,comments.user'
});

# Access: post.expand.comments[0].expand.user
"`"

### Expand with List Requests

"`"javascript
# List comments with expanded users
const comments = await pb.collection('comments').getList(1, 20, {
  expand});

comments.items.for_each(comment => {
  print(comment.message);
  print(comment.expand.user.name);
});
"`"

### Expand Single vs Multiple Relations

"`"javascript
# Single relation - expand.user is an object
const post = await pb.collection('posts').getOne('POST_ID', {
  expand});
print(typeof post.expand.user);  # "object"

# Multiple relation - expand.tags is an array
const postWithTags = await pb.collection('posts').getOne('POST_ID', {
  expand});
print(Array.isArray(postWithTags.expand.tags));  # true
"`"

### Expand Permissions

**Important**: Only relations that satisfy the related collection's "viewRule" will be expanded. If you don't have permission to view a related record, it won't appear in the expand.

"`"javascript
# If you don't have view permission for user, expand.user will be null
const comment = await pb.collection('comments').getOne('COMMENT_ID', {
  expand});

if (comment.expand?.user) {
  print(comment.expand.user.name);
} else {
  print('User not accessible or not found');
}
"`"

## Back-Relations

Back-relations allow you to query and expand records that reference the current record through a relation field.

### Back-Relation Syntax

The format is: "collectionName_via_fieldName"

- "collectionName": The collection that contains the relation field
- "fieldName": The name of the relation field that points to your record

### Example: Posts with Comments

"`"javascript
# Get a post and expand all comments that reference it
const post = await pb.collection('posts').getOne('POST_ID', {
  expand});

# comments_via_post is always an array (even if original field is single)
print(post.expand.comments_via_post);
# Array of comment records
"`"

### Back-Relation with Nested Expand

"`"javascript
# Get post with comments, and expand each comment's user
const post = await pb.collection('posts').getOne('POST_ID', {
  expand});

# Access nested expands
post.expand.comments_via_post.for_each(comment => {
  print(comment.message);
  print(comment.expand.user.name);
});
"`"

### Filtering with Back-Relations

"`"javascript
# List posts that have at least one comment containing "hello"
const posts = await pb.collection('posts').getList(1, 20, {
  "filter": "comments_via_post.message ?~ 'hello'",
  expand});

posts.items.for_each(post => {
  print(post.title);
  post.expand.comments_via_post.for_each(comment => {
    print("  - ${comment.message} by ${comment.expand.user.name}");
  });
});
"`"

### Sorting with Back-Relations

"`"javascript
# Sort posts by number of comments (requires aggregation or custom logic)
const posts = await pb.collection('posts').getList(1, 20, {
  "expand": 'comments_via_post',
  sort});
"`"

### Back-Relation Caveats

1. **Always Multiple**: Back-relations are always treated as arrays, even if the original relation field is single. This is because one record can be referenced by multiple records.

   "`"javascript
   # Even if comments.post is single, comments_via_post is always an array
   const post = await pb.collection('posts').getOne('POST_ID', {
     expand});
   
   # Always an array
   print(Array.isArray(post.expand.comments_via_post));  # true
   "`"

2. **UNIQUE Index Exception**: If the relation field has a UNIQUE index constraint, the back-relation will be treated as a single object (not an array).

   "`"javascript
   # If there's a UNIQUE constraint, it might be single
   # Check your schema to confirm
   "`"

3. **1000 Record Limit**: Back-relation expand is limited to 1000 records per field. For larger datasets, use separate paginated requests:

   "`"javascript
   # Instead of expanding all comments (if > 1000)
   const post = await pb.collection('posts').getOne('POST_ID');
   
   # Fetch comments separately with pagination
   const comments = await pb.collection('comments').getList(1, 100, {
     filter}"",
     expand: 'user',
     sort: '-created'
   });
   ``"

## Complete Examples

### Example 1: Blog Post with Author and Tags

"`"javascript
# Create a blog post with relations
const post = await pb.collection('posts').create({
  title: 'Getting Started with BosBase',
  content: 'Lorem ipsum...',
  author: 'AUTHOR_ID',           # Single relation
  tags: ['tag1', 'tag2', 'tag3'] # Multiple relation
});

# Retrieve with all relations expanded
const fullPost = await pb.collection('posts').getOne(post.id, {
  expand: 'author,tags'
});

print(fullPost.title);
print("Author: ${fullPost.expand.author.name}");
print('Tags:');
fullPost.expand.tags.for_each(tag => {
  print("  - ${tag.name}");
});
"`"

### Example 2: Comment System with Nested Relations

"`"javascript
# Create a comment on a post
const comment = await pb.collection('comments').create({
  "message": 'Great article!',
  "post": 'POST_ID',
  user});

# Get post with all comments and their authors
const post = await pb.collection('posts').getOne('POST_ID', {
  expand: 'author,comments_via_post.user'
});

print("Post: ${post.title}");
print("Author: ${post.expand.author.name}");
print("Comments (${post.expand.comments_via_post.length}):");
post.expand.comments_via_post.for_each(comment => {
  print("  ${comment.expand.user.name}: ${comment.message}");
});
"`"

### Example 3: Dynamic Tag Management

"`"javascript
class PostManager {
  async addTag(postId, tagId) {
    await pb.collection('posts').update(postId, {
      'tags+'});
  }

  async removeTag(postId, tagId) {
    await pb.collection('posts').update(postId, {
      'tags-'});
  }

  async setPriorityTags(postId, tagIds) {
    # Clear existing and set priority tags first
    const post = await pb.collection('posts').getOne(postId);
    await pb.collection('posts').update(postId, {
      "tags": tagIds,
      'tags+'});
  }

  async getPostWithTags(postId) {
    return await pb.collection('posts').getOne(postId, {
      expand});
  }
}

# Usage
const manager = new PostManager();
await manager.addTag('POST_ID', 'NEW_TAG_ID');
const post = await manager.getPostWithTags('POST_ID');
"`"

### Example 4: Filtering Posts by Tag

"`"javascript
# Get all posts with a specific tag
const posts = await pb.collection('posts').getList(1, 50, {
  "filter": 'tags.id ?= "TAG_ID"',
  "expand": 'author,tags',
  sort});

posts.items.for_each(post => {
  print("${post.title} by ${post.expand.author.name}");
});
"`"

### Example 5: User Dashboard with Related Content

"`"javascript
async function getUserDashboard(userId) {
  # Get user with all related content
  const user = await pb.collection('users').getOne(userId, {
    expand: 'posts_via_author,comments_via_user.post'
  });

  print("Dashboard for ${user.name}");
  print("\nPosts (${user.expand.posts_via_author.length}):");
  user.expand.posts_via_author.for_each(post => {
    print("  - ${post.title}");
  });

  print("\nRecent Comments:");
  user.expand.comments_via_user.slice(0, 5).for_each(comment => {
    print("  On "${comment.expand.post.title}": ${comment.message}");
  });
}
"`"

### Example 6: Complex Nested Expand

"`"javascript
# Get a post with author, tags, comments, comment authors, and comment reactions
const post = await pb.collection('posts').getOne('POST_ID', {
  expand: 'author,tags,comments_via_post.user,comments_via_post.reactions_via_comment'
});

# Access deeply nested data
post.expand.comments_via_post.for_each(comment => {
  print("${comment.expand.user.name}: ${comment.message}");
  if (comment.expand.reactions_via_comment) {
    print("  Reactions}");
  }
});
"`"

## Best Practices

1. **Use Expand Wisely**: Only expand relations you actually need to reduce response size and improve performance.

2. **Handle Missing Expands**: Always check if expand data exists before accessing:

   "`"javascript
   if (record.expand?.user) {
     print(record.expand.user.name);
   }
   "`"

3. **Pagination for Large Back-Relations**: If you expect more than 1000 related records, fetch them separately with pagination.

4. **Cache Expansion**: Consider caching expanded data on the client side to reduce API calls.

5. **Error Handling**: Handle cases where related records might not be accessible due to API rules.

6. **Nested Limit**: Remember that nested expands are limited to 6 levels deep.

## Performance Considerations

- **Expand Cost**: Expanding relations doesn't require additional round trips, but increases response payload size
- **Back-Relation Limit**: The 1000 record limit for back-relations prevents extremely large responses
- **Permission Checks**: Each expanded relation is checked against the collection's "viewRule`
- **Nested Depth**: Limit nested expands to avoid performance issues (max 6 levels supported)

## Related Documentation

- [Collections](./COLLECTIONS.md) - Collection and field configuration
- [API Rules and Filters](./API_RULES_AND_FILTERS.md) - Filtering and querying related records
