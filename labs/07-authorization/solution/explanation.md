# Solution - Lab 7

```
lab solve      # applies solution/solution.yaml
```

## What and why
An **ALLOW** AuthorizationPolicy on `catalog`'s pods with a single rule: the caller's
identity is `web`'s service account **and** the method is GET. Once a workload has any
ALLOW policy, requests that match none of its rules are denied with **403**, which is
how cart, orders and POSTs from web are rejected.

The identity comes from the caller's mTLS certificate (SPIFFE ID
`spiffe://cluster.local/ns/meshmart/sa/web`), so it can't be faked by changing an IP or a
header. That's why principals only work for callers inside the mesh.

## How the checker proves it
| Caller | Method | Expected |
|---|---|---|
| web | GET | 200 |
| web | POST | 403 |
| cart | GET | 403 |
| orders | GET | 403 |

It also confirms loadgen's shoppers still get their pages: web only reads catalog with GET.

## Common wrong answers
- **`from` and `to` in separate rules.** Separate rules are OR'd: "anyone from web, or any
  GET from anyone". cart's GET would be allowed.
- **Matching `namespaces: [meshmart]`.** Every MeshMart service is in that namespace, so
  cart and orders would still get in.
- **A DENY policy for cart and orders.** Works today, but the next service you add can call
  catalog. Allow-lists fail safe.

## Exam tip
Evaluation order: CUSTOM, then DENY, then ALLOW. An empty `spec: {}` policy in a
namespace denies everything there: the usual "deny by default" starting point.
