# CoreLasso Help

## lasso CLI

`lasso` is the CoreLasso companion CLI — a high-level wrapper around the Apple `container` CLI that adds Docker Compose and Dockerfile support. Installed at `/usr/local/bin/lasso`.

### Commands

| Command | Description |
|---------|-------------|
| `lasso up` | Start services from `docker-compose.yml` in the current directory |
| `lasso up -f <file>` | Start services from a specific compose file |
| `lasso up -p <name>` | Set a custom project name (default: `lasso`) |
| `lasso up -f Dockerfile` | Build and run a single container from a Dockerfile |
| `lasso down` | Stop and remove all containers for the project |
| `lasso down -f <file> -p <name>` | Target a specific project |
| `lasso build -t <tag> [ctx]` | Build an image from a Dockerfile |
| `lasso build -f <path> -t <tag> .` | Build from a specific Dockerfile path |
| `lasso ps` | List running containers |
| `lasso help` | Show CLI usage |

### Docker Compose Support

`lasso up` reads standard compose files and translates each service into a native Apple container. Auto-detected filenames (in order): `docker-compose.yml`, `docker-compose.yaml`, `compose.yml`, `compose.yaml`.

**Supported fields:**

| Field | Description |
|-------|-------------|
| `image` | OCI image for the container |
| `build.context` / `build.dockerfile` | Build from source |
| `ports` | Port mappings — `"8080:80"` (host:container) |
| `volumes` | Named volume mounts — `myVol:/data` |
| `environment` | Environment variables — `KEY=VALUE` |
| `networks` | Attach to named networks |
| `command` | Override the default command |
| `entrypoint` | Override the image entrypoint |
| `working_dir` | Working directory inside the container |
| `cpus` | Virtual CPU count |
| `mem_limit` | Memory limit — e.g. `512m`, `2g` |

### Container Naming

Containers are named `<project>_<service>`. With project `myapp` and services `web` + `db` you get `myapp_web` and `myapp_db`. `lasso down` removes them by the same convention.

### Examples

```
lasso up
lasso up -f myapp/docker-compose.yml -p myapp
lasso up -f Dockerfile
lasso down
lasso down -p myapp
lasso build -t my-nginx:latest .
lasso build -f docker/Dockerfile.prod -t app .
lasso ps
```
