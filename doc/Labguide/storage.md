# Storage

Persist data beyond a Pod's lifetime with volumes and PersistentVolumeClaims.
k3s ships the `local-path` StorageClass as the default provisioner.

## Commands
| Command | Description |
| --- | --- |
| kubectl get pvc,pv | list claims and volumes |
| kubectl get storageclass | list storage classes |
---

## Tasks
### 1. Use an emptyDir volume in a Pod
### 2. Create a PersistentVolumeClaim (default local-path StorageClass)
### 3. Mount the PVC in a Pod and write data
### 4. Delete and recreate the Pod; confirm the data persists
