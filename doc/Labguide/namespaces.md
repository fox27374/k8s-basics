# Namespaces

> **Goal:** partition a cluster with namespaces — see why the workload lives in `shop`, set it as your default, reach across namespaces by DNS, and cap a namespace with a ResourceQuota.

**Prerequisites:** the [labels and selectors](labels.md) chapter, plus the **frontend** tier running
in the `shop` namespace — the `shop` namespace and `frontend` Deployment are created in the
[Deployments](deployments.md) chapter and its Service in the [Services](services.md) chapter.

## Concept

A **namespace** is a virtual sub-cluster: a scope for object *names* and a boundary for policy.
Names must be unique *within* a namespace, not across the cluster, so a `frontend` Service in `shop`
and a `frontend` Service in `test` are entirely separate. Namespaces are the unit for:

- **isolation** — group an app, a team, or an environment (dev/test/prod) together;
- **policy** — RBAC roles, NetworkPolicies, ResourceQuotas and LimitRanges all attach to a namespace;
- **bulk cleanup** — `kubectl delete namespace shop` removes everything inside it in one command.

Not everything is namespaced: cluster-wide objects like Nodes, PersistentVolumes and StorageClasses
live *outside* any namespace. k3s starts with `default` (where you land if you specify nothing),
plus `kube-system` (the cluster's own components) and a couple of others. Our whole workload lives in
**`shop`**, created from [`lab/07/namespace.yaml`](../../lab/07/namespace.yaml).

## Commands

| Command | Description |
| --- | --- |
| `kubectl get namespaces` | list namespaces |
| `kubectl create namespace` / `apply -f` | create a namespace |
| `kubectl get … -n <ns>` / `-A` | scope a query to a namespace / all namespaces |
| `kubectl config set-context --current --namespace` | set your default namespace |
| `kubectl api-resources --namespaced=false` | list cluster-scoped (non-namespaced) kinds |

## Tasks

### 1. List the namespaces that exist

```bash
kubectl get namespaces
```

<details><summary>Expected output</summary>

```
NAME              STATUS   AGE
default           Active   1d
kube-system       Active   1d
kube-public       Active   1d
kube-node-lease   Active   1d
shop              Active   2h
```
</details>

### 2. The same query is empty or full depending on the namespace

```bash
kubectl get pods                 # your current default (probably 'default' → empty)
kubectl get pods -n shop         # the workload
kubectl get pods -A              # every namespace, including kube-system
```

> `-A` (`--all-namespaces`) is how you find a Pod when you're not sure where it lives.

### 3. Set `shop` as your default namespace

So you can drop the `-n shop` for the rest of the guide:

```bash
kubectl config set-context --current --namespace=shop
kubectl get pods                 # now lists the shop Pods without -n
```

> This edits your kubeconfig's current context — it's a client-side convenience, nothing changes in
> the cluster. Switch back any time with `kubectl config set-context --current --namespace=default`.

### 4. Namespaces isolate names

Create a second namespace and prove the same name can coexist:

```bash
kubectl create namespace test
kubectl create deployment frontend --image=nginx:alpine -n test    # same name as the shop one — fine
kubectl get deploy -A | grep frontend                              # one in shop, one in test
```

<details><summary>Expected output</summary>

```
shop   frontend   2/2   ...
test   frontend   1/1   ...
```
</details>

### 5. Reach a Service across namespaces by DNS

A short name only resolves within the *same* namespace; across namespaces you qualify it with the
namespace. From a Pod in `test`, the `shop` frontend Service is `frontend.shop`:

```bash
kubectl run client --rm -it --image=curlimages/curl -n test --restart=Never -- \
  sh -c 'curl -s http://frontend.shop/ | grep background-color; curl -s http://frontend.shop.svc.cluster.local/ | grep background-color'
```

<details><summary>Expected output</summary>

```
      background-color: blue;
      background-color: blue;
```
</details>

> DNS form is `<service>.<namespace>.svc.cluster.local`. In-namespace you can use just `<service>`;
> across namespaces add `.<namespace>`. This is why tiers find each other by name, not IP.

### 6. Tear a namespace down in one command

```bash
kubectl delete namespace test     # deletes the deployment, quota, everything inside it
```

> This is the cleanest teardown there is — and exactly how you'd remove the whole workload:
> `kubectl delete namespace shop`.

## Recap

- A **namespace** scopes object names and is the boundary for RBAC, quotas and NetworkPolicies.
- Cluster-scoped objects (Nodes, PVs, StorageClasses) live outside any namespace.
- `-n <ns>` scopes a command, `-A` spans all; set a default with `kubectl config set-context …`.
- Cross-namespace DNS is `<service>.<namespace>` (or the full `…svc.cluster.local`).
- `kubectl delete namespace <ns>` removes everything inside in one go.

## Cleanup

```bash
kubectl delete namespace test --ignore-not-found
# keep `shop` — the rest of the guide uses it (and assumes it's your default from Task 3)
```

## Going further (optional)

- A **LimitRange** sets default/min/max requests per Pod in a namespace — pair it with a ResourceQuota.
- Namespaces are *not* a hard security boundary by themselves; combine RBAC + NetworkPolicies for
  real multi-tenant isolation. `kubectl explain networkpolicy.spec`.
