"""MeshMart: one small HTTP service that plays every role in the MeshMart example store.

The same program runs as web, catalog (v1/v2), cart, orders and loadgen. Behaviour is set
with environment variables, so each Deployment differs only in its env:

  SERVICE           service name shown in responses (web, catalog, cart, orders, loadgen)
  VERSION           version label shown in responses (v1, v2, ...)
  PORT              listen port (default 8080)
  UPSTREAMS         comma-separated services to call on every request, e.g. "catalog,cart".
                    A bare name means http://<name>/; a full URL is used as is.
  UPSTREAM_TIMEOUT  seconds to wait for each upstream (default 30: long on purpose, so
                    timeouts are something you configure in Istio, not in the app)
  DELAY             extra latency per request, e.g. "3s" or "500ms" (default none)
  DELAY_PERCENT     share of requests that get DELAY, 0-100 (default 100)
  ERROR_PERCENT     share of requests answered with ERROR_CODE, 0-100 (default 0)
  ERROR_CODE        HTTP status for injected errors (default 503)
  TARGET            loadgen only: URL to call (default http://web/)
  RATE              loadgen only: requests per second (default 2)
  SHUTDOWN_DELAY    seconds to keep serving after SIGTERM (default 5)

Endpoints: /healthz (liveness/readiness), /version (plain-text version, handy in checks),
/stats (loadgen counters; ?reset=1 clears them), and everything else returns this
service's response (JSON, or an HTML storefront when a browser asks web for a page).

Standard library only: no packages to install.
"""

import html
import json
import os
import random
import signal
import socket
import sys
import threading
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

# Headers copied from the incoming request to every upstream call: tracing headers so a
# request shows up as one trace, plus the ones the course uses for routing and auth.
FORWARD_HEADERS = [
    "x-request-id", "traceparent", "tracestate",
    "x-b3-traceid", "x-b3-spanid", "x-b3-parentspanid", "x-b3-sampled", "x-b3-flags", "b3",
    "x-ot-span-context", "x-preview", "authorization",
]


def env(key, default=""):
    return os.environ.get(key, "").strip() or default


def env_int(key, default):
    try:
        return int(env(key, str(default)))
    except ValueError:
        sys.exit(f"{key}: not a number")


def env_seconds(key, default):
    """Accepts "3", "3s", "500ms" or "1m"; returns seconds as a float."""
    value = env(key, "")
    if not value:
        return default
    try:
        for suffix, factor in (("ms", 0.001), ("s", 1), ("m", 60)):
            if value.endswith(suffix):
                return float(value[: -len(suffix)]) * factor
        return float(value)
    except ValueError:
        sys.exit(f"{key}: not a duration (e.g. 500ms, 3s)")


SERVICE = env("SERVICE", "meshmart")
VERSION = env("VERSION", "v1")
PORT = env_int("PORT", 8080)
UPSTREAMS = [u.strip() for u in env("UPSTREAMS").split(",") if u.strip()]
UPSTREAM_TIMEOUT = env_seconds("UPSTREAM_TIMEOUT", 30)
DELAY = env_seconds("DELAY", 0)
DELAY_PERCENT = env_int("DELAY_PERCENT", 100)
ERROR_PERCENT = env_int("ERROR_PERCENT", 0)
ERROR_CODE = env_int("ERROR_CODE", 503)
TARGET = env("TARGET", "http://web/")
RATE = float(env("RATE", "2"))
SHUTDOWN_DELAY = env_seconds("SHUTDOWN_DELAY", 5)
POD = socket.gethostname()


def upstream_url(u):
    return u if "://" in u else f"http://{u}/"


def upstream_name(u):
    """The label used in responses: the bare name, or the URL's host."""
    return urlsplit(upstream_url(u)).hostname or u


def payload(service, version):
    """Business data each service returns. catalog v2 adds ratings and a new product,
    so a canary is visible both in the JSON and on the storefront."""
    if service == "catalog":
        products = [
            {"id": "mesh-mug", "name": "Mesh mug", "price_inr": 349},
            {"id": "sidecar-socks", "name": "Sidecar socks", "price_inr": 199},
            {"id": "envoy-tee", "name": "Envoy tee", "price_inr": 699},
            {"id": "sticker-pack", "name": "Sticker pack", "price_inr": 99},
        ]
        if version != "v1":
            for product, rating in zip(products, (4.6, 4.2, 4.8, 4.5)):
                product["rating"] = rating
            products.append({"id": "ambient-hoodie", "name": "Ambient hoodie",
                             "price_inr": 1499, "rating": 4.9, "new": True})
        return {"products": products}
    if service == "cart":
        return {"items": [{"id": "mesh-mug", "qty": 1}, {"id": "sticker-pack", "qty": 2}]}
    if service == "orders":
        return {"orders": [{"id": "MM-1042", "status": "shipped"}, {"id": "MM-1043", "status": "packing"}]}
    return None


def call_upstream(u, incoming_headers):
    """GET one upstream, forwarding the tracing/routing headers. Never raises."""
    result = {"service": upstream_name(u), "status": 0, "ms": 0}
    headers = {h: incoming_headers[h] for h in FORWARD_HEADERS if incoming_headers.get(h)}
    headers["Accept"] = "application/json"
    start = time.monotonic()
    try:
        req = urllib.request.Request(upstream_url(u), headers=headers)
        with urllib.request.urlopen(req, timeout=UPSTREAM_TIMEOUT) as resp:
            result["status"], body = resp.status, resp.read()
    except urllib.error.HTTPError as e:      # non-2xx answers still carry a status
        result["status"], body = e.code, e.read()
    except Exception as e:                   # timeouts, refused connections, resets
        result["error"] = str(e)
        body = b""
    result["ms"] = int((time.monotonic() - start) * 1000)
    try:
        data = json.loads(body)
        if isinstance(data, dict) and data.get("service"):
            result["version"] = data.get("version", "")
            result["response"] = data
    except ValueError:
        pass
    return result


class LoadStats:
    """loadgen's counters since the last reset."""

    def __init__(self):
        self.lock = threading.Lock()
        self.reset()

    def reset(self):
        with self.lock:
            self.since, self.sent, self.ok, self.failed = time.time(), 0, 0, 0
            self.codes, self.last_error = {}, ""

    def record(self, code, error=None):
        with self.lock:
            self.sent += 1
            key = "error" if error else str(code)
            self.codes[key] = self.codes.get(key, 0) + 1
            if not error and 200 <= code <= 299:
                self.ok += 1
            else:
                self.failed += 1
                self.last_error = error or f"HTTP {code}"

    def snapshot(self):
        with self.lock:
            rate = 100.0 if self.sent == 0 else self.ok * 100 / self.sent
            return {
                "target": TARGET,
                "since": datetime.fromtimestamp(self.since, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "sent": self.sent, "ok": self.ok, "failed": self.failed,
                "success_rate": int(rate * 10) / 10, "codes": dict(self.codes), "last_error": self.last_error,
            }


STATS = LoadStats() if SERVICE == "loadgen" else None
STOP = threading.Event()
POOL = ThreadPoolExecutor(max_workers=64)        # upstream calls
LOAD_POOL = ThreadPoolExecutor(max_workers=64)   # loadgen requests


def run_load():
    """Send TARGET RATE requests a second, each in its own worker so slow answers
    don't slow the pace (like real shoppers arriving independently)."""
    def one():
        try:
            with urllib.request.urlopen(TARGET, timeout=UPSTREAM_TIMEOUT) as resp:
                resp.read()
                STATS.record(resp.status)
        except urllib.error.HTTPError as e:
            STATS.record(e.code)
        except Exception as e:
            if not STOP.is_set():
                STATS.record(0, str(e))

    interval = 1 / RATE
    next_at = time.monotonic()
    while not STOP.is_set():
        LOAD_POOL.submit(one)
        next_at += interval
        STOP.wait(max(0, next_at - time.monotonic()))


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"   # keep-alive, like a real service behind Envoy
    server_version = "MeshMart"

    def log_message(self, *_):      # quiet: Envoy's access logs are the ones to read
        pass

    def send(self, status, body, content_type="application/json"):
        data = body.encode() if isinstance(body, str) else body
        try:
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError):
            pass                    # the caller gave up (e.g. an Istio timeout)

    def do_GET(self):
        path = urlsplit(self.path).path
        if path == "/healthz":
            return self.send(200, "ok\n", "text/plain")
        if path == "/version":
            return self.send(200, VERSION + "\n", "text/plain")
        if path == "/stats":
            if STATS is None:
                return self.send(404, "stats are only kept by loadgen\n", "text/plain")
            if parse_qs(urlsplit(self.path).query).get("reset"):
                STATS.reset()
            return self.send(200, json.dumps(STATS.snapshot(), indent=2) + "\n")
        self.serve()

    # Any method gets the same answer, so authorization labs can tell GET from POST.
    do_POST = do_PUT = do_DELETE = do_PATCH = do_GET

    def serve(self):
        # Injected faults come first, like a slow or failing dependency would.
        if DELAY > 0 and random.randrange(100) < DELAY_PERCENT:
            time.sleep(DELAY)
        if ERROR_PERCENT > 0 and random.randrange(100) < ERROR_PERCENT:
            return self.send(ERROR_CODE, f"{SERVICE} {VERSION}: injected error\n", "text/plain")

        if "content-length" in self.headers:          # drain any request body
            self.rfile.read(int(self.headers["content-length"] or 0))
        incoming = {k.lower(): v for k, v in self.headers.items()}
        resp = {"service": SERVICE, "version": VERSION, "pod": POD, "path": urlsplit(self.path).path}
        data = payload(SERVICE, VERSION)
        if data is not None:
            resp["data"] = data
        if UPSTREAMS:
            resp["upstreams"] = list(POOL.map(lambda u: call_upstream(u, incoming), UPSTREAMS))

        # The store only works if every service it depends on answered.
        broken = any(not 200 <= u["status"] <= 299 for u in resp.get("upstreams", []))
        status = 502 if broken else 200
        if SERVICE == "web" and "text/html" in incoming.get("accept", ""):
            return self.send(status, storefront(resp, broken), "text/html; charset=utf-8")
        self.send(status, json.dumps(resp, indent=2) + "\n")


def storefront(resp, broken):
    """The HTML store page web shows in a browser, built from its upstream answers."""
    products, cart, orders = [], 0, 0
    for u in resp.get("upstreams", []):
        data = (u.get("response") or {}).get("data") or {}
        name = (u.get("response") or {}).get("service")
        if name == "catalog":
            products = data.get("products", [])
        elif name == "cart":
            cart = sum(item.get("qty", 0) for item in data.get("items", []))
        elif name == "orders":
            orders = len(data.get("orders", []))

    e = html.escape

    def card(p):
        new = '<span class="new">NEW</span>' if p.get("new") else ""
        rating = f'<div class="rating">&#9733; {p["rating"]}</div>' if p.get("rating") else ""
        return (f'<div class="card">{new}<h3>{e(p["name"])}</h3>'
                f'<div class="price">&#8377;{p["price_inr"]}</div>{rating}</div>')

    cards = "".join(card(p) for p in products) or "<p>No products to show: the catalog did not answer.</p>"
    rows = "".join(
        f'<tr><td>{e(u["service"])}</td><td>{e(u.get("version", ""))}</td>'
        f'<td class="{"ok" if 200 <= u["status"] <= 299 else "fail"}">{u["status"] or e(u.get("error", ""))}</td>'
        f'<td>{u["ms"]} ms</td></tr>'
        for u in resp.get("upstreams", [])
    )
    alert = '<div class="alert">Part of the store is not responding. See "Served by" below.</div>' if broken else ""
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>MeshMart</title>
<style>
  :root {{ --brand: #4f46e5; --accent: #ec4899; --text: #0f172a; --muted: #475569; --border: #e2e8f0; }}
  * {{ box-sizing: border-box; }}
  body {{ margin: 0; min-height: 100vh; font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; color: var(--text);
         background: radial-gradient(700px 400px at 0% 0%, #eef2ff, transparent 70%), #f8fafc; }}
  header {{ display: flex; justify-content: space-between; align-items: center; padding: 18px 28px;
           border-bottom: 1px solid var(--border); background: #fff; }}
  .logo {{ font-weight: 800; font-size: 1.3rem; }} .logo span {{ color: var(--brand); }}
  .pill {{ border: 1px solid var(--border); border-radius: 999px; padding: 4px 12px; font-size: .9rem; margin-left: 8px; }}
  main {{ max-width: 980px; margin: 0 auto; padding: 28px; }}
  .grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 16px; }}
  .card {{ background: #fff; border: 1px solid var(--border); border-radius: 14px; padding: 18px; position: relative; }}
  .card h3 {{ margin: 0 0 6px; font-size: 1.05rem; }} .price {{ font-weight: 700; color: var(--brand); }}
  .new {{ position: absolute; top: 12px; right: 12px; background: var(--accent); color: #fff; font-size: .72rem;
         font-weight: 700; padding: 2px 8px; border-radius: 999px; }}
  .rating {{ color: var(--muted); font-size: .9rem; }}
  .alert {{ background: #fef2f2; border: 1px solid #fecaca; color: #991b1b; border-radius: 12px; padding: 12px 16px; margin-bottom: 18px; }}
  h2 {{ font-size: 1rem; margin: 32px 0 10px; color: var(--muted); text-transform: uppercase; letter-spacing: .06em; }}
  table {{ width: 100%; border-collapse: collapse; background: #fff; border: 1px solid var(--border); border-radius: 12px; overflow: hidden; }}
  td, th {{ text-align: left; padding: 8px 12px; border-bottom: 1px solid var(--border); font-size: .92rem; }}
  .ok {{ color: #15803d; font-weight: 600; }} .fail {{ color: #b91c1c; font-weight: 600; }}
</style></head><body>
<header><div class="logo">Mesh<span>Mart</span></div>
  <div><span class="pill">Cart: {cart}</span><span class="pill">Orders: {orders}</span></div></header>
<main>
  {alert}
  <div class="grid">{cards}</div>
  <h2>Served by</h2>
  <table><tr><th>Service</th><th>Version</th><th>Status</th><th>Time</th></tr>
  <tr><td>web</td><td>{e(resp["version"])}</td><td class="ok">200</td><td>pod {e(resp["pod"])}</td></tr>
  {rows}
  </table>
</main></body></html>
"""


def main():
    server = ThreadingHTTPServer(("", PORT), Handler)
    server.daemon_threads = True

    def on_sigterm(*_):
        # Keep serving briefly after SIGTERM: Kubernetes and the mesh take a moment to stop
        # sending traffic to a terminating pod. Closing at once would fail those requests.
        def stop():
            STOP.set()
            time.sleep(SHUTDOWN_DELAY)
            server.shutdown()
        threading.Thread(target=stop, daemon=True).start()

    signal.signal(signal.SIGTERM, on_sigterm)
    signal.signal(signal.SIGINT, on_sigterm)
    if STATS is not None:
        threading.Thread(target=run_load, daemon=True).start()
    print(f"meshmart {SERVICE} {VERSION} listening on :{PORT} (upstreams: {UPSTREAMS})", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
