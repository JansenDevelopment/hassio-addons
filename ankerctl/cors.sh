#!/bin/sh
# Patch for ankerctl 1.0.3: optional CORS for a few trusted origins.
#
# The Home Assistant wall tablet app is served from HA (port 8123) and calls
# ankerctl (port 4470) for print control, upload and reprint. Without CORS the
# browser blocks those calls. ANKERCTL_CORS_ORIGINS is a comma-separated list
# of exact origins (scheme://host:port); unset or empty = no CORS, as upstream.
set -eu
F=internal/web/server.go

grep -q 'r.Use(chimw.Recoverer)' "$F"
sed -i 's|\tr.Use(chimw.Recoverer)|\tr.Use(chimw.Recoverer)\n\tr.Use(corsFromEnv)|' "$F"

cat > internal/web/cors_patch.go <<'GO'
package web

import (
	"net/http"
	"os"
	"strings"
)

// corsFromEnv answers CORS for the exact origins in ANKERCTL_CORS_ORIGINS,
// including preflight. Other origins get no CORS headers (upstream behaviour).
func corsFromEnv(next http.Handler) http.Handler {
	allowed := map[string]bool{}
	for _, o := range strings.Split(os.Getenv("ANKERCTL_CORS_ORIGINS"), ",") {
		if o = strings.TrimRight(strings.TrimSpace(o), "/"); o != "" {
			allowed[o] = true
		}
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin != "" && allowed[origin] {
			h := w.Header()
			h.Set("Access-Control-Allow-Origin", origin)
			h.Add("Vary", "Origin")
			h.Set("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
			h.Set("Access-Control-Allow-Headers", "Content-Type, X-Api-Key")
			h.Set("Access-Control-Max-Age", "600")
			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusNoContent)
				return
			}
		}
		next.ServeHTTP(w, r)
	})
}
GO

grep -q 'r.Use(corsFromEnv)' "$F"
echo "cors patch applied"
