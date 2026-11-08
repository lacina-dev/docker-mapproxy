# mapproxy_seed_tms.py — mapproxy-seed with the level directories of
# directory_layout: tms fixed for the clean-up.
#
# MapProxy 1.16 (mapproxy/cache/path.py, location_funcs) gives the tms layout
# the generic level_location, which names a level "%02d": the clean-up looks
# for 00 ... 09, but tms stores z0-z9 in 0 ... 9 (z10+ are the same either
# way). So `mapproxy-seed --cleanup` silently skipped z0-z9 of every tms
# cache. The same file already has the right function, level_location_tms
# (str(level)); it is just not wired in. This wrapper wires it in for this
# process only and then runs the normal mapproxy-seed. The server is not
# touched (it never uses level_location).
#
# Run inside the container with the mapproxy-seed arguments, e.g.
#   docker exec -i <container> python3 - -f /mapproxy/mapproxy.yaml \
#       -s /mapproxy/cleanup.yaml --cleanup ALL < scripts/mapproxy_seed_tms.py
# (scripts/cache_cleanup.sh does this). With a MapProxy that already wires
# level_location_tms in, the wrapper changes nothing.
import sys

from mapproxy.cache import path

_orig_location_funcs = path.location_funcs


def _location_funcs(layout):
    tile_location, level_location = _orig_location_funcs(layout)
    if layout == 'tms' and level_location is path.level_location:
        level_location = path.level_location_tms
    return tile_location, level_location


if hasattr(path, 'level_location_tms'):
    path.location_funcs = _location_funcs
else:
    sys.stderr.write('mapproxy_seed_tms: no level_location_tms in this MapProxy, '
                     'tms levels 0-9 are not cleaned\n')

from mapproxy.seed.script import main  # noqa: E402  (after the patch)

sys.argv[0] = 'mapproxy-seed'
sys.exit(main())
