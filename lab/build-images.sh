#!/usr/bin/env sh
# Build the lab images and push them to the training registry.
#
# Usage (from anywhere — paths resolve relative to this script):
#   ./lab/build-images.sh                      # build + push to cr.lab.local using docker
#   REGISTRY=cr.lab.local ./lab/build-images.sh
#   ENGINE=podman ./lab/build-images.sh        # use podman instead of docker
#   PUSH=0 ./lab/build-images.sh               # build only, skip the push
set -eu

REGISTRY="${REGISTRY:-cr.lab.local}"
ENGINE="${ENGINE:-podman}"
PUSH="${PUSH:-1}"
LAB_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

echo ">> engine=$ENGINE  registry=$REGISTRY  push=$PUSH"

# 1. Build the two custom images. frontend v1 and v2 are the same build under two
#    tags — the "version" difference is the COLOR env var set on each Deployment.
"$ENGINE" build -f "$LAB_DIR/environment/Containerfile" -t "$REGISTRY/lab-frontend:v1" "$LAB_DIR/environment"
"$ENGINE" build -f "$LAB_DIR/environment/Containerfile" -t "$REGISTRY/lab-frontend:v2" "$LAB_DIR/environment"
"$ENGINE" build -f "$LAB_DIR/configmap/Containerfile"   -t "$REGISTRY/lab-api:1"       "$LAB_DIR/configmap"

# 2. Mirror the upstream postgres image into the lab registry.
"$ENGINE" pull docker.io/postgres:16-alpine
"$ENGINE" tag  docker.io/postgres:16-alpine "$REGISTRY/postgres:16-alpine"

IMAGES="lab-frontend:v1 lab-frontend:v2 lab-api:1 postgres:16-alpine"

# 3. Push everything.
if [ "$PUSH" = "1" ]; then
  for img in $IMAGES; do
    "$ENGINE" push "$REGISTRY/$img"
  done
fi

echo ">> done. images:"
for img in $IMAGES; do
  echo "   $REGISTRY/$img"
done
