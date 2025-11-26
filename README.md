BosBase GDScript SDK
====================

An asynchronous Godot 4.x client that mirrors the BosBase JS SDK surface. The API is close to the JS version but uses plain GDScript classes and `await`-based methods.

Quick start
-----------

1. Copy `gdscript-sdk/src` into your project (eg. under `res://gdscript-sdk/`).
2. Instantiate the client and call the same services you know from the JS SDK:

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

func _ready() -> void:
    var pb = BosBase.new("http://127.0.0.1:8090")
    var auth = await pb.collection("_superusers").auth_with_password("admin@example.com", "password")
    if auth is ClientResponseError:
        push_error(auth.to_string())
        return

    var list = await pb.collection("articles").get_list()
    print(list)
```

Key points
----------
- Services: collections, records, files, realtime (SSE), pubsub (websocket), settings, backups, crons, vectors, LLM documents, LangChaingo, cache, GraphQL, batch API and health/log helpers.
- Auth store: in-memory with optional disk persistence (`AuthStore` stores `token` and `model`).
- Errors: methods return a `ClientResponseError` instance when something goes wrong. Check `result is ClientResponseError` before using the payload.
- Files: pass `files` as a `Dictionary` or `Array` of `{name, filename, content_type, data}`; the body is sent as multipart with `@jsonPayload`.
- Realtime & pubsub: run on the main thread and reconnect when possible; callbacks are invoked on the main thread.

Notes
-----
- All network methods are `await`-able. They rely on `HTTPRequest`, `HTTPClient`, and `WebSocketPeer`, so the Godot main loop must be running.
- The SDK paths assume the folder lives at `res://gdscript-sdk/`; adjust the `preload()` paths in `bosbase.gd` if you place it elsewhere.
