# GraphQL Queries with the GDScript SDK

Use `pb.graphql.query()` to call `/api/graphql` with your current auth token. It returns `{"data": Dictionary, "errors": Array, "extensions": Dictionary}`.

> **Authentication**: The GraphQL endpoint is **superuser-only**. Authenticate as a superuser before calling GraphQL, e.g. `await pb.admins().auth_with_password(email, password)`.

## Single-table Query

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

# Authenticate as superuser
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return

var query = """
    query ActiveUsers($limit: Int!) {
        records(collection: "users", perPage: $limit, filter: "verified = true") {
            items {
                id
                email
                name
            }
        }
    }
"""

var result = await pb.graphql.query(query, {"limit": 10})

if result is ClientResponseError:
    push_error("GraphQL query failed: " + result.to_string())
    return

if result.errors and result.errors.size() > 0:
    push_error("GraphQL errors: ", result.errors)
    return

print(result.data)
```

## Multi-table Join via Expands

```gdscript
var query = """
    query PostsWithAuthors {
        records(
            collection: "posts",
            expand: ["author", "author.profile"],
            sort: "-created"
        ) {
            items {
                id
                title
                expand {
                    author {
                        id
                        name
                        email
                    }
                }
            }
        }
    }
"""

var result = await pb.graphql.query(query)

if result is ClientResponseError:
    push_error("GraphQL query failed: " + result.to_string())
    return

if not result.errors or result.errors.size() == 0:
    var posts = result.data.get("records", {}).get("items", [])
    for post in posts:
        print("Post: ", post.title)
        var author = post.get("expand", {}).get("author", {})
        print("Author: ", author.get("name", ""))
```

## Conditional Query with Variables

```gdscript
var query = """
    query FilteredOrders($minTotal: Float!, $state: String!) {
        records(
            collection: "orders",
            filter: "total >= $minTotal && status = $state",
            sort: "-created"
        ) {
            items {
                id
                total
                status
            }
        }
    }
"""

var variables = {"minTotal": 100.0, "state": "completed"}
var result = await pb.graphql.query(query, variables)

if result is ClientResponseError:
    push_error("GraphQL query failed: " + result.to_string())
    return
```

Use the `filter`, `sort`, `page`, `perPage`, and `expand` arguments to mirror REST list behavior while keeping query logic in GraphQL.

## Create a Record

```gdscript
var mutation = """
    mutation CreatePost($data: JSON!) {
        createRecord(collection: "posts", data: $data, expand: ["author"]) {
            id
            title
            created
        }
    }
"""

var data = {"title": "Hello", "author": "user_id"}
var result = await pb.graphql.query(mutation, {"data": data})

if result is ClientResponseError:
    push_error("GraphQL mutation failed: " + result.to_string())
    return
```

## Update a Record

```gdscript
var mutation = """
    mutation UpdatePost($id: ID!, $data: JSON!) {
        updateRecord(collection: "posts", id: $id, data: $data) {
            id
            title
            updated
        }
    }
"""

var result = await pb.graphql.query(mutation, {
    "id": "POST_ID",
    "data": {"title": "Updated Title"},
})

if result is ClientResponseError:
    push_error("GraphQL mutation failed: " + result.to_string())
    return
```

## Delete a Record

```gdscript
var mutation = """
    mutation DeletePost($id: ID!) {
        deleteRecord(collection: "posts", id: $id) {
            id
        }
    }
"""

var result = await pb.graphql.query(mutation, {"id": "POST_ID"})

if result is ClientResponseError:
    push_error("GraphQL mutation failed: " + result.to_string())
    return
```

## Complete Example

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

func graphql_example() -> void:
    # Authenticate as superuser
    var auth = await pb.admins().auth_with_password("admin@example.com", "password")
    if auth is ClientResponseError:
        push_error("Authentication failed: " + auth.to_string())
        return
    
    # Query with variables
    var query = """
        query GetPosts($limit: Int!) {
            records(collection: "posts", perPage: $limit, filter: "published = true") {
                items {
                    id
                    title
                    created
                }
                totalItems
            }
        }
    """
    
    var result = await pb.graphql.query(query, {"limit": 10})
    
    if result is ClientResponseError:
        push_error("GraphQL query failed: " + result.to_string())
        return
    
    if result.errors and result.errors.size() > 0:
        push_error("GraphQL errors: ", result.errors)
        return
    
    var records = result.data.get("records", {})
    print("Total items: ", records.get("totalItems", 0))
    
    for item in records.get("items", []):
        print("Post: ", item.title)
```

## Error Handling

```gdscript
var result = await pb.graphql.query(query, variables)

if result is ClientResponseError:
    match result.status:
        401:
            push_error("Authentication required (superuser only)")
        400:
            push_error("Invalid GraphQL query: ", result.data)
        _:
            push_error("GraphQL error: " + result.to_string())
    return

if result.errors and result.errors.size() > 0:
    push_error("GraphQL errors: ", result.errors)
    return

# Use result.data
print(result.data)
```

## Notes

1. **Superuser Only**: GraphQL endpoint requires superuser authentication
2. **Query Syntax**: Use standard GraphQL query syntax
3. **Variables**: Pass variables as a dictionary in the second parameter
4. **Response Format**: Always check for `errors` array in the response
5. **Error Handling**: Handle both `ClientResponseError` and GraphQL `errors`

## Related Documentation

- [Collection API](./COLLECTION_API.md) - REST collection operations
- [API Records](./API_RECORDS.md) - REST record operations
