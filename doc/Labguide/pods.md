# Pods

> **Goal:** define a Pod declaratively in a YAML manifest, apply it, compare your file with the live object, and add a second (sidecar) container.

**Prerequisites:** a running k3s cluster with `kubectl` configured (see the [README](../../README.md)), and the [imperative vs declarative](imperative-vs-declarative.md) chapter.

## Concept

A **manifest** is a YAML file describing the *desired state* of a resource. Every manifest has four
top-level fields: `apiVersion`, `kind`, `metadata` (name, labels) and `spec` (the resource-specific
desired state). For a Pod, the `spec` lists one or more **containers**. A Pod is the smallest
deployable unit in Kubernetes — one or more containers that share a network namespace (the same
`localhost`) and can share volumes. You rarely create bare Pods in production (a Deployment manages
them for you — next chapter), but writing one by hand is the clearest way to learn the manifest
structure every other object reuses.

## Commands

| Command | Description |
| --- | --- |
| `kubectl apply -f` | create/update resources from a manifest |
| `kubectl get -o yaml` | print the live resource as YAML |
| `kubectl explain` | discover the fields available in a `spec` |
| `kubectl delete -f` | delete the resources defined in a manifest |

## Tasks

### 1. Write a Pod manifest

Create `pod.yaml`:

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

### 2. Apply the manifest

```bash
kubectl apply -f pod.yaml
kubectl get pod web
```

<details><summary>Expected output</summary>

```
pod/web created
NAME   READY   STATUS    RESTARTS   AGE
web    1/1     Running   0          8s
```
</details>

### 3. Compare your manifest with the live object

```bash
kubectl get pod web -o yaml | less
```

> Kubernetes fills in dozens of fields you didn't write — `status`, `nodeName`, default values,
> a `creationTimestamp`. Your manifest is the *desired* state; the live object is the *actual*
> state plus all the defaults the API server applied.

### 4. Add a second container (sidecar)

Edit `pod.yaml` so the Pod runs two containers — the nginx server plus a small "sidecar" that just
keeps printing the date:

```yaml
spec:
  containers:
    - name: web
      image: nginx:alpine
      ports:
        - containerPort: 80
    - name: sidecar
      image: busybox
      command: ["sh", "-c", "while true; do date; sleep 5; done"]
```

Apply and inspect:

```bash
kubectl apply -f pod.yaml
kubectl get pod web                  # READY now shows 2/2
kubectl logs web -c sidecar          # -c selects a container in a multi-container Pod
```

<details><summary>Expected output</summary>

```
NAME   READY   STATUS    RESTARTS   AGE
web    2/2     Running   0          20s
```
</details>

> A Pod's containers always share the same node and network. `kubectl exec` and `kubectl logs`
> need `-c <container>` once a Pod has more than one container.

### 5. Delete the Pod via the manifest

```bash
kubectl delete -f pod.yaml
```

## Recap

- Every manifest has `apiVersion`, `kind`, `metadata`, `spec`.
- `kubectl apply -f` creates or updates; `kubectl delete -f` removes what the file defines.
- The live object (`-o yaml`) is your desired spec plus status and defaults.
- A Pod can hold multiple containers that share network and storage; select one with `-c`.

## Cleanup

```bash
kubectl delete pod web --ignore-not-found
```

## Going further (optional)

- Run `kubectl explain pod.spec.containers` and drill into `.resources`, `.env`, `.volumeMounts`.
- Add `kubectl apply --dry-run=server -f pod.yaml` to validate a manifest against the API server
  without creating anything.
