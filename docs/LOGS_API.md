# Logs API - GDScript SDK Documentation

## Overview

The Logs API provides endpoints for viewing and analyzing application logs. All operations require superuser authentication and allow you to query request logs, filter by various criteria, and get aggregated statistics.

**Key Features:**
- List and paginate logs
- View individual log entries
- Filter logs by status, URL, method, IP, etc.
- Sort logs by various fields
- Get hourly aggregated statistics
- Filter statistics by criteria

**Backend Endpoints:**
- `GET /api/logs` - List logs
- `GET /api/logs/{id}` - View log
- `GET /api/logs/stats` - Get statistics

**Note**: All Logs API operations require superuser authentication.

## Authentication

All Logs API operations require superuser authentication:

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://127.0.0.1:8090")

# Authenticate as superuser
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return
```

## List Logs

Returns a paginated list of logs with support for filtering and sorting.

### Basic Usage

```gdscript
# Basic list
var result = await pb.logs.get_list(1, 30)

print(result.page)        # 1
print(result.perPage)     # 30
print(result.totalItems)  # Total logs count
print(result.items)       # Array of log entries
```

### Log Entry Structure

Each log entry contains:

```gdscript
{
    "id": "ai5z3aoed6809au",
    "created": "2024-10-27 09:28:19.524Z",
    "level": 0,
    "message": "GET /api/collections/posts/records",
    "data": {
        "auth": "_superusers",
        "execTime": 2.392327,
        "method": "GET",
        "referer": "http://localhost:8090/_/",
        "remoteIP": "127.0.0.1",
        "status": 200,
        "type": "request",
        "url": "/api/collections/posts/records?page=1",
        "userAgent": "Mozilla/5.0...",
        "userIP": "127.0.0.1"
    }
}
```

### Filtering Logs

```gdscript
# Filter by HTTP status code
var error_logs = await pb.logs.get_list(1, 50, {
    "filter": "data.status >= 400"
})

# Filter by method
var get_logs = await pb.logs.get_list(1, 50, {
    "filter": "data.method = \"GET\""
})

# Filter by URL pattern
var api_logs = await pb.logs.get_list(1, 50, {
    "filter": "data.url ~ \"/api/\""
})

# Filter by IP address
var ip_logs = await pb.logs.get_list(1, 50, {
    "filter": "data.remoteIP = \"127.0.0.1\""
})

# Filter by execution time (slow requests)
var slow_logs = await pb.logs.get_list(1, 50, {
    "filter": "data.execTime > 1.0"
})

# Filter by log level
var error_level_logs = await pb.logs.get_list(1, 50, {
    "filter": "level > 0"
})

# Filter by date range
var recent_logs = await pb.logs.get_list(1, 50, {
    "filter": "created >= \"2024-10-27 00:00:00\""
})
```

### Complex Filters

```gdscript
# Multiple conditions
var complex_filter = await pb.logs.get_list(1, 50, {
    "filter": "data.status >= 400 && data.method = \"POST\" && data.execTime > 0.5"
})

# Exclude superuser requests
var user_logs = await pb.logs.get_list(1, 50, {
    "filter": "data.auth != \"_superusers\""
})

# Specific endpoint errors
var endpoint_errors = await pb.logs.get_list(1, 50, {
    "filter": "data.url ~ \"/api/collections/posts/records\" && data.status >= 400"
})

# Errors or slow requests
var problems = await pb.logs.get_list(1, 50, {
    "filter": "data.status >= 400 || data.execTime > 2.0"
})
```

### Sorting Logs

```gdscript
# Sort by creation date (newest first)
var recent = await pb.logs.get_list(1, 50, {
    "sort": "-created"
})

# Sort by execution time (slowest first)
var slowest = await pb.logs.get_list(1, 50, {
    "sort": "-data.execTime"
})

# Sort by status code
var by_status = await pb.logs.get_list(1, 50, {
    "sort": "data.status"
})

# Sort by rowid (most efficient)
var by_rowid = await pb.logs.get_list(1, 50, {
    "sort": "-rowid"
})

# Multiple sort fields
var multi_sort = await pb.logs.get_list(1, 50, {
    "sort": "-created,level"
})
```

### Get Full List

```gdscript
# Get all logs (be careful with large datasets)
var all_logs = await pb.logs.get_list(1, 1000, {
    "filter": "created >= \"2024-10-27 00:00:00\"",
    "sort": "-created"
})
```

## View Log

Retrieve a single log entry by ID:

```gdscript
# Get specific log
var log = await pb.logs.get_one("ai5z3aoed6809au")

if log is ClientResponseError:
    push_error("Failed to get log: " + log.to_string())
    return

print(log.message)
print(log.data.status)
print(log.data.execTime)
```

### Log Details

```gdscript
func analyze_log(log_id: String) -> void:
    var log = await pb.logs.get_one(log_id)
    
    if log is ClientResponseError:
        push_error("Failed to get log: " + log.to_string())
        return
    
    print("Log ID: ", log.id)
    print("Created: ", log.created)
    print("Level: ", log.level)
    print("Message: ", log.message)
    
    if log.data.get("type", "") == "request":
        print("Method: ", log.data.method)
        print("URL: ", log.data.url)
        print("Status: ", log.data.status)
        print("Execution Time: ", log.data.execTime, " ms")
        print("Remote IP: ", log.data.remoteIP)
        print("User Agent: ", log.data.get("userAgent", ""))
        print("Auth Collection: ", log.data.get("auth", ""))
```

## Logs Statistics

Get hourly aggregated statistics for logs:

### Basic Usage

```gdscript
# Get all statistics
var stats = await pb.logs.get_stats()

if stats is ClientResponseError:
    push_error("Failed to get stats: " + stats.to_string())
    return

# Each stat entry contains:
# { "total": 4, "date": "2022-06-01 19:00" }
for stat in stats:
    print("Date: ", stat.date, ", Total: ", stat.total)
```

### Filtered Statistics

```gdscript
# Statistics for errors only
var error_stats = await pb.logs.get_stats({
    "filter": "data.status >= 400"
})

# Statistics for specific endpoint
var endpoint_stats = await pb.logs.get_stats({
    "filter": "data.url ~ \"/api/collections/posts/records\""
})

# Statistics for slow requests
var slow_stats = await pb.logs.get_stats({
    "filter": "data.execTime > 1.0"
})

# Statistics excluding superuser requests
var user_stats = await pb.logs.get_stats({
    "filter": "data.auth != \"_superusers\""
})
```

## Filter Syntax

Logs support filtering with a flexible syntax similar to records filtering.

### Supported Fields

**Direct Fields:**
- `id` - Log ID
- `created` - Creation timestamp
- `updated` - Update timestamp
- `level` - Log level (0 = info, higher = warnings/errors)
- `message` - Log message

**Data Fields (nested):**
- `data.status` - HTTP status code
- `data.method` - HTTP method (GET, POST, etc.)
- `data.url` - Request URL
- `data.execTime` - Execution time in seconds
- `data.remoteIP` - Remote IP address
- `data.userIP` - User IP address
- `data.userAgent` - User agent string
- `data.referer` - Referer header
- `data.auth` - Auth collection ID
- `data.type` - Log type (usually "request")

### Filter Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `=` | Equal | `data.status = 200` |
| `!=` | Not equal | `data.status != 200` |
| `>` | Greater than | `data.status > 400` |
| `>=` | Greater than or equal | `data.status >= 400` |
| `<` | Less than | `data.execTime < 0.5` |
| `<=` | Less than or equal | `data.execTime <= 1.0` |
| `~` | Contains/Like | `data.url ~ "/api/"` |
| `!~` | Not contains | `data.url !~ "/admin/"` |

### Logical Operators

- `&&` - AND
- `||` - OR
- `()` - Grouping

### Filter Examples

```gdscript
# Simple equality
"filter": "data.method = \"GET\""

# Range filter
"filter": "data.status >= 400 && data.status < 500"

# Pattern matching
"filter": "data.url ~ \"/api/collections/\""

# Complex logic
"filter": "(data.status >= 400 || data.execTime > 2.0) && data.method = \"POST\""

# Exclude patterns
"filter": "data.url !~ \"/admin/\" && data.auth != \"_superusers\""

# Date range
"filter": "created >= \"2024-10-27 00:00:00\" && created <= \"2024-10-28 00:00:00\""
```

## Sort Options

Supported sort fields:

- `@random` - Random order
- `rowid` - Row ID (most efficient, use negative for DESC)
- `id` - Log ID
- `created` - Creation date
- `updated` - Update date
- `level` - Log level
- `message` - Message text
- `data.*` - Any data field (e.g., `data.status`, `data.execTime`)

```gdscript
# Sort examples
"sort": "-created"              # Newest first
"sort": "data.execTime"         # Fastest first
"sort": "-data.execTime"        # Slowest first
"sort": "-rowid"                # Most efficient (newest)
"sort": "level,-created"        # By level, then newest
```

## Complete Examples

### Example 1: Error Monitoring Dashboard

```gdscript
func get_error_metrics() -> Dictionary:
    # Get error logs from last 24 hours
    var yesterday = Time.get_unix_time_from_system() - (24 * 60 * 60)
    var yesterday_str = Time.get_datetime_string_from_unix_time(yesterday, false)
    var date_filter = "created >= \"" + yesterday_str.split("T")[0] + " 00:00:00\""
    
    # 4xx errors
    var client_errors = await pb.logs.get_list(1, 100, {
        "filter": date_filter + " && data.status >= 400 && data.status < 500",
        "sort": "-created"
    })
    
    # 5xx errors
    var server_errors = await pb.logs.get_list(1, 100, {
        "filter": date_filter + " && data.status >= 500",
        "sort": "-created"
    })
    
    # Get hourly statistics
    var error_stats = await pb.logs.get_stats({
        "filter": date_filter + " && data.status >= 400"
    })
    
    return {
        "clientErrors": client_errors.items if not client_errors is ClientResponseError else [],
        "serverErrors": server_errors.items if not server_errors is ClientResponseError else [],
        "stats": error_stats if not error_stats is ClientResponseError else []
    }
```

### Example 2: Performance Analysis

```gdscript
func analyze_performance() -> Dictionary:
    # Get slow requests
    var slow_requests = await pb.logs.get_list(1, 50, {
        "filter": "data.execTime > 1.0",
        "sort": "-data.execTime"
    })
    
    if slow_requests is ClientResponseError:
        push_error("Failed to get slow requests: " + slow_requests.to_string())
        return {}
    
    # Analyze by endpoint
    var endpoint_stats = {}
    
    for log in slow_requests.items:
        var url = log.data.url.split("?")[0]  # Remove query params
        if not endpoint_stats.has(url):
            endpoint_stats[url] = {
                "count": 0,
                "totalTime": 0.0,
                "maxTime": 0.0,
            }
        
        var stats = endpoint_stats[url]
        stats.count += 1
        stats.totalTime += log.data.execTime
        stats.maxTime = max(stats.maxTime, log.data.execTime)
    
    # Calculate averages
    for url in endpoint_stats:
        var stats = endpoint_stats[url]
        stats.avgTime = stats.totalTime / stats.count
    
    return endpoint_stats
```

### Example 3: Security Monitoring

```gdscript
func monitor_security() -> Dictionary:
    # Failed authentication attempts
    var auth_failures = await pb.logs.get_list(1, 100, {
        "filter": "data.url ~ \"/api/collections/\" && data.url ~ \"/auth-with-password\" && data.status >= 400",
        "sort": "-created"
    })
    
    if auth_failures is ClientResponseError:
        push_error("Failed to get auth failures: " + auth_failures.to_string())
        return {}
    
    # Suspicious IPs (multiple failed attempts)
    var ip_counts = {}
    
    for log in auth_failures.items:
        var ip = log.data.get("remoteIP", "")
        if ip_counts.has(ip):
            ip_counts[ip] += 1
        else:
            ip_counts[ip] = 1
    
    var suspicious_ips = []
    for ip in ip_counts:
        if ip_counts[ip] >= 5:
            suspicious_ips.append({"ip": ip, "attempts": ip_counts[ip]})
    
    return {
        "totalFailures": auth_failures.totalItems,
        "suspiciousIPs": suspicious_ips
    }
```

### Example 4: Log Viewer Component

```gdscript
class_name LogViewer

var pb: BosBase
var current_page: int = 1
var per_page: int = 50
var filter_text: String = ""
var sort_text: String = "-created"

func load_logs() -> Dictionary:
    var options = {}
    if filter_text != "":
        options["filter"] = filter_text
    if sort_text != "":
        options["sort"] = sort_text
    
    return await pb.logs.get_list(current_page, per_page, options)

func search_logs(search_term: String) -> Dictionary:
    filter_text = "message ~ \"" + search_term + "\" || data.url ~ \"" + search_term + "\""
    current_page = 1
    return await load_logs()

func filter_by_status(status: int) -> Dictionary:
    filter_text = "data.status = " + str(status)
    current_page = 1
    return await load_logs()

func get_error_rate() -> Dictionary:
    var today = Time.get_datetime_string_from_system(false).split("T")[0]
    var date_filter = "created >= \"" + today + " 00:00:00\""
    
    var stats = await pb.logs.get_stats({
        "filter": date_filter
    })
    
    var error_stats = await pb.logs.get_stats({
        "filter": date_filter + " && data.status >= 400"
    })
    
    if stats is ClientResponseError or error_stats is ClientResponseError:
        return {"total": 0, "errors": 0, "rate": 0.0}
    
    var total = 0
    for stat in stats:
        total += stat.get("total", 0)
    
    var errors = 0
    for stat in error_stats:
        errors += stat.get("total", 0)
    
    return {
        "total": total,
        "errors": errors,
        "rate": (float(errors) / float(total) * 100.0) if total > 0 else 0.0
    }
```

## Error Handling

```gdscript
var logs = await pb.logs.get_list(1, 50, {
    "filter": "data.status >= 400"
})

if logs is ClientResponseError:
    if logs.status == 401:
        push_error("Not authenticated")
    elif logs.status == 403:
        push_error("Not a superuser")
    elif logs.status == 400:
        push_error("Invalid filter: ", logs.data)
    else:
        push_error("Unexpected error: ", logs.to_string())
```

## Best Practices

1. **Use Filters**: Always use filters to narrow down results, especially for large log datasets
2. **Paginate**: Use pagination instead of fetching all logs at once
3. **Efficient Sorting**: Use "-rowid" for default sorting (most efficient)
4. **Filter Statistics**: Always filter statistics for meaningful insights
5. **Monitor Errors**: Regularly check for 4xx/5xx errors
6. **Performance Tracking**: Monitor execution times for slow endpoints
7. **Security Auditing**: Track authentication failures and suspicious activity
8. **Archive Old Logs**: Consider deleting or archiving old logs to maintain performance

## Limitations

- **Superuser Only**: All operations require superuser authentication
- **Data Fields**: Only fields in the `data` object are filterable
- **Statistics**: Statistics are aggregated hourly
- **Performance**: Large log datasets may be slow to query
- **Storage**: Logs accumulate over time and may need periodic cleanup

## Log Levels

- **0**: Info (normal requests)
- **> 0**: Warnings/Errors (non-200 status codes, exceptions, etc.)

Higher values typically indicate more severe issues.

## Related Documentation

- [Authentication](./AUTHENTICATION.md) - User authentication
- [API Records](./API_RECORDS.md) - Record operations
- [Collection API](./COLLECTION_API.md) - Collection management
