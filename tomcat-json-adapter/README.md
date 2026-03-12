# Tomcat JSON Adapter

This module contains the mobile-facing Tomcat adapter for `DataViewer`.

## What is here

- `dto/`: wire DTOs for channel search, plot history, and live updates
- `servlet/`: `HttpServlet` endpoints for `/api/v1/...`
- `service/`: service interfaces plus the Virgo backend wiring
- `json/`: a minimal JSON codec based on Nashorn so the adapter stays Java 8 friendly
- `org.virgo.dataviewer.backend.*`: the new backend internals
- `src/main/native/virgo_frame_jni.c`: the minimal JNI shim around the Frame library
- `src/main/webapp/WEB-INF/web.xml`: Tomcat deployment descriptor and init params

## Endpoints

- `GET /api/v1/channels/search`
- `GET /api/v1/channels/categories`
- `POST /api/v1/plots/query`
- `POST /api/v1/plots/live`
- `GET /api/v1/diagnostics/live-catalog`

## Runtime model

- `ZJChvBuf` is the new live and intermediate layer.
  It subscribes to the ZCM `SUB` endpoint, decodes `ZFD1` payloads, and keeps an in-memory circular buffer for continuity across the archive/live handoff.
  The buffer window is configured in minutes through `virgo.live.buffer.minutes` and can be set to `5`, `7`, `8`, or any other positive value.
  It also provides the default channel catalog used by `/api/v1/channels/search` and `/api/v1/channels/categories`.
- `JniTrendArchiveReader` is the default stateless history layer.
  It opens `/virgoData/ffl/trend.ffl` per request, reads 1 Hz windows through `FrFileIGetVAdc(...)`, applies missing-sample markers, and closes the file immediately.
- `SwigTrendArchiveReader` remains available as a fallback if you set `virgo.history.backend=swig`.
- `VirgoPlotService` joins both layers:
  archive data comes first, then `LiveDirectiveDto` tells the client where live polling should resume.
- `HttpChannelCatalogService` is now only an optional override if you want channel search/categories to come from a separate Tomcat channel-list service instead of the live `zJChv` payload.

## Init params

These `ServletContext` init params are recognized by the backend:

- `virgo.trend.ffl`
  Default: `/virgoData/ffl/trend.ffl`
- `virgo.history.backend`
  Default: `jni`
  Allowed values: `jni`, `swig`
- `virgo.frame.jni.library`
  Default: `virgo_frame_jni`
- `virgo.frame.jni.path`
  Optional absolute path to the JNI shared library. If set, it overrides `virgo.frame.jni.library`.
- `zcmsubendpoint`
  Default: `tcp://olserver38.virgo.infn.it:3333`
- `zcmgpschannel`
  Default: `GPS`
- `virgo.live.buffer.minutes`
  Default: `5`
- `virgo.live.buffer.seconds`
  Optional low-level override. If omitted, it is derived from `virgo.live.buffer.minutes * 60`.
- `virgo.live.poll.ms`
  Default: `1000`
- `virgo.channel.catalog.search.url`
  Optional upstream search endpoint override
- `virgo.channel.catalog.categories.url`
  Optional upstream categories endpoint override
- `virgo.channel.catalog.list.url`
  Optional full channel-list endpoint override used as a local cache and fallback for wildcard/category filtering
- `virgo.channel.catalog.timeout.ms`
  Default: `5000`
- `virgo.channel.catalog.cache.seconds`
  Default: `60`

## Build and deployment

Build the JNI shared library from the existing Frame sources with:

```bash
./scripts/build_virgo_frame_jni.sh
```

By default that script:
- reads Frame sources from `/home/sentenac/TOMCAT/Fr`
- writes the shared library to `tomcat-json-adapter/build/native/libvirgo_frame_jni.so`

Package the WAR with:

```bash
./scripts/package_tomcat_json_adapter.sh "$CATALINA_HOME/lib/servlet-api.jar"
```

To embed a Tomcat context file directly into the WAR:

```bash
./scripts/package_tomcat_json_adapter.sh \
  --context tomcat-json-adapter/deploy/dataviewer-context.xml.example \
  "$CATALINA_HOME/lib/servlet-api.jar"
```

To bundle additional runtime jars into `WEB-INF/lib`:

```bash
./scripts/package_tomcat_json_adapter.sh \
  --runtime-lib /path/to/jchv.jar \
  "$CATALINA_HOME/lib/servlet-api.jar"
```

That writes:
- WAR: `tomcat-json-adapter/build/distributions/dataviewer-tomcat-json-adapter.war`
- JNI library: `tomcat-json-adapter/build/native/libvirgo_frame_jni.so`

Exact Tomcat deployment steps:

1. Build the JNI library:
   ```bash
   ./scripts/build_virgo_frame_jni.sh
   ```
2. Build the WAR:
   ```bash
   ./scripts/package_tomcat_json_adapter.sh "$CATALINA_HOME/lib/servlet-api.jar"
   ```
3. Copy the WAR into Tomcat `webapps`:
   ```bash
   cp tomcat-json-adapter/build/distributions/dataviewer-tomcat-json-adapter.war \
      "$CATALINA_BASE/webapps/dataviewer.war"
   ```
4. Copy the JNI library to a stable location Tomcat can read:
   ```bash
   install -m 755 tomcat-json-adapter/build/native/libvirgo_frame_jni.so \
      /opt/dataviewer/lib/libvirgo_frame_jni.so
   ```
5. Install a Tomcat context file from [dataviewer-context.xml.example](deploy/dataviewer-context.xml.example):
   ```bash
   cp tomcat-json-adapter/deploy/dataviewer-context.xml.example \
      "$CATALINA_BASE/conf/Catalina/localhost/dataviewer.xml"
   ```
6. Edit `$CATALINA_BASE/conf/Catalina/localhost/dataviewer.xml` and set at least:
   - `virgo.frame.jni.path=/opt/dataviewer/lib/libvirgo_frame_jni.so`
   - `virgo.trend.ffl=/virgoData/ffl/trend.ffl`
   - `zcmsubendpoint=tcp://olserver38.virgo.infn.it:3333`
   - `virgo.live.buffer.minutes=5`
7. Restart Tomcat:
   ```bash
   "$CATALINA_BASE/bin/shutdown.sh" || true
   "$CATALINA_BASE/bin/startup.sh"
   ```
8. Verify the live catalog endpoint:
   ```bash
   curl "http://localhost:8080/dataviewer/api/v1/diagnostics/live-catalog"
   ```

For the current Virgo deployment target on `olserver134.virgo.infn.it`, use the repo script instead:

```bash
SSHPASS='<password>' ./scripts/deploy_backend_olserver134.sh
```

That script:
- packages the WAR with [dataviewer-context.olserver134.xml](deploy/dataviewer-context.olserver134.xml)
- builds the JNI library on `olserver134`
- patches the deployed WAR with the existing `jchv.jar` so `org.zeromq.ZMQ` is available
- verifies `GET /dataviewer/api/v1/diagnostics/live-catalog`

Only set `virgo.channel.catalog.*` in the context file if you want to override the default live catalog coming from `zJChv`.

The live catalog diagnostic endpoint returns:
- whether the live source is configured
- the configured buffer size in minutes
- the configured buffer size in seconds
- the current number of buffered snapshots
- the number of distinct catalog channels currently seen from `zJChv`
- oldest/latest buffered UTC sample times

The Gradle module now applies the `war` plugin, so Tomcat packaging includes `WEB-INF/web.xml`.

## Time handling

The backend converts the frontend local-time request to UTC and then to GPS with an explicit leap-second table.
That matters for your archive because dates from 2002 and 2026 do not share the same GPS-UTC offset.

## Why JNI instead of SWIG

The old SWIG surface was far broader than what the mobile backend needs.
The new JNI layer deliberately exports only the archive operations used by this service:

- archive bounds from `FrFileITStart` / `FrFileITEnd`
- raw 1 Hz ADC reads from `FrFileIGetVAdc`
- vector cleanup through `FrVectFree`

That keeps the native boundary small and makes the backend easier to maintain.
