# Rolling updates and rollbacks

Update a Deployment with zero downtime and roll back when something breaks.

## Commands
| Command | Description |
| --- | --- |
| kubectl set image | change a container image |
| kubectl rollout status/history | track a rollout |
| kubectl rollout undo | roll back to a previous revision |
---

## Tasks
### 1. Update the image of a Deployment
### 2. Watch the rolling update progress
### 3. View the rollout history
### 4. Roll back to the previous version
### 5. Tune the update strategy (maxSurge / maxUnavailable)
