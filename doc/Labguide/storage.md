# Storage

> **Goal:** persist data beyond a Pod's lifetime with a PersistentVolumeClaim — give the **db** tier durable storage and prove the data survives a Pod restart.

**Prerequisites:** the [secrets](secrets.md) chapter, with the `db` tier deployed in `shop`. k3s ships the `local-path` StorageClass as the default provisioner.

## Concept

A container's filesystem is ephemeral — delete the Pod and anything written inside is gone. Volumes
fix that. An **`emptyDir`** lives as long as the Pod (handy as scratch space shared between
containers). For data that must outlive the Pod you use a **PersistentVolumeClaim (PVC)**: a request
for storage of a given size and access mode. A **StorageClass** provisions a matching
**PersistentVolume (PV)** to satisfy the claim. On k3s the default StorageClass is **`local-path`**,
which dynamically carves the volume out of the node's disk — no cloud provider needed.

A database is the canonical case: postgres must keep its data directory across restarts and
upgrades. Our **db** Deployment mounts a PVC at postgres's data path, so the rows you write stay put.

## Commands

| Command | Description |
| --- | --- |
| `kubectl get storageclass` | list storage classes (note the default) |
| `kubectl get pvc,pv` | list claims and the volumes bound to them |
| `kubectl apply -f` | create a PVC from a manifest |
| `kubectl describe pvc` | see binding status and events |

## Tasks

### 1. See the default StorageClass

```bash
kubectl get storageclass
```

<details><summary>Expected output</summary>

```
NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      DEFAULT
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   true
```
</details>

> `WaitForFirstConsumer` means the volume isn't provisioned until a Pod that uses the claim is
> scheduled — so the PVC can sit `Pending` until then. That's expected.

### 2. Try an emptyDir (Pod-lifetime scratch)

```bash
kubectl run scratch -n shop --image=busybox --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"scratch","image":"busybox","command":["sh","-c","echo hi > /data/file; cat /data/file; sleep 3600"],"volumeMounts":[{"name":"d","mountPath":"/data"}]}],"volumes":[{"name":"d","emptyDir":{}}]}}'
kubectl logs scratch -n shop
kubectl delete pod scratch -n shop      # the emptyDir is gone with the Pod
```

### 3. Create the PersistentVolumeClaim for the db

```bash
kubectl apply -f lab/manifests/db-pvc.yaml
kubectl get pvc db-data -n shop
```

<details><summary>Expected output</summary>

```
NAME      STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
db-data   Bound     pvc-...  1Gi        RWO            local-path     10s
```
</details>

> If you deployed the db tier in the [secrets](secrets.md) chapter, the claim binds as soon as the
> postgres Pod is scheduled. `db-deployment.yaml` mounts this PVC at
> `/var/lib/postgresql/data`, with `PGDATA` in a `pgdata` subdirectory.

### 4. Write data into postgres

```bash
kubectl exec -n shop deploy/db -- sh -c \
  'PGPASSWORD=$POSTGRES_PASSWORD psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "create table if not exists notes(msg text); insert into notes values('"'"'persisted!'"'"'); select * from notes;"'
```

<details><summary>Expected output</summary>

```
   msg
-----------
 persisted!
(1 row)
```
</details>

### 5. Delete the Pod and confirm the data survives

```bash
kubectl delete pod -n shop -l app=db          # the Deployment recreates it
kubectl rollout status deployment/db -n shop
kubectl exec -n shop deploy/db -- sh -c \
  'PGPASSWORD=$POSTGRES_PASSWORD psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select * from notes;"'
```

<details><summary>Expected output</summary>

```
   msg
-----------
 persisted!
(1 row)
```
</details>

> New Pod, same PVC — the rows are still there. The data's lifecycle is tied to the **claim**, not
> the Pod.

## Recap

- Container filesystems are ephemeral; **`emptyDir`** lasts a Pod's lifetime, a **PVC** outlives it.
- A **StorageClass** dynamically provisions a **PV** to satisfy a **PVC**; k3s defaults to `local-path`.
- `WaitForFirstConsumer` defers provisioning until a Pod uses the claim (PVC may show `Pending`).
- The db tier keeps its data across Pod restarts because it stores it on the `db-data` PVC.

## Cleanup

```bash
# deleting the PVC deletes the local-path volume (ReclaimPolicy: Delete) — the data is gone
kubectl delete pvc db-data -n shop --ignore-not-found
```

## Going further (optional)

- Databases are usually run as a **StatefulSet** (stable network IDs + per-replica PVCs via
  `volumeClaimTemplates`). `kubectl explain statefulset.spec.volumeClaimTemplates`.
- Inspect where local-path put the data: `kubectl get pv` then look under `/var/lib/rancher/k3s/storage` on the node.
