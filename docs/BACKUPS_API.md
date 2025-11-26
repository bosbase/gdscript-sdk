# Backups API - GDScript SDK Documentation

## Overview

The Backups API provides endpoints for managing application data backups. You can create backups, upload existing backup files, download backups, delete backups, and restore the application from a backup.

**Key Features:**
- List all available backup files
- Create new backups with custom names or auto-generated names
- Upload existing backup ZIP files
- Download backup files (requires file token)
- Delete backup files
- Restore the application from a backup (restarts the app)

**Backend Endpoints:**
- `GET /api/backups` - List backups
- `POST /api/backups` - Create backup
- `POST /api/backups/upload` - Upload backup
- `GET /api/backups/{key}` - Download backup
- `DELETE /api/backups/{key}` - Delete backup
- `POST /api/backups/{key}/restore` - Restore backup

**Note**: All Backups API operations require superuser authentication (except download which requires a superuser file token).

## Authentication

All Backups API operations require superuser authentication:

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://127.0.0.1:8090")

# Authenticate as superuser
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return
```

**Downloading backups** requires a superuser file token (obtained via `pb.files.get_token()`), but does not require the Authorization header.

## Backup File Structure

Each backup file contains:
- `key`: The filename/key of the backup file (string)
- `size`: File size in bytes (number)
- `modified`: ISO 8601 timestamp of when the backup was last modified (string)

```gdscript
{
    "key": "pb_backup_20230519162514.zip",
    "size": 1048576,
    "modified": "2023-05-19T16:25:57.542Z"
}
```

## List Backups

Returns a list of all available backup files with their metadata.

### Basic Usage

```gdscript
# Get all backups
var backups = await pb.backups.get_full_list()

if backups is ClientResponseError:
    push_error("Failed to get backups: " + backups.to_string())
    return

print(backups)
# [
#   {
#     "key": "pb_backup_20230519162514.zip",
#     "modified": "2023-05-19T16:25:57.542Z",
#     "size": 1048576
#   },
#   {
#     "key": "pb_backup_20230518162514.zip",
#     "modified": "2023-05-18T16:25:57.542Z",
#     "size": 2097152
#   }
# ]
```

### Working with Backup Lists

```gdscript
# Sort backups by modification date (newest first)
var backups = await pb.backups.get_full_list()
if backups is ClientResponseError:
    push_error("Failed to get backups: " + backups.to_string())
    return

# Sort by modified date (newest first)
backups.sort_custom(func(a, b):
    var time_a = Time.get_unix_time_from_datetime_string(a.modified)
    var time_b = Time.get_unix_time_from_datetime_string(b.modified)
    return time_b - time_a
)

# Find the most recent backup
var most_recent = backups[0] if backups.size() > 0 else null

# Filter backups by size (larger than 100MB)
var large_backups = []
for backup in backups:
    if backup.size > 100 * 1024 * 1024:
        large_backups.append(backup)

# Get total storage used by backups
var total_size = 0
for backup in backups:
    total_size += backup.size

var total_size_mb = float(total_size) / 1024.0 / 1024.0
print("Total backup storage: %.2f MB" % total_size_mb)
```

## Create Backup

Creates a new backup of the application data. The backup process is asynchronous and may take some time depending on the size of your data.

### Basic Usage

```gdscript
# Create backup with custom name
var result = await pb.backups.create("my_backup_2024.zip")
if result is ClientResponseError:
    push_error("Failed to create backup: " + result.to_string())
    return

# Create backup with auto-generated name (pass empty string or let backend generate)
var result2 = await pb.backups.create("")
if result2 is ClientResponseError:
    push_error("Failed to create backup: " + result2.to_string())
```

### Backup Name Format

Backup names must follow the format: `[a-z0-9_-].zip`
- Only lowercase letters, numbers, underscores, and hyphens
- Must end with ".zip"
- Maximum length: 150 characters
- Must be unique (no existing backup with the same name)

### Examples

```gdscript
# Create a named backup
func create_named_backup(name: String) -> void:
    var result = await pb.backups.create(name)
    if result is ClientResponseError:
        if result.status == 400:
            push_error("Invalid backup name or backup already exists")
        else:
            push_error("Failed to create backup: " + result.to_string())
        return
    
    print("Backup \"%s\" creation initiated" % name)

# Create backup with timestamp
func create_timestamped_backup() -> String:
    var datetime = Time.get_datetime_string_from_system(false)
    # Replace colons and dots with hyphens
    datetime = datetime.replace(":", "-").replace(".", "-")
    var name = "backup_%s.zip" % datetime.substr(0, 19)
    await pb.backups.create(name)
    return name
```

### Important Notes

- **Asynchronous Process**: Backup creation happens in the background. The API returns immediately (204 No Content).
- **Concurrent Operations**: Only one backup or restore operation can run at a time. If another operation is in progress, you'll receive a 400 error.
- **Storage**: Backups are stored in the configured backup filesystem (local or S3).
- **S3 Consistency**: For S3 storage, the backup file may not be immediately available after creation due to eventual consistency.

## Upload Backup

Uploads an existing backup ZIP file to the server. This is useful for restoring backups created elsewhere or for importing backups.

### Basic Usage

```gdscript
# Upload from a file path
func upload_backup_file(file_path: String) -> void:
    var file = FileAccess.open(file_path, FileAccess.READ)
    if file == null:
        push_error("Failed to open file: " + file_path)
        return
    
    var file_data = file.get_buffer(file.get_length())
    file.close()
    
    # Extract filename from path
    var filename = file_path.get_file()
    
    # Upload the backup
    var files = {
        "file": {
            "filename": filename,
            "content_type": "application/zip",
            "data": file_data
        }
    }
    
    var result = await pb.backups.upload(files)
    if result is ClientResponseError:
        push_error("Upload failed: " + result.to_string())
        return
    
    print("Backup uploaded successfully")
```

### File Requirements

- **MIME Type**: Must be "application/zip"
- **Format**: Must be a valid ZIP archive
- **Name**: Must be unique (no existing backup with the same name)
- **Validation**: The file will be validated before upload

### Examples

```gdscript
# Upload backup from file path
func upload_backup_from_path(file_path: String) -> void:
    var file = FileAccess.open(file_path, FileAccess.READ)
    if file == null:
        push_error("Failed to open file")
        return
    
    var file_data = file.get_buffer(file.get_length())
    file.close()
    
    var files = {
        "file": {
            "filename": file_path.get_file(),
            "content_type": "application/zip",
            "data": file_data
        }
    }
    
    var result = await pb.backups.upload(files)
    if result is ClientResponseError:
        if result.status == 400:
            push_error("Invalid file or file already exists")
        else:
            push_error("Upload failed: " + result.to_string())
        return
    
    print("Backup uploaded successfully")
```

## Download Backup

Downloads a backup file. Requires a superuser file token for authentication.

### Basic Usage

```gdscript
# Get file token
var token = await pb.files.get_token()
if token is ClientResponseError:
    push_error("Failed to get token: " + token.to_string())
    return

# Build download URL
var url = pb.backups.get_download_url(token, "pb_backup_20230519162514.zip")

# Download the file using HTTPRequest
var http_request = HTTPRequest.new()
add_child(http_request)
http_request.request_completed.connect(_on_backup_downloaded)
http_request.request(url)
```

### Download URL Structure

The download URL format is:
```
/api/backups/{key}?token={fileToken}
```

### Examples

```gdscript
func download_backup(backup_key: String, save_path: String) -> void:
    # Get file token (valid for short period)
    var token = await pb.files.get_token()
    if token is ClientResponseError:
        push_error("Failed to get file token: " + token.to_string())
        return
    
    # Build download URL
    var url = pb.backups.get_download_url(token, backup_key)
    
    # Download using HTTPRequest
    var http_request = HTTPRequest.new()
    add_child(http_request)
    http_request.set_meta("save_path", save_path)
    http_request.request_completed.connect(_on_backup_downloaded)
    http_request.request(url)

func _on_backup_downloaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if response_code == 200:
        var save_path = get_meta("save_path", "")
        var file = FileAccess.open(save_path, FileAccess.WRITE)
        if file:
            file.store_buffer(body)
            file.close()
            print("Backup downloaded successfully to: ", save_path)
        else:
            push_error("Failed to write file")
    else:
        push_error("Download failed with code: ", response_code)
```

## Delete Backup

Deletes a backup file from the server.

### Basic Usage

```gdscript
var result = await pb.backups.delete("pb_backup_20230519162514.zip")
if result is ClientResponseError:
    push_error("Failed to delete backup: " + result.to_string())
```

### Important Notes

- **Active Backups**: Cannot delete a backup that is currently being created or restored
- **No Undo**: Deletion is permanent
- **File System**: The file will be removed from the backup filesystem

### Examples

```gdscript
# Delete backup with confirmation
func delete_backup_with_confirmation(backup_key: String) -> void:
    # In a real application, you would show a confirmation dialog
    var confirmed = true  # Replace with actual confirmation dialog
    
    if not confirmed:
        return
    
    var result = await pb.backups.delete(backup_key)
    if result is ClientResponseError:
        if result.status == 400:
            push_error("Backup is currently in use and cannot be deleted")
        elif result.status == 404:
            push_error("Backup not found")
        else:
            push_error("Failed to delete backup: " + result.to_string())
        return
    
    print("Backup deleted successfully")

# Delete old backups (older than 30 days)
func delete_old_backups() -> void:
    var backups = await pb.backups.get_full_list()
    if backups is ClientResponseError:
        push_error("Failed to get backups: " + backups.to_string())
        return
    
    var thirty_days_ago = Time.get_unix_time_from_system() - (30 * 24 * 60 * 60)
    
    for backup in backups:
        var modified_time = Time.get_unix_time_from_datetime_string(backup.modified)
        if modified_time < thirty_days_ago:
            var result = await pb.backups.delete(backup.key)
            if result is ClientResponseError:
                push_error("Failed to delete %s: %s" % [backup.key, result.to_string()])
            else:
                print("Deleted old backup: ", backup.key)
```

## Restore Backup

Restores the application from a backup file. **This operation will restart the application**.

### Basic Usage

```gdscript
var result = await pb.backups.restore("pb_backup_20230519162514.zip")
if result is ClientResponseError:
    push_error("Failed to restore backup: " + result.to_string())
```

### Important Warnings

⚠️ **CRITICAL**: Restoring a backup will:
1. Replace all current application data with data from the backup
2. **Restart the application process**
3. Any unsaved changes will be lost
4. The application will be unavailable during the restore process

### Prerequisites

- **Disk Space**: Recommended to have at least **2x the backup size** in free disk space
- **UNIX Systems**: Restore is primarily supported on UNIX-based systems (Linux, macOS)
- **No Concurrent Operations**: Cannot restore if another backup or restore is in progress
- **Backup Existence**: The backup file must exist on the server

### Restore Process

The restore process performs the following steps:
1. Downloads the backup file to a temporary location
2. Extracts the backup to a temporary directory
3. Moves current "pb_data" content to a temporary location (to be deleted on next app start)
4. Moves extracted backup content to "pb_data"
5. Restarts the application

### Examples

```gdscript
# Restore backup with confirmation
func restore_backup_with_confirmation(backup_key: String) -> void:
    # In a real application, you would show a warning dialog
    var confirmed = true  # Replace with actual confirmation dialog
    
    if not confirmed:
        return
    
    var result = await pb.backups.restore(backup_key)
    if result is ClientResponseError:
        if result.status == 400:
            if "another backup/restore" in result.to_string():
                push_error("Another backup or restore operation is in progress")
            else:
                push_error("Invalid or missing backup file")
        else:
            push_error("Failed to restore backup: " + result.to_string())
        return
    
    print("Restore initiated. Application will restart...")
```

## Complete Examples

### Example 1: Backup Manager Class

```gdscript
class_name BackupManager

var pb: BosBase

func list() -> Array:
    var backups = await pb.backups.get_full_list()
    if backups is ClientResponseError:
        push_error("Failed to get backups: " + backups.to_string())
        return []
    
    # Sort by modified date (newest first)
    backups.sort_custom(func(a, b):
        var time_a = Time.get_unix_time_from_datetime_string(a.modified)
        var time_b = Time.get_unix_time_from_datetime_string(b.modified)
        return time_b - time_a
    )
    
    return backups

func create(name: String = "") -> String:
    if name.is_empty():
        var datetime = Time.get_datetime_string_from_system(false)
        datetime = datetime.replace(":", "-").replace(".", "-")
        name = "backup_%s.zip" % datetime.substr(0, 19)
    
    await pb.backups.create(name)
    return name

func download(key: String) -> String:
    var token = await pb.files.get_token()
    if token is ClientResponseError:
        push_error("Failed to get token: " + token.to_string())
        return ""
    
    return pb.backups.get_download_url(token, key)

func delete_backup(key: String) -> void:
    await pb.backups.delete(key)

func restore_backup(key: String) -> bool:
    await pb.backups.restore(key)
    return true

func cleanup(days_old: int = 30) -> int:
    var backups = await list()
    var cutoff = Time.get_unix_time_from_system() - (days_old * 24 * 60 * 60)
    
    var deleted_count = 0
    for backup in backups:
        var modified_time = Time.get_unix_time_from_datetime_string(backup.modified)
        if modified_time < cutoff:
            var result = await pb.backups.delete(backup.key)
            if not result is ClientResponseError:
                deleted_count += 1
                print("Deleted: ", backup.key)
    
    return deleted_count

# Usage
var manager = BackupManager.new()
manager.pb = pb
var backups = await manager.list()
await manager.create("weekly_backup.zip")
```

### Example 2: Automated Backup Strategy

```gdscript
class_name AutomatedBackup

var pb: BosBase
var strategy: String = "daily"  # 'daily', 'weekly', 'monthly'
var max_backups: int = 7  # Keep last 7 backups

func create_scheduled_backup() -> void:
    var name = generate_backup_name()
    var result = await pb.backups.create(name)
    if result is ClientResponseError:
        push_error("Backup creation failed: " + result.to_string())
        return
    
    print("Created backup: ", name)
    await cleanup_old_backups()

func generate_backup_name() -> String:
    var now = Time.get_datetime_dict_from_system(false)
    
    if strategy == "daily":
        return "daily_%04d-%02d-%02d.zip" % [now.year, now.month, now.day]
    elif strategy == "weekly":
        var week = ceil(now.day / 7.0)
        return "weekly_%04d_W%02d.zip" % [now.year, week]
    else:  # monthly
        return "monthly_%04d_%02d.zip" % [now.year, now.month]

func cleanup_old_backups() -> void:
    var backups = await pb.backups.get_full_list()
    if backups is ClientResponseError:
        return
    
    # Sort by modified date (newest first)
    backups.sort_custom(func(a, b):
        var time_a = Time.get_unix_time_from_datetime_string(a.modified)
        var time_b = Time.get_unix_time_from_datetime_string(b.modified)
        return time_b - time_a
    )
    
    if backups.size() > max_backups:
        var to_delete = backups.slice(max_backups)
        for backup in to_delete:
            await pb.backups.delete(backup.key)
            print("Cleaned up old backup: ", backup.key)
```

## Error Handling

```gdscript
func handle_backup_error(operation: String, args: Array) -> void:
    var result
    match operation:
        "create":
            result = await pb.backups.create(args[0])
        "delete":
            result = await pb.backups.delete(args[0])
        "restore":
            result = await pb.backups.restore(args[0])
        _:
            push_error("Unknown operation: " + operation)
            return
    
    if result is ClientResponseError:
        match result.status:
            400:
                if "already exists" in result.to_string():
                    push_error("Backup with this name already exists")
                else:
                    push_error("Invalid request: " + result.to_string())
            401:
                push_error("Not authenticated")
            403:
                push_error("Not a superuser")
            404:
                push_error("Backup not found")
            _:
                push_error("Unexpected error: " + result.to_string())
```

## Best Practices

1. **Regular Backups**: Create backups regularly (daily, weekly, or based on your needs)
2. **Naming Convention**: Use clear, consistent naming (e.g., `backup_YYYY-MM-DD.zip`)
3. **Backup Rotation**: Implement cleanup to remove old backups and prevent storage issues
4. **Test Restores**: Periodically test restoring backups to ensure they work
5. **Off-site Storage**: Download and store backups in a separate location
6. **Pre-Restore Backup**: Always create a backup before restoring (if possible)
7. **Monitor Storage**: Monitor backup storage usage to prevent disk space issues
8. **Documentation**: Document your backup and restore procedures
9. **Automation**: Use cron jobs or schedulers for automated backups
10. **Verification**: Verify backup integrity after creation/download

## Limitations

- **Superuser Only**: All operations require superuser authentication
- **Concurrent Operations**: Only one backup or restore can run at a time
- **Restore Restart**: Restoring a backup restarts the application
- **UNIX Systems**: Restore primarily works on UNIX-based systems
- **Disk Space**: Restore requires significant free disk space (2x backup size recommended)
- **S3 Consistency**: S3 backups may not be immediately available after creation
- **Active Backups**: Cannot delete backups that are currently being created or restored

## Related Documentation

- [File API](./FILE_API.md) - File handling and tokens
- [Crons API](./CRONS_API.md) - Automated backup scheduling
- [Collection API](./COLLECTION_API.md) - Collection management
