// MeshMart: one small HTTP service that plays every role in the MeshMart example store.
//
// The same binary runs as web, catalog (v1/v2), cart, orders and loadgen. Behaviour is set
// with environment variables, so each Deployment differs only in its env:
//
//	SERVICE           service name shown in responses (web, catalog, cart, orders, loadgen)
//	VERSION           version label shown in responses (v1, v2, ...)
//	PORT              listen port (default 8080)
//	UPSTREAMS         comma-separated services to call on every request, e.g. "catalog,cart".
//	                  A bare name means http://<name>/; a full URL is used as is.
//	UPSTREAM_TIMEOUT  how long to wait for each upstream (default 30s: long on purpose, so
//	                  timeouts are something you configure in Istio, not in the app)
//	DELAY             extra latency per request, e.g. "3s" (default none)
//	DELAY_PERCENT     share of requests that get DELAY, 0-100 (default 100)
//	ERROR_PERCENT     share of requests answered with ERROR_CODE, 0-100 (default 0)
//	ERROR_CODE        HTTP status for injected errors (default 503)
//	TARGET            loadgen only: URL to call (default http://web/)
//	RATE              loadgen only: requests per second (default 2)
//
// Endpoints: /healthz (liveness/readiness), /version (plain-text version, handy in checks),
// /stats (loadgen counters; ?reset=1 clears them), and everything else returns this
// service's response (JSON, or an HTML storefront when a browser asks web for a page).
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math/rand/v2"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

// Headers copied from the incoming request to every upstream call: tracing headers so a
// request shows up as one trace, plus the ones the course uses for routing and auth.
var forwardHeaders = []string{
	"x-request-id", "traceparent", "tracestate",
	"x-b3-traceid", "x-b3-spanid", "x-b3-parentspanid", "x-b3-sampled", "x-b3-flags", "b3",
	"x-ot-span-context", "x-preview", "authorization",
}

type config struct {
	Service, Version, Port string
	Upstreams              []string
	UpstreamTimeout        time.Duration
	Delay                  time.Duration
	DelayPercent           int
	ErrorPercent           int
	ErrorCode              int
	Target                 string
	Rate                   float64
}

func env(key, def string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return def
}

func envInt(key string, def int) int {
	v, err := strconv.Atoi(env(key, strconv.Itoa(def)))
	if err != nil {
		log.Fatalf("%s: not a number: %v", key, err)
	}
	return v
}

func envDuration(key string, def time.Duration) time.Duration {
	s := env(key, "")
	if s == "" {
		return def
	}
	d, err := time.ParseDuration(s)
	if err != nil {
		log.Fatalf("%s: not a duration (e.g. 500ms, 3s): %v", key, err)
	}
	return d
}

func loadConfig() config {
	c := config{
		Service:         env("SERVICE", "meshmart"),
		Version:         env("VERSION", "v1"),
		Port:            env("PORT", "8080"),
		UpstreamTimeout: envDuration("UPSTREAM_TIMEOUT", 30*time.Second),
		Delay:           envDuration("DELAY", 0),
		DelayPercent:    envInt("DELAY_PERCENT", 100),
		ErrorPercent:    envInt("ERROR_PERCENT", 0),
		ErrorCode:       envInt("ERROR_CODE", http.StatusServiceUnavailable),
		Target:          env("TARGET", "http://web/"),
	}
	for _, u := range strings.Split(os.Getenv("UPSTREAMS"), ",") {
		if u = strings.TrimSpace(u); u != "" {
			c.Upstreams = append(c.Upstreams, u)
		}
	}
	rate, err := strconv.ParseFloat(env("RATE", "2"), 64)
	if err != nil || rate <= 0 {
		log.Fatalf("RATE: must be a positive number")
	}
	c.Rate = rate
	return c
}

// upstreamURL turns "catalog" into "http://catalog/" and leaves full URLs alone.
func upstreamURL(u string) string {
	if strings.Contains(u, "://") {
		return u
	}
	return "http://" + u + "/"
}

// upstreamName is the label used in responses: the bare name, or the URL's host.
func upstreamName(u string) string {
	if i := strings.Index(u, "://"); i >= 0 {
		u = u[i+3:]
	}
	return strings.SplitN(strings.SplitN(u, "/", 2)[0], ":", 2)[0]
}

// Response is what every MeshMart service returns as JSON.
type Response struct {
	Service   string     `json:"service"`
	Version   string     `json:"version"`
	Pod       string     `json:"pod"`
	Path      string     `json:"path"`
	Data      any        `json:"data,omitempty"`
	Upstreams []Upstream `json:"upstreams,omitempty"`
}

// Upstream records one call this service made while answering a request.
type Upstream struct {
	Service  string    `json:"service"`
	Status   int       `json:"status"`
	Version  string    `json:"version,omitempty"`
	Millis   int64     `json:"ms"`
	Error    string    `json:"error,omitempty"`
	Response *Response `json:"response,omitempty"`
}

type product struct {
	ID     string  `json:"id"`
	Name   string  `json:"name"`
	Price  int     `json:"price_inr"`
	Rating float64 `json:"rating,omitempty"`
	New    bool    `json:"new,omitempty"`
}

// payload is the business data each service returns. catalog v2 adds ratings and a new
// product, so a canary is visible both in the JSON and on the storefront.
func payload(service, version string) any {
	switch service {
	case "catalog":
		p := []product{
			{ID: "mesh-mug", Name: "Mesh mug", Price: 349},
			{ID: "sidecar-socks", Name: "Sidecar socks", Price: 199},
			{ID: "envoy-tee", Name: "Envoy tee", Price: 699},
			{ID: "sticker-pack", Name: "Sticker pack", Price: 99},
		}
		if version != "v1" {
			ratings := []float64{4.6, 4.2, 4.8, 4.5}
			for i := range p {
				p[i].Rating = ratings[i]
			}
			p = append(p, product{ID: "ambient-hoodie", Name: "Ambient hoodie", Price: 1499, Rating: 4.9, New: true})
		}
		return map[string]any{"products": p}
	case "cart":
		return map[string]any{"items": []map[string]any{{"id": "mesh-mug", "qty": 1}, {"id": "sticker-pack", "qty": 2}}}
	case "orders":
		return map[string]any{"orders": []map[string]any{{"id": "MM-1042", "status": "shipped"}, {"id": "MM-1043", "status": "packing"}}}
	}
	return nil
}

type server struct {
	cfg    config
	pod    string
	client *http.Client
	stats  *loadStats
}

func (s *server) callUpstream(ctx context.Context, in *http.Request, u string) Upstream {
	up := Upstream{Service: upstreamName(u)}
	start := time.Now()
	defer func() { up.Millis = time.Since(start).Milliseconds() }()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, upstreamURL(u), nil)
	if err != nil {
		up.Error = err.Error()
		return up
	}
	for _, h := range forwardHeaders {
		if v := in.Header.Get(h); v != "" {
			req.Header.Set(h, v)
		}
	}
	req.Header.Set("Accept", "application/json")
	resp, err := s.client.Do(req)
	if err != nil {
		up.Error = err.Error()
		return up
	}
	defer resp.Body.Close()
	up.Status = resp.StatusCode
	var r Response
	if json.NewDecoder(resp.Body).Decode(&r) == nil && r.Service != "" {
		up.Version = r.Version
		up.Response = &r
	}
	return up
}

func (s *server) handle(w http.ResponseWriter, r *http.Request) {
	// Injected faults come first, like a slow or failing dependency would.
	if s.cfg.Delay > 0 && rand.IntN(100) < s.cfg.DelayPercent {
		select {
		case <-time.After(s.cfg.Delay):
		case <-r.Context().Done():
			return
		}
	}
	if s.cfg.ErrorPercent > 0 && rand.IntN(100) < s.cfg.ErrorPercent {
		http.Error(w, fmt.Sprintf("%s %s: injected error", s.cfg.Service, s.cfg.Version), s.cfg.ErrorCode)
		return
	}

	resp := Response{Service: s.cfg.Service, Version: s.cfg.Version, Pod: s.pod, Path: r.URL.Path,
		Data: payload(s.cfg.Service, s.cfg.Version)}
	if len(s.cfg.Upstreams) > 0 {
		ctx, cancel := context.WithTimeout(r.Context(), s.cfg.UpstreamTimeout)
		defer cancel()
		resp.Upstreams = make([]Upstream, len(s.cfg.Upstreams))
		var wg sync.WaitGroup
		for i, u := range s.cfg.Upstreams {
			wg.Add(1)
			go func() {
				defer wg.Done()
				resp.Upstreams[i] = s.callUpstream(ctx, r, u)
			}()
		}
		wg.Wait()
	}

	// The store only works if every service it depends on answered.
	status := http.StatusOK
	for _, u := range resp.Upstreams {
		if u.Status < 200 || u.Status > 299 {
			status = http.StatusBadGateway
		}
	}

	if s.cfg.Service == "web" && strings.Contains(r.Header.Get("Accept"), "text/html") {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.WriteHeader(status)
		if err := storefront.Execute(w, storefrontView(resp)); err != nil {
			log.Printf("render: %v", err)
		}
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	_ = enc.Encode(resp)
}

// loadStats counts loadgen results since the last reset.
type loadStats struct {
	mu        sync.Mutex
	Target    string         `json:"target"`
	Since     time.Time      `json:"since"`
	Sent      int            `json:"sent"`
	OK        int            `json:"ok"`
	Failed    int            `json:"failed"`
	Codes     map[string]int `json:"codes"`
	LastError string         `json:"last_error,omitempty"`
}

func (l *loadStats) reset() {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.Since, l.Sent, l.OK, l.Failed, l.Codes, l.LastError = time.Now(), 0, 0, 0, map[string]int{}, ""
}

func (l *loadStats) record(code int, err error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.Sent++
	key := strconv.Itoa(code)
	if err != nil {
		key, l.LastError = "error", err.Error()
	}
	l.Codes[key]++
	if err == nil && code >= 200 && code <= 299 {
		l.OK++
	} else {
		l.Failed++
		if err == nil {
			l.LastError = fmt.Sprintf("HTTP %d", code)
		}
	}
}

func (s *server) runLoad(ctx context.Context) {
	tick := time.NewTicker(time.Duration(float64(time.Second) / s.cfg.Rate))
	defer tick.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-tick.C:
			go func() {
				req, err := http.NewRequestWithContext(ctx, http.MethodGet, s.cfg.Target, nil)
				if err != nil {
					s.stats.record(0, err)
					return
				}
				resp, err := s.client.Do(req)
				if err != nil {
					if !errors.Is(ctx.Err(), context.Canceled) {
						s.stats.record(0, err)
					}
					return
				}
				resp.Body.Close()
				s.stats.record(resp.StatusCode, nil)
			}()
		}
	}
}

func (s *server) handleStats(w http.ResponseWriter, r *http.Request) {
	if s.stats == nil {
		http.Error(w, "stats are only kept by loadgen", http.StatusNotFound)
		return
	}
	if r.URL.Query().Get("reset") != "" {
		s.stats.reset()
	}
	s.stats.mu.Lock()
	defer s.stats.mu.Unlock()
	rate := 100.0
	if s.stats.Sent > 0 {
		rate = float64(s.stats.OK) * 100 / float64(s.stats.Sent)
	}
	w.Header().Set("Content-Type", "application/json")
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	_ = enc.Encode(map[string]any{
		"target": s.stats.Target, "since": s.stats.Since.UTC().Format(time.RFC3339),
		"sent": s.stats.Sent, "ok": s.stats.OK, "failed": s.stats.Failed,
		"success_rate": float64(int(rate*10)) / 10, "codes": s.stats.Codes, "last_error": s.stats.LastError,
	})
}

func main() {
	cfg := loadConfig()
	pod, _ := os.Hostname()
	s := &server{cfg: cfg, pod: pod, client: &http.Client{Timeout: cfg.UpstreamTimeout}}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, os.Interrupt)
	defer stop()
	if cfg.Service == "loadgen" {
		s.stats = &loadStats{Target: cfg.Target}
		s.stats.reset()
		go s.runLoad(ctx)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { fmt.Fprintln(w, "ok") })
	mux.HandleFunc("/version", func(w http.ResponseWriter, _ *http.Request) { fmt.Fprintln(w, cfg.Version) })
	mux.HandleFunc("/stats", s.handleStats)
	mux.HandleFunc("/", s.handle)

	srv := &http.Server{Addr: ":" + cfg.Port, Handler: mux, ReadHeaderTimeout: 10 * time.Second}
	go func() {
		<-ctx.Done()
		shutdown, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		_ = srv.Shutdown(shutdown)
	}()
	log.Printf("meshmart %s %s listening on :%s (upstreams: %v)", cfg.Service, cfg.Version, cfg.Port, cfg.Upstreams)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}
