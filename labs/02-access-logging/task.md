# Lab 02 - Turn on access logging for the store

**Domain:** Installation   **Time:** ~10 min   **Namespace:** `meshmart`

## Scenario
Shoppers report the odd failed page, but nobody can see which requests went where:
MeshMart's Envoy proxies are not writing access logs.

## Your task
Make the MeshMart proxies write an **access log line for every request**, so that a
request through `web` shows up in the `istio-proxy` logs of both `web` and `catalog`.

## Rules
- Do **not** edit the Deployments or pods (no annotations, no restarts needed).
- Use Istio configuration. Either a mesh-wide or a `meshmart`-only setting is fine.
- Open book: `istio.io/latest/docs` is allowed, just like the real exam.

## Useful commands
```
kubectl -n meshmart logs deploy/web -c istio-proxy --tail=5
kubectl -n meshmart exec deploy/loadgen -- curl -s -H "x-request-id: hello-123" http://web/ -o /dev/null
kubectl get telemetry -A
```

## When you're done
```
lab check 2
```
Stuck? `lab hint 2` reveals one hint at a time.
