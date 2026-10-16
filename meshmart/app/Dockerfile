# MeshMart: one image for every service in the store (web, catalog, cart, orders, loadgen).
# Alpine (not scratch) so students can `kubectl exec ... -- curl` from any MeshMart pod.
FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS build
ARG TARGETOS TARGETARCH
WORKDIR /src
COPY go.mod ./
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags="-s -w" -o /meshmart .

FROM alpine:3.22
RUN apk add --no-cache curl && adduser -D -u 10001 meshmart
COPY --from=build /meshmart /usr/local/bin/meshmart
USER 10001
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/meshmart"]
