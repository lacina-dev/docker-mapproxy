#!/bin/bash
# check_mapproxy_yaml.sh — validate a MapProxy configuration BEFORE it goes live.
#
# The running container loads mapproxy_configuration/mapproxy.yaml with
# reloader=True (scripts/start.sh): a saved broken file breaks every layer on
# :8082 at once. So edit a copy, check it, then move it into place:
#
#     cp mapproxy_configuration/mapproxy.yaml /tmp/mapproxy.yaml   # edit this
#     scripts/check_mapproxy_yaml.sh /tmp/mapproxy.yaml && \
#         cp /tmp/mapproxy.yaml mapproxy_configuration/mapproxy.yaml
#
# Without an argument it checks the live file (e.g. after a git pull).
# The check runs the MapProxy of the running container (same version as
# production), with warnings fatal (ignore_warnings=False): unknown keys,
# missing sources/caches/grids, bad YAML. It also checks that every layer
# named in ui_sources.json (the robot UI catalog) exists.
# Exit 0 = OK, 1 = invalid, 2 = cannot check (container not running).
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
FILE="${1:-$HERE/mapproxy_configuration/mapproxy.yaml}"
CATALOG="$(dirname "$FILE")/ui_sources.json"
[ -f "$CATALOG" ] || CATALOG="$HERE/mapproxy_configuration/ui_sources.json"
C="${MAPPROXY_CONTAINER:-docker-mapproxy-mapproxy-1}"

[ -f "$FILE" ] || { echo "no such file: $FILE"; exit 1; }
docker inspect -f '{{.State.Running}}' "$C" 2>/dev/null | grep -q true \
    || { echo "container $C is not running — cannot check"; exit 2; }

TMP="/tmp/check_mapproxy_$$"
docker exec "$C" mkdir -p "$TMP" >/dev/null
trap 'docker exec "$C" rm -rf "$TMP" >/dev/null 2>&1' EXIT
docker cp "$FILE" "$C:$TMP/mapproxy.yaml" >/dev/null
[ -f "$CATALOG" ] && docker cp "$CATALOG" "$C:$TMP/ui_sources.json" >/dev/null

docker exec -i -w "$TMP" "$C" python3 - <<'EOF'
import json, os, sys
from mapproxy.config.loader import load_configuration, load_configuration_file, ConfigurationError
from mapproxy.config.validator import validate_references
try:
    # 1+2: YAML and options (warnings fatal)
    conf = load_configuration('mapproxy.yaml', ignore_warnings=False)
    # 3: references (MapProxy only logs these) — fatal here
    refs = validate_references(load_configuration_file(['mapproxy.yaml'], '.'))
    if refs:
        print('\n'.join(refs))
        raise ConfigurationError('missing references')
    # 4: build every service, as the server does on load
    conf.configured_services()
except ConfigurationError as e:
    print('INVALID: %s (details above)' % e)
    sys.exit(1)
except Exception as e:                      # YAML syntax and friends
    print('INVALID: %s: %s' % (type(e).__name__, e))
    sys.exit(1)
layers = set(conf.layers.keys())
bad = []
if os.path.exists('ui_sources.json'):
    try:
        cat = json.load(open('ui_sources.json'))
        for s in cat.get('sources', []):
            if s.get('layer') not in layers:
                bad.append(s.get('layer'))
    except Exception as e:
        print('INVALID ui_sources.json: %s' % e)
        sys.exit(1)
if bad:
    print('INVALID: ui_sources.json names layers missing in mapproxy.yaml: %s' % ', '.join(map(str, bad)))
    sys.exit(1)
print('OK — %d layers: %s' % (len(layers), ', '.join(sorted(layers))))
EOF
