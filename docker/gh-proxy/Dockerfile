# ============================================================
# gh-proxy – GitHub API reverse proxy (token injected server-side)
# Built with Go + Fiber for minimal footprint & low latency
# ============================================================

# ---- Build stage ----
FROM golang:1.25-alpine AS builder

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /gh-proxy .

# ---- Runtime stage ----
FROM alpine:3.20

RUN apk add --no-cache ca-certificates wget

COPY --from=builder /gh-proxy /gh-proxy

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD wget -qO- http://localhost:8080/health || exit 1

ENTRYPOINT ["/gh-proxy"]
