# Solution - Lab 8

```
lab solve 8      # fixes both faults
```

## Fault 1: a VirtualService routing to a host that doesn't exist
`istioctl analyze -n meshmart` reports
`Error [IST0101] (VirtualService meshmart/catalog) Referenced host not found: "catalgo"`.
Every call from web to catalog matches this route and goes nowhere, so Envoy answers
**503** and the store fails. Fix the destination host to `catalog` (or delete the
VirtualService, which nothing else needed).

You can see it in `istioctl proxy-config routes deploy/web -n meshmart` too, and, with
access logs on (lab 2), as 503s in web's proxy log.

## Fault 2: cart left the mesh
`kubectl -n meshmart get pods` shows cart as `1/1`, and `istioctl proxy-status` has no
proxy for it. Its pod template carries the label `sidecar.istio.io/inject: "false"`, which
overrides the namespace's injection setting. Removing the label rolls out a new pod, and
injection gives it a sidecar.

The store still worked without cart's sidecar because the namespace is PERMISSIVE.
Under STRICT mTLS (lab 6), every call to cart would have failed.

## Troubleshooting order
1. **Configuration:** `istioctl analyze`
2. **Control plane:** `istioctl proxy-status` (is every proxy connected and up to date?)
3. **Data plane:** `istioctl proxy-config routes|clusters|listeners`, proxy logs
