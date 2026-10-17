# Solution - Lab 1

```bash
kubectl label ns meshmart istio-injection=enabled
kubectl -n meshmart rollout restart deploy
kubectl -n meshmart get pods        # every pod shows 2/2: app + istio-proxy
istioctl proxy-status               # every MeshMart proxy is listed and connected to istiod
```

## Why it works
- Istio's sidecar injector is an admission webhook: it adds the `istio-proxy` container
  to pods **as they are created**, in namespaces labelled `istio-injection=enabled`
  (or `istio.io/rev=<revision>` when you use revisions for canary upgrades).
- Existing pods are not changed, so the Deployments must be restarted. A rolling restart
  starts each new pod before stopping the old one, so `loadgen` keeps getting answers.
- `istioctl proxy-status` confirms istiod has sent each new proxy its configuration.

## Exam tip
If pods show `1/1` after labelling, they were created before the label: restart them.
`kubectl get ns --show-labels` quickly shows which namespaces inject sidecars.
