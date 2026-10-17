# Lab 4 - Canary catalog v2 at 90/10

**Domain:** Traffic management   **Time:** ~10 min   **Namespace:** `meshmart`

## Scenario
MeshMart's catalog team has shipped **catalog v2** (product ratings and a new hoodie).
Both versions run side by side behind the `catalog` Service, so shoppers currently see
roughly a 50/50 mix: the Service load-balances across every catalog pod.

Before trusting v2 with everyone, you want only a small canary slice to reach it.

## Your task
Configure Istio so that requests to `catalog` from inside the mesh are sent:

- **90%** to catalog `v1`
- **10%** to catalog `v2`

## Rules
- Do **not** edit the Deployments or the Service (no scaling tricks).
- The `meshmart` namespace is already in the mesh.
- Open book: `istio.io/latest/docs` is allowed, just like the real exam.

## Useful commands
```
kubectl -n meshmart get pods --show-labels
kubectl -n meshmart exec deploy/web -- curl -s http://catalog/version
istioctl analyze -n meshmart
```

## When you're done
```
lab check
```
Stuck? `lab hint` reveals one hint at a time.
