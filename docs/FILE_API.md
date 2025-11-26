# File API - GDScript SDK Documentation

## Overview

The File API provides endpoints for downloading and accessing files stored in collection records. It supports thumbnail generation for images, protected file access with tokens, and force download options.

**Key Features:**
- Download files from collection records
- Generate thumbnails for images (crop, fit, resize)
- Protected file access with short-lived tokens
- Force download option for any file type
- Automatic content-type detection
- Support for Range requests and caching

**Backend Endpoints:**
- `GET /api/files/{collection}/{recordId}/{filename}` - Download/fetch file
- `POST /api/files/token` - Generate protected file token

## Download / Fetch File

Downloads a single file resource from a record.

### Basic Usage

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://127.0.0.1:8090")

# Get a record with a file field
var record = await pb.collection("posts").get_one("RECORD_ID")

if record is ClientResponseError:
    push_error("Failed to get record: " + record.to_string())
    return

# Get the file URL
var file_url = pb.files.get_url(record, record.get("image", ""))

# In GDScript/Godot, you would typically use an HTTPRequest node
# or download the file using HTTPClient
print("File URL: ", file_url)
```

### File URL Structure

The file URL follows this pattern:

```
/api/files/{collectionIdOrName}/{recordId}/{filename}
```

Example:
```
http://127.0.0.1:8090/api/files/posts/abc123/photo_xyz789.jpg
```

### Downloading Files in GDScript

```gdscript
func download_file(file_url: String, save_path: String) -> void:
    var http_request = HTTPRequest.new()
    add_child(http_request)
    
    http_request.request_completed.connect(_on_file_downloaded)
    http_request.request(file_url)
    
    # Store save path for later use
    http_request.set_meta("save_path", save_path)

func _on_file_downloaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if response_code == 200:
        var save_path = get_meta("save_path", "")
        var file = FileAccess.open(save_path, FileAccess.WRITE)
        if file:
            file.store_buffer(body)
            file.close()
            print("File downloaded successfully")
        else:
            push_error("Failed to write file")
    else:
        push_error("Download failed with code: ", response_code)
```

## Thumbnails

Generate thumbnails for image files on-the-fly.

### Thumbnail Formats

The following thumbnail formats are supported:

| Format | Example | Description |
|--------|---------|-------------|
| `WxH` | `100x300` | Crop to WxH viewbox (from center) |
| `WxHt` | `100x300t` | Crop to WxH viewbox (from top) |
| `WxHb` | `100x300b` | Crop to WxH viewbox (from bottom) |
| `WxHf` | `100x300f` | Fit inside WxH viewbox (without cropping) |
| `0xH` | `0x300` | Resize to H height preserving aspect ratio |
| `Wx0` | `100x0` | Resize to W width preserving aspect ratio |

### Using Thumbnails

```gdscript
# Get thumbnail URL
var thumb_url = pb.files.get_url(record, record.get("image", ""), {
    "thumb": "100x100"
})

# Different thumbnail sizes
var small_thumb = pb.files.get_url(record, record.get("image", ""), {
    "thumb": "100x100"
})

var medium_thumb = pb.files.get_url(record, record.get("image", ""), {
    "thumb": "300x300"
})

var large_thumb = pb.files.get_url(record, record.get("image", ""), {
    "thumb": "800x800"
})

# Fit thumbnail (no cropping)
var fit_thumb = pb.files.get_url(record, record.get("image", ""), {
    "thumb": "300x300f"
})

# Resize to specific width
var width_thumb = pb.files.get_url(record, record.get("image", ""), {
    "thumb": "400x0"
})

# Resize to specific height
var height_thumb = pb.files.get_url(record, record.get("image", ""), {
    "thumb": "0x400"
})
```

### Thumbnail Behavior

- **Image Files Only**: Thumbnails are only generated for image files (PNG, JPG, JPEG, GIF, WEBP)
- **Non-Image Files**: For non-image files, the thumb parameter is ignored and the original file is returned
- **Caching**: Thumbnails are cached and reused if already generated
- **Fallback**: If thumbnail generation fails, the original file is returned
- **Field Configuration**: Thumb sizes must be defined in the file field's "thumbs" option or use default "100x100"

## Protected Files

Protected files require a special token for access, even if you're authenticated.

### Getting a File Token

```gdscript
# Must be authenticated first
var auth = await pb.collection("users").auth_with_password("user@example.com", "password")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return

# Get file token
var token = await pb.files.get_token()

if token is ClientResponseError:
    push_error("Failed to get token: " + token.to_string())
    return

print("Token: ", token)  # Short-lived JWT token
```

### Using Protected File Token

```gdscript
# Get protected file URL with token
var protected_file_url = pb.files.get_url(record, record.get("document", ""), {
    "token": token
})

# In GDScript, you would download the file using HTTPRequest with the URL
print("Protected file URL: ", protected_file_url)
```

### Protected File Example

```gdscript
func display_protected_image(record_id: String) -> void:
    # Authenticate
    var auth = await pb.collection("users").auth_with_password("user@example.com", "password")
    if auth is ClientResponseError:
        push_error("Authentication failed: " + auth.to_string())
        return
    
    # Get record
    var record = await pb.collection("documents").get_one(record_id)
    if record is ClientResponseError:
        push_error("Failed to get record: " + record.to_string())
        return
    
    # Get file token
    var token = await pb.files.get_token()
    if token is ClientResponseError:
        push_error("Failed to get file token: " + token.to_string())
        return
    
    # Get protected file URL
    var image_url = pb.files.get_url(record, record.get("thumbnail", ""), {
        "token": token,
        "thumb": "300x300"
    })
    
    # In Godot, you would load the image using HTTPRequest
    # and display it using a TextureRect or Sprite2D
    print("Image URL: ", image_url)
```

### Token Lifetime

- File tokens are short-lived (typically expires after a few minutes)
- Tokens are associated with the authenticated user/superuser
- Generate a new token if the previous one expires

## Force Download

Force files to download instead of being displayed in the browser.

```gdscript
# Force download
var download_url = pb.files.get_url(record, record.get("document", ""), {
    "download": true
})

# In GDScript, use HTTPRequest to download the file
print("Download URL: ", download_url)
```

### Download Parameter Values

```gdscript
# These all force download:
pb.files.get_url(record, filename, { "download": true })
pb.files.get_url(record, filename, { "download": 1 })
pb.files.get_url(record, filename, { "download": "1" })

# These allow inline display (default):
pb.files.get_url(record, filename, { "download": false })
pb.files.get_url(record, filename, { "download": 0 })
pb.files.get_url(record, filename)  # No download parameter
```

## Complete Examples

### Example 1: Loading an Image into a TextureRect

```gdscript
extends TextureRect

var pb: BosBase

func load_image_from_record(record_id: String, field_name: String) -> void:
    # Get record
    var record = await pb.collection("posts").get_one(record_id)
    if record is ClientResponseError:
        push_error("Failed to get record: " + record.to_string())
        return
    
    # Get image URL
    var image_url = pb.files.get_url(record, record.get(field_name, ""))
    
    # Load image using HTTPRequest
    var http_request = HTTPRequest.new()
    add_child(http_request)
    http_request.request_completed.connect(_on_image_loaded.bind())
    http_request.request(image_url)

func _on_image_loaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if response_code == 200:
        var image = Image.new()
        var error = image.load_png_from_buffer(body)
        if error == OK:
            var texture = ImageTexture.create_from_image(image)
            texture = texture
            print("Image loaded successfully")
        else:
            push_error("Failed to load image from buffer")
    else:
        push_error("Failed to download image: ", response_code)
```

### Example 2: File Download Handler

```gdscript
func download_file(record_id: String, filename: String, save_path: String) -> void:
    # Get record
    var record = await pb.collection("documents").get_one(record_id)
    if record is ClientResponseError:
        push_error("Failed to get record: " + record.to_string())
        return
    
    # Get download URL
    var download_url = pb.files.get_url(record, filename, {
        "download": true
    })
    
    # Download using HTTPRequest
    var http_request = HTTPRequest.new()
    add_child(http_request)
    http_request.request_completed.connect(_on_file_downloaded.bind(save_path))
    http_request.request(download_url)

func _on_file_downloaded(save_path: String, result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if response_code == 200:
        var file = FileAccess.open(save_path, FileAccess.WRITE)
        if file:
            file.store_buffer(body)
            file.close()
            print("File downloaded to: ", save_path)
        else:
            push_error("Failed to write file to: ", save_path)
    else:
        push_error("Download failed with code: ", response_code)
```

### Example 3: Protected File Viewer

```gdscript
func view_protected_file(record_id: String) -> void:
    # Check authentication
    if not pb.auth_store.is_valid:
        var auth = await pb.collection("users").auth_with_password("user@example.com", "password")
        if auth is ClientResponseError:
            push_error("Authentication failed: " + auth.to_string())
            return
    
    # Get record
    var record = await pb.collection("private_docs").get_one(record_id)
    if record is ClientResponseError:
        push_error("Failed to get record: " + record.to_string())
        return
    
    # Get token
    var token = await pb.files.get_token()
    if token is ClientResponseError:
        push_error("Failed to get file token: " + token.to_string())
        return
    
    # Get file URL
    var file_url = pb.files.get_url(record, record.get("file", ""), {
        "token": token
    })
    
    # Display based on file type
    var filename = record.get("file", "")
    var ext = filename.get_extension().to_lower()
    
    if ext in ["jpg", "jpeg", "png", "gif", "webp"]:
        # Load and display image (see Example 1)
        load_image_from_url(file_url)
    elif ext == "pdf":
        # For PDF, you might need a PDF viewer plugin or open externally
        print("PDF file URL: ", file_url)
        OS.shell_open(file_url)
    else:
        # Download other files
        download_file(record_id, filename, "user://downloads/" + filename)
```

### Example 4: Multiple Files with Thumbnails

```gdscript
func display_file_list(record_id: String) -> void:
    var record = await pb.collection("attachments").get_one(record_id)
    if record is ClientResponseError:
        push_error("Failed to get record: " + record.to_string())
        return
    
    var files = record.get("files", [])
    if typeof(files) != TYPE_ARRAY:
        files = []
    
    for filename in files:
        # Check if it's an image
        var ext = filename.get_extension().to_lower()
        var is_image = ext in ["jpg", "jpeg", "png", "gif", "webp"]
        
        if is_image:
            # Show thumbnail
            var thumb_url = pb.files.get_url(record, filename, {
                "thumb": "100x100"
            })
            # Load thumbnail (see Example 1)
            load_thumbnail(thumb_url, filename)
        else:
            # Show file icon or download link
            print("File: ", filename)
            print("Download URL: ", pb.files.get_url(record, filename, {"download": true}))
```

## Error Handling

```gdscript
func load_file_safely(record_id: String, field_name: String) -> void:
    var record = await pb.collection("posts").get_one(record_id)
    if record is ClientResponseError:
        push_error("Failed to get record: " + record.to_string())
        return
    
    var filename = record.get(field_name, "")
    if filename.is_empty():
        push_error("File field is empty")
        return
    
    var file_url = pb.files.get_url(record, filename)
    
    if file_url.is_empty():
        push_error("Invalid file URL")
        return
    
    # Load file using HTTPRequest
    var http_request = HTTPRequest.new()
    add_child(http_request)
    http_request.request_completed.connect(_on_file_loaded)
    http_request.request(file_url)

func _on_file_loaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if response_code == 200:
        print("File loaded successfully")
    else:
        push_error("File access error: HTTP ", response_code)
```

### Protected File Token Error Handling

```gdscript
func get_protected_file_url(record: Dictionary, filename: String) -> String:
    var token = await pb.files.get_token()
    
    if token is ClientResponseError:
        if token.status == 401:
            push_error("Not authenticated")
            # Trigger re-authentication
        elif token.status == 403:
            push_error("No permission to access file")
        else:
            push_error("Failed to get file token: " + token.to_string())
        return ""
    
    return pb.files.get_url(record, filename, {"token": token})
```

## Best Practices

1. **Use Thumbnails for Lists**: Use thumbnails when displaying images in lists/grids to reduce bandwidth
2. **Error Handling**: Always handle file loading errors gracefully
3. **Cache Tokens**: Store file tokens and reuse them until they expire
4. **Content-Type**: Let the server handle content-type detection automatically
5. **Range Requests**: The API supports Range requests for efficient video/audio streaming
6. **Caching**: Files are cached with a 30-day cache-control header
7. **Security**: Always use tokens for protected files, never expose them in client-side code
8. **Async Operations**: Use `await` properly when loading files asynchronously

## Thumbnail Size Guidelines

| Use Case | Recommended Size |
|----------|-----------------|
| Profile picture | `100x100` or `150x150` |
| List thumbnails | `200x200` or `300x300` |
| Card images | `400x400` or `500x500` |
| Gallery previews | `300x300f` (fit) or `400x400f` |
| Hero images | Use original or `800x800f` |
| Avatar | `50x50` or `75x75` |

## Limitations

- **Thumbnails**: Only work for image files (PNG, JPG, JPEG, GIF, WEBP)
- **Protected Files**: Require authentication to get tokens
- **Token Expiry**: File tokens expire after a short period (typically minutes)
- **File Size**: Large files may take time to generate thumbnails on first request
- **Thumb Sizes**: Must match sizes defined in field configuration or use default "100x100"

## Related Documentation

- [Files Upload and Handling](./FILES.md) - Uploading and managing files
- [API Records](./API_RECORDS.md) - Working with records
- [Collections](./COLLECTIONS.md) - Collection configuration
