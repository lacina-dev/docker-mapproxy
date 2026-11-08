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
* **Zoom limits.** Sources with fewer levels than `gm_grid` (z0–z21) carry
  `max_res` and their cache `upscale_tiles`, so finer levels are upscaled
  instead of fetched: OpenTopoMap z17, Esri z18, ČÚZK ZTM and Bing z19, ČÚZK
  orthophoto z20 (the OSM `webmercator` grid ends at z19 itself). Put
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
  content), only a missing one is fetched and re-encoded to PNG.
* **CUZK orthophoto cache.** Since 2026-11-08 the orthophoto comes from the
  server's ready tiles (`cuzk_wm_cache`, JPEG); the old WMS cache
  `cache_data/cuzk_cache_EPSG900913` is no longer read. The site fills again
  on the first view or with the open-data seed (`garden_cuzk` below); the old
  directory can then be deleted.
* **Terms.** ČÚZK layers are open data (CC BY 4.0). Google, Esri and Bing
  tiles are used without an API key and cached against their terms, on the
  owner's decision (D40, private robot, few tiles); OSM/OpenTopoMap must not
  be bulk-downloaded (not in `seed.yaml`).
* **Seeding the site.** `scripts/seed_garden.sh` writes a square around the
  robot's map datum (from the UI's `/api/datum`) to
  `mapproxy_configuration/seed_area.wkt` (not in git: the position is
  private) and runs the tasks of `seed.yaml` with one request at a time. Dry
  run by default; `--go` fetches; `--tasks` picks (default `garden_cuzk`,
  open data only).
* **Cache cleanup.** `mapproxy_configuration/cleanup.yaml` removes tiles older
  than 90 days from the online caches (OSM, OpenTopoMap, ZTM, Google map,
  cadastre, contours, relief, slope, buildings); the photo caches (Google
  satellite/hybrid, Esri, Bing, ČÚZK orthophoto) are kept. `scripts/cache_cleanup.sh` runs it in the container
  (`--dry-run` / `--summary` pass through). Weekly via a systemd **user** timer
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
