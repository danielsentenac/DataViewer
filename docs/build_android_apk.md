# Build Android APK

To build an Android APK locally, you need:

- a JDK with `javac` available; `JDK 17` is the safe baseline for this project
- Android SDK command-line tools
- accepted Android SDK licenses

The build can use repo-local SDK and Gradle directories:

```bash
export JAVA_HOME=/path/to/jdk-17
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_SDK_ROOT="$PWD/.tooling/android-sdk"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export GRADLE_USER_HOME="$PWD/.tooling/gradle"
```

If the Android SDK is not installed yet, install the command-line tools and then:

```bash
"$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" --licenses
"$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" \
  "platform-tools" \
  "platforms;android-36" \
  "build-tools;35.0.0" \
  "ndk;28.2.13676358" \
  "cmake;3.22.1"
```

Then build:

```bash
cd flutter_app
../scripts/flutterw pub get
../scripts/flutterw build apk --release \
  --dart-define=DATAVIEWER_BASE_URL=http://your-tomcat-host:8081/dataviewer
```

Expected output:

- `flutter_app/build/app/outputs/flutter-apk/app-release.apk`

The backend URL is intentionally not hardcoded in the repository.
`DATAVIEWER_BASE_URL` must be provided at build time, and can also be passed
for local runs:

```bash
cd flutter_app
../scripts/flutterw run \
  --dart-define=DATAVIEWER_BASE_URL=http://your-tomcat-host:8081/dataviewer
```
