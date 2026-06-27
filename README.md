# Kubernetes basics training
## Labguide

This guide is inteded to be used during a instructor-led training. Some chapters are structured in the way that students can work on them alone without an instructor.

The labs build toward one workload: a three-tier **shop** app (frontend + api + db) where each tier
demonstrates one configuration mechanism (env var / ConfigMap / Secret), exposed via a Traefik
IngressRoute, finished with a canary release. Each chapter teaches one building block on its own
first; the [capstone](doc/Labguide/capstone-app.md) assembles them.

0) [kubectl basics](doc/Labguide/kubectl-basics.md)
1) [Imperative vs declarative](doc/Labguide/imperative-vs-declarative.md)
2) [Pod manifests](doc/Labguide/pod-manifests.md)
3) [Deployments](doc/Labguide/deployments.md)
4) [Environment variables](doc/Labguide/environment-variables.md)
5) [Services](doc/Labguide/services.md)
6) [Labels and namespaces](doc/Labguide/labels-and-namespaces.md)
7) [ConfigMaps](doc/Labguide/configmaps.md)
8) [Secrets](doc/Labguide/secrets.md)
9) [Storage](doc/Labguide/storage.md)
10) [Health checks and resources](doc/Labguide/health-and-resources.md)
11) [Rolling updates and rollbacks](doc/Labguide/rolling-updates.md)
12) [Ingress with Traefik IngressRoute](doc/Labguide/ingress.md)
13) [Canary deployment](doc/Labguide/canary-deployment.md)

Optional / advanced:

14) [Helm](doc/Labguide/helm.md)
15) [Capstone: multi-tier shop app](doc/Labguide/capstone-app.md)


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

## Building the lab images

The **frontend** and **api** tiers use two small images built from this repo
([`lab/environment/`](lab/environment/) and [`lab/configmap/`](lab/configmap/)). The **db** tier uses
stock `postgres:16-alpine` (pulled normally). There's no registry — build the images and side-load
them straight into k3s's containerd:

```bash
# build (docker or podman both work)
docker build -t lab-frontend:v1 lab/environment
docker build -t lab-frontend:v2 lab/environment   # same image; the "version" is the COLOR env value
docker build -t lab-api:1       lab/configmap

# import into k3s so Pods can run them without pulling from a registry
for img in lab-frontend:v1 lab-frontend:v2 lab-api:1; do
  docker save "$img" | sudo k3s ctr images import -
done
```

The manifests set `imagePullPolicy: IfNotPresent` so k3s uses these imported images instead of trying
to pull them. (Building `lab-frontend` twice as `v1`/`v2` is a teaching simplification for the
[canary](doc/Labguide/canary-deployment.md) chapter — the two "versions" differ only by the `COLOR`
env var; a real upgrade would be a genuinely new build.)
