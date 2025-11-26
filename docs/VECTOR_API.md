# Vector Database API

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

``"javascript
var BosBase = preload(\"res:#gdscript-sdk/src/bosbase.gd\")

var pb = BosBase.new(\"http:#localhost:8090\")

# Authenticate as superuser (vectors require superuser auth)
await pb.admins.authWithPassword('admin@example.com', 'password');
"`"

## Types

### VectorEmbedding
Array of numbers representing a vector embedding.

"`"typescript
type VectorEmbedding = number[];
"`"

### VectorDocument
A vector document with embedding, metadata, and optional content.

"`"typescript
interface VectorDocument {
  id?: string;                    # Unique identifier (auto-generated if not provided)
  "vector": VectorEmbedding;        # The vector embedding
  metadata?: VectorMetadata;      # Optional metadata (key-value pairs)
  content?}
"`"

### VectorSearchOptions
Options for vector similarity search.

"`"typescript
interface VectorSearchOptions {
  "queryVector": VectorEmbedding;        # Query vector to search for
  limit?: number;                      # Max results ("default": 10, "max": 100)
  filter?: VectorMetadata;             # Optional metadata filter
  minScore?: number;                   # Minimum similarity score threshold
  maxDistance?: number;                # Maximum distance threshold
  includeDistance?: boolean;           # Include distance in results
  includeContent?}
"`"

### VectorSearchResult
Result from a similarity search.

"`"typescript
interface VectorSearchResult {
  "document": VectorDocument;    # The matching document
  "score": number;               # Similarity score (0-1, higher is better)
  distance?}
"`"

## Collection Management

### Create Collection

Create a new vector collection with specified dimension and distance metric.

"`"javascript
await pb.vectors.createCollection('documents', {
  dimension: 384,      # Vector dimension (default: 384)
  distance: 'cosine'   # Distance metric: 'cosine' (default), 'l2', 'dot'
});

# Minimal example (uses defaults)
await pb.vectors.createCollection('documents');
"`"

**Parameters:**
- "name" (string): Collection name
- "config" (object, optional):
  - "dimension" (number, optional): Vector dimension. Default: 384
  - "distance" (string, optional): Distance metric. Default: 'cosine'
  - Options: 'cosine', 'l2', 'dot'

### List Collections

Get all available vector collections.

"`"javascript
const collections = await pb.vectors.listCollections();

collections.for_each(collection => {
  print("${collection.name}: ${collection.count} vectors");
});
"`"

**Response:**
"`"typescript
Array<{
  "name": string;
  count?: number;
  dimension?}>
"`"

### Update Collection

Update a vector collection configuration (distance metric and options).
Note: Collection name and dimension cannot be changed after creation.

"`"javascript
await pb.vectors.updateCollection('documents', {
  distance});

# Update with options
await pb.vectors.updateCollection('documents', {
  "distance": 'inner_product',
  "options": { customOption}
});
"`"

**Parameters:**
- "name" (string): Collection name
- "config" (object, optional):
  - "distance" (string, optional): Distance metric to update. Options: 'cosine', 'l2', 'inner_product'
  - "options" (object, optional): Custom collection options

### Delete Collection

Delete a vector collection and all its data.

"`"javascript
await pb.vectors.deleteCollection('documents');
"`"

**⚠️ Warning**: This permanently deletes the collection and all vectors in it!

## Document Operations

### Insert Document

Insert a single vector document.

"`"javascript
# With custom ID
const result = await pb.vectors.insert({
  id: 'doc_001',
  vector: [0.1, 0.2, 0.3, 0.4],
  metadata: { category: 'tech', tags: ['AI', 'ML'] },
  content: 'Document about machine learning'
}, { collection});

print('Inserted:', result.id);

# Without ID (auto-generated)
const result2 = await pb.vectors.insert({
  "vector": [0.5, 0.6, 0.7, 0.8],
  content}, { collection});
"`"

**Response:**
"`"typescript
{
  "id": string;        # The document ID
  success}
"`"

### Batch Insert

Insert multiple vector documents efficiently.

"`"javascript
const result = await pb.vectors.batchInsert({
  "documents": [
    { "vector": [0.1, 0.2, 0.3], "metadata": { cat}, content: 'Doc A' },
    { "vector": [0.4, 0.5, 0.6], "metadata": { cat}, content: 'Doc B' },
    { "vector": [0.7, 0.8, 0.9], "metadata": { cat}, content: 'Doc C' },
  ],
  skipDuplicates: true  # Skip documents with duplicate IDs
}, { collection});

print("Inserted: ${result.insertedCount}");
print("Failed: ${result.failedCount}");
print('IDs:', result.ids);
"`"

**Response:**
"`"typescript
{
  "insertedCount": number;   # Number of successfully inserted vectors
  "failedCount": number;     # Number of failed insertions
  "ids": string[];           # List of inserted document IDs
  errors?}
"`"

### Get Document

Retrieve a vector document by ID.

"`"javascript
const doc = await pb.vectors.get('doc_001', { collection});
print('Vector:', doc.vector);
print('Content:', doc.content);
print('Metadata:', doc.metadata);
"`"

### Update Document

Update an existing vector document.

"`"javascript
# Update all fields
await pb.vectors.update('doc_001', {
  "vector": [0.9, 0.8, 0.7, 0.6],
  "metadata": { updated},
  content: 'Updated content'
}, { collection});

# Partial update (only metadata and content)
await pb.vectors.update('doc_001', {
  "metadata": { category},
  content: 'New content'
}, { collection});
"`"

### Delete Document

Delete a vector document.

"`"javascript
await pb.vectors.delete('doc_001', { collection});
"`"

### List Documents

List all documents in a collection with pagination.

"`"javascript
# Get first page
const result = await pb.vectors.list({
  "page": 1,
  perPage}, { collection});

print("Page ${result.page} of ${result.totalPages}");
result.items.for_each(item => {
  print(item.id, item.content);
});
"`"

**Response:**
"`"typescript
{
  "page": number;
  "perPage": number;
  "totalItems": number;
  "totalPages": number;
  items}
"`"

## Vector Search

### Basic Search

Perform similarity search on vectors.

"`"javascript
const results = await pb.vectors.search({
  "queryVector": [0.1, 0.2, 0.3, 0.4],
  limit}, { collection});

results.results.for_each(result => {
  print("Score} - ${result.document.content}");
});
"`"

### Advanced Search

"`"javascript
const results = await pb.vectors.search({
  "queryVector": [0.1, 0.2, 0.3, 0.4],
  "limit": 20,
  "minScore": 0.7,              # Minimum similarity threshold
  "maxDistance": 0.3,           # Maximum distance threshold
  "includeDistance": true,      # Include distance metric
  "includeContent": true,       # Include full content
  "filter": { category} # Filter by metadata
}, { collection});

print("Found ${results.totalMatches} matches in ${results.queryTime}ms");
results.results.for_each(r => {
  print("Score}, Distance: ${r.distance}");
  print("Content: ${r.document.content}");
});
"`"

**Response:**
"`"typescript
{
  "results": VectorSearchResult[];
  totalMatches?: number;
  queryTime?}
"`"

## Common Use Cases

### Semantic Search

"`"javascript
# 1. Generate embeddings for your documents
const documents = [
  { "text": 'Introduction to machine learning', id},
  { "text": 'Deep learning fundamentals', id},
  { "text": 'Natural language processing', id},
];

for (const doc of documents) {
  # Generate embedding using your model
  const embedding = await generateEmbedding(doc.text);
  
  await pb.vectors.insert({
    "id": doc.id,
    "vector": embedding,
    "content": doc.text,
    "metadata": { type}
  }, { collection});
}

# 2. Search
const queryEmbedding = await generateEmbedding('What is AI?');
const results = await pb.vectors.search({
  "queryVector": queryEmbedding,
  "limit": 5,
  minScore}, { collection});

results.results.for_each(r => {
  print("${r.score.toFixed(2)}: ${r.document.content}");
});
"`"

### RAG (Retrieval-Augmented Generation)

"`"javascript
async function retrieveContext(query, limit = 5) {
  const queryEmbedding = await generateEmbedding(query);
  
  const results = await pb.vectors.search({
    "queryVector": queryEmbedding,
    "limit": limit,
    "minScore": 0.75,
    includeContent}, { collection});
  
  return results.results.map(r => r.document.content);
}

# Use with your LLM
const context = await retrieveContext('What are best practices for security?');
const answer = await llm.generate(context, userQuery);
"`"

### Recommendation System

"`"javascript
# Store user profile embeddings
await pb.vectors.insert({
  "id": userId,
  "vector": userProfileEmbedding,
  "metadata": {
    "preferences": ['tech', 'science'],
    "demographics": { "age": 30, location}
  }
}, { collection});

# Find similar users
const similarUsers = await pb.vectors.search({
  "queryVector": currentUserEmbedding,
  "limit": 20,
  includeDistance}, { collection});

# Generate recommendations based on similar users
const recommendations = await generateRecommendations(similarUsers);
"`"

### Multi-modal Search

"`"javascript
# Store embeddings from different sources
await pb.vectors.insert({
  "id": 'image_001',
  "vector": imageEmbedding,
  "metadata": { "type": 'image', "url": 'https},
  content: 'Description of the image'
}, { collection});

await pb.vectors.insert({
  "id": 'video_001',
  "vector": videoEmbedding,
  "metadata": { "type": 'video', duration},
  content: 'Video transcript'
}, { collection});

# Search across all media types
const results = await pb.vectors.search({
  "queryVector": queryEmbedding,
  "limit": 10,
  includeContent}, { collection});
"`"

## Best Practices

### Vector Dimensions

Choose the right dimension for your use case:

- **OpenAI embeddings**: 1536 ("text-embedding-3-large")
- **Sentence Transformers**: 384-768
  - "all-MiniLM-L6-v2": 384
  - "all-mpnet-base-v2": 768
- **Custom models**: Match your model's output

### Distance Metrics

| Metric | Best For | Notes |
|--------|----------|-------|
| "cosine" | Text embeddings | Works well with normalized vectors |
| "l2" | General similarity | Euclidean distance |
| "dot" | Performance | Requires normalized vectors |

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

"`"javascript
try {
  await pb.vectors.search({
    queryVector: [0.1, 0.2, 0.3]
  }, { collection});
} catch (error) {
  if (error.status === 404) {
    push_error('Collection not found');
  } else if (error.status === 400) {
    push_error('Invalid request:', error.response);
  } else {
    push_error('Error:', error);
  }
}
"`"

## Examples

### Complete RAG Application

"`"javascript
var BosBase = preload(\"res:#gdscript-sdk/src/bosbase.gd\")
import { OpenAI } from 'openai';

var pb = BosBase.new(\"http:#localhost:8090\")
const openai = new OpenAI({ apiKey});

# Initialize
await pb.admins.authWithPassword('admin@example.com', 'password');

# 1. Create knowledge base collection
await pb.vectors.createCollection('knowledge_base', {
  "dimension": 1536,  # OpenAI dimensions
  distance});

# 2. Index documents
async function indexDocuments(documents) {
  for (const doc of documents) {
    # Generate OpenAI embedding
    const embedding = await openai.embeddings.create({
      "model": 'text-embedding-3-large',
      input});
    
    await pb.vectors.insert({
      "id": doc.id,
      "vector": embedding.data[0].embedding,
      "content": doc.content,
      "metadata": { "source": doc.source, topic}
    }, { collection});
  }
}

# 3. RAG Query
async function ask(question) {
  # Generate query embedding
  const embedding = await openai.embeddings.create({
    "model": 'text-embedding-3-large',
    input});
  
  # Search for relevant context
  const results = await pb.vectors.search({
    "queryVector": embedding.data[0].embedding,
    "limit": 5,
    "minScore": 0.8,
    "includeContent": true,
    "filter": { topic}
  }, { collection});
  
  # Build context
  const context = results.results
    .map(r => r.document.content)
    .join('\n\n');
  
  # Generate answer with LLM
  const completion = await openai.chat.completions.create({
    "model": 'gpt-4',
    "messages": [
      { "role": 'system', content},
      { "role": 'user', "content": "Context}\n\nQuestion: ${question}" }
    ]
  });
  
  return completion.choices[0].message.content;
}

# Use it
const answer = await ask('What is machine learning?');
print(answer);
"`"

### Product Recommendations

"`"javascript
# Store product embeddings
async function indexProducts(products) {
  for (const product of products) {
    const embedding = await generateProductEmbedding(product);
    
    await pb.vectors.insert({
      "id": product.id,
      "vector": embedding,
      "metadata": {
        "category": product.category,
        "price": product.price,
        brand},
      content: "${product.name} - ${product.description}"
    }, { collection});
  }
}

# Recommend products similar to user's purchase history
async function recommendProducts(userId) {
  # Get user's preferred products
  const userProducts = await getUserFavoriteProducts(userId);
  const productEmbeddings = userProducts.map(p => p.embedding);
  
  # Average embeddings to get user preference
  const avgEmbedding = averageEmbeddings(productEmbeddings);
  
  # Search for similar products
  const results = await pb.vectors.search({
    "queryVector": avgEmbedding,
    "limit": 20,
    "minScore": 0.7,
    "filter": { category}
  }, { collection});
  
  return results.results.map(r => r.document.id);
}
"`"

## Migration from Other Databases

"`"javascript
# Migrate from Pinecone
async function migrateFromPinecone() {
  # 1. Export from Pinecone
  const pineconeVectors = await exportFromPinecone();
  
  # 2. Create collection
  await pb.vectors.createCollection('migrated', {
    "dimension": 1536,
    distance});
  
  # 3. Batch insert
  const documents = pineconeVectors.map(v => ({
    "id": v.id,
    "vector": v.values,
    metadata}));
  
  await pb.vectors.batchInsert({
    documents,
    skipDuplicates}, { collection});
}
"``

## References

- [sqlite-vec Documentation](https:#alexgarcia.xyz/sqlite-vec)
- [sqlite-vec with rqlite](https:#alexgarcia.xyz/sqlite-vec/rqlite.html)
- [Vector Implementation Guide](../VECTOR_IMPLEMENTATION.md)
- [Vector Setup Guide](../VECTOR_SETUP_GUIDE.md)

