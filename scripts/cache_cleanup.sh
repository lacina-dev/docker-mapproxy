#!/bin/bash
# cache_cleanup.sh — remove tiles older than 90 days from the ONLINE caches
# (mapproxy_configuration/cleanup.yaml), inside the running container.
# Weekly from the systemd user timer scripts/systemd/mapproxy-cache-cleanup.timer.
# Extra arguments go to mapproxy-seed (e.g. --dry-run, --summary).
set -eu
C="${MAPPROXY_CONTAINER:-docker-mapproxy-mapproxy-1}"
if ! docker inspect -f '{{.State.Running}}' "$C" 2>/dev/null | grep -q true; then
    echo "container $C is not running — nothing to clean"
    exit 0
fi
exec docker exec "$C" mapproxy-seed -f /mapproxy/mapproxy.yaml -s /mapproxy/cleanup.yaml \
    --cleanup ALL --use-cache-lock "$@"
