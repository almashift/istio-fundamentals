# MeshMart

The example online store used in every lab. Small on purpose: six pods that together
request about 60m CPU, so the whole store fits the smallest Codespace.

```
loadgen ──> web ──┬──> catalog (v1, v2)
                  ├──> cart
                  └──> orders ──> cart
```

| Service | What it does |
|---|---|
| `web` | The storefront. Calls catalog, cart and orders on every request. Open it in a browser for the store page, or `curl` it for JSON. |
| `catalog` v1, v2 | Product list. v2 adds ratings and a new product, so a canary is easy to see. |
| `cart`, `orders` | Shopping cart and recent orders. `orders` calls `cart`. |
| `loadgen` | Sends `web` two requests a second and counts the results: `curl localhost:8080/stats` inside the pod (`?reset=1` clears the counters). |

Every service is the same image (`app/`); environment variables pick its role and can
inject latency or errors. See the comment at the top of `app/main.go` for the full list.

Labs deploy the store with `bash setup/meshmart.sh --mesh` (or `--no-mesh`) into the
`meshmart` namespace. Handy endpoints on every service: `/version` (plain text, e.g.
`v2`) and `/healthz`.

## Changing the app

1. Edit `app/`, then bump `MESHMART_IMAGE` in `versions.env` (published tags never change).
2. Push: the `verify-labs` workflow builds the image from source and runs every lab.
3. Merge to `master`: `publish-meshmart` pushes the new tag to GitHub Packages.
