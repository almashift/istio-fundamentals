# Lab 01 - Weighted routing: canary v2 at 80/20

**Domain:** Traffic management   **Time:** ~10 min   **Namespace:** `lab01`

## Scenario
The `echo` service has two versions running side by side: `echo-v1` (stable)
and `echo-v2` (the new release). Right now callers see roughly a 50/50 mix,
because the Service load-balances across every pod it selects.

You want v2 to receive only a small canary slice of traffic.

## Your task
Configure Istio so that requests to `echo` made from inside the mesh are sent:

- **80%** to `v1`
- **20%** to `v2`

## Rules
- Do **not** edit the Deployments or the Service (no scaling tricks).
- Namespace `lab01` is already injected; the `client` pod is in the mesh.
- This is open-book. `istio.io/latest/docs` is allowed, just like the real exam.

## Useful commands
```
kubectl -n lab01 get pods,svc
kubectl -n lab01 exec deploy/client -c client -- curl -s http://echo/
istioctl analyze -n lab01
```

## When you're done
```
lab check 1
```
Stuck? `lab hint 1` reveals one hint at a time.
