# Lab 1 - Bring MeshMart into the mesh

**Domain:** Installation   **Time:** ~10 min   **Namespace:** `meshmart`

## Scenario
Istio is installed, and MeshMart is running in the `meshmart` namespace, but none of
its pods are in the mesh yet: no sidecars, no mTLS, nothing in Kiali.

`loadgen` sends the store a steady stream of requests, like real shoppers would.

## Your task
Put **every** MeshMart workload in the mesh (sidecar mode):

- each pod in `meshmart` runs an Envoy sidecar (`istio-proxy`)
- pods created later join the mesh automatically
- the store keeps serving `loadgen`'s traffic

## Rules
- Do not delete or recreate the Deployments; restart them instead.
- Open book: `istio.io/latest/docs` is allowed, just like the real exam.

## Useful commands
```
kubectl -n meshmart get pods
kubectl get ns meshmart --show-labels
istioctl proxy-status
kubectl -n meshmart exec deploy/loadgen -- curl -s localhost:8080/stats
```

## When you're done
```
lab check 1
```
Stuck? `lab hint 1` reveals one hint at a time.
