# DataViewer Flutter App

## Run On Linux

For repeat local runs, keep your private endpoint in the ignored
`scripts/dataviewer.local.env` file:

```bash
cp scripts/dataviewer.local.env.example scripts/dataviewer.local.env
$EDITOR scripts/dataviewer.local.env
./scripts/flutter_local.sh run -d linux
```

## Build Linux Bundle

```bash
./scripts/flutter_local.sh build linux
```

Direct `flutterw` commands still work if you prefer passing the endpoint inline:

```bash
cd flutter_app
../scripts/flutterw run -d linux \
  --dart-define=DATAVIEWER_BASE_URL=http://your-tomcat-host:8081/dataviewer
```

Output:

- `build/linux/x64/release/bundle/dataviewer`
