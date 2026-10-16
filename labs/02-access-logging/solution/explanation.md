# Solution - Lab 02

```
lab solve 2      # applies solution/solution.yaml
```

## What and why
A **Telemetry** resource in the root namespace (`istio-system`) turns on access logging
for every proxy in the mesh, using the built-in `envoy` provider, which writes to the
proxy's stdout. istiod pushes the change to the running proxies: no restarts needed.

```
kubectl -n meshmart logs deploy/web -c istio-proxy --tail=3
```
Each line shows the method, path, response code, response flags (e.g. `UT` for an
upstream timeout, `NR` for no route) and the upstream cluster: the first place to look
when a request fails.

## Other valid answers
- The same Telemetry in namespace `meshmart` (logs for MeshMart only).
- `meshConfig.accessLogFile: /dev/stdout` at install time
  (`istioctl install --set meshConfig.accessLogFile=/dev/stdout`). It works, but it
  changes the installation; the Telemetry API is the modern, per-namespace-capable way.

## Exam tip
Response flags are worth memorising: `UH` (no healthy upstream), `UF` (upstream connection
failure), `UT` (timeout), `NR` (no route configured), `URX` (retries exhausted).
