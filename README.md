
## Installation
- Download the `vuTelemetry-Flutter` Plugin from o11ySources page
- Add the plugin to your `pubspec.yaml` file and refer the path where you placed the downloaded plugin
```yaml
dependencies:
  flutter:
    sdk: flutter
  opentelemetry:
    path: ../../Projects/opentelemetry-dart
```

### Android specific setup

- Supports from minimum android version of `6` or `API 24`
- In your `app/build.gradle` or `app/build.gradle.kts` file  
	- Enable `coreLibraryDesugaring` 
	- Add coreLibraryDesugaring SDK

```gradle
android {

	...
	
    compileOptions {
	    ...
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        minSdk = 24
    }

	...

}

dependencies {
    coreLibraryDesugaring ("com.android.tools:desugar_jdk_libs:2.1.4")
}
```


## Initialisation

- Import the vuTelemetry flutter library
- Initialise with the following params
	- `logsIngestUrl` - Given by MRUM o11ySource
	- `tracesIngestUrl` -  Given by MRUM o11ySource
	- `appName` - Name of you application
	- `appType` - Like `Flutter` , `iOS` or `Android`
	- `enableSlowFrameTracking` - Optional param - defaults to `false` - Used to track slow rendering of flutter screens - If a screen took more than 16ms to render then it is treated as slow rendering


```dart
import 'package:flutter/material.dart';
import 'package:vutelemetry/flutter_sdk.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize OpenTelemetry SDK
  VuTelemetry.initialise(
    params: InitialisationParams(
      logsIngestUrl: 'http://10.0.2.2:4318/v1/logs',
      tracesIngestUrl: 'http://10.0.2.2:4318/v1/traces',
      appName: '<your-app-name>',
      appType: 'Flutter',
	  enableSlowFrameTracking: true,
    ),
  );

  runApp(const MainApp());
}
```

- This will trace all the errors and crashes


### Tracing Screen Navigation 

Use the `RouteObserverService` provided by the SDK to automatically trace all the screen navigation events.
```dart
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LoginPage(),
      navigatorObservers: [RouteObserverService()],
    );
  }
}
```


### Monitoring Network Calls

Use`TrackedHttpClient` Provided by the SDK

```dart
static final http.Client _client = TrackedHttpClient( http.Client());
```

This will automatically track Network events and add trace header to every network call in order to help distributed tracing 


### Tracking Click Events

Use the method `VuTelemetry.logClickEvent` with an event name to record any click event. You cab provide additional attributes to the click event.

```dart
DropdownButton<Account>(
  items: [...],
  value: provider.selectedAccout,
  hint: const Text('Select Account'),
  onChanged: (v) {
    VuTelemetry.logClickEvent(
      'Account Switch',
      attributes: {
        'account_number': v?.accountNumber ?? '',
      },
    );
    provider.switchAccount(v!);
  },
)
```


### Setting Custom Global Attributes

You can set any global identifier like userId by using the methods
- `VuTelemetry.setCustomAttribute`
- `VuTelemetry.setCustomAttributes`

```dart
VuTelemetry.setCustomAttribute(
	'userId',
	'xxxxxxxxxxxx',
);
```

