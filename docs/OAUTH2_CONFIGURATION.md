# OAuth2 Configuration Guide - GDScript SDK

This guide explains how to configure OAuth2 authentication providers for auth collections using the BosBase GDScript SDK.

## Overview

OAuth2 allows users to authenticate with your application using third-party providers like Google, GitHub, Facebook, etc. Before you can use OAuth2 authentication, you need to:

1. **Create an OAuth2 app** in the provider's dashboard
2. **Obtain Client ID and Client Secret** from the provider
3. **Register a redirect URL** (typically: `https://yourdomain.com/api/oauth2-redirect`)
4. **Configure the provider** in your BosBase auth collection using the SDK

## Prerequisites

- An auth collection in your BosBase instance
- OAuth2 app credentials (Client ID and Client Secret) from your chosen provider
- Admin/superuser authentication to configure collections

## Supported Providers

The following OAuth2 providers are supported:

- **google** - Google OAuth2
- **github** - GitHub OAuth2
- **gitlab** - GitLab OAuth2
- **discord** - Discord OAuth2
- **facebook** - Facebook OAuth2
- **microsoft** - Microsoft OAuth2
- **apple** - Apple Sign In
- **twitter** - Twitter OAuth2
- **spotify** - Spotify OAuth2
- **kakao** - Kakao OAuth2
- **twitch** - Twitch OAuth2
- **strava** - Strava OAuth2
- **vk** - VK OAuth2
- **yandex** - Yandex OAuth2
- **patreon** - Patreon OAuth2
- **linkedin** - LinkedIn OAuth2
- **instagram** - Instagram OAuth2
- **vimeo** - Vimeo OAuth2
- **digitalocean** - DigitalOcean OAuth2
- **bitbucket** - Bitbucket OAuth2
- **dropbox** - Dropbox OAuth2
- **planningcenter** - Planning Center OAuth2
- **notion** - Notion OAuth2
- **linear** - Linear OAuth2
- **oidc**, **oidc2**, **oidc3** - OpenID Connect (OIDC) providers

## Basic Usage

### 1. Enable OAuth2 for a Collection

First, enable OAuth2 authentication for your auth collection:

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("https://your-instance.com")

# Authenticate as admin
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return

# Enable OAuth2 for the "users" collection
var result = await pb.collections.enable_oauth2("users")
if result is ClientResponseError:
    push_error("Failed to enable OAuth2: " + result.to_string())
    return
```

### 2. Add an OAuth2 Provider

Add a provider configuration to your collection. You'll need the URLs and credentials from your OAuth2 app:

```gdscript
# Add Google OAuth2 provider
var result = await pb.collections.add_oauth2_provider("users", {
    "name": "google",
    "clientId": "your-google-client-id",
    "clientSecret": "your-google-client-secret",
    "authURL": "https://accounts.google.com/o/oauth2/v2/auth",
    "tokenURL": "https://oauth2.googleapis.com/token",
    "userInfoURL": "https://www.googleapis.com/oauth2/v2/userinfo",
    "displayName": "Google",
    "pkce": true,  # Optional: enable PKCE for enhanced security
})

if result is ClientResponseError:
    push_error("Failed to add OAuth2 provider: " + result.to_string())
    return
```

### 3. Configure Field Mapping

Map OAuth2 provider fields to your collection fields:

```gdscript
var result = await pb.collections.set_oauth2_mapped_fields("users", {
    "name": "name",        # OAuth2 "name" → collection "name"
    "email": "email",      # OAuth2 "email" → collection "email"
    "avatarUrl": "avatar", # OAuth2 "avatarUrl" → collection "avatar"
})

if result is ClientResponseError:
    push_error("Failed to set OAuth2 mapped fields: " + result.to_string())
    return
```

### 4. Get OAuth2 Configuration

Retrieve the current OAuth2 configuration:

```gdscript
var config = await pb.collections.get_oauth2_config("users")
if config is ClientResponseError:
    push_error("Failed to get OAuth2 config: " + config.to_string())
    return

print(config.enabled)        # true/false
print(config.providers)      # Array of providers
print(config.mappedFields)   # Field mappings
```

### 5. Update a Provider

Update an existing provider's configuration:

```gdscript
var result = await pb.collections.update_oauth2_provider("users", "google", {
    "clientId": "new-client-id",
    "clientSecret": "new-client-secret",
})

if result is ClientResponseError:
    push_error("Failed to update provider: " + result.to_string())
    return
```

### 6. Remove a Provider

Remove an OAuth2 provider:

```gdscript
var result = await pb.collections.remove_oauth2_provider("users", "google")
if result is ClientResponseError:
    push_error("Failed to remove provider: " + result.to_string())
    return
```

### 7. Disable OAuth2

Disable OAuth2 authentication for a collection:

```gdscript
var result = await pb.collections.disable_oauth2("users")
if result is ClientResponseError:
    push_error("Failed to disable OAuth2: " + result.to_string())
    return
```

## Complete Example

Here's a complete example of setting up Google OAuth2:

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("https://your-instance.com")

# Authenticate as admin
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return

# 1. Enable OAuth2
var result1 = await pb.collections.enable_oauth2("users")
if result1 is ClientResponseError:
    push_error("Failed to enable OAuth2: " + result1.to_string())
    return

# 2. Add Google provider
var result2 = await pb.collections.add_oauth2_provider("users", {
    "name": "google",
    "clientId": "your-google-client-id.apps.googleusercontent.com",
    "clientSecret": "your-google-client-secret",
    "authURL": "https://accounts.google.com/o/oauth2/v2/auth",
    "tokenURL": "https://oauth2.googleapis.com/token",
    "userInfoURL": "https://www.googleapis.com/oauth2/v2/userinfo",
    "displayName": "Google",
    "pkce": true,
})

if result2 is ClientResponseError:
    push_error("Failed to add Google provider: " + result2.to_string())
    return

# 3. Configure field mappings
var result3 = await pb.collections.set_oauth2_mapped_fields("users", {
    "name": "name",
    "email": "email",
    "avatarUrl": "avatar",
})

if result3 is ClientResponseError:
    push_error("Failed to set mapped fields: " + result3.to_string())
    return

print("OAuth2 configuration completed successfully!")
```

## Provider-Specific Examples

### GitHub

```gdscript
var result = await pb.collections.add_oauth2_provider("users", {
    "name": "github",
    "clientId": "your-github-client-id",
    "clientSecret": "your-github-client-secret",
    "authURL": "https://github.com/login/oauth/authorize",
    "tokenURL": "https://github.com/login/oauth/access_token",
    "userInfoURL": "https://api.github.com/user",
    "displayName": "GitHub",
    "pkce": false,
})
```

### Discord

```gdscript
var result = await pb.collections.add_oauth2_provider("users", {
    "name": "discord",
    "clientId": "your-discord-client-id",
    "clientSecret": "your-discord-client-secret",
    "authURL": "https://discord.com/api/oauth2/authorize",
    "tokenURL": "https://discord.com/api/oauth2/token",
    "userInfoURL": "https://discord.com/api/users/@me",
    "displayName": "Discord",
    "pkce": true,
})
```

### Microsoft

```gdscript
var result = await pb.collections.add_oauth2_provider("users", {
    "name": "microsoft",
    "clientId": "your-microsoft-client-id",
    "clientSecret": "your-microsoft-client-secret",
    "authURL": "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
    "tokenURL": "https://login.microsoftonline.com/common/oauth2/v2.0/token",
    "userInfoURL": "https://graph.microsoft.com/v1.0/me",
    "displayName": "Microsoft",
    "pkce": true,
})
```

## Important Notes

1. **Redirect URL**: When creating your OAuth2 app in the provider's dashboard, you must register the redirect URL as: `https://yourdomain.com/api/oauth2-redirect`

2. **Provider Names**: The `name` field must match one of the supported provider names exactly (case-sensitive).

3. **PKCE Support**: Some providers support PKCE (Proof Key for Code Exchange) for enhanced security. Check your provider's documentation to determine if PKCE should be enabled.

4. **Client Secret Security**: Never expose your client secret in client-side code. These configuration methods should only be called from server-side code or with proper authentication.

5. **Field Mapping**: The mapped fields determine how OAuth2 user data is mapped to your collection fields. Common OAuth2 fields include:
   - `name` - User's full name
   - `email` - User's email address
   - `avatarUrl` - User's avatar/profile picture URL
   - `username` - User's username

6. **Multiple Providers**: You can add multiple OAuth2 providers to the same collection. Users can choose which provider to use during authentication.

## Error Handling

All methods can return `ClientResponseError` if something goes wrong:

```gdscript
var result = await pb.collections.add_oauth2_provider("users", provider_config)

if result is ClientResponseError:
    match result.status:
        400:
            push_error("Invalid provider configuration: ", result.data)
        403:
            push_error("Permission denied. Make sure you are authenticated as admin.")
        _:
            push_error("Unexpected error: " + result.to_string())
    return
```

## API Reference

### `enable_oauth2(collection_id_or_name: String, options: Dictionary = {})`

Enables OAuth2 authentication for an auth collection.

**Parameters:**
- `collection_id_or_name` (string) - Collection id or name
- `options` (Dictionary, optional) - Request options

**Returns:** `Dictionary` or `ClientResponseError`

---

### `disable_oauth2(collection_id_or_name: String, options: Dictionary = {})`

Disables OAuth2 authentication for an auth collection.

**Parameters:**
- `collection_id_or_name` (string) - Collection id or name
- `options` (Dictionary, optional) - Request options

**Returns:** `Dictionary` or `ClientResponseError`

---

### `get_oauth2_config(collection_id_or_name: String, options: Dictionary = {})`

Gets the OAuth2 configuration for an auth collection.

**Parameters:**
- `collection_id_or_name` (string) - Collection id or name
- `options` (Dictionary, optional) - Request options

**Returns:** `Dictionary` with `{"enabled": bool, "mappedFields": Dictionary, "providers": Array}` or `ClientResponseError`

---

### `set_oauth2_mapped_fields(collection_id_or_name: String, mapped_fields: Dictionary, options: Dictionary = {})`

Sets the OAuth2 mapped fields for an auth collection.

**Parameters:**
- `collection_id_or_name` (string) - Collection id or name
- `mapped_fields` (Dictionary) - Object mapping OAuth2 fields to collection fields
- `options` (Dictionary, optional) - Request options

**Returns:** `Dictionary` or `ClientResponseError`

---

### `add_oauth2_provider(collection_id_or_name: String, provider: Dictionary, options: Dictionary = {})`

Adds a new OAuth2 provider to an auth collection.

**Parameters:**
- `collection_id_or_name` (string) - Collection id or name
- `provider` (Dictionary) - OAuth2 provider configuration:
  - `name` (string, required) - Provider name
  - `clientId` (string, required) - OAuth2 client ID
  - `clientSecret` (string, required) - OAuth2 client secret
  - `authURL` (string, required) - Authorization URL
  - `tokenURL` (string, required) - Token exchange URL
  - `userInfoURL` (string, required) - User info API URL
  - `displayName` (string, optional) - Display name for the provider
  - `pkce` (bool, optional) - Enable PKCE
  - `extra` (Dictionary, optional) - Additional provider-specific configuration
- `options` (Dictionary, optional) - Request options

**Returns:** `Dictionary` or `ClientResponseError`

---

### `update_oauth2_provider(collection_id_or_name: String, provider_name: String, updates: Dictionary, options: Dictionary = {})`

Updates an existing OAuth2 provider in an auth collection.

**Parameters:**
- `collection_id_or_name` (string) - Collection id or name
- `provider_name` (string) - Name of the provider to update
- `updates` (Dictionary) - Partial provider configuration to update
- `options` (Dictionary, optional) - Request options

**Returns:** `Dictionary` or `ClientResponseError`

---

### `remove_oauth2_provider(collection_id_or_name: String, provider_name: String, options: Dictionary = {})`

Removes an OAuth2 provider from an auth collection.

**Parameters:**
- `collection_id_or_name` (string) - Collection id or name
- `provider_name` (string) - Name of the provider to remove
- `options` (Dictionary, optional) - Request options

**Returns:** `Dictionary` or `ClientResponseError`

---

## Next Steps

After configuring OAuth2 providers, users can authenticate using the `auth_with_oauth2()` method. See the [Authentication Guide](./AUTHENTICATION.md) for details on using OAuth2 authentication in your application.
