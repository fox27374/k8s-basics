# Labels and namespaces

> **Goal:** organise resources with labels and selectors, and isolate the workload in its own `shop` namespace.

**Prerequisites:** the [services](services.md) chapter; the `frontend` Deployment and Service running in `shop`.

## Concept

**Labels** are arbitrary key/value tags on any object (`app: frontend`, `tier: web`,
`version: v1`). They carry no meaning to Kubernetes by themselves — their power is **selectors**:
Services pick their Pods with a selector, Deployments track their Pods with one, and you query with
`-l`. Good, consistent labels are what make a pile of objects navigable.

**Namespaces** partition a cluster into virtual sub-clusters. Names must be unique *within* a
namespace, not across the cluster, so `frontend` in `shop` and `frontend` in `test` are different
Services. Namespaces are the unit for quotas, RBAC and bulk cleanup (`kubectl delete ns shop`
removes everything inside). Our whole workload lives in **`shop`**.

## Commands

| Command | Description |
| --- | --- |
| `kubectl label` | add or remove labels on objects |
| `kubectl get -l` | select objects by label |
| `kubectl create namespace` / `apply -f` | create a namespace |
| `kubectl config set-context --current --namespace` | set your default namespace |

## Tasks

### 1. Inspect the labels already in place

```bash
kubectl get pods -n shop --show-labels
```

<details><summary>Expected output</summary>

```
NAME                        READY   STATUS    ...   LABELS
frontend-7c9b8d6f5d-abcde   1/1     Running   ...   app=frontend,tier=web,version=v1,...
```
</details>

### 2. Select with label selectors

```bash
kubectl get pods -n shop -l app=frontend            # equality
kubectl get pods -n shop -l 'tier in (web,backend)' # set-based
kubectl get all -n shop -l app=frontend             # every object for the app
```

> This is the same matching a Service uses to find its Pods — selectors are everywhere.

### 3. Add and remove a label

```bash
kubectl label deployment frontend -n shop owner=team-web
kubectl get deploy -n shop -l owner=team-web
kubectl label deployment frontend -n shop owner-        # trailing - removes it
```

### 4. The namespace and your default context

The workload already lives in `shop` (from `lab/manifests/namespace.yaml`). Compare:

```bash
kubectl get namespaces
kubectl get pods                 # your current default namespace (probably empty)
kubectl get pods -n shop         # the workload
```

Set `shop` as your default so you can drop the `-n shop` for the rest of the labs:

```bash
kubectl config set-context --current --namespace=shop
kubectl get pods                 # now lists the shop Pods
```

> To switch back: `kubectl config set-context --current --namespace=default`.

### 5. Namespaces isolate names

```bash
kubectl create namespace test
kubectl get svc -A | grep -E 'NAMESPACE|frontend'   # 'frontend' could exist in both, independently
kubectl delete namespace test                        # deletes everything inside it
```

## Recap

- **Labels** tag objects; **selectors** (`-l`, Service/Deployment selectors) query and wire them.
- **Namespaces** scope names and are the unit of isolation, quotas and bulk delete.
- Set a default namespace with `kubectl config set-context --current --namespace=…`.
- `kubectl delete namespace shop` tears the whole workload down in one command.

## Cleanup

Nothing to remove. (The rest of the guide assumes the `shop` default from Task 4; commands still
show `-n shop` explicitly so they work either way.)

## Going further (optional)

- Annotations (`kubectl annotate`) are like labels but for non-identifying metadata — they can't be
  selected on. `kubectl explain metadata.annotations`.
- Explore a ResourceQuota or LimitRange on the `shop` namespace to cap what the workload can request.
