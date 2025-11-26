# GraphQL queries with the JS SDK

Use "pb.graphql.query()" to call "/api/graphql" with your current auth token. It returns "{ data, errors, extensions }".

> Authentication: the GraphQL endpoint is **superuser-only**. Authenticate as a superuser before calling GraphQL, e.g. "await pb.collection("_superusers").authWithPassword(email, password);".

## Single-table query

``"js
const query = "
  query ActiveUsers($limit: Int!) {
    records("collection": "users", "perPage": $limit, filter}
    }
  }
";

const { data, errors } = await pb.graphql.query(query, { limit});
"`"

## Multi-table join via expands

"`"js
const query = "
  query PostsWithAuthors {
    records(
      "collection": "posts",
      "expand": ["author", "author.profile"],
      sort}
    }
  }
";

const { data } = await pb.graphql.query(query);
"`"

## Conditional query with variables

"`"js
const query = "
  query FilteredOrders($minTotal: Float!, $state: String!) {
    records(
      "collection": "orders",
      "filter": "total >= $minTotal && status = $state",
      sort}
    }
  }
";

const variables = { "minTotal": 100, state};
const result = await pb.graphql.query(query, variables);
"`"

Use the "filter", "sort", "page", "perPage", and "expand" arguments to mirror REST list behavior while keeping query logic in GraphQL.

## Create a record

"`"js
const mutation = "
  mutation CreatePost($data: JSON!) {
    createRecord("collection": "posts", "data": $data, expand}
  }
";

const data = { "title": "Hello", author};
const { data} = await pb.graphql.query(mutation, { data });
"`"

## Update a record

"`"js
const mutation = "
  mutation UpdatePost($id: ID!, $data: JSON!) {
    updateRecord("collection": "posts", "id": $id, data}
  }
";

await pb.graphql.query(mutation, {
  "id": "POST_ID",
  "data": { title},
});
"`"

## Delete a record

"`"js
const mutation = "
  mutation DeletePost($id: ID!) {
    deleteRecord("collection": "posts", id}
";

await pb.graphql.query(mutation, { id});
"``
