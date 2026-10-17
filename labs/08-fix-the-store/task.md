# Lab 8 - Fix the broken store (troubleshooting)

**Domain:** Troubleshooting   **Time:** ~15 min   **Namespace:** `meshmart`

## Scenario
It's Monday morning and MeshMart is broken: shoppers get error pages, and the on-call
notes say "someone changed something on Friday". There are **two** problems: one in
Istio's configuration, one in the data plane.

## Your task
Find and fix both problems, so that:

- `istioctl analyze` reports no errors in `meshmart`,
- every MeshMart pod is back in the mesh and in sync with istiod,
- `loadgen`'s requests succeed again.

## Rules
- Fix the causes; don't delete and recreate the whole store.
- Open book: `istio.io/latest/docs` is allowed, just like the real exam.

## Useful commands
```
istioctl analyze -n meshmart
istioctl proxy-status
kubectl -n meshmart get pods
kubectl -n meshmart exec deploy/loadgen -- curl -s localhost:8080/stats
kubectl -n meshmart logs deploy/web -c istio-proxy --tail=20
```

## When you're done
```
lab check 8
```
Stuck? `lab hint 8` reveals one hint at a time.
