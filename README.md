# counting-dockerization

This repository demonstrates how to **containerize and run the HashiCorp Consul demo `counting-service`** in a clean, production-aligned way.

It is designed as a **DevOps knowledge reference** covering:
- Go service containerization best practices
- Small Docker images (multi-stage builds)
- Runtime configuration via environment variables
- Running locally with Docker
- Running in Kubernetes

Source service:
- https://github.com/hashicorp/demo-consul-101/tree/main/services/counting-service

---

## What this repo is (and is not)

✅ **This repo is:**
- A CI/CD–friendly Dockerization example
- A reference for DevOps engineers learning Docker + Kubernetes
- A clean separation between *application source* and *delivery pipeline*

❌ **This repo is not:**
- A fork of the application source code
- A place where business logic lives

The Go source code is fetched during build time or by the CI pipeline.

---

## Architecture overview

```
Client / Browser
       |
       v
Kubernetes Service / Docker Port
       |
       v
counting-service (Go binary)
```

- The container runs **one stateless Go service**
- Configuration is provided at runtime
- The same image works locally and in Kubernetes

---

## Docker image design

### Key principles
- **Multi-stage build** (build tools are not in the final image)
- **Small runtime image** (`scratch` or minimal `alpine`)
- **Runtime configuration via environment variables**

### Resulting image size
- Build stage: ~300MB (Go toolchain, git, deps)
- Runtime stage: ~5–30MB (compiled Go binary only)

---

## Configuration

The service is configured at runtime.

### Environment variables

| Variable | Default | Description |
|--------|--------|-------------|
| `PORT` | `9003` | Port the service listens on |

> Note: Binding to a specific host IP is handled by Docker/Kubernetes networking, not by the Go app itself.

---

## Build the Docker image

```bash
docker build -t counting-service:latest .
```

Verify image size:
```bash
docker images | grep counting-service
```

---

## Run locally with Docker

### Basic run
```bash
docker run --rm \
  -e PORT=9003 \
  -p 9003:9003 \
  counting-service:latest
```

Access:
- http://localhost:9003

### Change the port
```bash
docker run --rm \
  -e PORT=9005 \
  -p 9005:9005 \
  counting-service:latest
```

### Expose one port, run on another (port mapping example)

It is very common in real systems to:
- run the application on **one port inside the container**
- expose it on **a different port on the host**

This is controlled by Docker port mapping:
```
HOST_PORT:CONTAINER_PORT
```

Example:
- Application listens on **9002** inside the container
- Host exposes it on **9004**

```bash
docker run --rm \
  -e PORT=9002 \
  -p 9004:9002 \
  counting-service:latest
```

Access from host:
- http://localhost:9004

What happens internally:
```
Browser -> localhost:9004 -> Docker -> container:9002 -> counting-service
```

This pattern is useful when:
- the host port is already taken
- you want multiple services running on different host ports
- the container image should stay unchanged across environments

> Note: `EXPOSE` in the Dockerfile is **documentation only**. The real port mapping is defined by `-p` (Docker) or `Service` (Kubernetes).

### Bind to localhost only
```bash
docker run --rm \
  -e PORT=9003 \
  -p 127.0.0.1:9003:9003 \
  counting-service:latest
```

---

## Kubernetes usage

### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: counting
spec:
  replicas: 1
  selector:
    matchLabels:
      app: counting
  template:
    metadata:
      labels:
        app: counting
    spec:
      containers:
        - name: counting
          image: counting-service:latest
          imagePullPolicy: IfNotPresent
          env:
            - name: PORT
              value: "9005"
          ports:
            - containerPort: 9005
```

### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: counting
spec:
  selector:
    app: counting
  ports:
    - port: 9005
      targetPort: 9005
  type: ClusterIP
```

Access inside cluster:
```
http://counting:9005
```

### Local access (development)
```bash
kubectl port-forward deploy/counting 9005:9005
```

Then open:
- http://localhost:9005

---

## Why this approach is recommended

- No large base images in production
- Clear separation of concerns
- Works the same in:
  - local Docker
  - CI pipelines
  - Kubernetes clusters
- Matches real-world DevOps practices

---

## Common pitfalls

❌ Building a single-stage image with `golang` base (huge images)

❌ Trying to "link" individual Go files from other repos

❌ Hardcoding ports in Dockerfiles

---

## Next steps

- Add CI pipelines (GitHub Actions / GitLab CI)
- Push image to a registry (GHCR, ECR, GCR, etc.)
- Register the service with Consul in Kubernetes
- Add health checks and probes

---

## Audience

This repository is intended for:
- DevOps engineers
- Platform engineers
- Backend engineers learning containerization

It can be safely used as a **training and reference repo**.