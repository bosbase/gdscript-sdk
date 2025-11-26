# Crons API - GDScript SDK Documentation

## Overview

The Crons API provides endpoints for viewing and manually triggering scheduled cron jobs. All operations require superuser authentication and allow you to list registered cron jobs and execute them on-demand.

**Key Features:**
- List all registered cron jobs
- View cron job schedules (cron expressions)
- Manually trigger cron jobs
- Built-in system jobs for maintenance tasks

**Backend Endpoints:**
- `GET /api/crons` - List cron jobs
- `POST /api/crons/{jobId}` - Run cron job

**Note**: All Crons API operations require superuser authentication.

## Authentication

All Crons API operations require superuser authentication:

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://127.0.0.1:8090")

# Authenticate as superuser
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return
```

## List Cron Jobs

Returns a list of all registered cron jobs with their IDs and schedule expressions.

### Basic Usage

```gdscript
# Get all cron jobs
var jobs = await pb.crons.get_full_list()

if jobs is ClientResponseError:
    push_error("Failed to get cron jobs: " + jobs.to_string())
    return

print(jobs)
# [
#   { "id": "__pbLogsCleanup__", "expression": "0 */6 * * *" },
#   { "id": "__pbDBOptimize__", "expression": "0 0 * * *" },
#   { "id": "__pbMFACleanup__", "expression": "0 * * * *" },
#   { "id": "__pbOTPCleanup__", "expression": "0 * * * *" }
# ]
```

### Cron Job Structure

Each cron job contains:

```gdscript
{
    "id": String,        # Unique identifier for the job
    "expression": String  # Cron expression defining the schedule
}
```

### Built-in System Jobs

The following cron jobs are typically registered by default:

| Job ID | Expression | Description | Schedule |
|--------|-----------|-------------|----------|
| `__pbLogsCleanup__` | `0 */6 * * *` | Cleans up old log entries | Every 6 hours |
| `__pbDBOptimize__` | `0 0 * * *` | Optimizes database | Daily at midnight |
| `__pbMFACleanup__` | `0 * * * *` | Cleans up expired MFA records | Every hour |
| `__pbOTPCleanup__` | `0 * * * *` | Cleans up expired OTP codes | Every hour |

### Working with Cron Jobs

```gdscript
# List all cron jobs
var jobs = await pb.crons.get_full_list()

if jobs is ClientResponseError:
    push_error("Failed to get cron jobs: " + jobs.to_string())
    return

# Find a specific job
var logs_cleanup = null
for job in jobs:
    if job.id == "__pbLogsCleanup__":
        logs_cleanup = job
        break

if logs_cleanup:
    print("Logs cleanup runs: ", logs_cleanup.expression)

# Filter system jobs
var system_jobs = []
for job in jobs:
    if job.id.begins_with("__pb"):
        system_jobs.append(job)

# Filter custom jobs
var custom_jobs = []
for job in jobs:
    if not job.id.begins_with("__pb"):
        custom_jobs.append(job)
```

## Run Cron Job

Manually trigger a cron job to execute immediately.

### Basic Usage

```gdscript
# Run a specific cron job
var result = await pb.crons.run("__pbLogsCleanup__")
if result is ClientResponseError:
    push_error("Failed to run cron job: " + result.to_string())
    return

print("Cron job triggered successfully")
```

### Use Cases

```gdscript
# Trigger logs cleanup manually
func cleanup_logs_now() -> void:
    var result = await pb.crons.run("__pbLogsCleanup__")
    if result is ClientResponseError:
        push_error("Failed to trigger logs cleanup: " + result.to_string())
        return
    print("Logs cleanup triggered")

# Trigger database optimization
func optimize_database() -> void:
    var result = await pb.crons.run("__pbDBOptimize__")
    if result is ClientResponseError:
        push_error("Failed to trigger database optimization: " + result.to_string())
        return
    print("Database optimization triggered")

# Trigger MFA cleanup
func cleanup_mfa() -> void:
    var result = await pb.crons.run("__pbMFACleanup__")
    if result is ClientResponseError:
        push_error("Failed to trigger MFA cleanup: " + result.to_string())
        return
    print("MFA cleanup triggered")

# Trigger OTP cleanup
func cleanup_otp() -> void:
    var result = await pb.crons.run("__pbOTPCleanup__")
    if result is ClientResponseError:
        push_error("Failed to trigger OTP cleanup: " + result.to_string())
        return
    print("OTP cleanup triggered")
```

## Cron Expression Format

Cron expressions use the standard 5-field format:

```
* * * * *
│ │ │ │ │
│ │ │ │ └─── Day of week (0-7, 0 or 7 is Sunday)
│ │ │ └───── Month (1-12)
│ │ └─────── Day of month (1-31)
│ └───────── Hour (0-23)
└─────────── Minute (0-59)
```

### Common Patterns

| Expression | Description |
|------------|-------------|
| `0 * * * *` | Every hour at minute 0 |
| `0 */6 * * *` | Every 6 hours |
| `0 0 * * *` | Daily at midnight |
| `0 0 * * 0` | Weekly on Sunday at midnight |
| `0 0 1 * *` | Monthly on the 1st at midnight |
| `*/30 * * * *` | Every 30 minutes |
| `0 9 * * 1-5` | Weekdays at 9 AM |

### Supported Macros

| Macro | Equivalent Expression | Description |
|-------|----------------------|-------------|
| `@yearly` or `@annually` | `0 0 1 1 *` | Once a year |
| `@monthly` | `0 0 1 * *` | Once a month |
| `@weekly` | `0 0 * * 0` | Once a week |
| `@daily` or `@midnight` | `0 0 * * *` | Once a day |
| `@hourly` | `0 * * * *` | Once an hour |

### Expression Examples

```gdscript
# Every hour
"0 * * * *"

# Every 6 hours
"0 */6 * * *"

# Daily at midnight
"0 0 * * *"

# Every 30 minutes
"*/30 * * * *"

# Weekdays at 9 AM
"0 9 * * 1-5"

# First day of every month
"0 0 1 * *"

# Using macros
"@daily"   # Same as "0 0 * * *"
"@hourly"  # Same as "0 * * * *"
```

## Complete Examples

### Example 1: Cron Job Monitor

```gdscript
class_name CronMonitor

var pb: BosBase

func list_all_jobs() -> Array:
    var jobs = await pb.crons.get_full_list()
    
    if jobs is ClientResponseError:
        push_error("Failed to get cron jobs: " + jobs.to_string())
        return []
    
    print("Found %d cron jobs:" % jobs.size())
    for job in jobs:
        print("  - %s: %s" % [job.id, job.expression])
    
    return jobs

func run_job(job_id: String) -> bool:
    var result = await pb.crons.run(job_id)
    if result is ClientResponseError:
        push_error("Failed to run %s: %s" % [job_id, result.to_string()])
        return false
    
    print("Successfully triggered: ", job_id)
    return true

func run_maintenance_jobs() -> void:
    var maintenance_jobs = [
        "__pbLogsCleanup__",
        "__pbDBOptimize__",
        "__pbMFACleanup__",
        "__pbOTPCleanup__",
    ]
    
    for job_id in maintenance_jobs:
        print("Running %s..." % job_id)
        await run_job(job_id)
        # Wait a bit between jobs
        await Engine.get_main_loop().process_frame
        await Engine.get_main_loop().process_frame

# Usage
var monitor = CronMonitor.new()
monitor.pb = pb
await monitor.list_all_jobs()
await monitor.run_maintenance_jobs()
```

### Example 2: Cron Job Health Check

```gdscript
func check_cron_jobs() -> bool:
    var jobs = await pb.crons.get_full_list()
    
    if jobs is ClientResponseError:
        push_error("Failed to check cron jobs: " + jobs.to_string())
        return false
    
    var expected_jobs = [
        "__pbLogsCleanup__",
        "__pbDBOptimize__",
        "__pbMFACleanup__",
        "__pbOTPCleanup__",
    ]
    
    var missing_jobs = []
    for expected_id in expected_jobs:
        var found = false
        for job in jobs:
            if job.id == expected_id:
                found = true
                break
        if not found:
            missing_jobs.append(expected_id)
    
    if missing_jobs.size() > 0:
        push_warning("Missing expected cron jobs: ", missing_jobs)
        return false
    
    print("All expected cron jobs are registered")
    return true
```

### Example 3: Manual Maintenance Script

```gdscript
func perform_maintenance() -> void:
    print("Starting maintenance tasks...")
    
    # Cleanup old logs
    print("1. Cleaning up old logs...")
    await pb.crons.run("__pbLogsCleanup__")
    
    # Cleanup expired MFA records
    print("2. Cleaning up expired MFA records...")
    await pb.crons.run("__pbMFACleanup__")
    
    # Cleanup expired OTP codes
    print("3. Cleaning up expired OTP codes...")
    await pb.crons.run("__pbOTPCleanup__")
    
    # Optimize database (run last as it may take longer)
    print("4. Optimizing database...")
    await pb.crons.run("__pbDBOptimize__")
    
    print("Maintenance tasks completed")
```

### Example 4: Cron Job Status Dashboard

```gdscript
func get_cron_status() -> Dictionary:
    var jobs = await pb.crons.get_full_list()
    
    if jobs is ClientResponseError:
        push_error("Failed to get cron jobs: " + jobs.to_string())
        return {}
    
    var system_count = 0
    var custom_count = 0
    var job_list = []
    
    for job in jobs:
        var is_system = job.id.begins_with("__pb")
        if is_system:
            system_count += 1
        else:
            custom_count += 1
        
        job_list.append({
            "id": job.id,
            "expression": job.expression,
            "type": "system" if is_system else "custom",
        })
    
    return {
        "total": jobs.size(),
        "system": system_count,
        "custom": custom_count,
        "jobs": job_list,
    }

# Usage
var status = await get_cron_status()
print("Total: %d, System: %d, Custom: %d" % [status.total, status.system, status.custom])
```

### Example 5: Cron Job Testing

```gdscript
func test_cron_job(job_id: String) -> bool:
    print("Testing cron job: ", job_id)
    
    # Check if job exists
    var jobs = await pb.crons.get_full_list()
    if jobs is ClientResponseError:
        push_error("Failed to get cron jobs: " + jobs.to_string())
        return false
    
    var job = null
    for j in jobs:
        if j.id == job_id:
            job = j
            break
    
    if not job:
        push_error("Cron job %s not found" % job_id)
        return false
    
    print("Job found with expression: ", job.expression)
    
    # Run the job
    print("Triggering job...")
    var result = await pb.crons.run(job_id)
    if result is ClientResponseError:
        push_error("Failed to test cron job: " + result.to_string())
        return false
    
    print("Job triggered successfully")
    return true

# Test a specific job
await test_cron_job("__pbLogsCleanup__")
```

## Error Handling

```gdscript
var jobs = await pb.crons.get_full_list()

if jobs is ClientResponseError:
    match jobs.status:
        401:
            push_error("Not authenticated")
        403:
            push_error("Not a superuser")
        _:
            push_error("Unexpected error: " + jobs.to_string())

# Run cron job with error handling
var result = await pb.crons.run("__pbLogsCleanup__")
if result is ClientResponseError:
    match result.status:
        401:
            push_error("Not authenticated")
        403:
            push_error("Not a superuser")
        404:
            push_error("Cron job not found")
        _:
            push_error("Unexpected error: " + result.to_string())
```

## Best Practices

1. **Check Job Existence**: Verify a cron job exists before trying to run it
2. **Error Handling**: Always handle errors when running cron jobs
3. **Rate Limiting**: Don't trigger cron jobs too frequently manually
4. **Monitoring**: Regularly check that expected cron jobs are registered
5. **Logging**: Log when cron jobs are manually triggered for auditing
6. **Testing**: Test cron jobs in development before running in production
7. **Documentation**: Document custom cron jobs and their purposes
8. **Scheduling**: Let the cron scheduler handle regular execution; use manual triggers sparingly

## Limitations

- **Superuser Only**: All operations require superuser authentication
- **Read-Only API**: The SDK API only allows listing and running jobs; adding/removing jobs must be done via backend hooks
- **Asynchronous Execution**: Running a cron job triggers it asynchronously; the API returns immediately
- **No Status**: The API doesn't provide execution status or history
- **System Jobs**: Built-in system jobs (prefixed with `__pb`) cannot be removed via the API

## Custom Cron Jobs

Custom cron jobs are typically registered through backend hooks (JavaScript VM plugins). The Crons API only allows you to:

- **View** all registered jobs (both system and custom)
- **Trigger** any registered job manually

To add or remove cron jobs, you need to use the backend hook system. This is configured on the backend/server side, not through the SDK.

## Related Documentation

- [Collection API](./COLLECTION_API.md) - Collection management
- [Logs API](./LOGS_API.md) - Log viewing and analysis
- [Backups API](./BACKUPS_API.md) - Backup management
