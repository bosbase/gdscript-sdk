# Custom Token Binding and Login - GDScript SDK

The GDScript SDK and BosBase service support binding a custom token to an auth record (both `users` and `_superusers`) and signing in with that token. The server stores bindings in the `_token_bindings` table (created automatically on first bind; legacy `_tokenBindings`/`tokenBindings` are auto-renamed). Tokens are stored as hashes so raw values aren't persisted.

## API Endpoints

- `POST /api/collections/{collection}/bind-token`
- `POST /api/collections/{collection}/unbind-token`
- `POST /api/collections/{collection}/auth-with-token`

## Binding a Token

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://127.0.0.1:8090")

# Bind for a regular user
var result = await pb.collection("users").bind_custom_token(
    "user@example.com",
    "user-password",
    "my-app-token",
)

if result is ClientResponseError:
    push_error("Failed to bind token: " + result.to_string())
    return

print("Token bound successfully")

# Bind for a superuser
var result2 = await pb.collection("_superusers").bind_custom_token(
    "admin@example.com",
    "admin-password",
    "admin-app-token",
)

if result2 is ClientResponseError:
    push_error("Failed to bind superuser token: " + result2.to_string())
    return
```

## Unbinding a Token

```gdscript
# Stop accepting the token for the user
var result = await pb.collection("users").unbind_custom_token(
    "user@example.com",
    "user-password",
    "my-app-token",
)

if result is ClientResponseError:
    push_error("Failed to unbind token: " + result.to_string())
    return

# Stop accepting the token for a superuser
var result2 = await pb.collection("_superusers").unbind_custom_token(
    "admin@example.com",
    "admin-password",
    "admin-app-token",
)

if result2 is ClientResponseError:
    push_error("Failed to unbind superuser token: " + result2.to_string())
    return
```

## Logging in with a Token

```gdscript
# Login with the previously bound token
var auth = await pb.collection("users").auth_with_token("my-app-token")

if auth is ClientResponseError:
    push_error("Token authentication failed: " + auth.to_string())
    return

print(auth.token)  # BosBase auth token
print(auth.record) # authenticated record

# Superuser token login
var super_auth = await pb.collection("_superusers").auth_with_token("admin-app-token")

if super_auth is ClientResponseError:
    push_error("Superuser token authentication failed: " + super_auth.to_string())
    return

print(super_auth.token)
print(super_auth.record)
```

## Complete Example

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://127.0.0.1:8090")

func setup_custom_token_auth() -> void:
    # Step 1: Bind a custom token to a user
    var bind_result = await pb.collection("users").bind_custom_token(
        "user@example.com",
        "password123",
        "my-custom-token-12345",
    )
    
    if bind_result is ClientResponseError:
        push_error("Failed to bind token: " + bind_result.to_string())
        return
    
    print("Token bound successfully")
    
    # Step 2: Later, authenticate using the custom token
    var auth = await pb.collection("users").auth_with_token("my-custom-token-12345")
    
    if auth is ClientResponseError:
        push_error("Token authentication failed: " + auth.to_string())
        return
    
    print("Authenticated as: ", auth.record.email)
    print("Auth token: ", auth.token)
    
    # Step 3: When done, unbind the token
    var unbind_result = await pb.collection("users").unbind_custom_token(
        "user@example.com",
        "password123",
        "my-custom-token-12345",
    )
    
    if unbind_result is ClientResponseError:
        push_error("Failed to unbind token: " + unbind_result.to_string())
        return
    
    print("Token unbound successfully")
```

## Error Handling

```gdscript
func safe_bind_token(collection: String, email: String, password: String, token: String) -> bool:
    var result = await pb.collection(collection).bind_custom_token(email, password, token)
    
    if result is ClientResponseError:
        match result.status:
            400:
                push_error("Invalid request - check email, password, or token format")
            401:
                push_error("Authentication failed - invalid email or password")
            404:
                push_error("User not found")
            _:
                push_error("Failed to bind token: " + result.to_string())
        return false
    
    return true

func safe_auth_with_token(collection: String, token: String) -> Dictionary:
    var auth = await pb.collection(collection).auth_with_token(token)
    
    if auth is ClientResponseError:
        match auth.status:
            401:
                push_error("Token authentication failed - token not bound or invalid")
            404:
                push_error("Token binding not found")
            _:
                push_error("Authentication error: " + auth.to_string())
        return {}
    
    return auth
```

## Notes

- **Binding Requirements**: Binding and unbinding require a valid email and password for the target account.
- **Token Reuse**: The same token value can be used for either `users` or `_superusers` collections; the collection is enforced during login.
- **MFA Support**: MFA and existing auth rules still apply when authenticating with a token.
- **Security**: Tokens are stored as hashes, so raw token values are never persisted in the database.
- **Multiple Tokens**: A single user can have multiple custom tokens bound.

## Best Practices

1. **Secure Token Generation**: Generate secure, random tokens for binding
2. **Token Rotation**: Regularly rotate custom tokens for security
3. **Error Handling**: Always handle errors when binding/unbinding tokens
4. **Token Cleanup**: Unbind tokens when they're no longer needed
5. **Logging**: Log token binding/unbinding operations for audit purposes

## Related Documentation

- [Authentication](./AUTHENTICATION.md) - Standard authentication methods
