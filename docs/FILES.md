# Files Upload and Handling - GDScript SDK Documentation

## Overview

BosBase allows you to upload and manage files through file fields in your collections. Files are stored with sanitized names and a random suffix for security (e.g., "test_52iwbgds7l.png").

**Key Features:**
- Upload multiple files per field
- Maximum file size: ~8GB (2^53-1 bytes)
- Automatic filename sanitization and random suffix
- Image thumbnails support
- Protected files with token-based access
- File modifiers for append/prepend/delete operations

**Backend Endpoints:**
- `POST /api/files/token` - Get file access token for protected files
- `GET /api/files/{collection}/{recordId}/{filename}` - Download file

## File Field Configuration

Before uploading files, you must add a file field to your collection:

```gdscript
var collection = await pb.collections.get_one("example")

collection.fields.append({
    "name": "documents",
    "type": "file",
    "maxSelect": 5,        # Maximum number of files (1 for single file)
    "maxSize": 5242880,    # 5MB in bytes (optional, default: 5MB)
    "mimeTypes": ["image/jpeg", "image/png", "application/pdf"],
    "thumbs": ["100x100", "300x300"],  # Thumbnail sizes for images
    "protected": false
})

await pb.collections.update("example", { "fields": collection.fields })
```

## Uploading Files

### Basic Upload with Create

When creating a new record, you can upload files directly:

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

# Read file from disk
var file_path = "res://path/to/file.jpg"
var file = FileAccess.open(file_path, FileAccess.READ)
if file == null:
    push_error("Failed to open file")
    return

var file_data = file.get_buffer(file.get_length())
file.close()

# Prepare files dictionary
var files = {
    "documents": {
        "filename": "file.jpg",
        "content_type": "image/jpeg",
        "data": file_data  # PackedByteArray
    }
}

# Create record with file
var created_record = await pb.collection("example").create({
    "title": "Hello world!"
}, {}, files)
```

### Upload with Update

```gdscript
# Read file
var file = FileAccess.open("res://path/to/file3.txt", FileAccess.READ)
var file_data = file.get_buffer(file.get_length())
file.close()

# Update record and upload new files
var files = {
    "documents": {
        "filename": "file3.txt",
        "content_type": "text/plain",
        "data": file_data
    }
}

var updated_record = await pb.collection("example").update("RECORD_ID", {
    "title": "Updated title"
}, {}, files)
```

### Append Files (Using + Modifier)

For multiple file fields, use the "+" modifier to append files:

```gdscript
# Append files to existing ones
var file = FileAccess.open("res://path/to/file4.txt", FileAccess.READ)
var file_data = file.get_buffer(file.get_length())
file.close()

var files = {
    "documents+": {
        "filename": "file4.txt",
        "content_type": "text/plain",
        "data": file_data
    }
}

await pb.collection("example").update("RECORD_ID", {}, {}, files)
```

### Upload Multiple Files

```gdscript
# Prepare multiple files
var files = {
    "documents": [
        {
            "filename": "file1.txt",
            "content_type": "text/plain",
            "data": file_data_1
        },
        {
            "filename": "file2.pdf",
            "content_type": "application/pdf",
            "data": file_data_2
        }
    ]
}

await pb.collection("example").update("RECORD_ID", {
    "title": "Updated"
}, {}, files)
```

## Deleting Files

### Delete All Files

```gdscript
# Delete all files in a field (set to empty array)
await pb.collection("example").update("RECORD_ID", {
    "documents": []
})
```

### Delete Specific Files (Using - Modifier)

```gdscript
# Delete individual files by filename
await pb.collection("example").update("RECORD_ID", {
    "documents-": ["file1.pdf", "file2.txt"]
})
```

## File URLs

### Get File URL

Each uploaded file can be accessed via its URL:

```
http://localhost:8090/api/files/COLLECTION_ID_OR_NAME/RECORD_ID/FILENAME
```

**Using SDK:**

```gdscript
var record = await pb.collection("example").get_one("RECORD_ID")

# Single file field (returns string)
var filename = record.documents
var url = pb.files.get_url(record, filename)

# Multiple file field (returns array)
var first_file = record.documents[0]
var url = pb.files.get_url(record, first_file)
```

### Image Thumbnails

If your file field has thumbnail sizes configured, you can request thumbnails:

```gdscript
var record = await pb.collection("example").get_one("RECORD_ID")
var filename = record.avatar  # Image file

# Get thumbnail with specific size
var thumb_url = pb.files.get_url(record, filename, {
    "thumb": "100x100"
})
```

**Thumbnail Formats:**

- `WxH` (e.g., "100x300") - Crop to WxH viewbox from center
- `WxHt` (e.g., "100x300t") - Crop to WxH viewbox from top
- `WxHb` (e.g., "100x300b") - Crop to WxH viewbox from bottom
- `WxHf` (e.g., "100x300f") - Fit inside WxH viewbox (no cropping)
- `0xH` (e.g., "0x300") - Resize to H height, preserve aspect ratio
- `Wx0` (e.g., "100x0") - Resize to W width, preserve aspect ratio

**Supported Image Formats:**
- JPEG (".jpg", ".jpeg")
- PNG (".png")
- GIF (".gif" - first frame only)
- WebP (".webp" - stored as PNG)

**Example:**

```gdscript
var record = await pb.collection("products").get_one("PRODUCT_ID")
var image = record.image

# Different thumbnail sizes
var thumb_small = pb.files.get_url(record, image, { "thumb": "100x100" })
var thumb_medium = pb.files.get_url(record, image, { "thumb": "300x300" })
var thumb_large = pb.files.get_url(record, image, { "thumb": "800x600f" })
var thumb_height = pb.files.get_url(record, image, { "thumb": "0x300" })
var thumb_width = pb.files.get_url(record, image, { "thumb": "100x0" })
```

### Force Download

To force download instead of preview:

```gdscript
var url = pb.files.get_url(record, filename, {
    "download": true
})
```

## Protected Files

By default, all files are publicly accessible if you know the full URL. For sensitive files, you can mark the field as "Protected" in the collection settings.

### Setting Up Protected Files

```gdscript
var collection = await pb.collections.get_one("example")

# Find and update file field
for field in collection.fields:
    if field.name == "documents":
        field.protected = true
        break

await pb.collections.update("example", { "fields": collection.fields })
```

### Accessing Protected Files

Protected files require authentication and a file token:

```gdscript
# Step 1: Authenticate
await pb.collection("users").auth_with_password("user@example.com", "password123")

# Step 2: Get file token (valid for ~2 minutes)
var file_token = await pb.files.get_token()

# Step 3: Get protected file URL with token
var record = await pb.collection("example").get_one("RECORD_ID")
var url = pb.files.get_url(record, record.private_document, {
    "token": file_token.token
})

# Use the URL (e.g., load into Texture2D or download)
```

**Important:**
- File tokens are short-lived (~2 minutes)
- Only authenticated users satisfying the collection's "viewRule" can access protected files
- Tokens must be regenerated when they expire

### Complete Protected File Example

```gdscript
func load_protected_image(record_id: String, filename: String) -> String:
    # Check if authenticated
    if not pb.auth_store.is_valid:
        push_error("Not authenticated")
        return ""

    # Get fresh token
    var token_result = await pb.files.get_token()
    if token_result is ClientResponseError:
        push_error("Failed to get file token: " + token_result.to_string())
        return ""

    # Get file URL
    var record = await pb.collection("example").get_one(record_id)
    if record is ClientResponseError:
        push_error("Failed to get record: " + record.to_string())
        return ""

    var url = pb.files.get_url(record, filename, { "token": token_result.token })
    return url
```

## Complete Examples

### Example 1: Image Upload with Thumbnails

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error(auth.to_string())
    return

# Create collection with image field and thumbnails
var collection = await pb.collections.create_base("products", {
    "fields": [
        { "name": "name", "type": "text", "required": true },
        {
            "name": "image",
            "type": "file",
            "maxSelect": 1,
            "mimeTypes": ["image/jpeg", "image/png"],
            "thumbs": ["100x100", "300x300", "800x600f"]  # Thumbnail sizes
        }
    ]
})

# Read image file
var image_path = "res://product.jpg"
var file = FileAccess.open(image_path, FileAccess.READ)
var image_data = file.get_buffer(file.get_length())
file.close()

# Upload product with image
var files = {
    "image": {
        "filename": "product.jpg",
        "content_type": "image/jpeg",
        "data": image_data
    }
}

var product = await pb.collection("products").create({
    "name": "My Product"
}, {}, files)

# Display thumbnail in UI
var thumbnail_url = pb.files.get_url(product, product.image, {
    "thumb": "100x100"
})

# Load texture from URL in Godot
# var texture = await load_texture_from_url(thumbnail_url)
```

### Example 2: Multiple File Upload

```gdscript
func upload_multiple_files(file_paths: Array) -> void:
    var files = {}
    var file_list = []
    
    for file_path in file_paths:
        var file = FileAccess.open(file_path, FileAccess.READ)
        if file == null:
            push_error("Failed to open file: " + file_path)
            continue
        
        var file_data = file.get_buffer(file.get_length())
        file.close()
        
        var extension = file_path.get_extension()
        var content_type = "application/octet-stream"
        match extension:
            "jpg", "jpeg":
                content_type = "image/jpeg"
            "png":
                content_type = "image/png"
            "pdf":
                content_type = "application/pdf"
        
        file_list.append({
            "filename": file_path.get_file(),
            "content_type": content_type,
            "data": file_data
        })
    
    files["documents"] = file_list
    
    var result = await pb.collection("example").create({
        "title": "Document Set"
    }, {}, files)
    
    if result is ClientResponseError:
        push_error("Upload failed: " + result.to_string())
    else:
        print("Uploaded files: ", result.documents)
```

### Example 3: File Management

```gdscript
class_name FileManager

var collection_id: String
var record_id: String
var record: Dictionary

func _init(collection_id: String, record_id: String) -> void:
    self.collection_id = collection_id
    self.record_id = record_id

func load_record() -> void:
    var result = await pb.collection(collection_id).get_one(record_id)
    if result is ClientResponseError:
        push_error("Failed to load record: " + result.to_string())
        return
    record = result

func delete_file(filename: String) -> void:
    await pb.collection(collection_id).update(record_id, {
        "documents-": [filename]
    })
    await load_record()  # Reload

func add_files(file_dict: Dictionary) -> void:
    # file_dict should be in format: { "documents+": {...} } or { "documents": [...] }
    await pb.collection(collection_id).update(record_id, {}, {}, file_dict)
    await load_record()  # Reload

func get_file_url(filename: String, thumb: String = "") -> String:
    var options = {}
    if thumb != "":
        options["thumb"] = thumb
    return pb.files.get_url(record, filename, options)
```

### Example 4: Protected Document Viewer

```gdscript
func view_protected_document(record_id: String, filename: String) -> String:
    # Authenticate if needed
    if not pb.auth_store.is_valid:
        var auth = await pb.collection("users").auth_with_password("user@example.com", "pass")
        if auth is ClientResponseError:
            push_error("Authentication failed: " + auth.to_string())
            return ""

    # Get token
    var token_result = await pb.files.get_token()
    if token_result is ClientResponseError:
        push_error("Failed to get file token: " + token_result.to_string())
        return ""

    # Get record and file URL
    var record = await pb.collection("documents").get_one(record_id)
    if record is ClientResponseError:
        push_error("Failed to get record: " + record.to_string())
        return ""

    var url = pb.files.get_url(record, filename, { "token": token_result.token })
    return url
```

### Example 5: Image Gallery with Thumbnails

```gdscript
func display_image_gallery(record_id: String) -> Array:
    var record = await pb.collection("gallery").get_one(record_id)
    if record is ClientResponseError:
        push_error("Failed to load gallery: " + record.to_string())
        return []
    
    var images = record.images  # Array of filenames
    var gallery_urls = []
    
    for filename in images:
        # Thumbnail for grid view
        var thumb_url = pb.files.get_url(record, filename, {
            "thumb": "200x200"
        })
        
        # Full size for detail view
        var full_url = pb.files.get_url(record, filename)
        
        gallery_urls.append({
            "thumb": thumb_url,
            "full": full_url,
            "filename": filename
        })
    
    return gallery_urls
```

## File Field Modifiers

### Summary

- **No modifier** - Replace all files: `"documents": [file1, file2]`
- **"+" suffix** - Append files: `"documents+": file3`
- **"-" suffix** - Delete files: `"documents-": ["file1.pdf"]`

## Best Practices

1. **File Size Limits**: Always validate file sizes on the client before upload
2. **MIME Types**: Configure allowed MIME types in collection field settings
3. **Thumbnails**: Pre-generate common thumbnail sizes for better performance
4. **Protected Files**: Use protected files for sensitive documents (ID cards, contracts)
5. **Token Refresh**: Refresh file tokens before they expire for protected files
6. **Error Handling**: Handle 404 errors for missing files and 401 for protected file access
7. **Filename Sanitization**: Files are automatically sanitized, but validate on client side too

## Error Handling

```gdscript
var file = FileAccess.open("res://test.txt", FileAccess.READ)
var file_data = file.get_buffer(file.get_length())
file.close()

var files = {
    "documents": {
        "filename": "test.txt",
        "content_type": "text/plain",
        "data": file_data
    }
}

var result = await pb.collection("example").create({
    "title": "Test"
}, {}, files)

if result is ClientResponseError:
    if result.status == 413:
        push_error("File too large")
    elif result.status == 400:
        push_error("Invalid file type or field validation failed")
    elif result.status == 403:
        push_error("Insufficient permissions")
    else:
        push_error("Upload failed: " + result.to_string())
```

## Storage Options

By default, BosBase stores files in `pb_data/storage` on the local filesystem. For production, you can configure S3-compatible storage (AWS S3, MinIO, Wasabi, DigitalOcean Spaces, etc.) from:
**Dashboard > Settings > Files storage**

This is configured server-side and doesn't require SDK changes.

## Related Documentation

- [Collections](./COLLECTIONS.md) - Collection and field configuration
- [Authentication](./AUTHENTICATION.md) - Required for protected files
