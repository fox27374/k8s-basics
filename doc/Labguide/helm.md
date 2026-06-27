# Helm (optional)

> **Goal:** package, install, configure and upgrade an application with Helm — install a chart as a release, override its values, then upgrade and roll back.

**Prerequisites:** a running k3s cluster with `kubectl`. Helm installs separately (Task 1).

## Concept

Everything so far meant hand-writing and applying manifests. **Helm** is the package manager for
Kubernetes: a **chart** is a templated bundle of manifests, and installing one creates a **release**
(a named, versioned instance you can upgrade and roll back as a unit). You customise a chart by
overriding its **values** (`--set` or a `values.yaml`) instead of editing YAML. Helm tracks each
release's revision history, so `helm rollback` reverts an entire app in one command — the same idea
as `kubectl rollout undo`, but for the whole release rather than a single Deployment.

This chapter uses a public chart so it stands alone from the lab workload.

## Commands

| Command | Description |
| --- | --- |
| `helm repo add` / `helm repo update` | register and refresh a chart repository |
| `helm install` | install a chart as a named release |
| `helm upgrade` | apply changed values / a new chart version |
| `helm rollback` | revert a release to a previous revision |
| `helm list` / `helm uninstall` | list and remove releases |

## Tasks

### 1. Install Helm and add a chart repository

```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### 2. Install a chart as a release

```bash
kubectl create namespace demo
helm install web bitnami/nginx -n demo
helm list -n demo
kubectl get pods -n demo
```

<details><summary>Expected output</summary>

```
NAME    NAMESPACE   REVISION   STATUS     CHART          APP VERSION
web     demo        1          deployed   nginx-x.y.z    1.27.x
```
</details>

### 3. Override values

Inspect what's configurable, then change the replica count:

```bash
helm show values bitnami/nginx | grep -A3 replicaCount
helm upgrade web bitnami/nginx -n demo --set replicaCount=3
kubectl get pods -n demo            # now 3 nginx Pods
```

> `--set` overrides values on the command line; for anything non-trivial keep them in a
> `values.yaml` and pass `-f values.yaml`.

### 4. Upgrade, inspect history, then roll back

```bash
helm history web -n demo
helm rollback web 1 -n demo         # back to revision 1 (replicaCount=1)
helm history web -n demo            # a new revision recording the rollback
kubectl get pods -n demo
```

## Recap

- A **chart** templates manifests; installing one creates a versioned **release**.
- Customise with **values** (`--set` / `-f values.yaml`) instead of editing YAML.
- `helm upgrade` / `helm rollback` manage the whole release's revision history at once.
- Helm is how most third-party software (databases, ingress controllers, monitoring) is shipped.

## Cleanup

```bash
helm uninstall web -n demo
kubectl delete namespace demo
```

## Going further (optional)

- `helm create mychart` scaffolds a chart — package the lab workload (frontend/api/db) as one chart
  with values for image tags and the `COLOR`.
- `helm template .` renders a chart to plain YAML locally without installing — useful in CI/GitOps.
