package main

import (
	"encoding/json"
	"html/template"
)

// view is what the storefront template needs, pulled out of web's upstream responses.
type view struct {
	Pod      string
	Version  string
	Products []product
	Cart     int
	Orders   int
	Calls    []Upstream
	Broken   bool
}

func storefrontView(r Response) view {
	v := view{Pod: r.Pod, Version: r.Version, Calls: r.Upstreams}
	for _, u := range r.Upstreams {
		if u.Status < 200 || u.Status > 299 {
			v.Broken = true
		}
		if u.Response == nil || u.Response.Data == nil {
			continue
		}
		// Data arrives as generic JSON; round-trip it into the shape each service sends.
		raw, _ := json.Marshal(u.Response.Data)
		switch u.Response.Service {
		case "catalog":
			var d struct{ Products []product }
			_ = json.Unmarshal(raw, &d)
			v.Products = d.Products
		case "cart":
			var d struct{ Items []struct{ Qty int } }
			_ = json.Unmarshal(raw, &d)
			for _, it := range d.Items {
				v.Cart += it.Qty
			}
		case "orders":
			var d struct{ Orders []any }
			_ = json.Unmarshal(raw, &d)
			v.Orders = len(d.Orders)
		}
	}
	return v
}

var storefront = template.Must(template.New("store").Parse(`<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>MeshMart</title>
<style>
  :root { --brand: #4f46e5; --accent: #ec4899; --text: #0f172a; --muted: #475569; --border: #e2e8f0; }
  * { box-sizing: border-box; }
  body { margin: 0; min-height: 100vh; font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; color: var(--text);
         background: radial-gradient(700px 400px at 0% 0%, #eef2ff, transparent 70%), #f8fafc; }
  header { display: flex; justify-content: space-between; align-items: center; padding: 18px 28px;
           border-bottom: 1px solid var(--border); background: #fff; }
  .logo { font-weight: 800; font-size: 1.3rem; } .logo span { color: var(--brand); }
  .pill { border: 1px solid var(--border); border-radius: 999px; padding: 4px 12px; font-size: .9rem; margin-left: 8px; }
  main { max-width: 980px; margin: 0 auto; padding: 28px; }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 16px; }
  .card { background: #fff; border: 1px solid var(--border); border-radius: 14px; padding: 18px; position: relative; }
  .card h3 { margin: 0 0 6px; font-size: 1.05rem; } .price { font-weight: 700; color: var(--brand); }
  .new { position: absolute; top: 12px; right: 12px; background: var(--accent); color: #fff; font-size: .72rem;
         font-weight: 700; padding: 2px 8px; border-radius: 999px; }
  .rating { color: var(--muted); font-size: .9rem; }
  .alert { background: #fef2f2; border: 1px solid #fecaca; color: #991b1b; border-radius: 12px; padding: 12px 16px; margin-bottom: 18px; }
  h2 { font-size: 1rem; margin: 32px 0 10px; color: var(--muted); text-transform: uppercase; letter-spacing: .06em; }
  table { width: 100%; border-collapse: collapse; background: #fff; border: 1px solid var(--border); border-radius: 12px; overflow: hidden; }
  td, th { text-align: left; padding: 8px 12px; border-bottom: 1px solid var(--border); font-size: .92rem; }
  .ok { color: #15803d; font-weight: 600; } .fail { color: #b91c1c; font-weight: 600; }
</style></head><body>
<header><div class="logo">Mesh<span>Mart</span></div>
  <div><span class="pill">Cart: {{.Cart}}</span><span class="pill">Orders: {{.Orders}}</span></div></header>
<main>
  {{if .Broken}}<div class="alert">Part of the store is not responding. See "Served by" below.</div>{{end}}
  <div class="grid">
  {{range .Products}}<div class="card">{{if .New}}<span class="new">NEW</span>{{end}}
    <h3>{{.Name}}</h3><div class="price">&#8377;{{.Price}}</div>
    {{if .Rating}}<div class="rating">&#9733; {{.Rating}}</div>{{end}}</div>
  {{else}}<p>No products to show: the catalog did not answer.</p>{{end}}
  </div>
  <h2>Served by</h2>
  <table><tr><th>Service</th><th>Version</th><th>Status</th><th>Time</th></tr>
  <tr><td>web</td><td>{{.Version}}</td><td class="ok">200</td><td>pod {{.Pod}}</td></tr>
  {{range .Calls}}<tr><td>{{.Service}}</td><td>{{.Version}}</td>
    <td class="{{if and (ge .Status 200) (le .Status 299)}}ok{{else}}fail{{end}}">{{if .Status}}{{.Status}}{{else}}{{.Error}}{{end}}</td>
    <td>{{.Millis}} ms</td></tr>{{end}}
  </table>
</main></body></html>`))
