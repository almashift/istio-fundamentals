# Solution - Lab 3

```
lab solve      # applies solution/solution.yaml and waits for the gateway pod
```

## What and why
1. **Gateway `meshmart-gateway`** (`gatewayClassName: istio`, HTTP listener on port 80). Istio's
   gateway controller sees it and *deploys* a gateway for you: a Deployment and a
   Service named `meshmart-gateway-istio` (`<gateway>-<class>`), both owned by the Gateway. Delete
   the Gateway and they go away with it. This is "automated deployment"; with Istio's
   own `Gateway` API you had to install an ingress gateway yourself.
2. **HTTPRoute `shop`** attaches to `meshmart-gateway` through `parentRefs` and only handles
   `hostnames: [shop.meshmart.local]`. Its rules:
   - `PathPrefix /api` goes to `orders`. Gateway API prefixes match **whole path segments**:
     `/api` and `/api/orders` match, `/apidocs` does not.
   - A rule with no `matches` means "PathPrefix `/`", so everything else goes to `web`.
   Rule order doesn't matter: the most specific (longest) match wins.
3. A request for any other host matches no route, so the gateway's Envoy answers **404**.

`allowedRoutes.namespaces.from: Same` is the default. It's written out to show that
only routes in `meshmart` may attach to this listener.

## How the checker proves it
| Request from `visitor` (outside the mesh) to `meshmart-gateway-istio` | Expected |
|---|---|
| `Host: shop.meshmart.local`, `/` | `web` |
| `Host: shop.meshmart.local`, `/api`, `/api/orders` | `orders` |
| `Host: shop.meshmart.local`, `/apidocs` | `web` |
| `Host: unknown.meshmart.local`, `/` | 404 from `server: istio-envoy` |

It also checks that `meshmart-gateway-istio` is owned by Gateway `meshmart-gateway`, so a hand-made Service or
Deployment with that name doesn't count.

## About `PROGRAMMED False`
A lab cluster has no cloud load balancer. The generated Service defaults to `type: LoadBalancer`,
its external IP stays `<pending>`, and the Gateway reports `Programmed=False`
(`AddressNotAssigned`). Traffic inside the cluster still works. For a cluster-internal
gateway, ask for a ClusterIP Service and the Gateway becomes `Programmed=True`:

```yaml
metadata:
  name: meshmart-gateway
  annotations:
    networking.istio.io/service-type: ClusterIP
```

## Common wrong answers
- **Istio `Gateway` + `VirtualService`.** That also works on Istio, but the task asks for the
  Kubernetes Gateway API, and the ICA covers both. The checker rejects the Istio APIs here.
- **No `hostnames` on the route.** `/` and `/api` work, but `unknown.meshmart.local` reaches the
  shop too: no 404.
- **`RegularExpression` `/api.*`** instead of `PathPrefix /api`. Gateway API ranks every
  `PathPrefix` match, even `/`, above regex matches, so the catch-all rule wins and
  `/api` lands on `web`.
- **`backendRefs` without `port`.** Required for a Service backend; the API server
  rejects the HTTPRoute outright ("Must have port for Service reference").
- **Gateway in another namespace without `allowedRoutes`.** By default a listener only
  accepts routes from its own namespace; the route stays `Accepted=False` (`NotAllowedByListeners`).

## Production note
The Gateway API CRDs are **not** part of Kubernetes. Install them (the version that matches
your Istio release) *before* installing istiod. If they are added later, restart istiod
to be safe. This lab environment does both for you (`setup/gateway-api-crds.sh`).
