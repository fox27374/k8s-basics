# ConfigMaps

> **Goal:** move configuration out of the image with a ConfigMap — inject values as env vars, and mount a config file into the **api** tier of the workload.

**Prerequisites:** the [environment variables](environment-variables.md) chapter; lab images pushed to `cr.lab.local`; working in the `shop` namespace.

## Concept

A **ConfigMap** stores non-sensitive configuration as key/value pairs, decoupled from the container
image. You consume it two ways: **as environment variables** (single keys via `valueFrom`, or all
keys via `envFrom`), or **as files** by mounting it as a volume — each key becomes a file whose
contents are the value. Mounting is the right choice when an app reads a config *file* rather than
env vars.

Our **`lab-api`** app (a small Go service) reads a file at `/data.json` and serves it at `/api`,
and serves its own Pod hostname at `/`. We supply that file from a ConfigMap, so we can change the
API's data without rebuilding the image. ConfigMaps are for *non-secret* config; for passwords and
tokens use a [Secret](secrets.md) (next chapter), which looks almost identical.

## Commands

| Command | Description |
| --- | --- |
| `kubectl create configmap` | create a ConfigMap from literals or files |
| `kubectl get configmap -o yaml` | inspect a ConfigMap's data |
| `kubectl apply -f` | create a ConfigMap from a manifest |
| `kubectl rollout restart` | restart Pods to pick up changed config |

## Tasks

### 1. Create a ConfigMap — two ways

Imperatively, from literals and from a file:

```bash
kubectl create configmap demo -n shop \
  --from-literal=greeting=hello \
  --from-literal=tier=backend
kubectl get configmap demo -n shop -o yaml
```

The workload's real ConfigMap is declarative — it holds the JSON the api serves:

```bash
kubectl apply -f lab/manifests/api-configmap.yaml
kubectl get configmap api-data -n shop -o yaml
```

<details><summary>Expected output (api-data)</summary>

```yaml
data:
  data.json: |
    {
      "version": 1,
      "name": "shop-api",
      "items": ["shoes", "socks", "hats"]
    }
```
</details>

### 2. Inject ConfigMap values as environment variables

The `demo` ConfigMap, surfaced as env vars in a throwaway Pod:

```bash
kubectl run cm-env --rm -it -n shop --restart=Never --image=busybox \
  --overrides='{"spec":{"containers":[{"name":"cm-env","image":"busybox","command":["env"],"envFrom":[{"configMapRef":{"name":"demo"}}]}]}}' \
  | grep -E 'greeting|tier'
```

<details><summary>Expected output</summary>

```
greeting=hello
tier=backend
```
</details>

### 3. Mount a ConfigMap as a file (the api tier)

`lab/manifests/api-deployment.yaml` mounts the `api-data` ConfigMap's `data.json` key at
`/data.json` — exactly where the Go app reads it:

```yaml
volumeMounts:
  - name: api-data
    mountPath: /data.json
    subPath: data.json
volumes:
  - name: api-data
    configMap:
      name: api-data
```

Deploy the api tier (Deployment + Service) and call it:

```bash
kubectl apply -f lab/manifests/api-deployment.yaml -f lab/manifests/api-service.yaml
kubectl rollout status deployment/api -n shop
kubectl run client --rm -it --image=curlimages/curl -n shop --restart=Never -- curl -s http://api/api
```

<details><summary>Expected output</summary>

```json
{"version":1,"name":"shop-api","items":["shoes","socks","hats"]}
```
</details>

### 4. Change the config and re-roll

Edit the data in `lab/manifests/api-configmap.yaml` (e.g. add an item), then:

```bash
kubectl apply -f lab/manifests/api-configmap.yaml
kubectl rollout restart deployment/api -n shop      # remount the updated file
kubectl run client --rm -it --image=curlimages/curl -n shop --restart=Never -- curl -s http://api/api
```

> Mounted ConfigMaps update in the volume eventually, but the app only read the file at startup, so
> we `rollout restart` to pick up the change cleanly. Config changed — no image rebuild.

## Recap

- A **ConfigMap** keeps non-secret config out of the image; consume it as env vars or mounted files.
- `--from-literal` / `--from-file` create them imperatively; a manifest is the declarative source.
- Mounting a key makes it a file (the api reads `/data.json`); `subPath` mounts a single file.
- Changing a ConfigMap doesn't restart Pods — use `kubectl rollout restart` to apply it.

## Cleanup

```bash
kubectl delete configmap demo -n shop --ignore-not-found
# keep api-data + the api tier for later chapters
```

## Going further (optional)

- Drop `subPath` and mount the whole ConfigMap at a directory — every key becomes a file there.
- `kubectl create configmap … --dry-run=client -o yaml` generates the manifest from files.
