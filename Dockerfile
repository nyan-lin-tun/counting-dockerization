FROM golang:1.22-alpine AS build
WORKDIR /src

# Needed only for fetching the source
RUN apk add --no-cache git ca-certificates

# Pull external repo (shallow clone to reduce build-time download)
RUN git clone --depth 1 https://github.com/hashicorp/demo-consul-101.git

WORKDIR /src/demo-consul-101/services/counting-service

# Build a small static binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" -o /out/counting-service .

# --- runtime image ---
# Use scratch for the smallest possible image.
# If your service makes HTTPS calls and needs CA certs, switch to alpine in the comment below.
FROM scratch

COPY --from=build /out/counting-service /counting-service

# Defaults (override at runtime with `-e PORT=...` etc.)
ENV PORT=9001
# Note: the upstream demo uses PORT env; binding to a specific IP is usually done via Docker port-publish.
# Keep this here for future compatibility if you add BIND_ADDR support in the Go code.
ENV BIND_ADDR=0.0.0.0

EXPOSE 9001
ENTRYPOINT ["/counting-service"]
# Users can provide CLI args after the image name; they will be appended to ENTRYPOINT.
CMD []

# If you need CA certificates for outbound HTTPS, replace the runtime stage above with:
# FROM alpine:3.20
# RUN apk add --no-cache ca-certificates
# COPY --from=build /out/counting-service /usr/local/bin/counting-service
# EXPOSE 9001
# ENTRYPOINT ["/usr/local/bin/counting-service"]