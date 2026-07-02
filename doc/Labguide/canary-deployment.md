# Canary deployment

> **Goal:** release a new frontend version to a *fraction* of traffic — run **v2 (green)** alongside **v1 (blue)** and split requests by weight with a Traefik `TraefikService`, then shift the split and promote.

**Prerequisites:** the [ingress](ingress.md) chapter — the `frontend` Deployment, Service and `IngressRoute` running in `shop`.

## Concept

A [rolling update](rolling-updates.md) replaces the old version with the new one for everyone. A
**canary** instead runs both versions at once and sends a small slice of real traffic (say 20%) to
the new one, so you can watch error rates and latency before committing. If it looks good you shift
more traffic; if not, you drop the canary to 0% — no rollback churn, no user-visible incident.

Traefik implements weighted traffic splitting with a **`TraefikService`** of kind *weighted*: it
references several real Services, each with a `weight`, and an `IngressRoute` points at it instead of
at a single Service. We deploy **`frontend-v2`** (the same colour app with `COLOR=green`, standing in
for "a new build") and weight blue/green, then move the dial.

> Our two "versions" differ only by the `COLOR` env value so the split is visible at a glance. In a
> real canary, v2 is a genuinely new image tag — everything else here is identical.

The pieces (all in `lab/14/frontend-canary.yaml`):

- `frontend-v2` Deployment + Service (selector `version: v2`)
- the `frontend` Service is pinned to `version: v1`, so blue and green are cleanly separable
- a `TraefikService` **`frontend-split`** weighting `frontend` (blue) and `frontend-v2` (green)
- the `frontend` `IngressRoute` re-pointed at `frontend-split`

## Commands

| Command | Description |
| --- | --- |
| `kubectl apply -f` | deploy v2 + the weighted TraefikService |
| `kubectl get traefikservice` | list weighted services |
| `kubectl patch` | shift the weights |
| `curl` (in a loop) | observe the traffic split |

## Tasks

### 1. Deploy the canary (v2) alongside v1

```bash
kubectl apply -f lab/14/frontend-canary.yaml
kubectl rollout status deployment/frontend-v2 -n shop
kubectl get deploy -n shop -l app=frontend          # frontend (v1) and frontend-v2 both Ready
```

<details><summary>Expected output</summary>

```
NAME          READY   UP-TO-DATE   AVAILABLE   AGE
frontend      2/2     2            2           20m
frontend-v2   2/2     2            2           15s
```
</details>

> This also re-points the `frontend` IngressRoute at the `frontend-split` TraefikService
> (80% blue / 20% green).

### 2. Observe the 80/20 split

The colour app paints the page, so curl the background-colour line repeatedly and count:

```bash
for i in $(seq 1 20); do
  curl -s http://frontend.127.0.0.1.nip.io/ | grep -o 'background-color: [a-z]*'
done | sort | uniq -c
```

<details><summary>Expected output</summary>

```
  16 background-color: blue
   4 background-color: green
```
</details>

> Roughly 80/20 — Traefik's weighted round-robin sending most traffic to v1 and a slice to the
> canary. (Counts vary run to run.)

### 3. Increase the canary to 50/50

```bash
kubectl patch traefikservice frontend-split -n shop --type=json -p '[
  {"op":"replace","path":"/spec/weighted/services/0/weight","value":50},
  {"op":"replace","path":"/spec/weighted/services/1/weight","value":50}]'
# re-run the curl loop from Task 2 — now roughly half green
```

### 4. Promote v2 (100%) once it looks healthy

```bash
kubectl patch traefikservice frontend-split -n shop --type=json -p '[
  {"op":"replace","path":"/spec/weighted/services/0/weight","value":0},
  {"op":"replace","path":"/spec/weighted/services/1/weight","value":100}]'
for i in $(seq 1 10); do curl -s http://frontend.127.0.0.1.nip.io/ | grep -o 'background-color: [a-z]*'; done | sort | uniq -c
```

<details><summary>Expected output</summary>

```
  10 background-color: green
```
</details>

### 5. Retire v1 (clean up the old version)

With all traffic on green, scale the blue Deployment to zero (or delete it):

```bash
kubectl scale deployment frontend -n shop --replicas=0
# optionally simplify routing back to a single Service:
kubectl apply -f lab/14/frontend-ingressroute.yaml   # points straight at frontend (now v1, scaled 0)
```

> In a real promotion you'd instead roll v1's Deployment forward to the v2 image (so `frontend`
> becomes the new baseline) and delete `frontend-v2` and the TraefikService. The mechanism is the
> same: weight to 0, verify, retire.

## Recap

- **Canary** = run new + old together and split traffic by weight; **rolling update** = replace in place.
- Traefik splits traffic with a weighted **`TraefikService`** that an `IngressRoute` points at.
- Pin each version's Service to a `version` label so the weighted backends are cleanly separated.
- Promote by shifting weight to 100% and retiring the old version; abort by shifting back to 0%.

## Cleanup

```bash
kubectl delete -f lab/14/frontend-canary.yaml --ignore-not-found
kubectl apply -f lab/14/frontend-deployment.yaml -f lab/14/frontend-service.yaml \
  -f lab/14/frontend-ingressroute.yaml
```

## Going further (optional)

- A **blue/green** release is the 0→100 jump with no intermediate split — same objects, flip the
  weights in one step.
- Tools like **Argo Rollouts** or **Flagger** automate canaries: they shift weight gradually and
  auto-roll-back on bad metrics. This chapter is the manual version of what they do.
