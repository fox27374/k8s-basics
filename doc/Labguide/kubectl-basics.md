# kubectl basics

> **Goal:** talk to a running cluster with `kubectl` — run a Pod, then list, inspect, read the logs of, and run commands inside it.

**Prerequisites:** a running k3s cluster with `kubectl` configured (see the [README](../../README.md)).

## Concept

`kubectl` is the command-line client for the Kubernetes API server. Almost everything in Kubernetes is a *resource* (Pods, Nodes, Services, …), and you work with them using a handful of verbs: `get` (list), `describe` (details + events), `logs` (container output) and `exec` (run a command inside a container). `kubectl explain` is your built-in documentation. Get comfortable with these — every later chapter builds on them.

## Commands

| Command | Description |
| --- | --- |
| `kubectl get` | list resources (`pods`, `nodes`, …) |
| `kubectl run` | start a single Pod |
| `kubectl describe` | show detailed state and events |
| `kubectl logs` | print a container's logs |
| `kubectl exec` | run a command inside a container |
| `kubectl explain` | show the fields of a resource |

A handy alias used throughout the guide:

```bash
alias k='kubectl'
```

## Tasks

### 1. Confirm you can reach the cluster

```bash
kubectl get nodes
```

<details><summary>Expected output</summary>

```
NAME    STATUS   ROLES                  AGE   VERSION
k3s-1   Ready    control-plane,master   1d    v1.30.5+k3s1
```
</details>

### 2. Run your first Pod

```bash
kubectl run web --image=nginx:alpine
```

### 3. List the Pods

```bash
kubectl get pods
kubectl get pods -o wide      # adds node + Pod IP
kubectl get pods -A           # every namespace
```

<details><summary>Expected output</summary>

```
NAME   READY   STATUS    RESTARTS   AGE
web    1/1     Running   0          15s
```
</details>

### 4. Inspect the Pod and read its events

```bash
kubectl describe pod web
```

> The **Events** section at the bottom is the first place to look when a Pod misbehaves.

### 5. Read the container logs

```bash
kubectl logs web
kubectl logs -f web           # follow (Ctrl-C to stop)
```

### 6. Run a command inside the container

```bash
kubectl exec -it web -- sh
# inside the container:
curl -s localhost
```

### 7. Discover fields with `kubectl explain`

```bash
kubectl explain pod.spec.containers
```

### 8. Namespaces and context

```bash
kubectl get namespaces
kubectl get pods -n kube-system        # k3s system components
kubectl config get-contexts
```

## Recap

- `kubectl` drives the cluster; resources are managed with `get` / `describe` / `logs` / `exec`.
- `describe` shows **events** — your main troubleshooting tool.
- `-o wide`, `-A` and `-n <ns>` change what and where you see.

## Cleanup

```bash
kubectl delete pod web
```

## Going further (optional)

- Add `-o yaml` to any `get` to see the full live object.
- Try `kubectl get pods --watch` in a second terminal while you delete the Pod.
