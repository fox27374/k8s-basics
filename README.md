# Kubernetes basics training
## Labguide

This guide is inteded to be used during a instructor-led training. Some chapters are structured in the way that students can work on them alone without an instructor.

The labs build toward one workload: a three-tier **shop** app (frontend + api + db) where each tier
demonstrates one configuration mechanism (env var / ConfigMap / Secret), exposed via a Traefik
IngressRoute, finished with a canary release. Each chapter teaches one building block on its own
first; the [capstone](doc/Labguide/capstone-app.md) assembles them.

0) [kubectl basics](doc/Labguide/kubectl-basics.md)
1) [Imperative vs declarative](doc/Labguide/imperative-vs-declarative.md)
2) [Pods](doc/Labguide/pods.md)
3) [Labels and selectors](doc/Labguide/labels.md)
4) [Deployments](doc/Labguide/deployments.md)
5) [Environment variables](doc/Labguide/environment-variables.md)
6) [Services](doc/Labguide/services.md)
7) [Namespaces](doc/Labguide/namespaces.md)
8) [ConfigMaps](doc/Labguide/configmaps.md)
9) [Secrets](doc/Labguide/secrets.md)
10) [Storage](doc/Labguide/storage.md)
11) [Health checks and resources](doc/Labguide/health-and-resources.md)
12) [Rolling updates and rollbacks](doc/Labguide/rolling-updates.md)
13) [Ingress with Traefik IngressRoute](doc/Labguide/ingress.md)
14) [Canary deployment](doc/Labguide/canary-deployment.md)

Optional / advanced:

15) [Helm](doc/Labguide/helm.md)
16) [Capstone: multi-tier shop app](doc/Labguide/capstone-app.md)


## Lab environment

All commands are tested on [k3s](https://k3s.io) running on [Ubuntu 24.04](https://ubuntu.com). IP addresses and FQDN names are internal lab IPs and names.

k3s gives you a real cluster with batteries included:

- `kubectl` is installed with k3s; the kubeconfig lives at `/etc/rancher/k3s/k3s.yaml`
- **Traefik** ingress controller, including the `IngressRoute` CRD (used in the Ingress and Canary chapters)
- **local-path** default StorageClass (used in the Storage chapter)
- **ServiceLB** so `LoadBalancer` Services work without a cloud provider

Install a single-node cluster with:

```
curl -sfL https://get.k3s.io | sh -
```

Reusable manifests applied during the labs live under [`lab/manifests/`](lab/manifests/).

## Preparing the lab images

Every image the manifests use is pulled from the lab registry at **`cr.lab.local`**. The **frontend**
and **api** tiers are built from this repo ([`lab/environment/`](lab/environment/) and
[`lab/configmap/`](lab/configmap/)); the **db** tier is upstream `postgres:16-alpine` mirrored into
the same registry. Build, tag and push everything **before the training starts** — the
[`lab/build-images.sh`](lab/build-images.sh) script does all of it:

```bash
./lab/build-images.sh                 # build + push to cr.lab.local with docker
REGISTRY=cr.lab.local ENGINE=podman ./lab/build-images.sh   # overrides
```

Or run the steps by hand (note the `-f`, since the build files are named `Containerfile`, not `Dockerfile`):

```bash
# build and tag for the registry (docker or podman both work)
docker build -f lab/environment/Containerfile -t cr.lab.local/lab-frontend:v1 lab/environment
docker build -f lab/environment/Containerfile -t cr.lab.local/lab-frontend:v2 lab/environment   # same image; the "version" is the COLOR env value
docker build -f lab/configmap/Containerfile   -t cr.lab.local/lab-api:1       lab/configmap

# mirror the upstream postgres image into the lab registry
docker pull postgres:16-alpine
docker tag  postgres:16-alpine cr.lab.local/postgres:16-alpine

# push everything
for img in lab-frontend:v1 lab-frontend:v2 lab-api:1 postgres:16-alpine; do
  docker push "cr.lab.local/$img"
done
```

The manifests reference these images by their `cr.lab.local/…` name with `imagePullPolicy: IfNotPresent`,
so each node pulls an image once and then serves it from its local cache.

> **Registry trust / auth.** If `cr.lab.local` serves plain HTTP or uses a private CA, configure the
> k3s nodes to trust it in `/etc/rancher/k3s/registries.yaml` and restart k3s. If it requires
> authentication, put the credentials there too (or create an `imagePullSecret` and reference it from
> the Deployments).

(Building `lab-frontend` twice as `v1`/`v2` is a teaching simplification for the
[canary](doc/Labguide/canary-deployment.md) chapter — the two "versions" differ only by the `COLOR`
env var; a real upgrade would be a genuinely new build.)
