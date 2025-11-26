# Health API - GDScript SDK Documentation

## Overview

The Health API provides a simple endpoint to check the health status of the server. It returns basic health information and, when authenticated as a superuser, provides additional diagnostic information about the server state.

**Key Features:**
- No authentication required for basic health check
- Superuser authentication provides additional diagnostic data
- Lightweight endpoint for monitoring and health checks

**Backend Endpoints:**
- `GET /api/health` - Check health status

**Note**: The health endpoint is publicly accessible, but superuser authentication provides additional information.

## Authentication

Basic health checks do not require authentication:

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://127.0.0.1:8090")

# Basic health check (no auth required)
var health = await pb.health.check()
```

For additional diagnostic information, authenticate as a superuser:

```gdscript
# Authenticate as superuser for extended health data
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return

var health = await pb.health.check()
```

## Health Check Response Structure

### Basic Response (Guest/Regular User)

```gdscript
{
    "code": 200,
    "message": "API is healthy.",
    "data": {}
}
```

### Superuser Response

```gdscript
{
    "code": 200,
    "message": "API is healthy.",
    "data": {
        "canBackup": true,           # Whether backup operations are allowed
        "realIP": "192.168.1.100",   # Real IP address of the client
        "requireS3": false,           # Whether S3 storage is required
        "possibleProxyHeader": ""     # Proxy header if behind proxy
    }
}
```

## Check Health Status

Returns the health status of the API server.

### Basic Usage

```gdscript
# Simple health check
var health = await pb.health.check()

if health is ClientResponseError:
    push_error("Health check failed: " + health.to_string())
    return

print(health.message)  # "API is healthy."
print(health.code)     # 200
```

### With Superuser Authentication

```gdscript
# Authenticate as superuser first
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return

# Get extended health information
var health = await pb.health.check()

if health is ClientResponseError:
    push_error("Health check failed: " + health.to_string())
    return

var data = health.get("data", {})
print(data.get("canBackup", false))           # true/false
print(data.get("realIP", ""))                 # "192.168.1.100"
print(data.get("requireS3", false))           # false
print(data.get("possibleProxyHeader", ""))    # "" or header name
```

## Response Fields

### Common Fields (All Users)

| Field | Type | Description |
|-------|------|-------------|
| `code` | number | HTTP status code (always 200 for healthy server) |
| `message` | string | Health status message ("API is healthy.") |
| `data` | object | Health data (empty for non-superusers, populated for superusers) |

### Superuser-Only Fields (in `data`)

| Field | Type | Description |
|-------|------|-------------|
| `canBackup` | boolean | `true` if backup/restore operations can be performed, `false` if a backup/restore is currently in progress |
| `realIP` | string | The real IP address of the client (useful when behind proxies) |
| `requireS3` | boolean | `true` if S3 storage is required (local fallback disabled), `false` otherwise |
| `possibleProxyHeader` | string | Detected proxy header name (e.g., "X-Forwarded-For", "CF-Connecting-IP") if the server appears to be behind a reverse proxy, empty string otherwise |

## Use Cases

### 1. Basic Health Monitoring

```gdscript
func check_server_health() -> bool:
    var health = await pb.health.check()
    
    if health is ClientResponseError:
        push_error("Health check error: " + health.to_string())
        return false
    
    if health.code == 200 and health.message == "API is healthy.":
        print("✓ Server is healthy")
        return true
    else:
        print("✗ Server health check failed")
        return false

# Use in monitoring (call periodically)
var is_healthy = await check_server_health()
if not is_healthy:
    push_warning("Server health check failed!")
```

### 2. Backup Readiness Check

```gdscript
func can_perform_backup() -> bool:
    # Authenticate as superuser
    var auth = await pb.admins().auth_with_password("admin@example.com", "password")
    if auth is ClientResponseError:
        push_error("Authentication failed: " + auth.to_string())
        return false
    
    var health = await pb.health.check()
    if health is ClientResponseError:
        push_error("Health check failed: " + health.to_string())
        return false
    
    var data = health.get("data", {})
    if data.get("canBackup", false) == false:
        print("⚠️ Backup operation is currently in progress")
        return false
    
    print("✓ Backup operations are allowed")
    return true

# Use before creating backups
if await can_perform_backup():
    await pb.backups.create("backup.zip")
```

### 3. Monitoring Dashboard

```gdscript
class_name HealthMonitor

var pb: BosBase
var is_superuser: bool = false

func authenticate_as_superuser(email: String, password: String) -> bool:
    var auth = await pb.admins().auth_with_password(email, password)
    if auth is ClientResponseError:
        push_error("Superuser authentication failed: " + auth.to_string())
        return false
    is_superuser = true
    return true

func get_health_status() -> Dictionary:
    var health = await pb.health.check()
    
    if health is ClientResponseError:
        return {
            "healthy": false,
            "error": health.to_string(),
            "timestamp": Time.get_datetime_string_from_system(),
        }
    
    var status = {
        "healthy": health.code == 200,
        "message": health.message,
        "timestamp": Time.get_datetime_string_from_system(),
    }
    
    if is_superuser and health.has("data"):
        var data = health.data
        status["diagnostics"] = {
            "canBackup": data.get("canBackup", null),
            "realIP": data.get("realIP", null),
            "requireS3": data.get("requireS3", null),
            "behindProxy": data.get("possibleProxyHeader", "") != "",
            "proxyHeader": data.get("possibleProxyHeader", null),
        }
    
    return status

# Usage
var monitor = HealthMonitor.new()
monitor.pb = pb
await monitor.authenticate_as_superuser("admin@example.com", "password")
var status = await monitor.get_health_status()
print("Health Status: ", status)
```

### 4. Pre-Flight Checks

```gdscript
func pre_flight_check() -> Dictionary:
    var checks = {
        "serverHealthy": false,
        "canBackup": false,
        "storageConfigured": false,
        "issues": [],
    }
    
    # Basic health check
    var health = await pb.health.check()
    if health is ClientResponseError:
        checks.issues.append("Health check error: " + health.to_string())
        return checks
    
    checks.serverHealthy = health.code == 200
    
    if not checks.serverHealthy:
        checks.issues.append("Server health check failed")
        return checks
    
    # Authenticate as superuser for extended checks
    var auth = await pb.admins().auth_with_password("admin@example.com", "password")
    if auth is ClientResponseError:
        checks.issues.append("Superuser authentication failed - limited diagnostics available")
        return checks
    
    var detailed_health = await pb.health.check()
    if detailed_health is ClientResponseError:
        checks.issues.append("Detailed health check failed")
        return checks
    
    var data = detailed_health.get("data", {})
    checks.canBackup = data.get("canBackup", false) == true
    checks.storageConfigured = not data.get("requireS3", false)
    
    if not checks.canBackup:
        checks.issues.append("Backup operations are currently unavailable")
    
    if data.get("requireS3", false):
        checks.issues.append("S3 storage is required but may not be configured")
    
    return checks

# Use before critical operations
var checks = await pre_flight_check()
if checks.issues.size() > 0:
    push_warning("Pre-flight check issues: ", checks.issues)
```

## Error Handling

```gdscript
func safe_health_check() -> Dictionary:
    var health = await pb.health.check()
    
    if health is ClientResponseError:
        # Network errors, server down, etc.
        return {
            "success": false,
            "error": health.to_string(),
            "code": health.status if health.has("status") else 0,
        }
    
    return {
        "success": true,
        "data": health,
    }

# Handle different error scenarios
var result = await safe_health_check()
if not result.success:
    if result.code == 0:
        push_error("Network error or server unreachable")
    else:
        push_error("Server returned error: ", result.code)
```

## Best Practices

1. **Monitoring**: Use health checks for regular monitoring (e.g., every 30-60 seconds)
2. **Pre-flight Checks**: Check `canBackup` before initiating backup operations
3. **Error Handling**: Always handle errors gracefully as the server may be down
4. **Rate Limiting**: Don't poll the health endpoint too frequently (avoid spamming)
5. **Caching**: Consider caching health check results for a few seconds to reduce load
6. **Logging**: Log health check results for troubleshooting and monitoring
7. **Alerting**: Set up alerts for consecutive health check failures
8. **Superuser Auth**: Only authenticate as superuser when you need diagnostic information
9. **Proxy Configuration**: Use `possibleProxyHeader` to detect and configure reverse proxy settings

## Response Codes

| Code | Meaning |
|------|---------|
| 200 | Server is healthy |
| Network Error | Server is unreachable or down |

## Limitations

- **No Detailed Metrics**: The health endpoint does not provide detailed performance metrics
- **Basic Status Only**: Returns basic status, not detailed system information
- **Superuser Required**: Extended diagnostics require superuser authentication
- **No Historical Data**: Only returns current status, no historical health data

## Related Documentation

- [Backups API](./BACKUPS_API.md) - Using `canBackup` to check backup readiness
- [Authentication](./AUTHENTICATION.md) - Superuser authentication
