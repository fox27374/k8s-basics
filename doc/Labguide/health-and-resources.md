# Health checks and resources

Tell Kubernetes when a container is healthy and how much CPU/memory it may use.

## Commands
| Command | Description |
| --- | --- |
| kubectl describe pod | see probe results and restarts |
| kubectl top | show resource usage (needs metrics-server) |
---

## Tasks
### 1. Add a liveness probe and watch a failing container restart
### 2. Add a readiness probe and observe traffic gating
### 3. Set resource requests and limits
### 4. Observe what happens when a container exceeds its memory limit
