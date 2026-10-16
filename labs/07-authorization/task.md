# Lab 07 - Only web may call catalog (authorization)

**Domain:** Security   **Time:** ~15 min   **Namespace:** `meshmart`

## Scenario
Any pod in the mesh can call `catalog` today, with any HTTP method. Only the storefront
(`web`) needs it, and only to **read** products. Lock it down.

## Your task
Configure Istio so that `catalog`:

- accepts **GET** requests from **`web`**,
- rejects every other caller (e.g. `cart`, `orders`) with **HTTP 403**,
- rejects non-GET requests (e.g. POST) from `web` too.

The store must keep working for shoppers.

## Rules
- Identify `web` by its **workload identity** (service account), not by IP address.
- Scope the change to `meshmart`: nothing in `istio-system`.
- Open book: `istio.io/latest/docs` is allowed, just like the real exam.

## Useful commands
```
kubectl -n meshmart get sa
kubectl -n meshmart exec deploy/cart -- curl -s -o /dev/null -w "%{http_code}\n" http://catalog/
kubectl -n meshmart exec deploy/web  -- curl -s -o /dev/null -w "%{http_code}\n" -X POST http://catalog/
```

## When you're done
```
lab check 7
```
Stuck? `lab hint 7` reveals one hint at a time.
