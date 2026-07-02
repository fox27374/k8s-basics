# Health checks and resources

> **Goal:** tell Kubernetes when a container is alive and ready, and how much CPU/memory it may use — using probes and resource requests/limits on the workload's tiers.

**Prerequisites:** the [storage](storage.md) chapter; the `frontend`, `api` and `db` tiers running in `shop`. k3s bundles metrics-server, so `kubectl top` works.

## Concept

Kubernetes can't know what "healthy" means for *your* app unless you tell it, with **probes**:

- **liveness** — "is the process wedged?" A failing liveness probe **restarts** the container.
- **readiness** — "can it serve traffic *right now*?" A failing readiness probe pulls the Pod out
  of its Service endpoints (no restart) until it recovers — critical during startup and rollouts.
- **startup** — gives slow-booting apps time before liveness kicks in.

**Resources** are the other half of being a good cluster citizen. A **request** is what the
scheduler reserves for a container (and uses to place it); a **limit** is the hard ceiling. Exceed a
**memory** limit and the container is **OOM-killed**; exceed a **CPU** limit and it's throttled.
Requests/limits also define a Pod's Quality-of-Service class, which decides who gets evicted first
under pressure.

## Commands

| Command | Description |
| --- | --- |
| `kubectl describe pod` | see probe results, restarts and OOM events |
| `kubectl get pod -w` | watch READY/RESTARTS change live |
| `kubectl top pod` | show live CPU/memory (needs metrics-server) |
| `kubectl explain pod.spec.containers.livenessProbe` | discover probe fields |

## Tasks

### 1. See the probes and limits already in the manifests

The lab tiers already declare them — for example the api's readiness probe and limits:

```bash
kubectl get deploy api -n shop -o yaml | grep -A6 readinessProbe
kubectl get deploy api -n shop -o yaml | grep -A6 resources
```

> `frontend` and `api` use HTTP readiness probes; `db` uses an `exec` probe (`pg_isready`).

### 2. Watch a readiness probe keep a Pod out of service

Apply the throwaway Pod in [`lab/11/probe-demo.yaml`](../../lab/11/probe-demo.yaml) — it runs nginx,
but its readiness probe checks `/healthz`, a path nginx doesn't serve, so the probe never passes:

```bash
kubectl apply -f lab/11/probe-demo.yaml
kubectl get pod probe-demo -n shop -w        # READY stays 0/1 while STATUS is Running
```

<details><summary>Expected output</summary>

```
NAME         READY   STATUS    RESTARTS   AGE
probe-demo   0/1     Running   0          20s
```
</details>

```bash
kubectl describe pod probe-demo -n shop | sed -n '/Events/,$p'   # "Readiness probe failed... 404"
```

> The container is **running** but not **ready**: a failing readiness probe never restarts the Pod,
> it just holds it out of Service endpoints. Point the probe at `/` in the manifest and re-apply and
> `READY` flips to `1/1`.
>
> Want the other kind? Change `readinessProbe` to `livenessProbe` in the same file and re-apply — a
> failing **liveness** probe **restarts** the container, so `RESTARTS` climbs instead.

```bash
kubectl delete -f lab/11/probe-demo.yaml
```

### 3. Observe readiness gating traffic

```bash
kubectl describe pod -n shop -l app=frontend | grep -A4 Readiness
```

> During a rollout a new Pod stays out of the Service until its readiness probe passes — that's how
> you get zero-downtime updates. Compare the endpoint count while scaling:
> `kubectl get endpoints frontend -n shop`.

### 4. Set resource requests and limits

The frontend already caps itself (`requests cpu:10m/mem:16Mi`, `limits cpu:100m/mem:64Mi`). Inspect
live usage:

```bash
kubectl top pod -n shop
```

<details><summary>Expected output</summary>

```
NAME                        CPU(cores)   MEMORY(bytes)
api-6d4f...-abcde           1m           8Mi
db-7c9b...-fghij            6m           28Mi
frontend-5f8c...-klmno      1m           4Mi
```
</details>

### 5. Watch a container exceed its memory limit (OOMKill)

Run a Pod with a tiny memory limit and a process that allocates past it:

```bash
kubectl run oom-demo -n shop --image=polinux/stress --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"oom-demo","image":"polinux/stress","resources":{"limits":{"memory":"32Mi"}},"command":["stress","--vm","1","--vm-bytes","128M","--vm-hang","0"]}]}}'
kubectl get pod oom-demo -n shop -w        # STATUS becomes OOMKilled, then CrashLoopBackOff
```

<details><summary>Expected output</summary>

```
NAME       READY   STATUS      RESTARTS   AGE
oom-demo   0/1     OOMKilled   1          6s
```
</details>

```bash
kubectl describe pod oom-demo -n shop | grep -i -A2 'last state'   # Reason: OOMKilled
kubectl delete pod oom-demo -n shop
```

## Recap

- **liveness** restarts a wedged container; **readiness** gates traffic without restarting.
- **requests** drive scheduling; **limits** are hard ceilings — memory over-limit = OOMKill, CPU = throttle.
- `kubectl describe pod` surfaces probe failures and OOM events; `kubectl top` shows live usage.
- Every workload tier should declare probes and limits to be a good cluster citizen.

## Cleanup

```bash
kubectl delete -f lab/11/probe-demo.yaml --ignore-not-found
kubectl delete pod oom-demo -n shop --ignore-not-found
```

## Going further (optional)

- Add a **startup probe** to the db so a slow first boot doesn't trip liveness.
- Set requests == limits on a Pod to give it the **Guaranteed** QoS class; compare with `kubectl get pod -o jsonpath='{.status.qosClass}'`.
