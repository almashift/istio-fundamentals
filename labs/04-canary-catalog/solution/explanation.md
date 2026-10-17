# Solution - Lab 4

```
lab solve 4      # applies solution/solution.yaml
```

## What and why
1. **DestinationRule `catalog`** turns pod labels into named *subsets*. Without it,
   `subset: v1` in the VirtualService points at nothing and requests fail.
2. **VirtualService `catalog`** matches requests to host `catalog` and splits them 90/10
   across the two subsets. Weights are relative and must add up to 100.

Routing is decided by the **caller's sidecar** (here, `web`'s), which is why the caller
must be in the mesh. Traffic from a pod outside the mesh ignores this VirtualService.

## Rolling forward
Raise v2's weight in steps (50/50, then 0/100) and watch error rates in Kiali at each
step. Once v2 takes all traffic, you can remove catalog-v1.

## Common wrong answers
- **Scaling catalog-v1 to 9 replicas and v2 to 1.** Roughly 90/10, but it ties traffic
  share to pod count. The checker rejects it on purpose.
- **VirtualService without a DestinationRule.** `istioctl analyze` flags the missing
  subset; real requests fail.
- **Weights that don't sum to 100** (e.g. 90/5). Rejected by validation.
- **Wrong label.** Subsets must select on `version`, not `app` (both share `app: catalog`).
