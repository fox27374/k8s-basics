# Environment variables

> **Goal:** configure a container with environment variables — set the **frontend**'s `COLOR`, watch the change roll out, and understand why env vars stop scaling once config grows.

**Prerequisites:** the [deployments](deployments.md) chapter, with the `frontend` Deployment running in the `shop` namespace.

## Concept

The simplest way to configure a container is an **environment variable**. In a Pod spec you set them
under a container's `env:` (one name/value pair at a time) or `envFrom:` (import every key from a
ConfigMap or Secret at once). Env vars are the classic "twelve-factor" way to keep configuration out
of the image, so the *same* image behaves differently in dev, staging and prod.

Our **`lab-frontend`** image reads one variable, `COLOR`, and paints the page that colour. Changing
`COLOR` is a change to the Pod template, so the Deployment rolls out new Pods to apply it — config
changes are deployments too. Env vars are perfect for a handful of small values; when configuration
grows into files or needs to be shared across Deployments, you reach for a
[ConfigMap](configmaps.md), and for sensitive values a [Secret](secrets.md). This chapter is the
bridge to both.

## Commands

| Command | Description |
| --- | --- |
| `kubectl set env` | add/change/remove env vars on a Deployment |
| `kubectl exec ... -- env` | print the env vars seen inside a container |
| `kubectl rollout status` | wait for the config change to roll out |

## Tasks

### 1. See the value baked into the manifest

The `frontend` Deployment already sets `COLOR=blue`:

```bash
kubectl get deploy frontend -n shop -o jsonpath='{.spec.template.spec.containers[0].env}' ; echo
```

<details><summary>Expected output</summary>

```
[{"name":"COLOR","value":"blue"}]
```
</details>

### 2. Confirm the container actually sees it

```bash
kubectl exec -n shop deploy/frontend -- env | grep COLOR
```

<details><summary>Expected output</summary>

```
COLOR=blue
```
</details>

> `kubectl exec deploy/frontend` runs in one of the Deployment's Pods — handy for a quick check.

### 3. Change the value and watch it roll out

```bash
kubectl set env deployment/frontend -n shop COLOR=rebeccapurple
kubectl rollout status deployment/frontend -n shop
kubectl exec -n shop deploy/frontend -- env | grep COLOR
```

> Changing an env var edits the Pod template, so the Deployment creates new Pods with the new value
> and retires the old ones — a rolling config change with no downtime. (You'll see the page colour
> change for real once it's exposed in the [services](services.md) and [ingress](ingress.md)
> chapters.)

### 4. Declarative is still the source of truth

`kubectl set env` is imperative. Re-applying the manifest resets `COLOR` to its declared value:

```bash
kubectl apply -f lab/05/frontend-deployment.yaml
kubectl exec -n shop deploy/frontend -- env | grep COLOR     # back to blue
```

### 5. Import many values at once with `envFrom`

You won't list 20 `env:` entries by hand. `envFrom` pulls *every* key from a ConfigMap or Secret in
as env vars — this is exactly how the **db** tier consumes its Secret later:

```yaml
# excerpt — the pattern, not something to apply now
envFrom:
  - secretRef:
      name: db-credentials      # every key (POSTGRES_USER, _PASSWORD, _DB) becomes an env var
```

> Keep this in mind for [Secrets](secrets.md): `lab/09/db-deployment.yaml` uses `envFrom`
> with `secretRef` to feed postgres its credentials.

## Recap

- `env:` sets variables one at a time; `envFrom:` imports all keys from a ConfigMap/Secret.
- Env vars keep config out of the image so one image runs in many environments.
- Changing env edits the Pod template → the Deployment rolls out new Pods.
- Inline env is great for a few values; large or shared config → ConfigMap; secrets → Secret.

## Cleanup

Nothing to remove — leave `frontend` running with `COLOR=blue` for the next chapter.

## Going further (optional)

- `kubectl set env deployment/frontend -n shop COLOR-` (trailing `-`) removes the variable.
- Try the **downward API**: inject the Pod's own name with
  `valueFrom.fieldRef.fieldPath: metadata.name`. Run `kubectl explain pod.spec.containers.env.valueFrom`.
