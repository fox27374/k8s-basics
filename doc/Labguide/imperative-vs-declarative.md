# Imperative vs declarative

> **Goal:** understand the two ways to drive Kubernetes — telling it *what to do* (imperative) versus telling it *what you want* (declarative) — and when to reach for each.

**Prerequisites:** a running k3s cluster with `kubectl` configured (see the [README](../../README.md)), and the [kubectl basics](kubectl-basics.md) chapter.

## Concept

There are two styles for working with the Kubernetes API:

- **Imperative** — you issue a command that performs an action *now*: `kubectl run`, `kubectl create`, `kubectl scale`, `kubectl edit`. Fast and great for learning, debugging and one-off tasks, but the desired state lives only in your shell history.
- **Declarative** — you write a manifest that describes the *desired state* and hand it to the cluster with `kubectl apply -f`. Kubernetes figures out the changes needed to reach that state. The manifest is a file you can review, commit to git and re-apply. This is how real clusters are run (GitOps).

A useful rule of thumb: **imperative to explore, declarative to operate.** Imperative commands can also *generate* manifests for you (`--dry-run=client -o yaml`), which is the fastest way to a correct starting YAML.

## Commands

| Command | Description |
| --- | --- |
| `kubectl run` / `kubectl create` | imperative: create a resource directly |
| `kubectl scale` / `kubectl edit` | imperative: change a live resource in place |
| `kubectl apply -f` | declarative: reconcile the cluster to a manifest |
| `kubectl diff -f` | preview what `apply` would change |
| `kubectl delete -f` | delete the resources defined in a manifest |
| `--dry-run=client -o yaml` | generate a manifest without touching the cluster |

## Tasks

### 1. The imperative way: create a Pod with one command

```bash
kubectl run web --image=nginx:alpine
kubectl get pod web
```

The Pod exists, but the only record of *how* you made it is this command. There is no file to review or re-use.

### 2. Change it imperatively

```bash
kubectl create deployment api --image=nginx:alpine
kubectl scale deployment api --replicas=3
kubectl get deployment api
```

<details><summary>Expected output</summary>

```
NAME   READY   UP-TO-DATE   AVAILABLE   AGE
api    3/3     3            3           20s
```
</details>

> Each command mutates the cluster immediately. Effective for quick fixes — but if a teammate asks "why are there 3 replicas?", the answer is buried in someone's terminal.

### 3. Generate a manifest from an imperative command

Add `--dry-run=client -o yaml` to *print* what would be created instead of creating it:

```bash
kubectl create deployment api --image=nginx:alpine --replicas=3 \
  --dry-run=client -o yaml > api-deployment.yaml
```

You now have a starting manifest without hand-writing YAML. Open `api-deployment.yaml` and have a look.

### 4. The declarative way: write a manifest

Create `web-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web
  labels:
    app: web
spec:
  containers:
    - name: web
      image: nginx:alpine
      ports:
        - containerPort: 80
```

### 5. Apply it

```bash
kubectl apply -f web-pod.yaml
```

<details><summary>Expected output</summary>

```
pod/web created
```
</details>

> If the Pod already exists from Task 1, delete it first (`kubectl delete pod web`) so the manifest owns it.

### 6. Re-apply to see reconciliation (idempotency)

Run the exact same command again:

```bash
kubectl apply -f web-pod.yaml
```

<details><summary>Expected output</summary>

```
pod/web unchanged
```
</details>

> Re-running an imperative `kubectl run web ...` would instead error with *AlreadyExists*. `apply` is **idempotent** — it only changes what differs from the desired state.

### 7. Edit the file, preview, then apply

Change `image: nginx:alpine` to `image: nginx:1.27-alpine` in `web-pod.yaml`, then:

```bash
kubectl diff -f web-pod.yaml      # preview the change
kubectl apply -f web-pod.yaml     # apply it
```

> `kubectl diff` shows exactly what `apply` would do — your safety net before changing a live cluster.

### 8. Delete via the manifest

```bash
kubectl delete -f web-pod.yaml
```

The same file that created the resource also cleans it up — no need to remember resource names.

## Recap

- **Imperative** (`run`, `create`, `scale`, `edit`) acts immediately; the intent lives only in your shell history.
- **Declarative** (`apply -f`) reconciles the cluster to a file you can review, commit and re-apply.
- `apply` is **idempotent**; `kubectl diff -f` previews changes before they happen.
- `--dry-run=client -o yaml` turns an imperative command into a manifest — the fastest path to good YAML.

## Cleanup

```bash
kubectl delete pod web --ignore-not-found
kubectl delete deployment api --ignore-not-found
```

## Going further (optional)

- Try `kubectl apply -f .` to apply every manifest in a directory at once.
- Run `kubectl edit deployment api` and then ask yourself how you'd reproduce that change on another cluster — this is the core motivation for going declarative.
- Read about `kubectl apply` and the `last-applied-configuration` annotation it stores to track desired state.
