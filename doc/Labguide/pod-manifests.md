# Pod manifests

Move from imperative commands to declarative YAML: define a Pod in a manifest and apply it.

## Commands
| Command | Description |
| --- | --- |
| kubectl apply -f | create/update resources from a manifest |
| kubectl get -o yaml | print the live resource as YAML |
| kubectl delete -f | delete resources defined in a manifest |
---

## Tasks
### 1. Write a Pod manifest (pod.yaml)
### 2. Apply the manifest
### 3. Compare your manifest with the live object (`-o yaml`)
### 4. Add a second container (sidecar) to the Pod
### 5. Delete the Pod via the manifest
