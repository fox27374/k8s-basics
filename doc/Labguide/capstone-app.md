# Capstone: deploy the multi-tier shop app (optional)

> **Goal:** assemble everything into one workload — a **frontend** (env var), an **api** (ConfigMap), and a **db** (Secret + PVC), exposed through a Traefik `IngressRoute` — then run a **canary** release of the frontend.

**Prerequisites:** all earlier chapters, the lab images built and imported into k3s
(see [Building the lab images](../../README.md#building-the-lab-images)), and Traefik (bundled with k3s).

## Concept

This is the destination the whole guide has been building toward. Each tier demonstrates one
configuration mechanism you learned separately, now wired together in the `shop` namespace:

| Tier | Image | Config mechanism | Reached by |
| --- | --- | --- | --- |
| **frontend** | `lab-frontend:v1` | **env var** `COLOR=blue` | IngressRoute (public) |
| **api** | `lab-api:1` | **ConfigMap** mounted at `/data.json` | Service `api` (internal) |
| **db** | `postgres:16-alpine` | **Secret** → env + **PVC** for data | Service `db` (internal) |

All the manifests live in [`lab/manifests/`](../../lab/manifests/); the capstone is mostly *applying
them together* and verifying the whole thing end to end, then performing a canary.

## Tasks

### 1. Deploy the entire workload

Apply the whole manifest directory (skip `frontend-canary.yaml` for now — that's Task 5):

```bash
kubectl apply \
  -f lab/manifests/namespace.yaml \
  -f lab/manifests/db-secret.yaml -f lab/manifests/db-pvc.yaml \
  -f lab/manifests/db-deployment.yaml -f lab/manifests/db-service.yaml \
  -f lab/manifests/api-configmap.yaml \
  -f lab/manifests/api-deployment.yaml -f lab/manifests/api-service.yaml \
  -f lab/manifests/frontend-deployment.yaml -f lab/manifests/frontend-service.yaml \
  -f lab/manifests/frontend-ingressroute.yaml
```

### 2. Verify every tier is healthy

```bash
kubectl get all -n shop
kubectl rollout status deployment/db -n shop
kubectl rollout status deployment/api -n shop
kubectl rollout status deployment/frontend -n shop
```

<details><summary>Expected output</summary>

```
NAME                            READY   STATUS    RESTARTS   AGE
pod/db-...                      1/1     Running   0          1m
pod/api-...                     1/1     Running   0          1m
pod/api-...                     1/1     Running   0          1m
pod/frontend-...                1/1     Running   0          1m
pod/frontend-...                1/1     Running   0          1m
```
</details>

### 3. Exercise the internal wiring

api serves its ConfigMap data; db answers with the Secret credentials — both over ClusterIP DNS:

```bash
kubectl run client --rm -it --image=curlimages/curl -n shop --restart=Never -- curl -s http://api/api
kubectl exec -n shop deploy/db -- sh -c \
  'PGPASSWORD=$POSTGRES_PASSWORD psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select 1;"'
```

### 4. Reach the frontend from outside

```bash
curl -s http://frontend.127.0.0.1.nip.io/ | grep background-color
```

<details><summary>Expected output</summary>

```
      background-color: blue;
```
</details>

> Traefik → `frontend` Service → blue Pods. Open it in a browser on the node to see the blue page.

### 5. Canary-release a new frontend version

Roll out **v2 (green)** to a slice of traffic, then promote — the full procedure is in the
[canary deployment](canary-deployment.md) chapter:

```bash
kubectl apply -f lab/manifests/frontend-canary.yaml      # v2 + weighted TraefikService (80/20)
for i in $(seq 1 20); do curl -s http://frontend.127.0.0.1.nip.io/ | grep -o 'background-color: [a-z]*'; done | sort | uniq -c
```

<details><summary>Expected output</summary>

```
  16 background-color: blue
   4 background-color: green
```
</details>

Shift the weight to 100% green to promote (see the canary chapter for the `kubectl patch` commands).

### 6. (Stretch) Add probes and limits everywhere

The frontend, api and db manifests already declare readiness probes and resource requests/limits
(see [health checks and resources](health-and-resources.md)). Confirm with:

```bash
kubectl get deploy -n shop -o custom-columns=\
'NAME:.metadata.name,PROBE:.spec.template.spec.containers[0].readinessProbe.httpGet.path,CPU-LIM:.spec.template.spec.containers[0].resources.limits.cpu'
```

## Recap

- The capstone is the three tiers wired together: **env var** (frontend), **ConfigMap** (api),
  **Secret + PVC** (db), fronted by a Traefik **IngressRoute**.
- Internal tiers talk over **ClusterIP DNS**; only the frontend is exposed.
- A **canary** ships the next frontend version to a weighted slice before promoting.
- Everything is declarative in [`lab/manifests/`](../../lab/manifests/) — `kubectl apply` stands the
  whole stack up, and `kubectl delete namespace shop` tears it down.

## Cleanup

```bash
kubectl delete namespace shop
```

## Going further (optional)

- Package the workload as a **Helm chart** (see [Helm](helm.md)) with values for image tags and `COLOR`.
- Wire the api to actually query the db, so the data path spans all three tiers.
- Put it under GitOps: commit `lab/manifests/` and have Argo CD or Flux apply it.
