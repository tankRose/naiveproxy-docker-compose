#!/bin/sh
set -e

docker buildx bake \
  --builder colima \
  -f docker-compose-build.yml \
  --no-cache \
  --load \
  reality