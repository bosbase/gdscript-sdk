# LLM Document API - GDScript SDK

The `LLMDocumentService` wraps the `/api/llm-documents` endpoints that are backed by the embedded chromem-go vector store (persisted in rqlite). Each document contains text content, optional metadata and an embedding vector that can be queried with semantic search.

## Getting Started

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

# Authenticate as superuser
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return

# Create a logical namespace for your documents
var result = await pb.llm_documents.create_collection("knowledge-base", {
    "domain": "internal",
})

if result is ClientResponseError:
    push_error("Failed to create collection: " + result.to_string())
    return
```

## Insert Documents

```gdscript
var doc = await pb.llm_documents.insert(
    {
        "content": "Leaves are green because chlorophyll absorbs red and blue light.",
        "metadata": {"topic": "biology"},
    },
    {"collection": "knowledge-base"},
)

if doc is ClientResponseError:
    push_error("Failed to insert document: " + doc.to_string())
    return

# Insert with custom ID
var doc2 = await pb.llm_documents.insert(
    {
        "id": "sky",
        "content": "The sky is blue because of Rayleigh scattering.",
        "metadata": {"topic": "physics"},
    },
    {"collection": "knowledge-base"},
)
```

## Query Documents

```gdscript
var result = await pb.llm_documents.query(
    {
        "queryText": "Why is the sky blue?",
        "limit": 3,
        "where": {"topic": "physics"},
    },
    {"collection": "knowledge-base"},
)

if result is ClientResponseError:
    push_error("Query failed: " + result.to_string())
    return

for match in result.results:
    print(match.id, match.similarity)
```

## Manage Documents

```gdscript
# Update a document
var update_result = await pb.llm_documents.update(
    "sky",
    {"metadata": {"topic": "physics", "reviewed": true}},
    {"collection": "knowledge-base"},
)

if update_result is ClientResponseError:
    push_error("Failed to update: " + update_result.to_string())

# List documents with pagination
var page = await pb.llm_documents.list({
    "collection": "knowledge-base",
    "page": 1,
    "perPage": 25,
})

if not page is ClientResponseError:
    print("Total documents: ", page.totalItems)
    for doc in page.items:
        print(doc.id, doc.content)

# Delete unwanted entries
var delete_result = await pb.llm_documents.delete("sky", {"collection": "knowledge-base"})
if delete_result is ClientResponseError:
    push_error("Failed to delete: " + delete_result.to_string())
```

## Complete Example

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

func setup_knowledge_base() -> void:
    # Authenticate as superuser
    var auth = await pb.admins().auth_with_password("admin@example.com", "password")
    if auth is ClientResponseError:
        push_error("Authentication failed: " + auth.to_string())
        return
    
    # Create collection
    var collection_result = await pb.llm_documents.create_collection("knowledge-base", {
        "domain": "internal",
    })
    
    if collection_result is ClientResponseError:
        push_error("Failed to create collection: " + collection_result.to_string())
        return
    
    # Insert documents
    var documents = [
        {
            "content": "Leaves are green because chlorophyll absorbs red and blue light.",
            "metadata": {"topic": "biology"},
        },
        {
            "id": "sky",
            "content": "The sky is blue because of Rayleigh scattering.",
            "metadata": {"topic": "physics"},
        },
        {
            "content": "Water boils at 100 degrees Celsius at sea level.",
            "metadata": {"topic": "physics"},
        },
    ]
    
    for doc_data in documents:
        var result = await pb.llm_documents.insert(doc_data, {"collection": "knowledge-base"})
        if result is ClientResponseError:
            push_error("Failed to insert document: " + result.to_string())
            continue
    
    # Query documents
    var query_result = await pb.llm_documents.query(
        {
            "queryText": "Why is the sky blue?",
            "limit": 3,
            "where": {"topic": "physics"},
        },
        {"collection": "knowledge-base"},
    )
    
    if not query_result is ClientResponseError:
        print("Found %d matching documents:" % query_result.results.size())
        for match in query_result.results:
            print("  - %s (similarity: %.3f)" % [match.id, match.similarity])
```

## HTTP Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| `GET /api/llm-documents/collections` | List collections |
| `POST /api/llm-documents/collections/{name}` | Create collection |
| `DELETE /api/llm-documents/collections/{name}` | Delete collection |
| `GET /api/llm-documents/{collection}` | List documents |
| `POST /api/llm-documents/{collection}` | Insert document |
| `GET /api/llm-documents/{collection}/{id}` | Fetch document |
| `PATCH /api/llm-documents/{collection}/{id}` | Update document |
| `DELETE /api/llm-documents/{collection}/{id}` | Delete document |
| `POST /api/llm-documents/{collection}/documents/query` | Query by semantic similarity |

## Management Page

Prefer to click instead of code? Open the Bosbase console at `/_/#/vectors` and switch to the **LLM Documents** view. The UI speaks to the same `/api/llm-documents` endpoints, so anything you do there is instantly reflected in SDK clients (and vice versa).

### CRUD Workflow

- **Browse** – Collections load in a sidebar and each selection renders a paginated table of documents; the page/limit controls map directly to the `page` and `perPage` query params exposed by `llm_documents.list()`.
- **Create** – Use the *New document* action to paste content, attach optional metadata JSON, and either supply an ID or let the backend generate one before the UI issues a `POST /api/llm-documents/{collection}` request.
- **Update** – Click any row to open an inline JSON/text editor. Saving triggers the `PATCH /api/llm-documents/{collection}/{id}` endpoint so you can revise content or metadata without leaving the browser.
- **Delete** – Remove individual rows or select many at once; the UI fans out the appropriate `DELETE` calls so you can clean up collections in bulk.

## Related Documentation

- [Vector API](./VECTOR_API.md) - Vector database operations
- [LangChaingo API](./LANGCHAINGO_API.md) - LangChain integration
