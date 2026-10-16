# Solution - Lab 05

```
lab solve 5      # applies solution/solution.yaml
```

## What and why
The VirtualService gives the route from any caller to `catalog` a retry policy:

- `perTryTimeout: 1s`: web's Envoy abandons an attempt that hasn't answered within 1 second.
- `attempts: 2`: it then retries, up to 2 more times. With 1 in 5 attempts hanging, all
  three hang only about 1 time in 125, so almost every call now succeeds within ~1-3s.
- `retryOn`: which failures are retried. A per-try timeout always counts.

`web` itself was not changed: its sidecar enforces the policy. Envoy counts each retry
(`upstream_rq_retry`), which is how the checker proves the retries happened.

## Timeout vs perTryTimeout
- `timeout` on the route caps the **whole** call, all retries included.
- `perTryTimeout` caps **each attempt**, so a retry can still succeed.

`timeout: 1s` on its own would stop the freezes, but every hang would become an error.

## Production note
Retries multiply load on a struggling service. Keep attempts low, only retry idempotent
requests (GET is safe; a payment POST may not be), and pair retries with outlier detection
in a DestinationRule so bad pods are ejected instead of retried forever.
