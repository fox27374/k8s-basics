# Services

> **Goal:** give a set of Pods one stable address, load-balance across them, and reach them by DNS name from inside the cluster.

**Prerequisites:** the [deployments](deployments.md) chapter, with the `frontend` Deployment running in the `shop` namespace.

## Concept

Pods are disposable — they come and go, each with a different IP. A **Service** is a stable virtual
IP and DNS name in front of a *set* of Pods, chosen by a **label selector**. Traffic to the Service
is load-balanced across the matching Pods, and the set updates automatically as Pods come and go.
The default type, **ClusterIP**, is reachable only inside the cluster — exactly what you want for
tier-to-tier traffic (frontend → api → db). Every Service gets a DNS name:
`<service>.<namespace>.svc.cluster.local` (within the same namespace just `<service>` works).
To reach a Service from *outside* the cluster you use a **NodePort**, a **LoadBalancer**, or an
[Ingress](ingress.md) — covered later.

## Commands

| Command | Description |
| --- | --- |
| `kubectl expose` | create a Service for a Deployment imperatively |
| `kubectl apply -f` | create a Service from a manifest |
| `kubectl get svc` | list Services and their ClusterIPs |
| `kubectl get endpoints` | show which Pod IPs a Service currently targets |

## Tasks

### 1. Expose the frontend as a ClusterIP Service

```bash
kubectl apply -f lab/06/frontend-service.yaml
kubectl get svc -n shop frontend
```

<details><summary>Expected output</summary>

```
NAME       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
frontend   ClusterIP   10.43.182.77    <none>        80/TCP    5s
```
</details>

The imperative equivalent is `kubectl expose deployment frontend -n shop --port=80`.

### 2. See which Pods it targets

```bash
kubectl get endpoints frontend -n shop
```

> The Service selector (`app: frontend, version: v1`) matched the frontend Pods and turned their
> IPs into endpoints. Scale the Deployment and re-run — the endpoint list tracks the Pods.

### 3. Reach the Service by DNS from another Pod

Start a throwaway client Pod and curl the Service by name:

```bash
kubectl run client --rm -it --image=curlimages/curl -n shop --restart=Never -- \
  curl -s http://frontend
```

<details><summary>Expected output</summary>

```
<!DOCTYPE html>
<html>
... a page with background-color: blue ...
```
</details>

> From inside `shop`, `http://frontend` resolves. From another namespace you'd use the fully
> qualified `http://frontend.shop.svc.cluster.local`. This is **service discovery** — tiers find
> each other by name, never by Pod IP.

### 4. Repeat the load-balancing across replicas

The **api** tier makes load-balancing visible because each Pod returns its own hostname. (You'll
deploy it in the [ConfigMaps](configmaps.md) chapter.) Once `api` is running:

```bash
kubectl run client --rm -it --image=curlimages/curl -n shop --restart=Never -- \
  sh -c 'for i in 1 2 3 4; do curl -s http://api/ ; echo; done'
```

> The `name` field in the responses alternates between Pod hostnames — the Service is balancing
> across the ReplicaSet.

### 5. Try a NodePort (external access without Ingress)

Switch the Service to `NodePort` to reach it on a node port directly:

```bash
kubectl patch svc frontend -n shop -p '{"spec":{"type":"NodePort"}}'
kubectl get svc frontend -n shop          # note the 3xxxx port under PORT(S)
curl -s http://<node-ip>:<nodePort>       # replace with your k3s node IP and the assigned port
```

Then switch it back (Ingress is the cleaner way to expose HTTP):

```bash
kubectl apply -f lab/06/frontend-service.yaml
```

## Recap

- A **Service** is a stable IP + DNS name over a label-selected set of Pods, with load-balancing.
- **ClusterIP** (default) is internal — the right type for tier-to-tier traffic.
- DNS: `<service>` in-namespace, `<service>.<namespace>.svc.cluster.local` across namespaces.
- **NodePort**/**LoadBalancer**/**Ingress** expose a Service outside the cluster.

## Cleanup

Keep `frontend` + its Service for later chapters, or:

```bash
kubectl delete -f lab/06/frontend-service.yaml
```

## Going further (optional)

- `kubectl get svc -n shop frontend -o yaml | grep -A3 selector` — the selector is the whole story.
- A **headless** Service (`clusterIP: None`) returns Pod IPs directly instead of one virtual IP —
  used by StatefulSets. Run `kubectl explain service.spec.clusterIP`.
