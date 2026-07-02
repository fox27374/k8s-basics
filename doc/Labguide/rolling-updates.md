# Rolling updates and rollbacks

> **Goal:** update the **frontend** with zero downtime, watch the rollout replace Pods gradually, roll back a bad release, and tune the update strategy.

**Prerequisites:** the [deployments](deployments.md) chapter; the `frontend` Deployment running in `shop`.

## Concept

When you change a Deployment's Pod template (a new image, a new env value), the Deployment performs
a **rolling update**: it creates a *new* ReplicaSet and shifts Pods from old to new a few at a time,
keeping enough ready Pods to serve traffic throughout. Two knobs control the pace — **`maxSurge`**
(how many extra Pods above the desired count may exist during the update) and **`maxUnavailable`**
(how many may be missing). Each rollout is recorded as a **revision**, so `kubectl rollout undo`
returns to the previous one.

A rolling update **replaces** the old version with the new one for *everybody* at once (just
gradually). It does not let you send, say, 10% of users to the new version while watching — that's a
**canary**, which we do in the [next chapter](canary-deployment.md) with weighted routing. Know the
difference: rolling = replace-in-place; canary = run-both-and-split.

## Commands

| Command | Description |
| --- | --- |
| `kubectl set image` | change a container's image (triggers a rollout) |
| `kubectl rollout status` | watch a rollout progress |
| `kubectl rollout history` | list revisions |
| `kubectl rollout undo` | roll back to the previous (or a specific) revision |

## Tasks

### 1. Update the image of a Deployment

We "ship a new version" by switching the frontend image tag (here `v2`, which we'll reuse as the
canary's green build):

```bash
kubectl set image deployment/frontend -n shop frontend=cr.lab.local/lab-frontend:v2 --record
```

> `--record` stores the command in the revision's change-cause so `history` is readable.

### 2. Watch the rolling update progress

```bash
kubectl rollout status deployment/frontend -n shop
kubectl get rs -n shop -l app=frontend       # old RS scaled to 0, new RS scaled up
```

<details><summary>Expected output</summary>

```
Waiting for deployment "frontend" rollout to finish: 1 out of 2 new replicas have been updated...
deployment "frontend" successfully rolled out
```
</details>

> Throughout the rollout at least one Pod stayed Ready (thanks to the readiness probe + default
> strategy), so there was no downtime.

### 3. View the rollout history

```bash
kubectl rollout history deployment/frontend -n shop
```

<details><summary>Expected output</summary>

```
REVISION  CHANGE-CAUSE
1         <none>
2         kubectl set image deployment/frontend frontend=cr.lab.local/lab-frontend:v2 --record=true
```
</details>

### 4. Simulate a bad release and roll back

Deploy an image tag that doesn't exist — the new Pods never become Ready:

```bash
kubectl set image deployment/frontend -n shop frontend=cr.lab.local/lab-frontend:broken
kubectl rollout status deployment/frontend -n shop --timeout=30s   # will not complete
kubectl get pods -n shop -l app=frontend                           # new Pod stuck ImagePullBackOff
```

Roll back to the last good revision:

```bash
kubectl rollout undo deployment/frontend -n shop
kubectl rollout status deployment/frontend -n shop
```

> Because the bad Pods never passed readiness, the old ones were never removed — the app kept
> serving. `undo` discards the broken ReplicaSet. This is the safety net that makes frequent
> deploys viable.

### 5. Tune the update strategy

Make rollouts stricter (never drop below full capacity) by setting `maxUnavailable: 0`:

```bash
kubectl patch deployment frontend -n shop -p \
  '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":1,"maxUnavailable":0}}}}'
kubectl get deploy frontend -n shop -o jsonpath='{.spec.strategy.rollingUpdate}'; echo
```

> `maxUnavailable: 0` adds a surge Pod *before* removing an old one — safest, slightly more
> resource-hungry. The default is `25%`/`25%`.

## Recap

- Changing the Pod template triggers a **rolling update**: a new ReplicaSet, Pods shifted gradually.
- **`maxSurge`** / **`maxUnavailable`** control the pace; readiness probes keep it zero-downtime.
- Each rollout is a **revision**; `kubectl rollout undo` rolls back, even mid-failed-rollout.
- Rolling update ≠ canary — it replaces for everyone. Traffic-splitting is the [next chapter](canary-deployment.md).

## Cleanup

Reset the frontend to the baseline manifest before moving on:

```bash
kubectl apply -f lab/manifests/frontend-deployment.yaml
```

## Going further (optional)

- `kubectl rollout pause`/`resume deployment/frontend` to stage multiple changes into one rollout.
- `kubectl rollout undo deployment/frontend --to-revision=1` to jump to a specific revision.
