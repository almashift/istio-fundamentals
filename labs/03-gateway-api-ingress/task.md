# Lab 03 - Ingress with the Kubernetes Gateway API

**Domain:** Traffic management   **Time:** ~15 min   **Namespace:** `lab03`

## Scenario
The shop at `shop.example.com` is made of two services in `lab03`: `web` (the
storefront) and `api` (the backend). Both run in the mesh, but nothing outside
the mesh can reach them yet: there is no ingress.

The platform team has standardised on the **Kubernetes Gateway API** (not Istio's
own `Gateway`/`VirtualService`), with Istio as the implementation.

## Your task
In namespace `lab03`, expose the shop through a gateway:

- a Gateway named **`edge`**, implemented by Istio, listening for HTTP on **port 80**;
- for host **`shop.example.com`**:
  - `/api` and every path below it (e.g. `/api/orders`) go to Service **`api`**,
  - every other path (e.g. `/`, `/apidocs`) goes to Service **`web`**;
- requests for any other host must **not** reach the shop (HTTP 404).

The `client` pod is outside the mesh and plays the role of an external user. It
calls the gateway's Service, which Istio creates for you, with a `Host` header.

## Rules
- Use the Gateway API (`gateway.networking.k8s.io`). No Istio `Gateway` or
  `VirtualService` in `lab03`.
- Let Istio deploy the gateway for you. Do not create the gateway's Deployment or Service yourself.
- Do not edit the `web`/`api` Deployments or Services, and do not inject a sidecar into `client`.
- Open-book: `istio.io/latest/docs` and `gateway-api.sigs.k8s.io` are allowed.

## Useful commands
```
kubectl -n lab03 get gateway,httproute,deploy,svc
kubectl -n lab03 exec deploy/client -- curl -s -H 'Host: shop.example.com' http://edge-istio/api
kubectl -n lab03 get gateway edge -o yaml        # read status.conditions
istioctl analyze -n lab03
```
On this kind cluster there is no cloud load balancer, so a `LoadBalancer` Service
stays `<pending>`, and a Gateway that asks for one reports `PROGRAMMED False`
(`AddressNotAssigned`). That on its own does not stop in-cluster traffic.

## When you're done
```
lab check 3
```
Stuck? `lab hint 3` reveals one hint at a time.
