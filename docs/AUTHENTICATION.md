# Authentication - GDScript SDK Documentation

## Overview

Authentication in BosBase is stateless and token-based. A client is considered authenticated as long as it sends a valid `Authorization: YOUR_AUTH_TOKEN` header with requests.

**Key Points:**
- **No sessions**: BosBase APIs are fully stateless (tokens are not stored in the database)
- **No logout endpoint**: To "logout", simply clear the token from your local state (`pb.auth_store.clear()`)
- **Token generation**: Auth tokens are generated through auth collection Web APIs or programmatically
- **Admin users**: "_superusers" collection works like regular auth collections but with full access (API rules are ignored)
- **OAuth2 limitation**: OAuth2 is not supported for "_superusers" collection

## Authentication Methods

BosBase supports multiple authentication methods that can be configured individually for each auth collection:

1. **Password Authentication** - Email/username + password
2. **OTP Authentication** - One-time password via email
3. **OAuth2 Authentication** - Google, GitHub, Microsoft, etc.
4. **Multi-factor Authentication (MFA)** - Requires 2 different auth methods

## Authentication Store

The SDK maintains an `auth_store` that automatically manages the authentication state:

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

# Check authentication status
print(pb.auth_store.is_valid)      # true/false
print(pb.auth_store.token)         # current auth token
print(pb.auth_store.record)        # authenticated user record
print(pb.auth_store.model)         # same as record (legacy)

# Clear authentication (logout)
pb.auth_store.clear()
```

## Password Authentication

Authenticate using email/username and password. The identity field can be configured in the collection options (default is email).

**Backend Endpoint:** `POST /api/collections/{collection}/auth-with-password`

### Basic Usage

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

# Authenticate with email and password
var auth_data = await pb.collection("users").auth_with_password(
    "test@example.com",
    "password123"
)

# Check for errors
if auth_data is ClientResponseError:
    push_error("Authentication failed: " + auth_data.to_string())
    return

# Auth data is automatically stored in pb.auth_store
print(pb.auth_store.is_valid)  # true
print(pb.auth_store.token)     # JWT token
print(pb.auth_store.record.id) # user record ID
```

### Response Format

```gdscript
{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "record": {
    "id": "record_id",
    "email": "test@example.com",
    # ... other user fields
  }
}
```

### Error Handling with MFA

```gdscript
var auth_result = await pb.collection("users").auth_with_password("test@example.com", "pass123")

if auth_result is ClientResponseError:
    # Check for MFA requirement
    var response_data = auth_result.data
    if response_data.has("mfaId"):
        var mfa_id = response_data["mfaId"]
        # Handle MFA flow (see Multi-factor Authentication section)
        await handle_mfa("test@example.com", mfa_id)
    else:
        push_error("Authentication failed: " + auth_result.to_string())
```

## OTP Authentication

One-time password authentication via email.

**Backend Endpoints:**
- `POST /api/collections/{collection}/request-otp` - Request OTP
- `POST /api/collections/{collection}/auth-with-otp` - Authenticate with OTP

### Request OTP

```gdscript
# Send OTP to user's email
var result = await pb.collection("users").request_otp("test@example.com")

if result is ClientResponseError:
    push_error("Failed to request OTP: " + result.to_string())
    return

print(result.otpId)  # OTP ID to use in auth_with_otp
```

### Authenticate with OTP

```gdscript
# Step 1: Request OTP
var result = await pb.collection("users").request_otp("test@example.com")
if result is ClientResponseError:
    push_error("Failed to request OTP: " + result.to_string())
    return

# Step 2: User enters OTP from email
var otp_code = "123456"  # Get from user input

var auth_data = await pb.collection("users").auth_with_otp(
    result.otpId,
    otp_code
)

if auth_data is ClientResponseError:
    push_error("OTP authentication failed: " + auth_data.to_string())
else:
    print("Successfully authenticated with OTP")
```

## OAuth2 Authentication

**Backend Endpoint:** `POST /api/collections/{collection}/auth-with-oauth2`

### Manual Code Exchange

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("https://bosbase.io")

# Get auth methods
var auth_methods = await pb.collection("users").list_auth_methods()
if auth_methods is ClientResponseError:
    push_error("Failed to get auth methods: " + auth_methods.to_string())
    return

# Find provider (e.g., google)
var providers = auth_methods.get("oauth2", {}).get("providers", [])
var provider = null
for p in providers:
    if p.get("name") == "google":
        provider = p
        break

if provider == null:
    push_error("Google OAuth2 provider not found")
    return

# Exchange code for token (after OAuth2 redirect)
var auth_data = await pb.collection("users").auth_with_oauth2_code(
    provider.name,
    code,  # OAuth2 code from redirect
    provider.codeVerifier,
    redirect_url
)

if auth_data is ClientResponseError:
    push_error("OAuth2 authentication failed: " + auth_data.to_string())
else:
    print("OAuth2 authentication successful")
```

## Multi-Factor Authentication (MFA)

Requires 2 different auth methods.

```gdscript
var mfa_id: String = ""

# First auth method (password)
var auth_result = await pb.collection("users").auth_with_password("test@example.com", "pass123")

if auth_result is ClientResponseError:
    var response_data = auth_result.data
    if response_data.has("mfaId"):
        mfa_id = response_data["mfaId"]
        
        # Second auth method (OTP)
        var otp_result = await pb.collection("users").request_otp("test@example.com")
        if otp_result is ClientResponseError:
            push_error("Failed to request OTP: " + otp_result.to_string())
            return
        
        var otp_code = "123456"  # Get from user
        
        var mfa_auth = await pb.collection("users").auth_with_otp(
            otp_result.otpId,
            otp_code,
            {},
            {},
            {},
            {},
            mfa_id  # Pass MFA ID
        )
        
        if mfa_auth is ClientResponseError:
            push_error("MFA authentication failed: " + mfa_auth.to_string())
        else:
            print("MFA authentication successful")
```

## User Impersonation

Superusers can impersonate other users.

**Backend Endpoint:** `POST /api/collections/{collection}/impersonate/{id}`

```gdscript
# Authenticate as superuser
var admin_auth = await pb.admins().auth_with_password("admin@example.com", "adminpass")
if admin_auth is ClientResponseError:
    push_error("Admin authentication failed: " + admin_auth.to_string())
    return

# Impersonate a user
var impersonate_client = await pb.collection("users").impersonate(
    "USER_RECORD_ID",
    3600  # Optional: token duration in seconds
)

if impersonate_client is ClientResponseError:
    push_error("Impersonation failed: " + impersonate_client.to_string())
    return

# Use impersonate client (returns a new BosBase client instance)
var data = await impersonate_client.collection("posts").get_full_list()
```

## Auth Token Verification

Verify token by calling `auth_refresh()`.

**Backend Endpoint:** `POST /api/collections/{collection}/auth-refresh`

```gdscript
var refresh_result = await pb.collection("users").auth_refresh()

if refresh_result is ClientResponseError:
    push_error("Token verification failed: " + refresh_result.to_string())
    pb.auth_store.clear()
else:
    print("Token is valid")
```

## List Available Auth Methods

**Backend Endpoint:** `GET /api/collections/{collection}/auth-methods`

```gdscript
var auth_methods = await pb.collection("users").list_auth_methods()

if auth_methods is ClientResponseError:
    push_error("Failed to get auth methods: " + auth_methods.to_string())
    return

print(auth_methods.password.enabled)
print(auth_methods.oauth2.providers)
print(auth_methods.mfa.enabled)
```

## Complete Examples

See the full documentation for detailed examples of:
- Full authentication flow
- OAuth2 integration
- Token management
- Admin impersonation
- Error handling

## Related Documentation

- [Collections](./COLLECTIONS.md)
- [API Rules](./API_RULES_AND_FILTERS.md)

## Detailed Examples

### Example 1: Complete Authentication Flow with Error Handling

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

func authenticate_user(email: String, password: String) -> Dictionary:
    # Try password authentication
    var auth_result = await pb.collection("users").auth_with_password(email, password)
    
    if auth_result is ClientResponseError:
        # Check if MFA is required
        var response_data = auth_result.data
        if auth_result.status == 401 and response_data.has("mfaId"):
            print("MFA required, proceeding with second factor...")
            return await handle_mfa(email, response_data["mfaId"])
        
        # Handle other errors
        if auth_result.status == 400:
            push_error("Invalid credentials")
            return {}
        elif auth_result.status == 403:
            push_error("Password authentication is not enabled for this collection")
            return {}
        else:
            push_error("Authentication failed: " + auth_result.to_string())
            return {}
    
    print("Successfully authenticated: ", auth_result.record.email)
    return auth_result

func handle_mfa(email: String, mfa_id: String) -> Dictionary:
    # Request OTP for second factor
    var otp_result = await pb.collection("users").request_otp(email)
    if otp_result is ClientResponseError:
        push_error("Failed to request OTP: " + otp_result.to_string())
        return {}
    
    # In a real app, show a modal/form for the user to enter OTP
    # For this example, we'll simulate getting the OTP
    var user_entered_otp = await get_user_otp_input()  # Your UI function
    
    # Authenticate with OTP and MFA ID
    var mfa_auth = await pb.collection("users").auth_with_otp(
        otp_result.otpId,
        user_entered_otp,
        {},
        {},
        {},
        {},
        mfa_id  # Pass MFA ID
    )
    
    if mfa_auth is ClientResponseError:
        if mfa_auth.status == 429:
            push_error("Too many OTP attempts, please request a new OTP")
        else:
            push_error("Invalid OTP code")
        return {}
    
    print("MFA authentication successful")
    return mfa_auth

# Usage
var result = await authenticate_user("user@example.com", "password123")
if not result.is_empty():
    print("User is authenticated: ", pb.auth_store.record)
```

### Example 2: Token Management and Refresh

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

func check_auth() -> bool:
    if pb.auth_store.is_valid:
        print("User is authenticated: ", pb.auth_store.record.email)
        
        # Verify token is still valid and refresh if needed
        var refresh_result = await pb.collection("users").auth_refresh()
        if refresh_result is ClientResponseError:
            print("Token expired or invalid, clearing auth")
            pb.auth_store.clear()
            return false
        
        print("Token refreshed successfully")
        return true
    return false

# Usage
var is_authenticated = await check_auth()
if not is_authenticated:
    # Redirect to login
    print("User not authenticated, redirecting to login...")
```

### Example 3: Admin Impersonation for Support

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

func impersonate_user_for_support(user_id: String) -> Dictionary:
    # Authenticate as admin
    var admin_auth = await pb.admins().auth_with_password("admin@example.com", "adminpassword")
    if admin_auth is ClientResponseError:
        push_error("Admin authentication failed: " + admin_auth.to_string())
        return {}
    
    # Impersonate the user (1 hour token)
    var user_client = await pb.collection("users").impersonate(user_id, 3600)
    
    if user_client is ClientResponseError:
        push_error("Impersonation failed: " + user_client.to_string())
        return {}
    
    print("Impersonating user: ", user_client.auth_store.record.email)
    
    # Use the impersonated client to test user experience
    var user_records = await user_client.collection("posts").get_full_list()
    if user_records is ClientResponseError:
        push_error("Failed to get user records: " + user_records.to_string())
        return {}
    
    print("User can see ", user_records.size(), " posts")
    
    # Check what the user sees
    var user_view = await user_client.collection("posts").get_list(1, 10, {
        "filter": "published = true"
    })
    
    if user_view is ClientResponseError:
        push_error("Failed to get user view: " + user_view.to_string())
        return {}
    
    return {
        "canAccess": user_view.items.size(),
        "totalPosts": user_records.size()
    }

# Usage in support dashboard
var result = await impersonate_user_for_support("user_record_id")
if not result.is_empty():
    print("User access check: ", result)
```

## Best Practices

1. **Secure Token Storage**: Never expose tokens in client-side code or logs
2. **Token Refresh**: Implement automatic token refresh before expiration
3. **Error Handling**: Always handle MFA requirements and token expiration
4. **OAuth2 Security**: Always validate the "state" parameter in OAuth2 callbacks
5. **API Keys**: Use impersonation tokens for server-to-server communication only
6. **Superuser Tokens**: Never expose superuser impersonation tokens in client code
7. **OTP Security**: Use OTP with MFA for security-critical applications
8. **Rate Limiting**: Be aware of rate limits on authentication endpoints

## Troubleshooting

### Token Expired

If you get 401 errors, check if the token has expired:

```gdscript
var refresh_result = await pb.collection("users").auth_refresh()

if refresh_result is ClientResponseError:
    # Token expired, require re-authentication
    pb.auth_store.clear()
    # Redirect to login
```

### MFA Required

If authentication returns 401 with mfaId:

```gdscript
if auth_result is ClientResponseError and auth_result.status == 401:
    var response_data = auth_result.data
    if response_data.has("mfaId"):
        # Proceed with second authentication factor
        await handle_mfa(email, response_data["mfaId"])
```
