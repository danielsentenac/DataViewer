# DataViewer Flutter App

## Run On Linux

The backend endpoint is injected at compile time with `--dart-define`.

```bash
cd flutter_app
../scripts/flutterw run -d linux \
  --dart-define=DATAVIEWER_BASE_URL=http://olserver134.virgo.infn.it:8081/dataviewer
```

## Build Linux Bundle

```bash
cd flutter_app
../scripts/flutterw build linux \
  --dart-define=DATAVIEWER_BASE_URL=http://olserver134.virgo.infn.it:8081/dataviewer
```

Output:

- `build/linux/x64/release/bundle/dataviewer`
