# Solution - Lab 01

```
lab solve 1      # applies solution/solution.yaml
```

## What and why
1. **DestinationRule `echo`** turns pod labels into named *subsets*. Without it,
   `subset: v1` in the VirtualService points at nothing and requests fail.
2. **VirtualService `echo`** matches requests to host `echo` and splits them 80/20
   across the two subsets. Weights are relative and must add up to 100.

Routing is decided by the **client's sidecar**, which is why the `client` pod
had to be injected. Traffic from a pod outside the mesh ignores this VirtualService.

## Common wrong answers
- **Scaling to 4 replicas of v1 and 1 of v2.** Roughly 80/20, but it couples traffic
  share to pod count. The checker rejects it on purpose.
- **VirtualService without a DestinationRule.** `istioctl analyze` flags the missing
  subset; real requests fail.
- **Weights that don't sum to 100** (e.g. 80/10). Rejected by validation.
- **Wrong label.** Subsets must select on `version`, not `app` (both pods share `app: echo`).

## Production note
Check outlier detection and retries before shifting a real canary above ~20%:
a bad v2 with default retries can quietly mask errors from the 20% slice.
