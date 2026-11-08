#!/bin/bash
# seed_garden.sh — pre-fill the MapProxy caches around the robot's site
# (tasks in mapproxy_configuration/seed.yaml), inside the running container.
#
#     scripts/seed_garden.sh [--go] [--tasks t1,t2] [--half METRES] [--lat LAT --lon LON]
#
# The area is a square around the site's map datum (GET /api/datum of the
# robot UI on this machine, port 7779) unless --lat/--lon are given. It is
# written to mapproxy_configuration/seed_area.wkt, which is NOT in git (the
# position is private). Without --go it is a dry run (mapproxy-seed -n:
# counts the tiles, fetches nothing). With --go it fetches ONE tile at a time
# (-c 1); run it when the robot is docked and the network is free.
# Default tasks: garden_cuzk (open data) and garden_google_sat (Google
# satellite, the UI's default base). The other commercial tasks
# (garden_photo_google/esri/bing) only when named.
set -eu
HERE="$(cd "$(dirname "$0")/.." && pwd)"
C="${MAPPROXY_CONTAINER:-docker-mapproxy-mapproxy-1}"
UI="${VITULUS_UI:-http://localhost:7779}"
GO=0; TASKS=garden_cuzk,garden_google_sat; HALF=200; LAT=""; LON=""
while [ $# -gt 0 ]; do
    case "$1" in
        --go) GO=1 ;;
        --tasks) TASKS="$2"; shift ;;
        --half) HALF="$2"; shift ;;
        --lat) LAT="$2"; shift ;;
        --lon) LON="$2"; shift ;;
        -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
        *) echo "unknown argument: $1"; exit 1 ;;
    esac
    shift
done
if [ -z "$LAT" ] || [ -z "$LON" ]; then
    read -r LAT LON < <(curl -fsS "$UI/api/datum" 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print(float(d["origin_lat"]), float(d["origin_lon"])) if d.get("ok") else None
except Exception:
    pass') || { echo "no site datum from $UI/api/datum: pass --lat and --lon"; exit 2; }
fi
python3 - "$LAT" "$LON" "$HALF" > "$HERE/mapproxy_configuration/seed_area.wkt" <<'PY'
import math, sys
lat, lon, half = map(float, sys.argv[1:4])
dlat = half / 111320.0
dlon = half / (111320.0 * math.cos(math.radians(lat)))
w, e, s, n = lon - dlon, lon + dlon, lat - dlat, lat + dlat
print("POLYGON((%.6f %.6f, %.6f %.6f, %.6f %.6f, %.6f %.6f, %.6f %.6f))"
      % (w, s, e, s, e, n, w, n, w, s))
PY
docker inspect -f '{{.State.Running}}' "$C" 2>/dev/null | grep -q true \
    || { echo "container $C is not running"; exit 2; }
ARGS=(-f /mapproxy/mapproxy.yaml -s /mapproxy/seed.yaml --seed "$TASKS" -c 1 --use-cache-lock)
[ "$GO" = 1 ] || ARGS+=(--dry-run)
echo "seed: tasks=$TASKS half=${HALF} m $([ "$GO" = 1 ] && echo FETCHING || echo 'dry run (add --go to fetch)')"
exec docker exec "$C" nice -n 10 mapproxy-seed "${ARGS[@]}"
