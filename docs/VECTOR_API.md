# Vector Database API - GDScript SDK

Vector database operations for semantic search, RAG (Retrieval-Augmented Generation), and AI applications.

> **Note**: Vector operations are currently implemented using sqlite-vec but are designed with abstraction in mind to support future vector database providers.

## Overview

The Vector API provides a unified interface for working with vector embeddings, enabling you to:
- Store and search vector embeddings
- Perform similarity search
- Build RAG applications
- Create recommendation systems
- Enable semantic search capabilities

## Getting Started

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

# Authenticate as superuser (vectors require superuser auth)
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return
```

## Types

### VectorEmbedding

Array of numbers representing a vector embedding.

```gdscript
# Vector embedding is an array of floats
var embedding: Array[float] = [0.1, 0.2, 0.3, 0.4]
```

### VectorDocument

A vector document with embedding, metadata, and optional content.

```gdscript
{
    "id": String,              # Unique identifier (optional, auto-generated if not provided)
    "vector": Array[float],    # The vector embedding
    "metadata": Dictionary,    # Optional metadata (key-value pairs)
    "content": String          # Optional content
}
```

### VectorSearchOptions

Options for vector similarity search.

```gdscript
{
    "queryVector": Array[float],     # Query vector to search for
    "limit": int,                    # Max results (default: 10, max: 100)
    "filter": Dictionary,            # Optional metadata filter
    "minScore": float,               # Minimum similarity score threshold
    "maxDistance": float,            # Maximum distance threshold
    "includeDistance": bool,         # Include distance in results
    "includeContent": bool           # Include content in results
}
```

### VectorSearchResult

Result from a similarity search.

```gdscript
{
    "document": Dictionary,    # The matching document
    "score": float,            # Similarity score (0-1, higher is better)
    "distance": float          # Distance metric (optional)
}
```

## Collection Management

### Create Collection

Create a new vector collection with specified dimension and distance metric.

```gdscript
var result = await pb.vectors.create_collection("documents", {
    "dimension": 384,      # Vector dimension (default: 384)
    "distance": "cosine"   # Distance metric: "cosine" (default), "l2", "dot"
})

# Minimal example (uses defaults)
var result2 = await pb.vectors.create_collection("documents")
```

**Parameters:**
- `name` (string): Collection name
- `config` (dictionary, optional):
  - `dimension` (int, optional): Vector dimension. Default: 384
  - `distance` (string, optional): Distance metric. Default: "cosine"
  - Options: "cosine", "l2", "dot"

### List Collections

Get all available vector collections.

```gdscript
var collections = await pb.vectors.list_collections()

if collections is ClientResponseError:
    push_error("Failed to list collections: " + collections.to_string())
    return

for collection in collections:
    print("%s: %d vectors" % [collection.name, collection.get("count", 0)])
```

**Response:**
```gdscript
Array[{
    "name": String,
    "count": int,      # Optional
    "dimension": int   # Optional
}]
```

### Update Collection

Update a vector collection configuration (distance metric and options).
Note: Collection name and dimension cannot be changed after creation.

```gdscript
await pb.vectors.update_collection("documents", {
    "distance": "l2"
})

# Update with options
await pb.vectors.update_collection("documents", {
    "distance": "inner_product",
    "options": {"customOption": "value"}
})
```

**Parameters:**
- `name` (string): Collection name
- `config` (dictionary, optional):
  - `distance` (string, optional): Distance metric to update. Options: "cosine", "l2", "inner_product"
  - `options` (dictionary, optional): Custom collection options

### Delete Collection

Delete a vector collection and all its data.

```gdscript
var result = await pb.vectors.delete_collection("documents")
if result is ClientResponseError:
    push_error("Failed to delete collection: " + result.to_string())
```

**⚠️ Warning**: This permanently deletes the collection and all vectors in it!

## Document Operations

### Insert Document

Insert a single vector document.

```gdscript
# With custom ID
var result = await pb.vectors.insert({
    "id": "doc_001",
    "vector": [0.1, 0.2, 0.3, 0.4],
    "metadata": {"category": "tech", "tags": ["AI", "ML"]},
    "content": "Document about machine learning"
}, {"collection": "documents"})

if result is ClientResponseError:
    push_error("Failed to insert document: " + result.to_string())
    return

print("Inserted: ", result.id)

# Without ID (auto-generated)
var result2 = await pb.vectors.insert({
    "vector": [0.5, 0.6, 0.7, 0.8],
    "content": "Another document"
}, {"collection": "documents"})
```

**Response:**
```gdscript
{
    "id": String,        # The document ID
    "success": bool
}
```

### Batch Insert

Insert multiple vector documents efficiently.

```gdscript
var result = await pb.vectors.batch_insert({
    "documents": [
        {"vector": [0.1, 0.2, 0.3], "metadata": {"cat": "A"}, "content": "Doc A"},
        {"vector": [0.4, 0.5, 0.6], "metadata": {"cat": "B"}, "content": "Doc B"},
        {"vector": [0.7, 0.8, 0.9], "metadata": {"cat": "C"}, "content": "Doc C"},
    ],
    "skipDuplicates": true  # Skip documents with duplicate IDs
}, {"collection": "documents"})

if result is ClientResponseError:
    push_error("Failed to batch insert: " + result.to_string())
    return

print("Inserted: ", result.insertedCount)
print("Failed: ", result.failedCount)
print("IDs: ", result.ids)
```

**Response:**
```gdscript
{
    "insertedCount": int,    # Number of successfully inserted vectors
    "failedCount": int,      # Number of failed insertions
    "ids": Array[String],    # List of inserted document IDs
    "errors": Array          # Optional error details
}
```

### Get Document

Retrieve a vector document by ID.

```gdscript
var doc = await pb.vectors.get("doc_001", {"collection": "documents"})

if doc is ClientResponseError:
    push_error("Failed to get document: " + doc.to_string())
    return

print("Vector: ", doc.vector)
print("Content: ", doc.content)
print("Metadata: ", doc.metadata)
```

### Update Document

Update an existing vector document.

```gdscript
# Update all fields
await pb.vectors.update("doc_001", {
    "vector": [0.9, 0.8, 0.7, 0.6],
    "metadata": {"updated": true},
    "content": "Updated content"
}, {"collection": "documents"})

# Partial update (only metadata and content)
await pb.vectors.update("doc_001", {
    "metadata": {"category": "updated"},
    "content": "New content"
}, {"collection": "documents"})
```

### Delete Document

Delete a vector document.

```gdscript
var result = await pb.vectors.delete("doc_001", {"collection": "documents"})
if result is ClientResponseError:
    push_error("Failed to delete document: " + result.to_string())
```

### List Documents

List all documents in a collection with pagination.

```gdscript
# Get first page
var result = await pb.vectors.list({
    "page": 1,
    "perPage": 50
}, {"collection": "documents"})

if result is ClientResponseError:
    push_error("Failed to list documents: " + result.to_string())
    return

print("Page %d of %d" % [result.page, result.totalPages])
for item in result.items:
    print(item.id, item.content)
```

**Response:**
```gdscript
{
    "page": int,
    "perPage": int,
    "totalItems": int,
    "totalPages": int,
    "items": Array[VectorDocument]
}
```

## Vector Search

### Basic Search

Perform similarity search on vectors.

```gdscript
var results = await pb.vectors.search({
    "queryVector": [0.1, 0.2, 0.3, 0.4],
    "limit": 10
}, {"collection": "documents"})

if results is ClientResponseError:
    push_error("Search failed: " + results.to_string())
    return

for result in results.results:
    print("Score: %.2f - %s" % [result.score, result.document.content])
```

### Advanced Search

```gdscript
var results = await pb.vectors.search({
    "queryVector": [0.1, 0.2, 0.3, 0.4],
    "limit": 20,
    "minScore": 0.7,              # Minimum similarity threshold
    "maxDistance": 0.3,           # Maximum distance threshold
    "includeDistance": true,      # Include distance metric
    "includeContent": true,       # Include full content
    "filter": {"category": "tech"}  # Filter by metadata
}, {"collection": "documents"})

if results is ClientResponseError:
    push_error("Search failed: " + results.to_string())
    return

print("Found %d matches in %dms" % [results.totalMatches, results.queryTime])
for r in results.results:
    print("Score: %.2f, Distance: %.2f" % [r.score, r.distance])
    print("Content: ", r.document.content)
```

**Response:**
```gdscript
{
    "results": Array[VectorSearchResult],
    "totalMatches": int,      # Optional
    "queryTime": int          # Optional (milliseconds)
}
```

## Common Use Cases

### Semantic Search

```gdscript
# 1. Generate embeddings for your documents
var documents = [
    {"text": "Introduction to machine learning", "id": "doc1"},
    {"text": "Deep learning fundamentals", "id": "doc2"},
    {"text": "Natural language processing", "id": "doc3"},
]

for doc in documents:
    # Generate embedding using your model
    var embedding = await generate_embedding(doc.text)
    
    await pb.vectors.insert({
        "id": doc.id,
        "vector": embedding,
        "content": doc.text,
        "metadata": {"type": "article"}
    }, {"collection": "documents"})

# 2. Search
var query_embedding = await generate_embedding("What is AI?")
var results = await pb.vectors.search({
    "queryVector": query_embedding,
    "limit": 5,
    "minScore": 0.7
}, {"collection": "documents"})

if not results is ClientResponseError:
    for r in results.results:
        print("%.2f: %s" % [r.score, r.document.content])
```

### RAG (Retrieval-Augmented Generation)

```gdscript
func retrieve_context(query: String, limit: int = 5) -> Array[String]:
    var query_embedding = await generate_embedding(query)
    
    var results = await pb.vectors.search({
        "queryVector": query_embedding,
        "limit": limit,
        "minScore": 0.75,
        "includeContent": true
    }, {"collection": "documents"})
    
    if results is ClientResponseError:
        push_error("Failed to search: " + results.to_string())
        return []
    
    var context = []
    for r in results.results:
        context.append(r.document.content)
    
    return context

# Use with your LLM
var context = await retrieve_context("What are best practices for security?")
# Build prompt with context and generate answer
```

## Best Practices

### Vector Dimensions

Choose the right dimension for your use case:

- **OpenAI embeddings**: 1536 (`text-embedding-3-large`)
- **Sentence Transformers**: 384-768
  - `all-MiniLM-L6-v2`: 384
  - `all-mpnet-base-v2`: 768
- **Custom models**: Match your model's output

### Distance Metrics

| Metric | Best For | Notes |
|--------|----------|-------|
| `cosine` | Text embeddings | Works well with normalized vectors |
| `l2` | General similarity | Euclidean distance |
| `dot` | Performance | Requires normalized vectors |

### Performance Tips

1. **Use batch insert** for multiple vectors
2. **Set appropriate limits** to avoid excessive results
3. **Use metadata filtering** to narrow search space
4. **Enable indexes** (automatic with sqlite-vec)

### Security

- All vector endpoints require superuser authentication
- Never expose credentials in client-side code
- Use environment variables for sensitive data

## Error Handling

```gdscript
var results = await pb.vectors.search({
    "queryVector": [0.1, 0.2, 0.3]
}, {"collection": "documents"})

if results is ClientResponseError:
    match results.status:
        404:
            push_error("Collection not found")
        400:
            push_error("Invalid request: ", results.data)
        _:
            push_error("Error: " + results.to_string())
```

## References

- [sqlite-vec Documentation](https://alexgarcia.xyz/sqlite-vec)
- [sqlite-vec with rqlite](https://alexgarcia.xyz/sqlite-vec/rqlite.html)
