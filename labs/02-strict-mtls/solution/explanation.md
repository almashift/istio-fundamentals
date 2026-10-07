# Solution - Lab 02

```
lab solve 2      # applies solution/solution.yaml
```

## What and why
1. **`default` (namespace-wide, no selector, `STRICT`)**: every sidecar in `lab02`
   now accepts only mutual-TLS connections. A plain-text caller is rejected at
   the connection level (no HTTP response at all).
2. **`legacy-exception` (selector `app: legacy`, `PERMISSIVE`)**: a workload-level
   policy overrides the namespace policy for the `legacy` pods only, so the
   non-mesh batch job can still reach it.

Precedence is **workload > namespace > mesh**: the most specific policy wins.

## How the checker proves it
| Caller | Target | Expected |
|---|---|---|
| client-mesh (sidecar) | echo | HTTP 200 (mTLS works) |
| client-mesh (sidecar) | legacy | HTTP 200 |
| client-plain (no sidecar) | legacy | HTTP 200 (exception works) |
| client-plain (no sidecar) | echo | **rejected**: no HTTP response |

## Common wrong answers
- **STRICT in `istio-system` (mesh-wide).** It works for the namespace but changes every
  namespace in the cluster, and breaks the legacy exception unless you also add one.
- **AuthorizationPolicy to "deny plain-text".** That is an authorization decision, so the
  caller gets an HTTP 403, not a rejected connection. mTLS enforcement belongs in
  PeerAuthentication.
- **STRICT only on `echo`.** Passes for today's pods, but a new workload added tomorrow
  would silently be PERMISSIVE. The intent is a secure default with explicit exceptions.
- **Injecting a sidecar into `client-plain`.** Fixes the symptom by changing the client; the
  real batch job couldn't be changed.

## Production note
Never flip a namespace to STRICT cold. Run PERMISSIVE first and use Kiali or
`istioctl x describe`/metrics to confirm all clients already send mTLS, then tighten.
Otherwise you will discover your non-mesh callers the hard way.
