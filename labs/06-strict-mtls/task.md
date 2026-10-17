# Lab 6 - Lock down the store (strict mTLS)

**Domain:** Security   **Time:** ~15 min   **Namespace:** `meshmart`

## Scenario
Security has mandated that traffic between MeshMart's services must use mutual TLS.
Right now the mesh is in its default mode (PERMISSIVE), so anything, including pods
outside the mesh, can still call MeshMart's services in plain text.

There is one catch: **`reports`**, a nightly reporting job, runs outside the mesh and
reads from **`orders`**. It can't be migrated yet, so `orders` must keep accepting
plain-text calls.

## Your task
Configure Istio so that, in namespace `meshmart`:

- every workload requires **mutual TLS (STRICT)**,
- except **`orders`**, which must still accept plain-text traffic.

In-mesh callers (such as `web`) must keep working against every service.

## Rules
- Scope the change to namespace `meshmart`. Do **not** create a mesh-wide policy
  (nothing in `istio-system`).
- Do **not** use AuthorizationPolicy to do the job: this is about transport security.
- Do not edit the Deployments or Services, and do not inject a sidecar into `reports`.
- Open book: `istio.io/latest/docs` is allowed, just like the real exam.

## Useful commands
```
kubectl -n meshmart get pods
kubectl -n meshmart exec deploy/reports -- curl -s -o /dev/null -w "%{http_code}\n" http://catalog/
kubectl -n meshmart exec deploy/web     -- curl -s -o /dev/null -w "%{http_code}\n" http://catalog/
istioctl analyze -n meshmart
```

## When you're done
```
lab check
```
Stuck? `lab hint` reveals one hint at a time.
