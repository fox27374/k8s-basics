# Ingress with Traefik IngressRoute

> **Goal:** expose the **frontend** to the outside world with Traefik's `IngressRoute` CRD — the ingress controller k3s bundles.

**Prerequisites:** the [services](services.md) chapter; the `frontend` Deployment + ClusterIP Service running in `shop`.

## Concept

A ClusterIP Service is only reachable inside the cluster. To accept HTTP from outside you need an
**ingress controller** — a reverse proxy at the edge that routes by hostname and path to the right
Service. k3s ships **Traefik** preinstalled and wired to ports 80/443.

Traefik can be driven by the standard Kubernetes `Ingress` object, but its native, more expressive
API is the **`IngressRoute`** custom resource (CRD). An `IngressRoute` has **entryPoints** (which
listener — `web` is :80) and **routes**, each a **match** rule that forwards to one or more Services.
A rule can match on host (``Host(`shop.example`)``), path (``PathPrefix(`/api`)``), or both. We use
`IngressRoute` here because its weighted-services feature is exactly what the
[canary chapter](canary-deployment.md) needs — same object, one step further.

In this lab a **reverse proxy sits in front of the k3s node**, so requests don't arrive with a
specific hostname to match on. Instead of a `Host()` rule we match on path with ``PathPrefix(`/`)``,
which accepts **any** host — every request reaching Traefik on :80 is routed to the frontend. Reach
it at your node's address (or the proxy in front of it); we'll call that `<lab-host>`.

## Commands

| Command | Description |
| --- | --- |
| `kubectl get svc -n kube-system traefik` | show the bundled Traefik controller |
| `kubectl get ingressroute -n shop` | list Traefik IngressRoutes |
| `kubectl describe ingressroute` | inspect routes and matchers |
| `kubectl apply -f` | create an IngressRoute from a manifest |

## Tasks

### 1. Confirm Traefik is running

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
kubectl get svc -n kube-system traefik
```

<details><summary>Expected output</summary>

```
NAME      TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)                      AGE
traefik   LoadBalancer   10.43.0.50     192.168.x.x   80:31600/TCP,443:31832/TCP   1d
```
</details>

> Traefik is exposed via k3s's ServiceLB, so it has an external IP on the node. The `IngressRoute`
> CRD (`traefik.io/v1alpha1`) is installed with it.

### 2. Create an IngressRoute for the frontend

```bash
kubectl apply -f lab/12/ingressroute.yaml
kubectl get ingressroute -n shop frontend
```

The manifest sends every request to the `frontend` Service — no host match:

```yaml
spec:
  entryPoints: [web]                                   # :80
  routes:
    - match: PathPrefix(`/`)                           # any host, any path
      kind: Rule
      services:
        - name: frontend
          port: 80
```

### 3. Reach the app through the IngressRoute

```bash
curl -s http://<lab-host>/
```

<details><summary>Expected output</summary>

```html
<!DOCTYPE html>
<html>
... a page with background-color: blue ...
```
</details>

> The request hits Traefik on :80 and, because the route matches any path on any host, is forwarded
> to the `frontend` Service, which load-balances across the Pods. Replace `<lab-host>` with your node
> or reverse-proxy address; open it in a browser to *see* the blue page.

### 4. Route a second path to another Service

You can host multiple Services behind one entrypoint. Add a `PathPrefix` rule for the api (illustrative):

```yaml
- match: PathPrefix(`/api`)
      kind: Rule
      services:
        - name: api
          port: 80
```

<details><summary>Expected output</summary>

```json
{"version":1,"name":"shop-api","items":["shoes","socks","hats"]}
```
</details>

> Two backends behind one entrypoint, split by path — Traefik sends `/api` to the api Service (the
> longer `PathPrefix` wins) and everything else to the frontend. Re-apply the manifest to drop the
> extra route: `kubectl apply -f lab/12/ingressroute.yaml`.

## Recap

- An **ingress controller** (Traefik on k3s) is the cluster's HTTP edge; it routes by host/path.
- Traefik's **`IngressRoute`** CRD uses **entryPoints** + **match** rules (``Host()``, `PathPrefix()`).
- Matching on ``PathPrefix(`/`)`` accepts any host — the right choice when a reverse proxy fronts the cluster.
- One IngressRoute can fan out to several Services — and to *weighted* Services for canaries (next).

## Cleanup

Keep the IngressRoute for the [canary chapter](canary-deployment.md), or remove it:

```bash
kubectl delete -f lab/12/ingressroute.yaml
```

## Going further (optional)

- Add a **Middleware** CRD (e.g. a redirect-to-HTTPS or basic-auth) and attach it to the route.
- Compare with the portable `kind: Ingress` object: `kubectl explain ingress.spec.rules`. The
  trade-off is portability vs. Traefik's richer matchers and traffic-splitting.
