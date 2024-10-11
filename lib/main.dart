import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:awesome_notifications/awesome_notifications.dart';
import "package:universal_html/html.dart" as universal_html;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  AwesomeNotifications().initialize(
    null, // Icône de la notif
    [
      NotificationChannel(
        channelKey: 'sound_channel',
        channelName: 'Pomodoro Timer',
        channelDescription: 'Notification channel for Pomodoro timer',
        defaultColor: Color(0xFF9D50E8),
        ledColor: Colors.white,
        soundSource: 'resource://raw/merci_mehdi.mp3',
        enableVibration: true,
        criticalAlerts: true,
        playSound: true
      ),
    ],
  );

  runApp(const MyApp());
}

void startBackgroundService() {
  final service = FlutterBackgroundService();
  service.startService();
}

void stopBackgroundService() {
  final service = FlutterBackgroundService();
  service.invoke("stop");
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
    ),
    androidConfiguration: AndroidConfiguration(
      autoStart: true,
      onStart: onStart,
      isForegroundMode: false,
      autoStartOnBoot: true,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  Timer.periodic(Duration(seconds: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      service.setAsBackgroundService();
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Pomodoro timer'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static int _workTime = 45;
  static int _breakTime = 15;
  int _currentTime = _workTime;
  bool _isWorking = true;
  bool _isRunning = false;
  late Timer _timer;
  bool _pause = true;
  String _stateText = "Au travail camarade !";

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      requestWebNotificationPermission();
    }
  }

  void showWebNotification(String title, String body) {
    if (universal_html.window.navigator.userAgent.contains('Chrome')) {
      universal_html.Notification(title, body: body);
    }
  }

  void requestWebNotificationPermission() {
    if (universal_html.Notification.permission != "granted") {
      universal_html.Notification.requestPermission();
    }
  }

  void showNativeNotification(String title, String body, String soundResource) {
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 1,
        channelKey: 'pomodoro_channel',
        title: title,
        body: body,
        displayOnBackground: true,
        displayOnForeground: true,
        customSound: soundResource,
      ),
    );
  }

  void showNotification(String title, String body) {
    if (kIsWeb) {
      // Notification Web
      showWebNotification(title, body);
    } else {
      // Notification native pour mobile
      showNativeNotification(title, body, 'resource://raw/merci_mehdi.mp3');
    }
  }

  void _startTimer() {
    if (_pause) {
      _pause = false;
      _isRunning = true;
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          if (_isRunning) {
            if (_currentTime > 0) {
              _currentTime--; 
            } else if (_isWorking) {
              _isWorking = false;
              _currentTime = _breakTime;
              _stateText = "Repos !";
              showNotification("Travail Terminé", "Il est temps de faire une pause !");
            } else {
              _isWorking = true;
              _currentTime = _workTime;
              _stateText = "Au travail camarade !";
              showNotification("Pause Terminée", "Il est temps de travailler !");
            }
          }
        });
      });
    }
  }

  void _pauseTimer() {
    if (!_pause) {
      setState(() {
        _pause = true;
        _isRunning = false;
        _timer.cancel();
      });
    }
  }

  void _resetTimer() {
    _timer.cancel();
    setState(() {
      _currentTime = _workTime;
      _pause = true;
      _isRunning = false;
      _isWorking = true;
      _stateText = "Au travail camarade !";
    });
  }

  void _45_15() {
    setState(() {
      _workTime = 45;
      _breakTime = 15;
      _isWorking = true;
      _currentTime = _workTime;
      _stateText = "Au travail camarade !";
    });
  }

  void _25_5() {
    setState(() {
      _workTime = 25;
      _breakTime = 5;
      _isWorking = true;
      _currentTime = _workTime;
      _stateText = "Au travail camarade !";
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _stateText,
              style: TextStyle(fontSize: 30),
            ),
            Text(
              '$_currentTime',
              style: TextStyle(fontSize: 60, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  onPressed: _startTimer,
                  child: Text('Démarrer'),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _pauseTimer,
                  child: Text('Pause'),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _resetTimer,
                  child: Text('Reset'),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  onPressed: _45_15,
                  child: Text('45/15'),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _25_5,
                  child: Text('25/5'),
                ),
              ],
            ),
          ],
        ),
      ),
      /*floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.*/
    );
  }
}
