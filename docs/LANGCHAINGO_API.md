# LangChaingo API - GDScript SDK

BosBase exposes the `/api/langchaingo` endpoints so you can run LangChainGo powered workflows without leaving the platform. The GDScript SDK wraps these endpoints with the `pb.langchaingo` service.

The service exposes four high-level methods:

| Method | HTTP Endpoint | Description |
| --- | --- | --- |
| `pb.langchaingo.completions()` | `POST /api/langchaingo/completions` | Runs a chat/completion call using the configured LLM provider. |
| `pb.langchaingo.rag()` | `POST /api/langchaingo/rag` | Runs a retrieval-augmented generation pass over an `llmDocuments` collection. |
| `pb.langchaingo.query_documents()` | `POST /api/langchaingo/documents/query` | Asks an OpenAI-backed chain to answer questions over `llmDocuments` and optionally return matched sources. |
| `pb.langchaingo.sql()` | `POST /api/langchaingo/sql` | Lets OpenAI draft and execute SQL against your BosBase database, then returns the results. |

Each method accepts an optional `model` block:

```gdscript
{
    "provider": "openai",  # or "ollama" or other provider
    "model": "gpt-4o-mini",  # optional
    "apiKey": "your-key",  # optional, overrides server defaults
    "baseUrl": "https://api.openai.com/v1",  # optional
}
```

If you omit the `model` section, BosBase defaults to `provider: "openai"` and `model: "gpt-4o-mini"` with credentials read from the server environment. Passing an `apiKey` lets you override server defaults on a per-request basis.

## Text + Chat Completions

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

var completion = await pb.langchaingo.completions({
    "model": {"provider": "openai", "model": "gpt-4o-mini"},
    "messages": [
        {"role": "system", "content": "You are a helpful assistant"},
        {"role": "user", "content": "Hello"},
    ],
    "temperature": 0.2,
})

if completion is ClientResponseError:
    push_error("Completion failed: " + completion.to_string())
    return

print(completion.content)
```

The completion response mirrors the LangChainGo `ContentResponse` shape, so you can inspect the `functionCall`, `toolCalls`, or `generationInfo` fields when you need more than plain text.

## Retrieval-Augmented Generation (RAG)

Pair the LangChaingo endpoints with the `/api/llm-documents` store to build RAG workflows. The backend automatically uses the chromem-go collection configured for the target LLM collection.

```gdscript
var answer = await pb.langchaingo.rag({
    "collection": "knowledge-base",
    "question": "Why is the sky blue?",
    "topK": 4,
    "returnSources": true,
    "filters": {
        "where": {"topic": "physics"},
    },
})

if answer is ClientResponseError:
    push_error("RAG failed: " + answer.to_string())
    return

print(answer.answer)
if answer.sources:
    for source in answer.sources:
        print("%.3f %s" % [source.score, source.metadata.get("title", "")])
```

Set `promptTemplate` when you want to control how the retrieved context is stuffed into the answer prompt:

```gdscript
var answer = await pb.langchaingo.rag({
    "collection": "knowledge-base",
    "question": "Summarize the explanation below in 2 sentences.",
    "promptTemplate": "Context: {{.context}}\n\nQuestion: {{.question}}\nSummary:",
})
```

## LLM Document Queries

> **Note**: This interface is only available to superusers.

When you want to pose a question to a specific `llmDocuments` collection and have LangChaingo+OpenAI synthesize an answer, use `query_documents`. It mirrors the RAG arguments but takes a `query` field:

```gdscript
# Authenticate as superuser first
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return

var response = await pb.langchaingo.query_documents({
    "collection": "knowledge-base",
    "query": "List three bullet points about Rayleigh scattering.",
    "topK": 3,
    "returnSources": true,
})

if response is ClientResponseError:
    push_error("Query failed: " + response.to_string())
    return

print(response.answer)
print(response.sources)
```

## SQL Generation + Execution

> **Important Notes**:
> - This interface is only available to superusers. Requests authenticated with regular `users` tokens return a `401 Unauthorized`.
> - It is recommended to execute query statements (SELECT) only.
> - **Do not use this interface for adding or modifying table structures.** Collection interfaces should be used instead for managing database schema.
> - Directly using this interface for initializing table structures and adding or modifying database tables will cause errors that prevent the automatic generation of APIs.

Superuser tokens (`_superusers` records) can ask LangChaingo to have OpenAI propose a SQL statement, execute it, and return both the generated SQL and execution output.

```gdscript
# Authenticate as superuser first
var auth = await pb.admins().auth_with_password("admin@example.com", "password")
if auth is ClientResponseError:
    push_error("Authentication failed: " + auth.to_string())
    return

var result = await pb.langchaingo.sql({
    "query": "Add a demo project row if it doesn't exist, then list the 5 most recent projects.",
    "tables": ["projects"],  # optional hint to limit which tables the model sees
    "topK": 5,
})

if result is ClientResponseError:
    push_error("SQL generation failed: " + result.to_string())
    return

print(result.sql)    # Generated SQL
print(result.answer) # Model's summary of the execution
print(result.columns, result.rows)
```

Use `tables` to restrict which table definitions and sample rows are passed to the model, and `topK` to control how many rows the model should target when building queries. You can also pass the optional `model` block described above to override the default OpenAI model or key for this call.

## Complete Example: RAG Application

```gdscript
var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var pb = BosBase.new("http://localhost:8090")

func setup_rag_system() -> void:
    # Authenticate as superuser
    var auth = await pb.admins().auth_with_password("admin@example.com", "password")
    if auth is ClientResponseError:
        push_error("Authentication failed: " + auth.to_string())
        return
    
    # Create LLM documents collection
    await pb.llm_documents.create_collection("knowledge-base", {
        "domain": "internal",
    })
    
    # Insert documents
    var documents = [
        {
            "content": "The sky appears blue due to Rayleigh scattering of sunlight.",
            "metadata": {"topic": "physics"},
        },
        {
            "content": "Leaves are green because chlorophyll absorbs red and blue light.",
            "metadata": {"topic": "biology"},
        },
    ]
    
    for doc_data in documents:
        await pb.llm_documents.insert(doc_data, {"collection": "knowledge-base"})
    
    # Query with RAG
    var answer = await pb.langchaingo.rag({
        "collection": "knowledge-base",
        "question": "Why is the sky blue?",
        "topK": 3,
        "returnSources": true,
    })
    
    if not answer is ClientResponseError:
        print("Answer: ", answer.answer)
        if answer.sources:
            print("Sources:")
            for source in answer.sources:
                print("  - ", source.metadata)
```

## Error Handling

```gdscript
var result = await pb.langchaingo.completions({
    "messages": [{"role": "user", "content": "Hello"}],
})

if result is ClientResponseError:
    match result.status:
        401:
            push_error("Authentication required")
        403:
            push_error("Superuser access required for this operation")
        _:
            push_error("Error: " + result.to_string())
    return
```

## Related Documentation

- [LLM Documents API](./LLM_DOCUMENTS.md) - Document management for RAG
- [Vector API](./VECTOR_API.md) - Vector database operations
