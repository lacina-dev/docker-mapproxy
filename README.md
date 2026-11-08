# Table of Contents
* [Mapproxy Dockerfile](#mapproxy-dockerfile)
   * [Getting the image](#getting-the-image)
       * [Trusted builds](#trusted-builds)
       * [Local Builds](#local-builds)
   * [Environment variables](#environment-variables)
   * [Mounting Configs](#mounting-configs)
   * [Running Mapproxy](#running-mapproxy)
       * [Docker run commands](#docker-run-commands)
       * [docker-compose](#docker-compose)
           * [Reverse proxy](#reverse-proxy)
           * [S3 storage backend](#s3-storage-backend)
   * [Vitulus robot: map sources, config check, cache cleanup](#vitulus-robot-map-sources-config-check-cache-cleanup)
   * [Support](#support)
   * [Credits](#credits)

# Mapproxy Dockerfile

This will build a [docker](http://www.docker.com/) image that runs [mapproxy
](http://mapproxy.org).

## Getting the image

There are various ways to get the image onto your system:

### Trusted builds

The preferred way (but using most bandwidth for the initial image) is to
get our docker trusted build like this:


```
docker pull kartoza/mapproxy
```

### Local Builds

To build the image yourself do:

```
docker build -t kartoza/mapproxy git://github.com/kartoza/docker-mapproxy
```

To build  using a local url instead of directly from GitHub.

```
git clone git://github.com/kartoza/docker-mapproxy
```

```
docker build -t kartoza/mapproxy .
```

**Note:** We do not use tagged versions as we install the latest
version of mapproxy.

To build a specific version

You can use the build arg `MAPPROXY_VERSION: '==1.15.1'` and substitute this in
the `docker-compose-build.yml` then 

```bash
docker compose -f docker-compose-build.yml build
```

## Environment variables
The image specifies a couple of environment variables

* `MAPPROXY_DATA_DIR`=path to store configuration files when running single
  app mode
* `MULTI_MAPPROXY_DATA_DIR`=path to store configuration files when running
  multi app mode
* `PROCESSES`=number of processes to run uwsgi in. Only available
  when running the production version.
* `CHEAPER=`Minimum number of workers allowed. This should always be lower than
the env `PROCESSES`
* `THREADS`=maximum number of parallel threads to run production instance with.
* `PRODUCTION`=Boolean value to indicate if you need to run develop server or using uwsgi
* `MULTI_MAPPROXY`=Boolean value to indicate if you need to run multi mapproxy. Defaults to false
* `ALLOW_LISTING`=Allows listing all config files in multi map mode
* `LOGGING`=Boolean value to indicate if you need to activate logging. Useful
when using uwsgi (not in multi-app mode)
* `ENABLE_S3_CACHE`=Boolean value to indicate if support for the S3 storage backend should be enabled.
* `AWS_ACCESS_KEY_ID`=The S3 backend username value
* `AWS_SECRET_ACCESS_KEY`=The S3 backend password value
* `CREATE_DEFAULT_S3_BUCKETS`=Boolean value to indicate if mapproxy should try to create buckets when
the container starts. If MinIO starts up with the MapProxy container, it will not have a bucket available by
default, so S3 based caching will not work until a bucket is created. The default value is false.
* `S3_BUCKET_LIST`=A list of bucket names to check for on the S3 endpoint, and create if they are not available.
Supports space, comma, and semicolon separated values. Default value is `mapproxy`.
* `S3_BUCKET_ENDPOINT`=The endpoint for your S3 service. Unless you are using S3 from AWS directly,
you most likely want to set this to `http://minio:9000/` or the URL of your external S3 service.

## Mounting Configs

if running in production you can specify any uwsgi parameters.

You can mount the [uwsgi.ini](https://github.com/kartoza/docker-mapproxy/blob/master/build_data/uwsgi.ini) to
a path inside the container thus overriding a lot of the uwsgi default settings.

```bash
-v /data/uwsgi.ini:/settings/uwsgi.ini
```

## Running Mapproxy

You can run mapproxy either using docker run command or using the docker-compose.

### Docker run commands

To run a mapproxy container do:

```
docker run --name "mapproxy" -p 8080:8080 -d -t kartoza/mapproxy
```

Typically, you will want to mount the mapproxy volume, otherwise you won't be
able to edit the configs:

In single app mode
```bash
mkdir mapproxy
docker run --name "mapproxy" -p 8080:8080 -d -t -v `pwd`/mapproxy:/mapproxy kartoza/mapproxy
```

In multi mode app

```bash
mkdir multi_mapproxy
docker run --name "mapproxy" -p 8080:8080 -d -t -v `pwd`/multi_mapproxy:/multi_mapproxy kartoza/mapproxy
```

The first time your run the container, mapproxy basic default configuration
files will be written into `/mapproxy` or `multi_mapproxy` volumes. You should read the mapproxy documentation
on how to configure these files and create appropriate service definitions for
your WMS services. Then restart the container to activate your changes.

The cached wms tiles will be written to a path defined by the environment variable `MAPPROXY_CACHE_DIR` 
`/cache_data` externally or any other path that is defined by the mapproxy.yaml.

**Note** that the mapproxy containerised application will run as the user that
owns the /mapproxy folder. The UID:GID of the process will be 1000:1000.
If you are mounting existing config directory i.e.  `./configuration` folder,
you need to set the folder permission with `chown -R 1000:1000 ./configuration` from this directory.

### docker-compose
You can set up the services using the docker-compose. The docker-compose sets up the QGIS server
container and links it to the mapproxy container and nginx for reverse proxy.

An `index.html` is provided in the web folder to preview the layers in mapproxy.

#### Reverse proxy

The mapproxy container 'speaks' ``uwsgi`` protocol, so you can also put nginx in front of it
to receive http request and translate it to uwsgi
(try the ``nginx docker container``). However, our sample configuration by default
make `uwsgi` uses `http` socket instead of `socket` parameter (uwsgi protocol). A sample configuration (via linked
containers) that will forward traffic into the uwsgi container, adding the appropriate
headers as needed is provided via docker-compose

Take a look at the [docker-compose](https://github.com/kartoza/docker-mapproxy/blob/develop/docker-compose.yml) or [docker-compose-s3](https://github.com/kartoza/docker-mapproxy/blob/develop/docker-compose-s3.yml) 
to look at linking two or more containers

Once the service is up and running you can connect to the default demo
mapproxy service by pointing QGIS' WMS client to the mapproxy service.
In the example below the nginx container is running on
``localhost`` on port 8080.

```
http://localhost/mapproxy/service/?
```

#### S3 storage backend

MapProxy supports the S3 storage backend for data caching. This provides a number of benefits, including the ability to decouple MapProxy and more readily scale your solution with multiple instances of MapProxy sharing the same storage backend without having to concern yourself with io locks or access collisions.

We provide an example implementation with `mapproxy-s3.yaml`, which is used in the `docker-compose-s3.yml` implementation, to configure an S3 backend for certain services.

```
docker compose -f ${pwd}docker-compose-s3.yml up -d
```

Then review the example service at `http://localhost/`. Ensure that `minio_admin` and `secure_minio_secret` are stored and used as environment variables in production deployments.

This implementation mounts [MinIO](https://min.io/) - an S3 Compatible container service - as a storage backend for MapProxy

MinIO can be accessed from `http://localhost:9001` or using the minio api endpoint from `http://localhost:9000`

Note that the MinIO service does not support subpaths or routes on the web server and any reverse proxy will need to be implemented at the web root, using a dedicated subdomain. Note as well that MinIO provides a Console (web-ui), and an API endpoint as distinct services which serve different functions... api calls to the console will return errors.

You can use this methodology to serve as a proxy for other storage solutions, for example, using MinIO as a [proxy for Microsoft Azure Blob Storage](https://cloudblogs.microsoft.com/opensource/2017/11/09/s3cmd-amazon-s3-compatible-apps-azure-storage/).

## Vitulus robot: map sources, config check, cache cleanup

This fork serves the map layers of the Vitulus mower UI (port 8082). The
container runs from `docker-compose-build.yml` (`docker compose -f
docker-compose-build.yml up -d --no-build mapproxy`); `scripts/start.sh` is
mounted from this repo and starts MapProxy with `reloader=True`, so a saved
`mapproxy_configuration/mapproxy.yaml` goes live at once.

* **Layers and the UI list.** Every layer the robot UI offers is listed in
  `mapproxy_configuration/ui_sources.json` (id, `layer` = the MapProxy layer
  name, grid, format, kind `base`/`overlay`, en/cs names, zoom range, credit,
  `layer_order` of overlays). A new source = a layer in `mapproxy.yaml` + an
  entry there; the UI needs no change.
* **Check before saving** (a broken file takes every layer down):

      cp mapproxy_configuration/mapproxy.yaml /tmp/mapproxy.yaml   # edit the copy
      scripts/check_mapproxy_yaml.sh /tmp/mapproxy.yaml && \
          cp /tmp/mapproxy.yaml mapproxy_configuration/mapproxy.yaml

  It validates with the container's own MapProxy (YAML, options, references,
  service set-up) and checks that every layer of `ui_sources.json` exists.
  Without an argument it checks the live file.
* **uWSGI settings.** `mapproxy_configuration/uwsgi.robot.ini` is written to
  `/settings/uwsgi.ini` by `scripts/start.sh` on every container start
  (envsubst, the same variables as the image's `build_data/uwsgi.ini`), so a
  change needs only a restart: `docker restart docker-mapproxy-mapproxy-1`.
  T17 M9-3: workers restart after a day / 20000 requests instead of an hour /
  1000 (with 16–20 workers that was one restart about every 3 minutes);
  `reload-on-rss` 512 MB (was 2048; a worker uses ~50 MB) is the memory guard.
  Single mode only (the robot, `MULTI_MAPPROXY=false`); not named `uwsgi.ini`,
  which the image would copy without envsubst.
* **Zoom limits.** Sources with fewer levels than `gm_grid` (z0–z21) carry
  `max_res` and their cache `upscale_tiles`, so finer levels are upscaled
  instead of fetched: OpenTopoMap z17, Esri and its Wayback releases z18,
  the M6 DMR 5G / DMP 1G renderings z18 (2 m data), the CENIA 1950s
  orthophoto z18 (0.5 m data), ČÚZK ZTM and Bing z19, Google satellite and
  hybrid z20 (T17 M9-2: their z21 measured no more detail than z20, also over
  the garden; z21 is upscaled from z20, `ui_sources.json` `native_zoom` 20)
  (the OSM `webmercator` grid ends at z19 itself). The ČÚZK orthophoto tiles end
  at z20; its z21 comes from the ČÚZK WMS (see "CUZK orthophoto cache"). Put
  `max_res` a little BELOW the resolution of the last real level (e.g. 0.25
  for z19 = 0.2986 m/px): the exact value is lost to float rounding and the
  last real level is then served upscaled from the one above.
* **Formats.** New photo caches are JPEG (stored as the server sends them),
  drawn maps and transparent overlays PNG. `gm_layer` (Google satellite, the
  default base) is unchanged: its cache is format PNG and its files are
  named `*.png`, but hold the JPEG Google sends — switching it to JPEG would
  lose the warm offline cache. `cuzk_layer` is the old PNG URL of
  `cuzk_ortho_layer` (nothing stored): a tile already in that JPEG cache goes
  out as is (JPEG bytes, Content-Type `image/png`; browsers decode by
  content), only a missing one is fetched and re-encoded to PNG. A new ČÚZK
  orthophoto tile is always decoded and re-encoded once before it is stored
  (merged sources; JPEG quality 90, measured 38.8–40.4 dB PSNR against the
  received tile, ~10 % smaller; a refresh always starts from the server).
* **CUZK orthophoto cache and offline.** Since 2026-11-08 the orthophoto
  comes from the server's ready tiles (`cuzk_wm_cache`, JPEG). The cache also
  reads, never writes, the old WMS cache `cache_data/cuzk_cache_EPSG900913`
  (cache `cuzk_cache`, no source) and its own coarser levels
  (`cuzk_wm_coarse`). Online the server tile is stored as before. Without
  network a missing tile shows the old cache's tile, else a coarser level
  magnified (old cache up to 6 levels, own cache up to 4), else a plain white
  tile — not stored, no 500. So the offline orthophoto of the site stays
  after the update without any seed. MapProxy 1.16 can do this only by
  merging these sources (details in `mapproxy.yaml` at `cuzk_wm_cache`); the
  other layers still answer 500 offline for a tile they do not have (a
  fallback for those belongs in the UI: a 500 tells it the tile is missing,
  a white tile would not). Delete `cuzk_cache_EPSG900913` (86 MB on the robot) only after the
  open-data seed (`garden_cuzk` below) has run with `--go` WITH network and
  the result is checked: the seed reports 100 % even offline while storing
  nothing, so count the files of `cuzk_wm_cache_EPSG900913` for z14–z20
  around the site against the dry-run estimate first. Offline the orthophoto
  fallback tiles (white or old cache) are sent with max-age 1 h and one
  constant ETag; an open page shows them until it reloads the tiles.
* **Shared WMS slots on ags.cuzk.cz.** MapProxy's `concurrent_requests` is a file
  semaphore per host shared by all WMS sources on it: slope, RÚIAN and the relief ×10/×20,
  aspect and DMP layers (limit 4 each since T17, before 1 and 2) pick one of the same 4 slots
  (lock wait is capped by the source's `http.client_timeout`, 15 s, then 500). Measured at public points
  in Prague (cold cache, 108 tiles of RÚIAN + slope + relief ×10 at z17/z18): 24 parallel tile
  requests 4.2 s instead of 10.3 s (median of 7 runs each), RÚIAN complete after ~1.5 s
  instead of ~5 s; 6 parallel (one browser) 7.3 s instead of 11.2 s; `mapproxy-seed -c 4`
  6.5 s instead of 14.2 s (`seed_garden.sh` runs one request at a time: unchanged). The RÚIAN
  WMS answered 96 direct GetMaps at 1/2/4/8 at once without a 429/503. One limit-4 burst met
  an upstream read hanging 60 s while ČÚZK was slow: uWSGI `harakiri` (60 s) then kills the
  whole worker with its other threads (42 of 108 tiles failed in that run). Hence the time
  limits (`globals: http: client_timeout: 20`, the ČÚZK WMS sources 15 s): meta-tile lock 20 s
  + slot 15 s + read 15 s = 50 s < 60 s. With a fake hung (and a 45 s slow) WMS in place of
  RÚIAN, 36 RÚIAN + 36 OpenTopoMap tiles 24 at once: before (60/60 s) and with 30 s on the
  source alone 20–35 RÚIAN requests were cut at 60 s by harakiri; with 20/15 s all 36 answered
  500 within 45 s, no harakiri, OpenTopoMap all 200 in < 0.6 s. The 20 s is also the read
  timeout of every source without its own value (normal tiles take well under 2 s, the
  slowest ČÚZK rendering seen was 12 s). Aspect is a categorical colour map with no neutral
  colour: it tints the whole view, keep its opacity low.
* **ČÚZK layers vs Google/Bing: ~1 m shift, not a MapProxy error** (measured
  2026-11-08 at five public points in Prague: Ladronka, Ořechovka, náměstí
  Míru, Letná, Karlín; phase correlation of 1024 px z19 mosaics). MapProxy
  does not transform the ČÚZK layers: it asks the servers for EPSG:3857
  directly (`supported_srs`). The servers turn S-JTSK into WGS 84 with the
  7-parameter "S-JTSK to WGS 84 (1)" (EPSG:1623): RÚIAN address points from
  the REST API in EPSG:3857 equal the EPSG:5514 ones run through that
  transformation in PROJ to 0.00 m, the RÚIAN WMS image and the ORTOFOTO_WM
  tiles match the S-JTSK images reprojected that way within 0.3 m (1.5 px).
  That transformation lands in ETRS89, which moves with Europe: in 2026 a
  point placed by its ETRS89 coordinates shows 0.77 m west and 0.58 m south
  of its current WGS 84/ITRF position (PROJ, ETRS89 → ITRF2014 at epoch
  2026.85). Google imagery sits +0.62…+0.79 m east
  and +0.58…+0.80 m north of the ČÚZK orthophoto at four of the points (the
  fifth, Letná, has no reliable match), Bing +0.25…+0.58 m east, +0.36…+0.51 m
  north — the ETRS89 drift. Building outlines (RÚIAN) also never fit roofs
  exactly on any photo: roofs lean away from the camera by up to a few
  metres (not true orthophotos). So RÚIAN fits the ČÚZK orthophoto and is
  ~1 m off Google by design. The UI aligns each georeference on its own
  (catalog `offset_key`: RÚIAN, cadastre, relief share `cuzk`, Google bases
  `sat`), which is the right place to correct it; shifting the ČÚZK layers
  in MapProxy would break those stored alignments and mix shifted and
  unshifted tiles in the caches. Requesting EPSG:5514 and reprojecting in
  MapProxy gives the same result (PROJ's best S-JTSK transformations here
  differ from EPSG:1623 by ≤ 0.05 m) at more CPU. The CENIA 1950s orthophoto,
  reprojected by MapProxy, shares the ČÚZK georeference: in the catalog it
  has `offset_key: "cuzk"`, so it uses the ČÚZK alignment of the UI.
* **Historical orthophoto, 1950s (CENIA).** Layer `cenia_hist_layer`
  (catalog id `cenia_1950s`, "Ortofoto 50. léta (CENIA)"): greyscale aerial
  photos mostly from 1952–1954 (gaps filled with 1937–1970 and 1996),
  0.5 m/px, from the CENIA MapCache WMS
  `https://gis.cenia.cz/mapcache/ortofotomapa_historicka/wms` (layer `orto`).
  The server answers only in S-JTSK (EPSG:5514, EPSG:3857 gives 400), so
  MapProxy fetches each uncached 4×4 meta tile in S-JTSK and reprojects it
  into `gm_grid` (PROJ, "S-JTSK to WGS 84 (5)", 1 m accuracy in Czechia; at a
  public test point in Prague the picture sits within 0–3 px of the ČÚZK
  orthophoto at z16, no constant shift). z18 is fetched, z19–z21 upscaled
  from it (not stored). **CPU** (measured 2026-11-08 in
  `kartoza/mapproxy:robot` on an i7-13650HX laptop, container cgroup CPU per
  cold request, 8 meta tiles each): 86 ms (z16) / 126 ms (z18) median per
  meta tile, i.e. 5–8 ms per stored tile, against 19 ms for a non-reprojected
  JPEG WMS of the same size (`cuzk_hillshade_z10_layer`); one request of 16
  took 700 ms. A cached tile costs ~1 ms, an upscaled z19 tile ~6 ms. The
  robot's i7-8559U is slower per core (not measured there). Not seeded;
  cleaned after 90 days like the Wayback releases (the photo never changes).
  **Licence** checked in the CENIA metadata catalogue (micka): dataset record
  `50210752-9d9c-4f47-956b-1951c0a80137` and view service record
  `60b09c14-9538-4a0f-a66c-6118c0a80164` both give Creative Commons BY 4.0,
  no limits on public access (open data), credit "Historická ortofotomapa ©
  CENIA 2010 a © GEODIS BRNO, spol. s r.o. 2010, podkladové letecké snímky
  poskytl VGHMÚř Dobruška, © MO ČR 2009" — shortened in the UI credit
  (`ui_sources.json`).
* **Precipitation mosaic (`precip_mosaic`, catalog id `precip`).** The newest
  frame (`latest`) of the robot's own precipitation mosaic service
  `vitulus_precip` (repo precip-mosaic, its own container on the host
  network from `deploy/docker-compose.yml`, HTTP port **8097** on all
  interfaces; procedure in its README, *Deployment on the robot*). Transparent PNG, nothing stored
  (`disable_storage`: the frame changes every 5 min); the service draws
  z3–z8 around the site, z9–z21 are upscaled from its z8 tile. This
  container runs on the compose bridge network, so the source URL uses
  `host.docker.internal`, mapped to the host by `extra_hosts:
  host-gateway` in `docker-compose-build.yml` — the container must be
  **recreated** once after that change (`docker compose -f
  docker-compose-build.yml up -d --no-build mapproxy`). Until then, and
  whenever the service is down or hangs (15 s timeout), the layer answers a
  transparent tile (HTTP 200, not stored) and the other layers are not
  affected. MapProxy sends these tiles with the global max-age 1 h, so a
  browser keeps a stale frame unless the client adds a changing query
  parameter (MapProxy ignores it). The robot UI uses this layer only as a
  fallback: with the catalog's `"timeline": {"port": 8097}` it takes the
  frames from the service itself, each with its own URL. Credit: © EUMETNET OPERA (CC BY 4.0),
  © ČHMÚ, Weather data by RainViewer; RainViewer data are for personal use
  only (not redistributable): keep this endpoint private. The time slider of
  the UI talks to the service directly.
* **Terms.** ČÚZK layers and the CENIA 1950s orthophoto are open data (CC BY
  4.0). Google, Esri (also
  the Esri Wayback releases `esri_wb_*`) and Bing tiles are used without an API key and cached against their terms, on the
  owner's decision (D40, private robot, few tiles); OSM/OpenTopoMap must not
  be bulk-downloaded (not in `seed.yaml`).
* **Bing (`bing_layer`), checked 2026-11-08.** The URL
  `ecn.t0.tiles.virtualearth.net/tiles/a<quadkey>.jpeg?g=1` is the tile
  server the official Bing Maps Imagery Metadata API hands out (its
  `imageUrl`), only without the key-based session and with an old
  generation `g=1`, which still answers. It has worked unchanged for many
  years (also `t1`…`t3`, same tile; HTTP 200 JPEG with `max-age` one year and
  `X-VE-TileMeta-CaptureDatesRange`, the capture date of the tile). **Not
  legal by the terms:** the metadata API without a key answers
  `NoCredentials` with the notice that the content may not be used without
  Microsoft's written consent; Bing Maps for Enterprise free (Basic) keys
  stopped working on 2025-06-30, so no free key exists any more, and the
  Enterprise licence (paid) ends on 2028-06-30 in favour of Azure Maps.
  **Stability:** fine today, but nothing promises the endpoint after that
  date; when it goes, the cached tiles still show, a new tile answers 500
  (no `on_error` on purpose: an error must not be cached as an image).
  **Recommendation: keep** it as the owner's D40 extra photo base (it is
  never the default and is not in the default seed), and drop it from
  `ui_sources.json` when it stops answering or by mid-2028. The legal
  replacement is Azure Maps imagery (`tilesetId=microsoft.imagery`, key
  required, Gen2 free tier ~1,000 imagery transactions = ~15,000 tiles a
  month); it needs a key kept OUT of this public repo (MapProxy 1.16 does
  not expand environment variables in the YAML: a git-ignored `base:`
  include would be needed) and its caching terms checked first.
* **Seeding the site.** `scripts/seed_garden.sh` writes a square around the
  robot's map datum (from the UI's `/api/datum`) to
  `mapproxy_configuration/seed_area.wkt` (not in git: the position is
  private) and runs the tasks of `seed.yaml` with one request at a time. Dry
  run by default; `--go` fetches; `--tasks` picks. Default tasks:
  `garden_cuzk` (open data) and `garden_google_sat` (Google satellite
  `gm_cache`, the UI's default base, same levels z14–z20, about 410 tiles for
  the 400 m square; tiles already cached are kept), so offline in the garden
  the default base covers the whole square. `--tasks garden_cuzk` = open data
  only; the other commercial tasks (`garden_photo_google/esri/bing`) run only
  when named.
* **Scripts run as the MapProxy user.** `seed_garden.sh`, `cache_cleanup.sh`
  and `check_mapproxy_yaml.sh` call `docker exec -u <MAPPROXY_USER_ID>:<MAPPROXY_GROUP_ID>`
  (read from the container, 1000:1000 here; override with `MAPPROXY_EXEC_USER`).
  A plain `docker exec` runs as root: a seed run that way left the ČÚZK lock
  file and the RÚIAN/slope cache directories owned by root, and the server
  (uWSGI runs as `mapproxy`) answered 500 for slope, RÚIAN and relief until
  the owner was fixed (`chown -R 1000:1000` of `cache_data`). Seed and
  clean-up run in `cache_data`, where `--use-cache-lock` keeps its lock file
  `.mapproxy_seed.lck` (before, as root, in the container's `/`).
* **Cache cleanup.** `mapproxy_configuration/cleanup.yaml` removes old tiles
  from the online caches: after 90 days OSM, OpenTopoMap, Google map, the
  relief ×10/×20, aspect and DMP 1G overlays, the Esri Wayback releases and
  the CENIA 1950s orthophoto (not seeded; these photos never change, they go
  only to save disk);
  after 52 weeks the layers the seed keeps for the garden (ZTM, cadastre,
  contours, relief, slope, buildings — the seed refreshes them at the same
  age, so run it again about once a year). The photo caches (Google
  satellite/hybrid, Esri, Bing, ČÚZK orthophoto) and the old orthophoto
  cache are kept. `scripts/cache_cleanup.sh` runs it in the container
  (`--dry-run` / `--summary` pass through) through
  `scripts/mapproxy_seed_tms.py`: plain `mapproxy-seed --cleanup` of MapProxy
  1.16 never cleans z0–z9 of a `directory_layout: tms` cache (it looks for
  the level directories `00`…`09`, tms stores `0`…`9`; `mapproxy/cache/path.py`
  gives tms the generic `level_location` although `level_location_tms`
  exists). The wrapper wires `level_location_tms` in for the clean-up run
  only, so no cache moves (a layout change would orphan every stored tile).
  Checked on a cache copy (tiles 120 days old, two levels kept fresh): plain
  MapProxy left all old z0–z9 tiles (OpenTopoMap/Google map z0–z9, Wayback
  z5–z9, relief z9), the wrapper removed them and kept the fresh ones; the
  `tc` OSM cache is cleaned the same either way. Weekly via a systemd **user** timer
  (no root, logged in the user journal, catches up after downtime):

      ln -sf ~/catkin_ws/src/docker-mapproxy/scripts/systemd/mapproxy-cache-cleanup.{service,timer} ~/.config/systemd/user/
      systemctl --user daemon-reload && systemctl --user enable --now mapproxy-cache-cleanup.timer
      journalctl --user -u mapproxy-cache-cleanup   # what it removed

## Support

If you require more substantial assistance from [kartoza](https://kartoza.com)  (because our work and interaction on docker-mapproxy is pro bono),
please consider taking out a [Support Level Agreement](https://kartoza.erpnext.com/product/support)

## Credits
Tim Sutton (tim@kartoza.com)
Admire Nyakudya (admire@kartoza.com)
September 2022
