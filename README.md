# Kubernetes basics training
## Labguide

This guide is inteded to be used during a instructor-led training. Some chapters are structured in the way that students can work on them alone without an instructor.

0) [kubectl basics](doc/Labguide/kubectl-basics.md)
1) [Imperative vs declarative](doc/Labguide/imperative-vs-declarative.md)
2) [Pod manifests](doc/Labguide/pod-manifests.md)
3) [Deployments](doc/Labguide/deployments.md)
4) [Services](doc/Labguide/services.md)
5) [Labels and namespaces](doc/Labguide/labels-and-namespaces.md)
6) [ConfigMaps and Secrets](doc/Labguide/configmaps-and-secrets.md)
7) [Storage](doc/Labguide/storage.md)
8) [Health checks and resources](doc/Labguide/health-and-resources.md)
9) [Rolling updates](doc/Labguide/rolling-updates.md)
10) [Ingress](doc/Labguide/ingress.md)

Optional / advanced:

11) [Helm](doc/Labguide/helm.md)
12) [Capstone: multi-tier app](doc/Labguide/capstone-app.md)


## Lab environment

All commands are tested on [k3s](https://k3s.io) running on [Ubuntu 24.04](https://ubuntu.com). IP addresses and FQDN names are internal lab IPs and names.

k3s gives you a real cluster with batteries included:

- `kubectl` is installed with k3s; the kubeconfig lives at `/etc/rancher/k3s/k3s.yaml`
- **Traefik** ingress controller (used in the Ingress chapter)
- **local-path** default StorageClass (used in the Storage chapter)
- **ServiceLB** so `LoadBalancer` Services work without a cloud provider

Install a single-node cluster with:

```
curl -sfL https://get.k3s.io | sh -
```

Reusable manifests applied during the labs live under [`lab/manifests/`](lab/manifests/).
