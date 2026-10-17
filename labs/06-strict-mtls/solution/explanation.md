# Solution - Lab 6

```
lab solve      # applies solution/solution.yaml
```

## What and why
1. **`default` (namespace-wide, no selector, `STRICT`)**: every sidecar in `meshmart`
   now accepts only mutual-TLS connections. A plain-text caller is rejected at the
   connection level (no HTTP response at all).
2. **`orders-plaintext-for-reports` (selector `app: orders`, `PERMISSIVE`)**: a
   workload-level policy overrides the namespace policy for the `orders` pods only, so
   the `reports` job outside the mesh can still read from it.

Precedence is **workload > namespace > mesh**: the most specific policy wins.

## How the checker proves it
| Caller | Target | Expected |
|---|---|---|
| web (sidecar) | catalog | HTTP 200 (mTLS works) |
| web (sidecar) | orders | HTTP 200 |
| reports (no sidecar) | orders | HTTP 200 (the exception works) |
| reports (no sidecar) | catalog | **rejected**: no HTTP response |

## Common wrong answers
- **STRICT in `istio-system` (mesh-wide).** It changes every namespace in the cluster.
  The task scopes the change to `meshmart`.
- **AuthorizationPolicy to "deny plain text".** That is an authorization decision, so the
  caller gets HTTP 403, not a rejected connection. mTLS enforcement belongs in
  PeerAuthentication.
- **STRICT only on `catalog`.** Passes today, but a workload added tomorrow would silently
  be PERMISSIVE. The intent is a secure default with explicit exceptions.
- **Injecting a sidecar into `reports`.** Fixes the symptom by changing the client, which
  the scenario says can't be migrated yet.

## Production note
Never flip a namespace to STRICT cold. Run PERMISSIVE first and use Kiali or metrics to
confirm every client already sends mTLS, then tighten. Otherwise you find your non-mesh
callers the hard way.
