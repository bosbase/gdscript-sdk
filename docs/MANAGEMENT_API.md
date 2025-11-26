# Management API Documentation - GDScript SDK

This document covers the management API capabilities available in the GDScript SDK, which correspond to the features available in the backend management UI.

> **Note**: All management API operations require superuser authentication (🔐).

## Table of Contents

- [Settings Service](#settings-service)
  - [Application Configuration](#application-configuration)
  - [Mail Configuration](#mail-configuration)
  - [Storage Configuration](#storage-configuration)
  - [Backup Configuration](#backup-configuration)
  - [Log Configuration](#log-configuration)
- [Backup Service](#backup-service)
- [Log Service](#log-service)
- [Cron Service](#cron-service)
- [Health Service](#health-service)
- [Collection Service](#collection-service)

---

## Settings Service

The Settings Service provides comprehensive management of application settings, matching the capabilities available in the backend management UI.

### Application Configuration

Manage application settings including meta information, trusted proxy, rate limits, and batch configuration.

#### Get Application Settings

```gdscript
var settings = await pb.settings.get_application_settings()
if settings is ClientResponseError:
    push_error("Failed to get settings: " + settings.to_string())
    return

# Returns: { meta, trustedProxy, rateLimits, batch }
```

**Example:**
```gdscript
var app_settings = await pb.settings.get_application_settings()
if not app_settings is ClientResponseError:
    print(app_settings.meta.appName)  # Application name
    print(app_settings.rateLimits.rules)  # Rate limit rules
```

#### Update Application Settings

```gdscript
var result = await pb.settings.update_application_settings({
    "meta": {
        "appName": "My App",
        "appURL": "https://example.com",
        "hideControls": false,
    },
    "trustedProxy": {
        "headers": ["X-Forwarded-For"],
        "useLeftmostIP": true,
    },
    "rateLimits": {
        "enabled": true,
        "rules": [
            {
                "label": "api/users",
                "duration": 3600,
                "maxRequests": 100,
            }
        ]
    },
    "batch": {
        "enabled": true,
        "maxRequests": 100,
        "interval": 30,
    }
})

if result is ClientResponseError:
    push_error("Failed to update settings: " + result.to_string())
```

#### Individual Settings Updates

**Update Meta Settings:**
```gdscript
var result = await pb.settings.update_meta({
    "appName": "My App",
    "appURL": "https://example.com",
    "senderName": "My App",
    "senderAddress": "noreply@example.com",
    "hideControls": false,
})
```

**Update Trusted Proxy:**
```gdscript
var result = await pb.settings.update_trusted_proxy({
    "headers": ["X-Forwarded-For", "X-Real-IP"],
    "useLeftmostIP": true,
})
```

**Update Rate Limits:**
```gdscript
var result = await pb.settings.update_rate_limits({
    "enabled": true,
    "rules": [
        {
            "label": "api/users",
            "audience": "public",
            "duration": 3600,
            "maxRequests": 100,
        }
    ]
})
```

**Update Batch Configuration:**
```gdscript
var result = await pb.settings.update_batch({
    "enabled": true,
    "maxRequests": 100,
    "timeout": 30,
    "maxBodySize": 1048576,
})
```

---

### Mail Configuration

Manage SMTP email settings and sender information.

#### Get Mail Settings

```gdscript
var mail_settings = await pb.settings.get_mail_settings()
if mail_settings is ClientResponseError:
    push_error("Failed to get mail settings: " + mail_settings.to_string())
    return

# Returns: { meta: { senderName, senderAddress }, smtp }
```

**Example:**
```gdscript
var mail = await pb.settings.get_mail_settings()
if not mail is ClientResponseError:
    print(mail.meta.senderName)  # Sender name
    print(mail.smtp.host)  # SMTP host
```

#### Update Mail Settings

Update both sender info and SMTP configuration in one call:

```gdscript
var result = await pb.settings.update_mail_settings({
    "senderName": "My App",
    "senderAddress": "noreply@example.com",
    "smtp": {
        "enabled": true,
        "host": "smtp.example.com",
        "port": 587,
        "username": "user@example.com",
        "password": "password",
        "authMethod": "PLAIN",
        "tls": true,
        "localName": "localhost",
    }
})

if result is ClientResponseError:
    push_error("Failed to update mail settings: " + result.to_string())
```

#### Update SMTP Only

```gdscript
var result = await pb.settings.update_smtp({
    "enabled": true,
    "host": "smtp.example.com",
    "port": 587,
    "username": "user@example.com",
    "password": "password",
    "authMethod": "PLAIN",
    "tls": true,
    "localName": "localhost",
})
```

#### Test Email

Send a test email to verify SMTP configuration:

```gdscript
var result = await pb.settings.test_mail(
    "test@example.com",
    "verification",  # template: verification, password-reset, email-change, otp, login-alert
    "_superusers"  # collection (optional, defaults to _superusers)
)

if result is ClientResponseError:
    push_error("Failed to send test email: " + result.to_string())
```

**Email Templates:**
- `verification` - Email verification template
- `password-reset` - Password reset template
- `email-change` - Email change confirmation template
- `otp` - One-time password template
- `login-alert` - Login alert template

---

### Storage Configuration

Manage S3 storage configuration for file storage.

#### Get Storage S3 Configuration

```gdscript
var s3_config = await pb.settings.get_storage_s3()
if s3_config is ClientResponseError:
    push_error("Failed to get S3 config: " + s3_config.to_string())
    return

# Returns: { enabled, bucket, region, endpoint, accessKey, secret, forcePathStyle }
```

#### Update Storage S3 Configuration

```gdscript
var result = await pb.settings.update_storage_s3({
    "enabled": true,
    "bucket": "my-bucket",
    "region": "us-east-1",
    "endpoint": "https://s3.amazonaws.com",
    "accessKey": "ACCESS_KEY",
    "secret": "SECRET_KEY",
    "forcePathStyle": false,
})

if result is ClientResponseError:
    push_error("Failed to update S3 config: " + result.to_string())
```

#### Test Storage S3 Connection

```gdscript
var result = await pb.settings.test_storage_s3()
if result is ClientResponseError:
    push_error("S3 connection test failed: " + result.to_string())
    return

# Returns: true if connection succeeds
```

---

### Backup Configuration

Manage auto-backup scheduling and S3 storage for backups.

#### Get Backup Settings

```gdscript
var backup_settings = await pb.settings.get_backup_settings()
if backup_settings is ClientResponseError:
    push_error("Failed to get backup settings: " + backup_settings.to_string())
    return

# Returns: { cron, cronMaxKeep, s3 }
```

**Example:**
```gdscript
var backups = await pb.settings.get_backup_settings()
if not backups is ClientResponseError:
    print(backups.cron)  # Cron expression (e.g., "0 0 * * *")
    print(backups.cronMaxKeep)  # Maximum backups to keep
```

#### Update Backup Settings

```gdscript
var result = await pb.settings.update_backup_settings({
    "cron": "0 0 * * *",  # Daily at midnight (empty string to disable)
    "cronMaxKeep": 10,  # Keep maximum 10 backups
    "s3": {
        "enabled": true,
        "bucket": "backup-bucket",
        "region": "us-east-1",
        "endpoint": "https://s3.amazonaws.com",
        "accessKey": "ACCESS_KEY",
        "secret": "SECRET_KEY",
        "forcePathStyle": false,
    }
})

if result is ClientResponseError:
    push_error("Failed to update backup settings: " + result.to_string())
```

#### Set Auto-Backup Schedule

```gdscript
# Enable daily backups at midnight, keep 10 backups
var result = await pb.settings.set_auto_backup_schedule("0 0 * * *", 10)
if result is ClientResponseError:
    push_error("Failed to set backup schedule: " + result.to_string())

# Disable auto-backup
var result2 = await pb.settings.disable_auto_backup()
if result2 is ClientResponseError:
    push_error("Failed to disable auto-backup: " + result2.to_string())
```

**Common Cron Expressions:**
- `"0 0 * * *"` - Daily at midnight
- `"0 0 * * 0"` - Weekly on Sunday at midnight
- `"0 0 1 * *"` - Monthly on the 1st at midnight
- `"0 0 * * 1,3"` - Twice weekly (Monday and Wednesday)

#### Test Backups S3 Connection

```gdscript
var result = await pb.settings.test_backups_s3()
if result is ClientResponseError:
    push_error("Backups S3 connection test failed: " + result.to_string())
    return

# Returns: true if connection succeeds
```

---

### Log Configuration

Manage log retention and logging settings.

#### Get Log Settings

```gdscript
var log_settings = await pb.settings.get_log_settings()
if log_settings is ClientResponseError:
    push_error("Failed to get log settings: " + log_settings.to_string())
    return

# Returns: { maxDays, minLevel, logIP, logAuthId }
```

#### Update Log Settings

```gdscript
var result = await pb.settings.update_log_settings({
    "maxDays": 30,  # Retain logs for 30 days
    "minLevel": 0,  # Minimum log level (negative=debug/info, 0=warning, positive=error)
    "logIP": true,  # Log IP addresses
    "logAuthId": true,
})

if result is ClientResponseError:
    push_error("Failed to update log settings: " + result.to_string())
```

#### Individual Log Settings

```gdscript
# Set log retention days
var result1 = await pb.settings.set_log_retention_days(30)
if result1 is ClientResponseError:
    push_error("Failed to set retention: " + result1.to_string())

# Set minimum log level
var result2 = await pb.settings.set_min_log_level(0)  # -100 to 100
if result2 is ClientResponseError:
    push_error("Failed to set log level: " + result2.to_string())

# Enable/disable IP logging
var result3 = await pb.settings.set_log_ip_addresses(true)
if result3 is ClientResponseError:
    push_error("Failed to set IP logging: " + result3.to_string())

# Enable/disable auth ID logging
var result4 = await pb.settings.set_log_auth_ids(true)
if result4 is ClientResponseError:
    push_error("Failed to set auth ID logging: " + result4.to_string())
```

**Log Levels:**
- Negative values: Debug/Info levels
- `0`: Default/Warning level
- Positive values: Error levels

---

## Backup Service

Manage application backups - create, list, upload, delete, and restore backups.

### List All Backups

```gdscript
var backups = await pb.backups.get_full_list()
if backups is ClientResponseError:
    push_error("Failed to get backups: " + backups.to_string())
    return

# Returns: Array[Dictionary] with { key, size, modified }
```

**Example:**
```gdscript
var backups = await pb.backups.get_full_list()
if not backups is ClientResponseError:
    for backup in backups:
        print("%s: %d bytes, modified: %s" % [backup.key, backup.size, backup.modified])
```

### Create Backup

```gdscript
var result = await pb.backups.create("backup-2024-01-01")
if result is ClientResponseError:
    push_error("Failed to create backup: " + result.to_string())
    return

# Creates a new backup with the specified basename
```

### Upload Backup

Upload an existing backup file:

```gdscript
# Read backup file
var file_path = "res://backup.zip"
var file = FileAccess.open(file_path, FileAccess.READ)
if file == null:
    push_error("Failed to open backup file")
    return

var file_data = file.get_buffer(file.get_length())
file.close()

var files = {
    "file": {
        "filename": "backup.zip",
        "content_type": "application/zip",
        "data": file_data
    }
}

var result = await pb.backups.upload(files)
if result is ClientResponseError:
    push_error("Failed to upload backup: " + result.to_string())
```

### Delete Backup

```gdscript
var result = await pb.backups.delete("backup-2024-01-01")
if result is ClientResponseError:
    push_error("Failed to delete backup: " + result.to_string())
    return

# Deletes the specified backup file
```

### Restore Backup

```gdscript
var result = await pb.backups.restore("backup-2024-01-01")
if result is ClientResponseError:
    push_error("Failed to restore backup: " + result.to_string())
    return

# Restores the application from the specified backup
```

**⚠️ Warning**: Restoring a backup will replace all current application data!

### Get Backup Download URL

```gdscript
# First, get a file token
var token = await pb.files.get_token()
if token is ClientResponseError:
    push_error("Failed to get token: " + token.to_string())
    return

# Then build the download URL
var url = pb.backups.get_download_url(token, "backup-2024-01-01")
print(url)  # Full URL to download the backup
```

---

## Log Service

Query and analyze application logs.

### List Logs

```gdscript
var result = await pb.logs.get_list(1, 30, {
    "filter": "level >= 0",
    "sort": "-created",
})
if result is ClientResponseError:
    push_error("Failed to get logs: " + result.to_string())
    return

# Returns: { page, perPage, totalItems, totalPages, items }
```

**Example with filtering:**
```gdscript
# Get error logs from the last 24 hours
var yesterday = Time.get_unix_time_from_system() - (24 * 60 * 60)
var yesterday_str = Time.get_datetime_string_from_unix_time(yesterday, false)
var date_filter = "created >= \"" + yesterday_str.split("T")[0] + " 00:00:00\""

var error_logs = await pb.logs.get_list(1, 50, {
    "filter": date_filter + " && level > 0",
    "sort": "-created"
})

if not error_logs is ClientResponseError:
    for log in error_logs.items:
        print("[%d] %s" % [log.level, log.message])
```

### Get Single Log

```gdscript
var log = await pb.logs.get_one("log-id")
if log is ClientResponseError:
    push_error("Failed to get log: " + log.to_string())
    return

# Returns: LogModel with full log details
```

### Get Log Statistics

```gdscript
var stats = await pb.logs.get_stats({
    "filter": "level >= 0",
})

if stats is ClientResponseError:
    push_error("Failed to get stats: " + stats.to_string())
    return

# Returns: Array[Dictionary] with { total, date } - hourly statistics
```

**Example:**
```gdscript
var stats = await pb.logs.get_stats()
if not stats is ClientResponseError:
    for stat in stats:
        print("%s: %d requests" % [stat.date, stat.total])
```

---

## Cron Service

Manage and execute cron jobs.

### List All Cron Jobs

```gdscript
var cron_jobs = await pb.crons.get_full_list()
if cron_jobs is ClientResponseError:
    push_error("Failed to get cron jobs: " + cron_jobs.to_string())
    return

# Returns: Array[Dictionary] with { id, expression }
```

**Example:**
```gdscript
var cron_jobs = await pb.crons.get_full_list()
if not cron_jobs is ClientResponseError:
    for job in cron_jobs:
        print("Job %s: %s" % [job.id, job.expression])
```

### Run Cron Job

Manually trigger a cron job:

```gdscript
var result = await pb.crons.run("job-id")
if result is ClientResponseError:
    push_error("Failed to run cron job: " + result.to_string())
    return

# Executes the specified cron job immediately
```

**Example:**
```gdscript
var cron_jobs = await pb.crons.get_full_list()
if not cron_jobs is ClientResponseError:
    for job in cron_jobs:
        if "backup" in job.id:
            await pb.crons.run(job.id)
            print("Backup job executed manually")
            break
```

---

## Health Service

Check the health status of the API.

### Check Health

```gdscript
var health = await pb.health.check()
if health is ClientResponseError:
    push_error("Health check failed: " + health.to_string())
    return

# Returns: Health status information
```

**Example:**
```gdscript
var health = await pb.health.check()
if health is ClientResponseError:
    push_error("Health check failed: " + health.to_string())
else:
    print("API is healthy: ", health)
```

---

## Collection Service

Manage collections (schemas) programmatically.

### List Collections

```gdscript
var collections = await pb.collections.get_list(1, 30)
if collections is ClientResponseError:
    push_error("Failed to get collections: " + collections.to_string())
    return

# Returns: Paginated list of collections
```

### Get Collection

```gdscript
var collection = await pb.collections.get_one("collection-id-or-name")
if collection is ClientResponseError:
    push_error("Failed to get collection: " + collection.to_string())
    return

# Returns: Full collection schema
```

### Create Collection

```gdscript
var collection = await pb.collections.create({
    "name": "posts",
    "type": "base",
    "schema": [
        {
            "name": "title",
            "type": "text",
            "required": true,
        },
        {
            "name": "content",
            "type": "editor",
            "required": false,
        }
    ]
})

if collection is ClientResponseError:
    push_error("Failed to create collection: " + collection.to_string())
    return
```

### Update Collection

```gdscript
var result = await pb.collections.update("collection-id", {
    "schema": [...],
})

if result is ClientResponseError:
    push_error("Failed to update collection: " + result.to_string())
```

### Delete Collection

```gdscript
var result = await pb.collections.delete("collection-id")
if result is ClientResponseError:
    push_error("Failed to delete collection: " + result.to_string())
```

### Truncate Collection

Delete all records in a collection (keeps the schema):

```gdscript
var result = await pb.collections.truncate("collection-id")
if result is ClientResponseError:
    push_error("Failed to truncate collection: " + result.to_string())
```

### Import Collections

```gdscript
var collections = [
    {
        "name": "collection1",
        # ... collection schema
    },
    {
        "name": "collection2",
        # ... collection schema
    }
]

var result = await pb.collections.import(collections, false)  # false = don't delete missing collections
if result is ClientResponseError:
    push_error("Failed to import collections: " + result.to_string())
```

---

## Complete Example: Automated Backup Management

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://127.0.0.1:8090")

func manage_backups() -> void:
    # Authenticate as superuser
    var auth = await pb.admins().auth_with_password("admin@example.com", "password")
    if auth is ClientResponseError:
        push_error("Authentication failed: " + auth.to_string())
        return
    
    # Check current backup settings
    var backup_settings = await pb.settings.get_backup_settings()
    if not backup_settings is ClientResponseError:
        print("Current backup schedule: ", backup_settings.cron)
    
    # List all existing backups
    var backups = await pb.backups.get_full_list()
    if not backups is ClientResponseError:
        print("Found %d backups" % backups.size())
    
    # Create a new backup
    var today = Time.get_datetime_string_from_system(false).split("T")[0]
    var result = await pb.backups.create("manual-backup-" + today)
    if result is ClientResponseError:
        push_error("Failed to create backup: " + result.to_string())
        return
    
    print("Backup created successfully")
    
    # Get updated backup list
    var updated_backups = await pb.backups.get_full_list()
    if not updated_backups is ClientResponseError:
        print("Now have %d backups" % updated_backups.size())
    
    # Configure auto-backup (daily at 2 AM, keep 7 backups)
    var schedule_result = await pb.settings.set_auto_backup_schedule("0 2 * * *", 7)
    if schedule_result is ClientResponseError:
        push_error("Failed to configure auto-backup: " + schedule_result.to_string())
        return
    
    print("Auto-backup configured")
    
    # Test backup S3 connection if configured
    var s3_test = await pb.settings.test_backups_s3()
    if s3_test is ClientResponseError:
        push_warning("S3 backup storage test failed: " + s3_test.to_string())
    else:
        print("S3 backup storage is working")
```

---

## Complete Example: Log Monitoring

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://127.0.0.1:8090")

func monitor_logs() -> void:
    # Authenticate as superuser
    var auth = await pb.admins().auth_with_password("admin@example.com", "password")
    if auth is ClientResponseError:
        push_error("Authentication failed: " + auth.to_string())
        return
    
    # Get log settings
    var log_settings = await pb.settings.get_log_settings()
    if not log_settings is ClientResponseError:
        print("Log retention: %d days" % log_settings.maxDays)
        print("Minimum log level: ", log_settings.minLevel)
    
    # Get recent error logs
    var error_logs = await pb.logs.get_list(1, 20, {
        "filter": "level > 0",
        "sort": "-created",
    })
    
    if not error_logs is ClientResponseError:
        print("Found %d error logs" % error_logs.totalItems)
        for log in error_logs.items:
            print("[%d] %s - %s" % [log.level, log.message, log.created])
    
    # Get hourly statistics for the last 24 hours
    var stats = await pb.logs.get_stats({
        "filter": "level >= 0",
    })
    
    if not stats is ClientResponseError:
        print("Hourly request statistics:")
        for stat in stats:
            print("%s: %d requests" % [stat.date, stat.total])
    
    # Update log settings to retain logs for 14 days
    var update_result = await pb.settings.set_log_retention_days(14)
    if update_result is ClientResponseError:
        push_error("Failed to update log retention: " + update_result.to_string())
        return
    
    print("Log retention updated to 14 days")
```

---

## Complete Example: Application Configuration Management

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://127.0.0.1:8090")

func configure_application() -> void:
    # Authenticate as superuser
    var auth = await pb.admins().auth_with_password("admin@example.com", "password")
    if auth is ClientResponseError:
        push_error("Authentication failed: " + auth.to_string())
        return
    
    # Get current application settings
    var app_settings = await pb.settings.get_application_settings()
    if not app_settings is ClientResponseError:
        print("App Name: ", app_settings.meta.get("appName", ""))
        print("App URL: ", app_settings.meta.get("appURL", ""))
    
    # Update application configuration
    var result = await pb.settings.update_application_settings({
        "meta": {
            "appName": "My Production App",
            "appURL": "https://api.example.com",
            "hideControls": false,
        },
        "rateLimits": {
            "enabled": true,
            "rules": [
                {
                    "label": "api/users",
                    "duration": 3600,
                    "maxRequests": 100,
                },
                {
                    "label": "api/posts",
                    "duration": 3600,
                    "maxRequests": 100,
                }
            ]
        },
        "batch": {
            "enabled": true,
            "maxRequests": 100,
            "interval": 30,
        }
    })
    
    if result is ClientResponseError:
        push_error("Failed to update settings: " + result.to_string())
        return
    
    print("Application settings updated")
    
    # Configure trusted proxy
    var proxy_result = await pb.settings.update_trusted_proxy({
        "headers": ["X-Forwarded-For", "X-Real-IP"],
        "useLeftmostIP": true,
    })
    
    if proxy_result is ClientResponseError:
        push_error("Failed to configure proxy: " + proxy_result.to_string())
        return
    
    print("Trusted proxy configured")
```

---

## Error Handling

All management API methods can return `ClientResponseError`. Always handle errors appropriately:

```gdscript
var result = await pb.backups.create("my-backup")
if result is ClientResponseError:
    match result.status:
        401:
            push_error("Authentication required")
        403:
            push_error("Superuser access required")
        _:
            push_error("Error: " + result.to_string())
else:
    print("Backup created successfully")
```

---

## Notes

1. **Authentication**: All management API operations require superuser authentication. Use `pb.admins().auth_with_password()` to authenticate.

2. **Rate Limiting**: Be mindful of rate limits when making multiple management API calls.

3. **Backup Safety**: Always test backup restoration in a safe environment before using in production.

4. **Log Retention**: Setting appropriate log retention helps manage storage usage.

5. **Cron Jobs**: Manual cron execution is useful for testing but should be used carefully in production.

For more information on specific services, see:
- [Backups API](./BACKUPS_API.md) - Detailed backup operations
- [Logs API](./LOGS_API.md) - Detailed log operations
- [Collections API](./COLLECTION_API.md) - Collection management
- [Crons API](./CRONS_API.md) - Cron job management
- [Health API](./HEALTH_API.md) - Health check operations
