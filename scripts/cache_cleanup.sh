#!/bin/bash
# cache_cleanup.sh — remove tiles older than 90 days from the ONLINE caches
# (mapproxy_configuration/cleanup.yaml), inside the running container.
# Weekly from the systemd user timer scripts/systemd/mapproxy-cache-cleanup.timer.
# Extra arguments go to mapproxy-seed (e.g. --dry-run, --summary).
# mapproxy-seed runs through scripts/mapproxy_seed_tms.py (fed on stdin): plain
# MapProxy 1.16 skips levels z0-z9 of every directory_layout: tms cache (it
# looks for 00-09, tms stores 0-9); the wrapper fixes that for this run only.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
C="${MAPPROXY_CONTAINER:-docker-mapproxy-mapproxy-1}"
if ! docker inspect -f '{{.State.Running}}' "$C" 2>/dev/null | grep -q true; then
    echo "container $C is not running — nothing to clean"
    exit 0
fi
# run as the MapProxy user (uid:gid of MAPPROXY_USER_ID/GROUP_ID, which
# start.sh gives the uWSGI server), never as root: a root-owned lock file or
# cache directory makes the server answer 500 for those layers. Working
# directory cache_data: --use-cache-lock keeps its lock file
# .mapproxy_seed.lck in the current directory (seed and clean-up share it)
U="${MAPPROXY_EXEC_USER:-$(docker exec "$C" sh -c 'echo "${MAPPROXY_USER_ID:-1000}:${MAPPROXY_GROUP_ID:-1000}"')}"
docker exec -u "$U" "$C" mkdir -p /mapproxy/cache_data
exec docker exec -i -u "$U" -w /mapproxy/cache_data "$C" python3 - -f /mapproxy/mapproxy.yaml -s /mapproxy/cleanup.yaml \
    --cleanup ALL --use-cache-lock "$@" < "$HERE/mapproxy_seed_tms.py"
