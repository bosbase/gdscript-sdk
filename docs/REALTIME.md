# Realtime API - GDScript SDK Documentation

## Overview

The Realtime API enables real-time updates for collection records using **Server-Sent Events (SSE)**. It allows you to subscribe to changes in collections or specific records and receive instant notifications when records are created, updated, or deleted.

**Key Features:**
- Real-time notifications for record changes
- Collection-level and record-level subscriptions
- Automatic connection management and reconnection
- Authorization support
- Subscription options (expand, custom headers, query params)
- Event-driven architecture

**Backend Endpoints:**
- `GET /api/realtime` - Establish SSE connection
- `POST /api/realtime` - Set subscriptions

## How It Works

1. **Connection**: The SDK establishes an SSE connection to "/api/realtime"
2. **Client ID**: Server sends "PB_CONNECT" event with a unique "clientId"
3. **Subscriptions**: Client submits subscription topics via POST request
4. **Events**: Server sends events when matching records change
5. **Reconnection**: SDK automatically reconnects on connection loss

## Basic Usage

### Subscribe to Collection Changes

Subscribe to all changes in a collection:

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://127.0.0.1:8090")

# Subscribe to all changes in the 'posts' collection
var unsubscribe = await pb.collection("posts").subscribe("*", func(e):
    print("Action: ", e.action)  # 'create', 'update', or 'delete'
    print("Record: ", e.record)  # The record data
)

# Later, unsubscribe
await pb.collection("posts").unsubscribe("*")
```

### Subscribe to Specific Record

Subscribe to changes for a single record:

```gdscript
# Subscribe to changes for a specific post
await pb.collection("posts").subscribe("RECORD_ID", func(e):
    print("Record changed: ", e.record)
    print("Action: ", e.action)
)
```

### Multiple Subscriptions

You can subscribe multiple times to the same or different topics:

```gdscript
# Define handler functions
func handle_change(e: Dictionary) -> void:
    print("Change event: ", e)

func handle_all_changes(e: Dictionary) -> void:
    print("Collection-wide change: ", e)

# Subscribe to multiple records
var unsubscribe1 = await pb.collection("posts").subscribe("RECORD_ID_1", handle_change)
var unsubscribe2 = await pb.collection("posts").subscribe("RECORD_ID_2", handle_change)
var unsubscribe3 = await pb.collection("posts").subscribe("*", handle_all_changes)

# Unsubscribe individually
await pb.collection("posts").unsubscribe("RECORD_ID_1")
await pb.collection("posts").unsubscribe("RECORD_ID_2")
await pb.collection("posts").unsubscribe("*")
```

## Event Structure

Each event received contains:

```gdscript
{
    "action": "create",  # Action type: 'create', 'update', or 'delete'
    "record": {          # Record data
        "id": "RECORD_ID",
        "collectionId": "COLLECTION_ID",
        "collectionName": "collection_name",
        "created": "2023-01-01 00:00:00.000Z",
        "updated": "2023-01-01 00:00:00.000Z",
        # ... other fields
    }
}
```

### PB_CONNECT Event

When the connection is established, you receive a "PB_CONNECT" event:

```gdscript
await pb.realtime.subscribe("PB_CONNECT", func(e):
    print("Connected! Client ID: ", e.clientId)
    # e.clientId - unique client identifier
)
```

## Subscription Topics

### Collection-Level Subscription

Subscribe to all changes in a collection:

```gdscript
# Wildcard subscription - all records in collection
func handler(e: Dictionary) -> void:
    print("Event: ", e)

await pb.collection("posts").subscribe("*", handler)
```

**Access Control**: Uses the collection's "ListRule" to determine if the subscriber has access to receive events.

### Record-Level Subscription

Subscribe to changes for a specific record:

```gdscript
# Specific record subscription
func handler(e: Dictionary) -> void:
    print("Event: ", e)

await pb.collection("posts").subscribe("RECORD_ID", handler)
```

**Access Control**: Uses the collection's "ViewRule" to determine if the subscriber has access to receive events.

## Subscription Options

You can pass additional options when subscribing:

```gdscript
func handler(e: Dictionary) -> void:
    print("Event: ", e)

await pb.collection("posts").subscribe("*", handler, {
    # Query parameters (for API rule filtering)
    "query": {
        "filter": "status = \"published\"",
        "expand": "author",
    },
    # Custom headers
    "headers": {
        "X-Custom-Header": "value",
    },
})
```

### Expand Relations

Expand relations in the event data:

```gdscript
await pb.collection("posts").subscribe("RECORD_ID", func(e):
    print(e.record.get("expand", {}).get("author"))  # Author relation expanded
, {
    "query": {
        "expand": "author,categories",
    },
})
```

### Filter with Query Parameters

Use query parameters for API rule filtering:

```gdscript
func handler(e: Dictionary) -> void:
    print("Event: ", e)

await pb.collection("posts").subscribe("*", handler, {
    "query": {
        "filter": "status = \"published\"",
    },
})
```

## Unsubscribing

### Unsubscribe from Specific Topic

```gdscript
# Remove all subscriptions for a specific record
await pb.collection("posts").unsubscribe("RECORD_ID")

# Remove all wildcard subscriptions for the collection
await pb.collection("posts").unsubscribe("*")
```

### Unsubscribe from All

```gdscript
# Unsubscribe from all subscriptions in the collection
await pb.collection("posts").unsubscribe()

# Or unsubscribe from everything
await pb.realtime.unsubscribe()
```

## Connection Management

### Connection Status

Check if the realtime connection is established:

```gdscript
if pb.realtime.is_connected:
    print("Realtime connected")
else:
    print("Realtime disconnected")
```

### Disconnect Handler

Handle disconnection events:

```gdscript
pb.realtime.on_disconnect = func(active_subscriptions: Array):
    if active_subscriptions.size() > 0:
        print("Connection lost, but subscriptions remain: ", active_subscriptions)
        # Connection will automatically reconnect
    else:
        print("Intentionally disconnected (no active subscriptions)")
```

### Automatic Reconnection

The SDK automatically:
- Reconnects when the connection is lost
- Resubmits all active subscriptions
- Handles network interruptions gracefully
- Closes connection after 5 minutes of inactivity (server-side timeout)

## Authorization

### Authenticated Subscriptions

Subscriptions respect authentication. If you're authenticated, events are filtered based on your permissions:

```gdscript
# Authenticate first
var auth = await pb.collection("users").auth_with_password("user@example.com", "password")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return

# Now subscribe - events will respect your permissions
func handler(e: Dictionary) -> void:
    print("Event: ", e)

await pb.collection("posts").subscribe("*", handler)
```

### Authorization Rules

- **Collection-level ("*")**: Uses "ListRule" to determine access
- **Record-level**: Uses "ViewRule" to determine access
- **Superusers**: Can receive all events (if rules allow)
- **Guests**: Only receive events they have permission to see

### Auth State Changes

When authentication state changes, you may need to resubscribe:

```gdscript
# After login/logout, resubscribe to update permissions
var auth = await pb.collection("users").auth_with_password("user@example.com", "password")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return

# Re-subscribe to update auth state in realtime connection
func handler(e: Dictionary) -> void:
    print("Event: ", e)

await pb.collection("posts").subscribe("*", handler)
```

## Advanced Examples

### Example 1: Real-time Chat

```gdscript
# Subscribe to messages in a chat room
func setup_chat_room(room_id: String) -> void:
    var unsubscribe = await pb.collection("messages").subscribe("*", func(e):
        # Filter for this room only
        if e.record.get("roomId") == room_id:
            if e.action == "create":
                display_message(e.record)
            elif e.action == "delete":
                remove_message(e.record.id)
    , {
        "query": {
            "filter": "roomId = \"" + room_id + "\"",
        },
    })

# Usage
await setup_chat_room("ROOM_ID")

# Cleanup
await pb.collection("messages").unsubscribe("*")
```

### Example 2: Real-time Dashboard

```gdscript
# Subscribe to multiple collections
func setup_dashboard() -> void:
    # Posts updates
    await pb.collection("posts").subscribe("*", func(e):
        if e.action == "create":
            add_post_to_feed(e.record)
        elif e.action == "update":
            update_post_in_feed(e.record)
    , {
        "query": {
            "filter": "status = \"published\"",
            "expand": "author",
        },
    })

    # Comments updates
    await pb.collection("comments").subscribe("*", func(e):
        update_comments_count(e.record.get("postId"))
    , {
        "query": {
            "expand": "user",
        },
    })

setup_dashboard()
```

### Example 3: User Activity Tracking

```gdscript
# Track changes to a user's own records
func track_user_activity(user_id: String) -> void:
    await pb.collection("posts").subscribe("*", func(e):
        # Only track changes to user's own posts
        if e.record.get("author") == user_id:
            print("Your post " + e.action + ": ", e.record.get("title"))
            
            if e.action == "update":
                show_notification("Post updated")
    , {
        "query": {
            "filter": "author = \"" + user_id + "\"",
        },
    })

# Usage
if pb.auth_store.is_valid:
    await track_user_activity(pb.auth_store.record.id)
```

### Example 4: Real-time Collaboration

```gdscript
# Track when a document is being edited
func track_document_edits(document_id: String) -> void:
    await pb.collection("documents").subscribe(document_id, func(e):
        if e.action == "update":
            var last_editor = e.record.get("lastEditor")
            var updated_at = e.record.get("updated")
            
            # Show who last edited the document
            show_editor_indicator(last_editor, updated_at)
    , {
        "query": {
            "expand": "lastEditor",
        },
    })

await track_document_edits("DOCUMENT_ID")
```

### Example 5: Connection Monitoring

```gdscript
# Monitor connection state
pb.realtime.on_disconnect = func(active_subscriptions: Array):
    if active_subscriptions.size() > 0:
        push_warning("Connection lost, attempting to reconnect...")
        show_connection_status("Reconnecting...")

# Monitor connection establishment
await pb.realtime.subscribe("PB_CONNECT", func(e):
    print("Connected to realtime: ", e.clientId)
    show_connection_status("Connected")
)
```

### Example 6: Conditional Subscriptions

```gdscript
# Subscribe conditionally based on user state
func setup_conditional_subscriptions() -> void:
    func handler(e: Dictionary) -> void:
        print("Event: ", e)
    
    if pb.auth_store.is_valid:
        # Authenticated user - subscribe to private posts
        await pb.collection("posts").subscribe("*", handler, {
            "query": {
                "filter": "@request.auth.id != \"\"",
            },
        })
    else:
        # Guest user - subscribe only to public posts
        await pb.collection("posts").subscribe("*", handler, {
            "query": {
                "filter": "public = true",
            },
        })
```

## Error Handling

```gdscript
func handler(e: Dictionary) -> void:
    print("Event: ", e)

var result = await pb.collection("posts").subscribe("*", handler)

if result is ClientResponseError:
    if result.status == 403:
        push_error("Permission denied")
    elif result.status == 404:
        push_error("Collection not found")
    else:
        push_error("Subscription error: " + result.to_string())
```

## Best Practices

1. **Unsubscribe When Done**: Always unsubscribe when components are destroyed or subscriptions are no longer needed
2. **Handle Disconnections**: Implement "onDisconnect" handler for better UX
3. **Filter Server-Side**: Use query parameters to filter events server-side when possible
4. **Limit Subscriptions**: Don't subscribe to more collections than necessary
5. **Use Record-Level When Possible**: Prefer record-level subscriptions over collection-level when you only need specific records
6. **Monitor Connection**: Track connection state for debugging and user feedback
7. **Handle Errors**: Check for ClientResponseError after subscription
8. **Respect Permissions**: Understand that events respect API rules and permissions

## Limitations

- **Maximum Subscriptions**: Up to 1000 subscriptions per client
- **Topic Length**: Maximum 2500 characters per topic
- **Idle Timeout**: Connection closes after 5 minutes of inactivity
- **Network Dependency**: Requires stable network connection

## Troubleshooting

### Connection Not Establishing

```gdscript
# Check connection status
print("Connected: ", pb.realtime.is_connected)

# Manually trigger connection
func handler(e: Dictionary) -> void:
    print("Event: ", e)

await pb.collection("posts").subscribe("*", handler)
```

### Events Not Received

1. Check API rules - you may not have permission
2. Verify subscription is active
3. Check network connectivity
4. Review server logs for errors

### Memory Leaks

Always unsubscribe:

```gdscript
# Good - unsubscribe when done
func handler(e: Dictionary) -> void:
    print("Event: ", e)

await pb.collection("posts").subscribe("*", handler)
# ... later
await pb.collection("posts").unsubscribe("*")

# Bad - no cleanup (memory leak)
await pb.collection("posts").subscribe("*", handler)
# Never unsubscribed - memory leak!
```

## Related Documentation

- [API Records](./API_RECORDS.md) - CRUD operations
- [Collections](./COLLECTIONS.md) - Collection configuration
- [API Rules and Filters](./API_RULES_AND_FILTERS.md) - Understanding API rules
