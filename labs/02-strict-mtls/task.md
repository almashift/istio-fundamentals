# Lab 02 - Strict mTLS with a legacy exception

**Domain:** Security   **Time:** ~15 min   **Namespace:** `lab02`

## Scenario
Security has mandated that service-to-service traffic in `lab02` must use
mutual TLS. Right now the mesh is in its default mode (PERMISSIVE), so anyone,
including pods outside the mesh, can still call your services in plain text.

There is one catch. `legacy` is called by a nightly batch job (`client-plain`)
that runs outside the mesh and cannot be migrated yet, so `legacy` must keep
accepting plain-text calls.

## Your task
Configure Istio so that, in namespace `lab02`:

- every workload requires **mutual TLS (STRICT)**,
- except the `legacy` workload, which must still accept plain-text traffic.

In-mesh callers (`client-mesh`) must keep working against both services.

## Rules
- Scope the change to namespace `lab02`. Do **not** create a mesh-wide policy
  (nothing in `istio-system`).
- Do **not** use AuthorizationPolicy to do the job: this is about transport security.
- Do not edit the Deployments or Services, and do not inject a sidecar into `client-plain`.
- Open-book: `istio.io/latest/docs` is allowed, just like the real exam.

## Useful commands
```
kubectl -n lab02 get pods
kubectl -n lab02 exec deploy/client-plain -c client -- curl -s http://echo/
kubectl -n lab02 exec deploy/client-mesh  -c client -- curl -s http://echo/
istioctl analyze -n lab02
```

## When you're done
```
lab check 2
```
Stuck? `lab hint 2` reveals one hint at a time.
