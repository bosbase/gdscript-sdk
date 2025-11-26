# Pub/Sub API - GDScript SDK

BosBase exposes a lightweight WebSocket-based publish/subscribe channel so SDK users can push and receive custom messages. The Go backend uses the `ws` transport and persists each published payload in the `_pubsub_messages` table so every node in a cluster can replay and fan-out messages to its local subscribers.

- **Endpoint**: `/api/pubsub` (WebSocket)
- **Auth**: The SDK automatically forwards `authStore.token` as a `token` query parameter; cookie-based auth also works. Anonymous clients may subscribe, but publishing requires an authenticated token.
- **Reliability**: Automatic reconnect with topic re-subscription; messages are stored in the database and broadcasted to all connected nodes.

## Quick Start

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://127.0.0.1:8090")

# Subscribe to a topic
var unsubscribe_func = await pb.pubsub.subscribe("chat/general", func(msg: Dictionary):
    print("Message from topic ", msg.topic, ": ", msg.data)
)

# Publish to a topic (resolves when the server stores and accepts it)
var ack = await pb.pubsub.publish("chat/general", {"text": "Hello, world!"})
if ack is ClientResponseError:
    push_error("Failed to publish: " + ack.to_string())
    return

print("Published at: ", ack.created)

# Later, stop listening
if unsubscribe_func:
    await unsubscribe_func()
```

## API Surface

- `pb.pubsub.publish(topic: String, data: Dictionary)` → Returns `Dictionary` with `{"id": String, "topic": String, "created": String}` or `ClientResponseError`
- `pb.pubsub.subscribe(topic: String, handler: Callable)` → Returns `Callable` (unsubscribe function) or `ClientResponseError`
- `pb.pubsub.unsubscribe(topic: String = "")` → Returns void or `ClientResponseError` (omit `topic` to drop all topics)
- `pb.pubsub.disconnect()` - Explicitly close the socket and clear pending requests
- `pb.pubsub.is_connected` - Property that exposes the current WebSocket state (bool)

## Complete Examples

### Basic Publish/Subscribe

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://127.0.0.1:8090")

func setup_chat() -> void:
    # Subscribe to chat messages
    var unsubscribe = await pb.pubsub.subscribe("chat/general", _on_chat_message)
    
    if unsubscribe is ClientResponseError:
        push_error("Failed to subscribe: " + unsubscribe.to_string())
        return
    
    # Store unsubscribe function for later
    unsubscribe_func = unsubscribe

func _on_chat_message(msg: Dictionary) -> void:
    var topic = msg.get("topic", "")
    var data = msg.get("data", {})
    print("Received message on ", topic, ": ", data)

func send_chat_message(text: String) -> void:
    var ack = await pb.pubsub.publish("chat/general", {
        "text": text,
        "timestamp": Time.get_unix_time_from_system()
    })
    
    if ack is ClientResponseError:
        push_error("Failed to publish message: " + ack.to_string())
        return
    
    print("Message published successfully at: ", ack.created)
```

### Multiple Topics

```gdscript
func subscribe_to_multiple_topics() -> void:
    # Subscribe to different topics
    var unsubscribe_notifications = await pb.pubsub.subscribe("notifications", _on_notification)
    var unsubscribe_updates = await pb.pubsub.subscribe("system/updates", _on_system_update)
    
    # Store unsubscribe functions
    unsubscribe_funcs = [unsubscribe_notifications, unsubscribe_updates]

func _on_notification(msg: Dictionary) -> void:
    var data = msg.get("data", {})
    print("Notification: ", data.get("message", ""))

func _on_system_update(msg: Dictionary) -> void:
    var data = msg.get("data", {})
    print("System update: ", data.get("version", ""))

func cleanup() -> void:
    # Unsubscribe from specific topic
    await pb.pubsub.unsubscribe("notifications")
    
    # Or unsubscribe from all topics
    await pb.pubsub.unsubscribe()
```

### Real-time Chat Example

```gdscript
class_name ChatClient

var pb: BosBase
var unsubscribe_func: Callable
var is_connected: bool = false

func _init(base_url: String) -> void:
    var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")
    pb = BosBase.new(base_url)

func connect_to_chat(room_name: String) -> void:
    # Authenticate if needed
    if not pb.auth_store.is_valid:
        var auth = await pb.collection("users").auth_with_password("user@example.com", "password")
        if auth is ClientResponseError:
            push_error("Authentication failed: " + auth.to_string())
            return
    
    # Subscribe to chat room
    var unsubscribe = await pb.pubsub.subscribe("chat/" + room_name, _on_chat_message)
    
    if unsubscribe is ClientResponseError:
        push_error("Failed to connect to chat: " + unsubscribe.to_string())
        return
    
    unsubscribe_func = unsubscribe
    is_connected = pb.pubsub.is_connected
    
    print("Connected to chat room: ", room_name)

func send_message(room_name: String, message: String) -> void:
    if not is_connected:
        push_error("Not connected to chat")
        return
    
    var ack = await pb.pubsub.publish("chat/" + room_name, {
        "user": pb.auth_store.record.get("name", "Anonymous"),
        "message": message,
        "timestamp": Time.get_unix_time_from_system()
    })
    
    if ack is ClientResponseError:
        push_error("Failed to send message: " + ack.to_string())
        return
    
    print("Message sent: ", ack.id)

func _on_chat_message(msg: Dictionary) -> void:
    var topic = msg.get("topic", "")
    var data = msg.get("data", {})
    
    print("[%s] %s: %s" % [
        data.get("user", "Unknown"),
        Time.get_datetime_string_from_unix_time(data.get("timestamp", 0)),
        data.get("message", "")
    ])
    
    # Emit signal or call callback
    message_received.emit(topic, data)

signal message_received(topic: String, data: Dictionary)

func disconnect_from_chat() -> void:
    if unsubscribe_func and unsubscribe_func.is_valid():
        await unsubscribe_func()
    
    pb.pubsub.disconnect()
    is_connected = false
    print("Disconnected from chat")
```

### Notification System

```gdscript
func setup_notification_system() -> void:
    # Authenticate
    var auth = await pb.collection("users").auth_with_password("user@example.com", "password")
    if auth is ClientResponseError:
        push_error("Authentication failed: " + auth.to_string())
        return
    
    # Subscribe to user-specific notifications
    var user_id = pb.auth_store.record.id
    var unsubscribe = await pb.pubsub.subscribe("notifications/" + user_id, _on_notification)
    
    if unsubscribe is ClientResponseError:
        push_error("Failed to subscribe: " + unsubscribe.to_string())
        return
    
    print("Notification system ready")

func _on_notification(msg: Dictionary) -> void:
    var data = msg.get("data", {})
    var notification_type = data.get("type", "")
    var message = data.get("message", "")
    
    match notification_type:
        "alert":
            push_warning("ALERT: ", message)
        "info":
            print("INFO: ", message)
        "error":
            push_error("ERROR: ", message)
        _:
            print("Notification: ", message)

func send_notification(user_id: String, notification_type: String, message: String) -> void:
    var ack = await pb.pubsub.publish("notifications/" + user_id, {
        "type": notification_type,
        "message": message,
        "created": Time.get_datetime_string_from_system()
    })
    
    if ack is ClientResponseError:
        push_error("Failed to send notification: " + ack.to_string())
        return
    
    print("Notification sent: ", ack.id)
```

## Error Handling

```gdscript
func safe_subscribe(topic: String, handler: Callable) -> Callable:
    var unsubscribe = await pb.pubsub.subscribe(topic, handler)
    
    if unsubscribe is ClientResponseError:
        match unsubscribe.status:
            401:
                push_error("Authentication required to subscribe")
            403:
                push_error("Permission denied")
            _:
                push_error("Failed to subscribe: " + unsubscribe.to_string())
        return Callable()
    
    return unsubscribe

func safe_publish(topic: String, data: Dictionary) -> bool:
    var ack = await pb.pubsub.publish(topic, data)
    
    if ack is ClientResponseError:
        match ack.status:
            401:
                push_error("Authentication required to publish")
            403:
                push_error("Permission denied to publish")
            400:
                push_error("Invalid topic or data: " + ack.to_string())
            _:
                push_error("Failed to publish: " + ack.to_string())
        return false
    
    return true
```

## Connection Management

```gdscript
func check_connection_status() -> void:
    if pb.pubsub.is_connected:
        print("WebSocket is connected")
    else:
        print("WebSocket is disconnected")
        # Attempt to reconnect by subscribing again
        var unsubscribe = await pb.pubsub.subscribe("my/topic", _on_message)

func cleanup() -> void:
    # Unsubscribe from all topics
    await pb.pubsub.unsubscribe()
    
    # Explicitly disconnect
    pb.pubsub.disconnect()
    
    print("Pub/Sub connection closed")
```

## Message Format

Messages published and received follow this format:

```gdscript
{
    "id": String,           # Unique message ID
    "topic": String,        # Topic name (e.g., "chat/general")
    "data": Dictionary,     # Your custom message data
    "created": String       # ISO 8601 timestamp
}
```

## Best Practices

1. **Authentication**: Publish operations require authentication; subscribe can work anonymously
2. **Error Handling**: Always check for `ClientResponseError` after pub/sub operations
3. **Connection Status**: Check `pb.pubsub.is_connected` before publishing
4. **Cleanup**: Always unsubscribe and disconnect when done to free resources
5. **Reconnection**: The SDK handles automatic reconnection, but you may need to re-subscribe to topics
6. **Topic Naming**: Use hierarchical topic names (e.g., `chat/room1`, `notifications/user123`)
7. **Message Size**: Keep message payloads reasonable in size
8. **Error Recovery**: Implement retry logic for critical messages

## Notes for Clusters

- Messages are written to `_pubsub_messages` with a timestamp; every running node polls the table and pushes new rows to its connected WebSocket clients.
- Old pub/sub rows are cleaned up automatically after a day to keep the table small.
- If a node restarts, it resumes from the latest message and replays new rows as they are inserted, so connected clients on other nodes stay in sync.

## Limitations

- **WebSocket Only**: Pub/Sub requires WebSocket connections (not HTTP polling)
- **Authentication**: Publishing requires authentication; subscribing can be anonymous
- **Topic Limits**: Be mindful of the number of topics and subscribers per connection
- **Message Persistence**: Messages are stored in the database for reliability but cleaned up after a day
- **Network Issues**: Automatic reconnection handles temporary network issues

## Related Documentation

- [Realtime API](./REALTIME.md) - Real-time collection updates
- [Authentication](./AUTHENTICATION.md) - User authentication
