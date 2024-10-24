import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:awesome_notifications/awesome_notifications.dart';
import "package:universal_html/html.dart" as universal_html;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeService();
  await initializeDateFormatting('fr_FR', null);
  Intl.defaultLocale = 'fr_FR';
  await AwesomeNotifications().initialize(
    'resource://drawable/res_app_icon', // Default icon for notifications
    [
      NotificationChannel(
        channelKey: 'basic_channel',
        channelName: 'Pomodoro Timer',
        channelDescription: 'Notification channel for Pomodoro timer',
        defaultColor: Color(0xFF9D50E8),
        ledColor: Colors.white,
        soundSource: 'resource://raw/merci_mehdi',
        enableVibration: true,
        criticalAlerts: true,
        playSound: true,
        importance: NotificationImportance.High,
        icon: 'resource://drawable/clock',
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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  User? _currentUser;
  int _sessionCount = 0;
  int _totalTimeWorked = 0;
  @override
  void initState() {
    super.initState();

    // Demander la permission de notification
    if (!kIsWeb) {
      requestNotificationPermission();
    } else {
      requestWebNotificationPermission();
    }
    _checkCurrentUser();
  }
  Future<void> _checkCurrentUser() async {
    setState(() {
      _currentUser = _auth.currentUser;
    });
  }

  void _saveSession() async {
    if (_currentUser != null) {
      await FirebaseFirestore.instance.collection('sessions').add({
        'userId': _currentUser!.uid,
        'dateStart': FieldValue.serverTimestamp(),
        'sessionCount': _sessionCount,
        'totalTimeWorked': _totalTimeWorked,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print("Session sauvegardée pour l'utilisateur: ${_currentUser!.uid}");
    } else {
      print("Aucun utilisateur connecté.");
    }
  }

  // Méthode pour se connecter avec Google
  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

      // Créer un nouvel identifiant de connexion avec les informations Google
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      // Authentifier avec Firebase
      UserCredential userCredential = await _auth.signInWithCredential(credential);

      // Connexion réussie
      print("Utilisateur connecté: ${userCredential.user?.email}");
      setState(() {
        _currentUser = userCredential.user;
      });
      // Vous pouvez naviguer vers une autre page ou mettre à jour l'interface utilisateur ici
    } catch (e) {
      print("Erreur lors de la connexion: $e");
    }
  }
  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();

      // Mettre à jour l'état pour refléter que l'utilisateur est déconnecté
      setState(() {
        _currentUser = null;
      });
    } catch (e) {
      print("Erreur lors de la déconnexion: $e");
    }
  }
  void requestNotificationPermission() async {
    // Vérifiez si les notifications sont autorisées
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    print('Notification permission allowed: $isAllowed'); // Debug log

    if (!isAllowed) {
      // Demande de permission
      await AwesomeNotifications().requestPermissionToSendNotifications();
      print('Notification permission requested'); // Debug log
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
        channelKey: 'basic_channel',
        title: title,
        body: body,
        displayOnBackground: true,
        displayOnForeground: true,
        customSound: soundResource,
        icon: 'resource://drawable/clock',
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
              _sessionCount++;
              _totalTimeWorked=_totalTimeWorked+_workTime;
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
      _sessionCount++;
      if (_isWorking) {
        _totalTimeWorked += (_workTime - _currentTime);
      } else {
        _totalTimeWorked += (_breakTime - _currentTime);
      }
      _saveSession();
      _currentTime = _workTime;
      _pause = true;
      _isRunning = false;
      _isWorking = true;
      _stateText = "Au travail camarade !";
      _sessionCount = 0;
      _totalTimeWorked = 0;
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Nouveau bouton pour la connexion Google
            if (_currentUser != null)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Connecté en tant que ${_currentUser!.displayName}',
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 10), // Espace entre le texte et le bouton
                  ElevatedButton(
                    onPressed: _signOut, // Appeler la méthode de déconnexion
                    child: const Text('Se déconnecter'),
                  ),
                ],
              )
            else
              ElevatedButton(
                onPressed: _signInWithGoogle, // Appeler la méthode de connexion
                child: const Text('Se connecter avec Google'),
              ),
            SizedBox(height: 20), // Ajouter un espace pour un meilleur alignement

            // Texte existant indiquant l'état actuel
            Text(
              _stateText,
              style: TextStyle(fontSize: 30),
            ),
            Text(
              '$_currentTime',
              style: TextStyle(fontSize: 60, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),

            // Boutons de contrôle du minuteur (Démarrer, Pause, Stop)
            if (!_isRunning) ...[
              // Afficher ces boutons lorsque le minuteur n'est pas en cours d'exécution
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: _startTimer,
                    child: Text('Démarrer'),
                  ),
                ],
              ),
              SizedBox(height: 20),
              // Boutons pour les paramètres de minuteur prédéfinis (45/15, 25/5)
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
            ] else ...[
              // Afficher ces boutons lorsque le minuteur est en cours d'exécution
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: _pauseTimer,
                    child: Text('Pause'),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _resetTimer,
                    child: Text('Stop'),
                  ),
                ],
              ),
            ],
            SizedBox(height: 20), // Espace supplémentaire pour le bouton suivant

            // Nouveau bouton pour ouvrir une page vide
            if (_currentUser != null) // Check if the user is logged in
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => UserSessionsPage(userId: _currentUser!.uid)),
                  );
                },
                child: const Text('Historique'),
              )
          ],
        ),
      ),
    );
  }
}

String formatDuration(int totalSeconds) {
  final hours = totalSeconds ~/ 3600; // Integer division for hours
  final minutes = (totalSeconds % 3600) ~/ 60; // Remaining minutes
  final seconds = totalSeconds % 60; // Remaining seconds
  return '${hours}h ${minutes}m ${seconds}s'; // Return formatted string
}

class UserSessionsPage extends StatelessWidget {
  final String userId;

  UserSessionsPage({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historique des Timers'), // Changer le titre ici
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sessions')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true) // Maintien l'ordre pour afficher les sessions les plus récentes en premier
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("Aucun timer trouvé")); // Changer le texte ici
          }

          // Retrieve the sessions
          final sessions = snapshot.data!.docs;

          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final sessionData = sessions[index].data() as Map<String, dynamic>;
              final dateStart = (sessionData['dateStart'] as Timestamp).toDate();
              final sessionCount = sessionData['sessionCount'] ?? 0;
              final totalTimeWorked = sessionData['totalTimeWorked'] ?? 0;

              // Format the total time worked into hours, minutes, and seconds
              final formattedTotalTime = formatDuration(totalTimeWorked);

              // Format the date and time
              final dateFormatter = DateFormat('dd MMMM yyyy à HH:mm:ss');

              return Card(
                child: ListTile(
                  title: Text('Timer ${sessions.length - index}'), // Changer "Session" à "Timer" ici
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Débuté le: ${dateFormatter.format(dateStart)}'),
                      Text('Nombre de sessions: $sessionCount'), // Changer "sessions" à "timers"
                      Text('Temps total travaillé: $formattedTotalTime'), // Afficher le temps formaté
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}