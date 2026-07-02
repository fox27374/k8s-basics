# Labels and selectors

> **Goal:** organise and query Pods with labels, and understand selectors — the mechanism the very next chapters (Deployments, Services) use to find the Pods they manage.

**Prerequisites:** the [Pods](pods.md) chapter (you can create and delete Pods with `kubectl`).

## Concept

**Labels** are arbitrary key/value tags on any object (`app: web`, `tier: frontend`, `env: dev`).
They carry no meaning to Kubernetes by themselves — their power is **selectors**, a query over those
labels. You'll lean on selectors immediately: a **Deployment** decides which Pods it owns with a
`selector` that must match its Pod template's labels, and a **Service** picks the Pods it
load-balances the same way. Get comfortable with labels now and those chapters click into place.

**Annotations** look similar but serve the opposite purpose: non-identifying metadata (a commit SHA,
a description, controller config) that you *cannot* select on.

We experiment here with a few bare Pods in the `default` namespace — no Deployment yet.

## Commands

| Command | Description |
| --- | --- |
| `kubectl run --labels` | create a Pod with labels |
| `kubectl get --show-labels` / `-L` | show labels as a column |
| `kubectl get -l` | select objects by label |
| `kubectl label` | add or remove labels on objects |
| `kubectl annotate` | add or remove annotations |

## Tasks

### 1. Create a few labeled Pods to query

```bash
kubectl run web   --image=nginx:alpine --labels='app=web,tier=frontend,env=dev'
kubectl run web-2 --image=nginx:alpine --labels='app=web,tier=frontend,env=prod'
kubectl run cache --image=redis:alpine --labels='app=cache,tier=backend,env=dev'
```

### 2. See the labels

```bash
kubectl get pods --show-labels
kubectl get pods -L tier -L env        # capital -L turns labels into columns
```

<details><summary>Expected output</summary>

```
NAME    READY   STATUS    ...   TIER       ENV
cache   1/1     Running   ...   backend    dev
web     1/1     Running   ...   frontend   dev
web-2   1/1     Running   ...   frontend   prod
```
</details>

### 3. Select with label selectors

```bash
kubectl get pods -l app=web                  # equality → web, web-2
kubectl get pods -l 'tier in (backend)'      # set-based → cache
kubectl get pods -l env=dev                  # → web, cache
kubectl get pods -l 'app=web,env!=prod'      # comma = AND, negation → web only
```

> A selector is exactly what a Deployment and a Service will use to choose their Pods — you're
> writing the same queries by hand.

### 4. Add and change a label on a live Pod

```bash
kubectl label pod cache env=staging --overwrite   # change an existing label
kubectl label pod web owner=team-web              # add a new one
kubectl get pods -l owner=team-web
kubectl label pod web owner-                       # trailing - removes it
```

> Changing a Pod's labels is how it later joins or leaves a Service: flip a label and the selector
> match changes. That's also the basis of the canary split much later in the guide.

### 5. Annotations: metadata you can't select on

```bash
kubectl annotate pod web description='storefront demo'
kubectl get pod web -o jsonpath='{.metadata.annotations.description}'; echo
kubectl get pods -l description=storefront\ demo     # returns nothing — annotations aren't selectable
kubectl annotate pod web description-                 # remove
```

## Recap

- **Labels** tag objects; **selectors** query them (`-l`), and Deployments/Services use the same queries to find Pods.
- Selector syntax: equality (`k=v`), set-based (`k in (a,b)`), negation (`k!=v`), comma = AND.
- `--show-labels` lists them; `-L <key>` makes a label its own column.
- **Annotations** hold non-identifying metadata and **cannot** be selected on.

## Cleanup

```bash
kubectl delete pod web web-2 cache --ignore-not-found
```

## Going further (optional)

- The recommended `app.kubernetes.io/*` labels (`name`, `part-of`, `component`) — tools and
  dashboards understand them. `kubectl explain metadata.labels`.
- Peek ahead: `kubectl explain deployment.spec.selector` and `service.spec.selector` — both are just
  label selectors like the ones above.
