# Secrets

> **Goal:** keep sensitive values out of manifests and images with a Secret — feed the **db** tier (postgres) its password, and understand that base64 is encoding, not encryption.

**Prerequisites:** the [ConfigMaps](configmaps.md) chapter; working in the `shop` namespace.

## Concept

A **Secret** is just like a ConfigMap — key/value data you inject as env vars or files — but
intended for sensitive values (passwords, tokens, TLS keys). Kubernetes stores Secret values
**base64-encoded**, which is *encoding, not encryption*: anyone who can read the Secret can decode
it. The real protection comes from RBAC (who may read Secrets) and, in production, encryption at
rest. The payoff is the same as a ConfigMap: credentials live outside your image and outside your
application manifests.

Our **db** tier is stock `postgres:16-alpine`. Postgres needs `POSTGRES_PASSWORD` (plus user/db);
we put all three in a Secret and import them with `envFrom: secretRef`. This is the textbook Secret
use case — a database password — and sets up the [storage](storage.md) chapter, where the same
postgres gets a persistent volume.

## Commands

| Command | Description |
| --- | --- |
| `kubectl create secret generic` | create a Secret from literals or files |
| `kubectl get secret -o jsonpath` | read a value (base64) |
| `kubectl apply -f` | create a Secret from a manifest (`stringData`) |
| `base64 -d` | decode a base64 value |

## Tasks

### 1. Create the db credentials Secret

`lab/09/secret.yaml` uses `stringData`, so you write plain text and Kubernetes encodes it
on apply:

```bash
kubectl apply -f lab/09/secret.yaml
kubectl get secret db-credentials -n shop
```

<details><summary>Expected output</summary>

```
NAME             TYPE     DATA   AGE
db-credentials   Opaque   3      5s
```
</details>

The imperative equivalent: `kubectl create secret generic db-credentials -n shop
--from-literal=POSTGRES_USER=shop --from-literal=POSTGRES_PASSWORD=s3cr3t-change-me
--from-literal=POSTGRES_DB=shop`.

### 2. Prove base64 is not encryption

```bash
kubectl get secret db-credentials -n shop -o jsonpath='{.data.POSTGRES_PASSWORD}'; echo
kubectl get secret db-credentials -n shop -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d; echo
```

<details><summary>Expected output</summary>

```
czNjcjN0LWNoYW5nZS1tZQ==
s3cr3t-change-me
```
</details>

> The stored value is reversible with a single command. Treat "it's in a Secret" as "keep RBAC
> tight", not "it's encrypted".

### 3. Inject the Secret into postgres with `envFrom`

`lab/09/deployment.yaml` imports every key as an env var:

```yaml
envFrom:
  - secretRef:
      name: db-credentials      # → POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB
```

Deploy the db tier and its Service:

```bash
kubectl apply -f lab/09/deployment.yaml -f lab/09/service.yaml
kubectl rollout status deployment/db -n shop
```

> This Deployment also references a PersistentVolumeClaim (`db-data`). If it stays `Pending`, apply
> the PVC bundled in this chapter's folder (`kubectl apply -f lab/09/pvc.yaml`); the
> [storage](storage.md) chapter covers what it does — on k3s the default `local-path` provisioner
> creates the volume automatically.

### 4. Confirm postgres came up with those credentials

```bash
kubectl exec -n shop deploy/db -- sh -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select 1 as ok;"'
```

<details><summary>Expected output</summary>

```
 ok
----
  1
(1 row)
```
</details>

### 5. Mount a Secret as a file (alternative form)

Secrets can also be mounted as files (each key a file) — common for TLS certs or
`~/.pgpass`-style credentials:

```yaml
# excerpt — the pattern
volumeMounts:
  - name: creds
    mountPath: /etc/db
    readOnly: true
volumes:
  - name: creds
    secret:
      secretName: db-credentials
```

> Mounted Secret files live on an in-memory `tmpfs`, never written to the node's disk.

## Recap

- A **Secret** is a ConfigMap for sensitive data; values are **base64-encoded, not encrypted**.
- Protect Secrets with RBAC (and encryption at rest in production), not by obscurity.
- `stringData` lets you author plain text; `envFrom: secretRef` imports all keys as env vars.
- The **db** tier gets `POSTGRES_PASSWORD` (and user/db) entirely from `db-credentials`.

## Cleanup

Keep the db tier for the [storage](storage.md) chapter, or tear it down:

```bash
kubectl delete -f lab/09/deployment.yaml -f lab/09/service.yaml \
  -f lab/09/secret.yaml --ignore-not-found
```

## Going further (optional)

- Secret `type` matters: `kubernetes.io/dockerconfigjson` for image pull creds,
  `kubernetes.io/tls` for certs. `kubectl explain secret.type`.
- Look into Sealed Secrets or External Secrets to keep real secrets out of git safely.
