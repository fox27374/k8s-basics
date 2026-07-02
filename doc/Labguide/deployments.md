# Deployments

> **Goal:** run Pods at scale with a Deployment — scale it, watch it self-heal, and meet the ReplicaSet working underneath. This chapter introduces the **frontend** app you'll grow into the capstone workload.

**Prerequisites:** a running k3s cluster, the [Pods](pods.md) and [labels and selectors](labels.md)
chapters, and the **lab images pushed to `cr.lab.local`**
(see [Preparing the lab images](../../README.md#preparing-the-lab-images)).

## Concept

You almost never create bare Pods. A **Deployment** declares *how many* replicas of a Pod you want
and which image they run; it creates a **ReplicaSet**, which in turn creates and watches the Pods.
It knows which Pods are "its own" through a label **`selector`** that matches the labels on its Pod
template — exactly the selectors from the [labels](labels.md) chapter, now doing real work.
If a Pod dies or a node disappears, the ReplicaSet makes a new one to match the declared
`replicas` count — this is Kubernetes **reconciliation** and **self-healing** in action. The
Deployment adds update and rollback behaviour on top (covered in [rolling updates](rolling-updates.md)).

The app we use here, **`lab-frontend`**, is an nginx image that paints the whole page a single
background colour read from a `COLOR` environment variable — so "is it running and which version?"
is answerable at a glance. We start it plain here; the [next chapter](environment-variables.md)
sets its colour.

## Commands

| Command | Description |
| --- | --- |
| `kubectl create deployment` | create a Deployment imperatively |
| `kubectl apply -f` | create/update a Deployment from a manifest |
| `kubectl scale` | change the replica count |
| `kubectl get rs` | list ReplicaSets |
| `kubectl rollout status` | wait for a rollout to finish |

## Tasks

### 1. Create a Deployment

The declarative way, from the lab manifest:

```bash
kubectl apply -f lab/04/namespace.yaml
kubectl apply -f lab/04/deployment.yaml
kubectl rollout status deployment/frontend -n shop
```

<details><summary>Expected output</summary>

```
namespace/shop created
deployment.apps/frontend created
deployment "frontend" successfully rolled out
```
</details>

> The manifest sets `namespace: shop`. The [namespaces](namespaces.md) chapter covers them in
> depth; for now just know every command below uses `-n shop`.

The quick imperative equivalent (no file) would be
`kubectl create deployment frontend --image=cr.lab.local/lab-frontend:v1 --replicas=2 -n shop`.

### 2. List what was created

```bash
kubectl get deploy,rs,pods -n shop -l app=frontend
```

<details><summary>Expected output</summary>

```
NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/frontend   2/2     2            2           30s

NAME                                  DESIRED   CURRENT   READY   AGE
replicaset.apps/frontend-7c9b8d6f5d   2         2         2       30s

NAME                            READY   STATUS    RESTARTS   AGE
pod/frontend-7c9b8d6f5d-abcde   1/1     Running   0          30s
pod/frontend-7c9b8d6f5d-fghij   1/1     Running   0          30s
```
</details>

> One Deployment → one ReplicaSet → N Pods. The Pod names are the ReplicaSet name plus a random
> suffix.

### 3. Scale it up and down

```bash
kubectl scale deployment frontend -n shop --replicas=4
kubectl get pods -n shop -l app=frontend
kubectl scale deployment frontend -n shop --replicas=2
```

> `scale` is imperative — quick, but the `replicas: 2` in the manifest is still the source of truth.
> Re-applying the manifest would reset the count.

### 4. Watch it self-heal

Delete one Pod and watch the ReplicaSet immediately replace it:

```bash
# in terminal 1: watch the Pods
kubectl get pods -n shop -l app=frontend -w

# in terminal 2: delete one Pod
kubectl delete pod -n shop "$(kubectl get pod -n shop -l app=frontend -o name | head -1)"
```

> You declared `replicas: 2`. Kubernetes' job is to keep actual state equal to desired state, so a
> deleted Pod is recreated within seconds. You manage the *desired count*, not individual Pods.

### 5. Inspect the ReplicaSet behind the Deployment

```bash
kubectl describe rs -n shop -l app=frontend
```

> Note the **Controlled By** (the Deployment owns the ReplicaSet) and the **Events**. When you
> change the image later, the Deployment creates a *new* ReplicaSet and scales the old one to zero
> — that's the mechanism behind rolling updates.

## Recap

- A **Deployment** manages a **ReplicaSet**, which manages **Pods**.
- `replicas:` is the desired count; Kubernetes reconciles actual → desired, so Pods self-heal.
- `kubectl scale` changes the count imperatively; the manifest remains the source of truth.
- Updating a Deployment spins up a new ReplicaSet — the basis for rolling updates and canaries.

## Cleanup

Keep `frontend` running if you're continuing to the next chapter. Otherwise:

```bash
kubectl delete -f lab/04/deployment.yaml
```

## Going further (optional)

- `kubectl get deploy frontend -n shop -o yaml | grep -A5 strategy` — see the default
  `RollingUpdate` strategy.
- Scale to `0` and back up — a clean way to "pause" a workload without deleting it.
