    import React, { useState, useEffect, useRef } from 'react';
    import { View, Text, TouchableOpacity, Image, StyleSheet, Platform, ScrollView } from 'react-native';
    import imagePause from './pause.png';
    import BackgroundTimer from 'react-native-background-timer';
    import { Audio } from 'expo-av';
    import * as Device from 'expo-device';
    import * as Notifications from 'expo-notifications';
    import Constants from 'expo-constants';
    import * as Permissions from 'react-native-permissions';
    import auth from '@react-native-firebase/auth';
    import { GoogleSignin, statusCodes } from '@react-native-google-signin/google-signin';
    import firestore from '@react-native-firebase/firestore';

    GoogleSignin.configure({
      webClientId: '350147608711-skgu3el8ktl8chp7jeca3bo5cm271c85.apps.googleusercontent.com',
    });

    // Configuration du gestionnaire de notifications
    Notifications.setNotificationHandler({
      handleNotification: async () => ({
        shouldShowAlert: true,
        shouldPlaySound: false,
        shouldSetBadge: false,
      }),
    });

    function PageHistorique({ onRetour, userId }) {
      const [sessions, setSessions] = useState([]);
    
      useEffect(() => {
        // Fonction pour récupérer l'historique des sessions de l'utilisateur depuis Firestore
        async function fetchSessions() {
          if (userId) {
              try {
                  const sessionSnapshot = await firestore()
                      .collection('sessions')
                      .where('userId', '==', userId)
                      .orderBy('createdAt', 'desc') // Tri par ordre décroissant de la date de création
                      .get();
      
                  if (sessionSnapshot.empty) {
                      console.log('Aucune session trouvée.');
                      return;
                  }
      
                  // Mappage des documents récupérés avec conversion de date
                  const sessionData = sessionSnapshot.docs.map(doc => ({
                      id: doc.id,
                      ...doc.data(),
                      dateStart: doc.data().dateStart ? doc.data().dateStart.toDate() : null, // Conversion du Timestamp en Date
                  }));
      
                  console.log('Sessions récupérées :', sessionData);
                  setSessions(sessionData);
              } catch (error) {
                  console.error('Erreur lors de la récupération des sessions :', error);
              }
          } else {
              console.log('userId non défini');
          }
      }
    
        fetchSessions();
      }, [userId]);
    
      return (
        <View style={styles.pageHistoriqueContainer}>
          <TouchableOpacity style={styles.retourButton} onPress={onRetour}>
            <Text style={styles.buttonText}>Retour</Text>
          </TouchableOpacity>
          <Text style={styles.text}>Historique des Sessions :</Text>
          <ScrollView style={styles.scrollView}>
            {sessions.length > 0 ? (
              sessions.map(session => (
                <View key={session.id} style={styles.sessionItem}>
                  <Text style={styles.sessionText}>
                    Début : {new Date(session.dateStart).toLocaleString()}
                  </Text>
                  <Text style={styles.sessionText}>
                    Nombre de sessions : {session.sessionCount}
                  </Text>
                  <Text style={styles.sessionText}>
                    Temps total travaillé : {session.totalTimeWorked} secondes
                  </Text>
                </View>
              ))
            ) : (
              <Text style={styles.noSessionText}>Aucune session trouvée.</Text>
            )}
          </ScrollView>
        </View>
      );
    }


    function Timer() {
      // Initialisation des états
      const [sessionStart, setSessionStart] = useState(0);
      const [sessionCount, setSessionCount] = useState(0); // Nombre de sessions
      const [totalTimeWorked, setTotalTimeWorked] = useState(0); // Temps total travaillé en secondes
      const [TempsTravail, setTempsTravail] = useState(8);
      const [TempsPause, setTempsPause] = useState(5);
      const [secondsLeft, setSecondsLeft] = useState(TempsTravail);
      const [pause, setPause] = useState(true);
      const [enTravail, setEnTravail] = useState(true);
      const [estLancé, setEstLancé] = useState(false);
      const [buttonName, setButtonName] = useState("Lancer le timer");
      const [expoPushToken, setExpoPushToken] = useState('');
      const [channels, setChannels] = useState([]);
      const [notification, setNotification] = useState(undefined);
      const [showTestPage, setShowTestPage] = useState(false);
      const [isSigningIn, setIsSigningIn] = useState(false); 
      const notificationListener = useRef();
      const responseListener = useRef();
      const soundRef = useRef(null);
      const signOut = async () => {
        try {
          // Déconnexion de Firebase
          await auth().signOut();
          // Déconnexion de Google
          await GoogleSignin.signOut();
          setUserInfo(null); // Réinitialiser l'état de l'utilisateur après déconnexion
          console.log('Utilisateur déconnecté');
        } catch (error) {
          console.error('Erreur lors de la déconnexion', error);
        }
      };
      const [userInfo, setUserInfo] = useState(null);
      const signInWithGoogle = async () => {
        if (isSigningIn) {
          console.log('Connexion déjà en cours');
          return;
        }
      
        setIsSigningIn(true);
        try {
          await GoogleSignin.hasPlayServices();
      
          const userInfo = await GoogleSignin.signIn();
          console.log('Google sign-in result:', userInfo);
      
          // Extraire idToken
          const { idToken } = userInfo.data;
      
          if (idToken) {
            const googleCredential = auth.GoogleAuthProvider.credential(idToken);
            const userCredential = await auth().signInWithCredential(googleCredential);
      
            // Enregistrement de l'utilisateur dans Firestore
            const userData = {
              uid: userCredential.user.uid,
              displayName: userCredential.user.displayName,
              email: userCredential.user.email,
              photoURL: userCredential.user.photoURL,
              createdAt: firestore.FieldValue.serverTimestamp(), // Timestamp de création
            };
      
            // Ajouter l'utilisateur à Firestore
            await firestore().collection('users').doc(userData.uid).set(userData, { merge: true });
      
            setUserInfo(userCredential.user);
            console.log('Utilisateur connecté :', userCredential.user);
          } else {
            throw new Error('idToken not found');
          }
        } catch (error) {
          console.error('Erreur lors de la connexion avec Google', error);
      
          if (error.code === statusCodes.SIGN_IN_CANCELLED) {
            console.log('Connexion annulée');
          } else if (error.code === statusCodes.IN_PROGRESS) {
            console.log('Connexion en cours');
          } else if (error.code === statusCodes.PLAY_SERVICES_NOT_AVAILABLE) {
            console.log('Services Google Play non disponibles');
          } else {
            console.error('Erreur lors de la connexion avec Google', error);
          }
        }
      };
      
      async function updateSessionData() {
        if (userInfo && userInfo.uid) {
          try {
            console.log('Session Count:', sessionCount);
            console.log('Total Time Worked:', totalTimeWorked - secondsLeft);
            console.log('Session Start:', sessionStart);
      
            // Référence à la collection des sessions
            const sessionsCollectionRef = firestore().collection('sessions');
      
            // Créez un document avec un ID unique (UUID) pour chaque session
            const sessionDocRef = sessionsCollectionRef.doc(); // Crée un doc avec un ID automatique
      
            // Convertir la chaîne en objet Date puis en Timestamp
            const dateStartTimestamp = sessionStart instanceof Date ? firestore.Timestamp.fromDate(sessionStart) : firestore.Timestamp.fromDate(new Date());
      
            // Enregistrement des données de session
            await sessionDocRef.set({
              userId: userInfo.uid, // ID de l'utilisateur
              sessionCount: sessionCount, // Nombre de sessions
              totalTimeWorked: totalTimeWorked - secondsLeft, // Temps total travaillé
              dateStart: dateStartTimestamp, // Assurez-vous que c'est un Timestamp
              createdAt: firestore.FieldValue.serverTimestamp() // Timestamp de la création
            });
      
            console.log('Session enregistrée avec succès pour l\'utilisateur:', userInfo.uid);
          } catch (error) {
            console.error('Erreur lors de la mise à jour de Firestore:', error);
          }
        } else {
          console.log('Aucun utilisateur connecté ou ID utilisateur non disponible.');
        }
      }
      

      //Init date d'aujourd'hui
      const [currentDateTime, setCurrentDateTime] = useState(new Date().toLocaleString());

      //Demande droits
      useEffect(() => {
        requestStoragePermissions();
      }, []);

      useEffect(() => {
        const dateAjd = setInterval(() => {
          setCurrentDateTime(new Date().toLocaleString());
        }, 1000);

        return () => clearInterval(timer);
      }, []);
      const playSound = async () => {
        try {
            // Set audio mode to allow background playback
            await Audio.setAudioModeAsync({
                staysActiveInBackground: true,
            });
            const { sound } = await Audio.Sound.createAsync(require('./Son.mp3'));
            soundRef.current = sound;
            await sound.playAsync();
        } catch (error) {
            console.log("Erreur lors de la lecture du son:", error);
        }
    };




        // Fonction de nettoyage du son lorsque le composant est démonté
        useEffect(() => {
          return () => {
            if (soundRef.current) {
              soundRef.current.unloadAsync();
            }
          };
        }, []);


      // Fonction d'initialisation des notifications
      useEffect(() => {
        registerForPushNotificationsAsync().then(token => token && setExpoPushToken(token));

        // Demander la permission de notification pour le web
        requestNotificationPermission();

        if (Platform.OS === 'android') {
          Notifications.getNotificationChannelsAsync().then(value => setChannels(value ?? []));
        }

        notificationListener.current = Notifications.addNotificationReceivedListener(notification => {
          setNotification(notification);
        });

        responseListener.current = Notifications.addNotificationResponseReceivedListener(response => {
          console.log(response);
        });

        return () => {
          notificationListener.current &&
            Notifications.removeNotificationSubscription(notificationListener.current);
          responseListener.current &&
            Notifications.removeNotificationSubscription(responseListener.current);
        };
      }, []);

    // Fonction pour demander la permission d'accès au stockage
    async function requestStoragePermissions() {
    const { status: readStatus } = await Permissions.askAsync(Permissions.READ_EXTERNAL_STORAGE);
    const { status: writeStatus } = await Permissions.askAsync(Permissions.WRITE_EXTERNAL_STORAGE);
    const { status: manageStatus } = await Permissions.askAsync(Permissions.MANAGE_EXTERNAL_STORAGE);

    // Vérifiez si les permissions sont accordées
    if (readStatus !== 'granted' || writeStatus !== 'granted' || manageStatus !== 'granted') {
      alert('Permissions d\'accès au stockage refusées! Impossible d\'enregistrer des fichiers.');
    }
    }


      // Demander la permission pour les notifications
      async function requestNotificationPermission() {
        if (Platform.OS !== 'web' || ("Notification" in window)) {
          const permission = await Notification.requestPermission();
          if (permission !== "granted") {
            console.warn("Notification permission not granted");
          }
        } else {
          console.warn("This browser does not support notifications.");
        }
      }

        // Afficher les notifications
        async function showNotification(title, body) {
          if (Platform.OS === 'web' && "Notification" in window && Notification.permission === "granted") {
            new Notification(title, {
              body: body,
              icon: imagePause, // Assurez-vous que le chemin est correct
            });
          } else {
            await Notifications.scheduleNotificationAsync({
              content: {
                title,
                body,
                data: { data: 'goes here' },
              },
              trigger: null, // Send immediately
            });
          }
        }

      // Décrémenter le timer
      useEffect(() => {
        let intervalId;
        if (!pause) {
          if (Platform.OS === 'android') {
            intervalId = BackgroundTimer.setInterval(() => {
              setSecondsLeft(prevSeconds => prevSeconds - 1);
            }, 1000);
          } else {
            intervalId = setInterval(() => {
              setSecondsLeft(prevSeconds => prevSeconds - 1);
            }, 1000);
          }
        }

        // Quand le temps est écoulé, changez d'état
        if (secondsLeft === 0) {
          if (enTravail) {
            // Afficher une notification de pause
            showNotification("PAUSE", "Il est temps de faire une pause !");
            setSecondsLeft(TempsPause);
            setEnTravail(false);
            playSound();
            setSessionCount(prevCount => prevCount + 1);
            setTotalTimeWorked(prevTime => prevTime + TempsTravail);
          } else {
            // Afficher une notification de reprise de travail
            showNotification("TRAVAIL", "Reprenez votre travail !");
            setSecondsLeft(TempsTravail);
            setEnTravail(true);
            playSound();
          }
        }

        // Nettoyage de l'intervalle pour éviter les fuites de mémoire
        return () => {
          if (Platform.OS === 'android') {
            BackgroundTimer.clearInterval(intervalId);
          } else {
            clearInterval(intervalId);
          }
        };
      }, [pause, secondsLeft, enTravail]);

      // Calcul du temps restant pour l'affichage
      const minutes = Math.floor(secondsLeft / 60);
      const secondes = secondsLeft % 60;
      const TexteAffiche = enTravail ? "En travail" : "En pause";

      // Gestion du clic sur le bouton pause
      function handlePauseClick() {
        if (!estLancé) {
          // Si c'est la première fois que le timer est lancé, on incrémente le compteur de sessions
          setSessionStart(setSessionStart(new Date()))
          setSessionCount(1);
          setTotalTimeWorked(TempsTravail);
        } else {
        }
        setEstLancé(true);
        setPause(!pause);
        setButtonName(pause ? "Faire une pause dans le timer" : "Lancer le timer");
      }

      // Gestion du clic sur le bouton stop
      function handleStopClick() {
        updateSessionData()
        setSecondsLeft(TempsTravail);
        setEnTravail(true);
        setPause(true);
        setEstLancé(false);
        setButtonName("Lancer le timer");
      }

      // Gestion du clic pour changer de format
      function handleChangeTypeClick() {
        if (TempsTravail === 45*60) {
          setTempsTravail(20*60);
          setTempsPause(5*60);
          setSecondsLeft(20*60);
        } else {
          setTempsTravail(45*60);
          setTempsPause(15*60);
          setSecondsLeft(45*60);
        }

        setButtonName(!pause ? "Faire une pause dans le timer" : "Lancer le timer");
      }

      // Rendu de l'interface
      return showTestPage ? (
        <PageHistorique onRetour={() => setShowTestPage(false)} userId={userInfo ? userInfo.uid : null} />
      ) : (
        <View style={styles.container}>
          <Text style={styles.text}>{TexteAffiche}</Text>
          {pause && <Image source={imagePause} style={styles.image} />}
          <Text style={styles.timer}>
            {minutes}:{secondes < 10 ? `0${secondes}` : secondes}
          </Text>
          <TouchableOpacity style={styles.button} onPress={handlePauseClick}>
            <Text style={styles.buttonText}>{buttonName}</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={handleStopClick}>
            <Text style={styles.buttonText}>Stopper et réinitialiser le timer</Text>
          </TouchableOpacity>
          {!estLancé && (
            <TouchableOpacity style={styles.button} onPress={handleChangeTypeClick}>
              <Text style={styles.buttonText}>Changer de format</Text>
            </TouchableOpacity>
          )}
          {userInfo ? (
            <View>
              <Text>Bienvenue, {userInfo.displayName}</Text>
              <TouchableOpacity style={styles.button} onPress={signOut}>
                <Text style={styles.buttonText}>Se déconnecter</Text>
              </TouchableOpacity>
            </View>
          ) : (
            <TouchableOpacity style={styles.button} onPress={signInWithGoogle}>
              <Text style={styles.buttonText}>Se connecter avec Google</Text>
            </TouchableOpacity>
          )}
    
          {/* Nouveau bouton pour aller à la page historique */}
          <TouchableOpacity style={styles.button} onPress={() => setShowTestPage(true)}>
            <Text style={styles.buttonText}>Historique</Text>
          </TouchableOpacity>
        </View>
      );
    }

    // Fonction principale
    export default function MyApp() {
      return (
        <View style={styles.appContainer}>
          <Timer />
        </View>
      );
    }

    // Styles de l'application
    const styles = StyleSheet.create({
      appContainer: {
        flex: 1,
        justifyContent: 'center',
        alignItems: 'center',
      },
      container: {
        alignItems: 'center',
      },
      text: {
        fontSize: 24,
        marginBottom: 20,
        marginTop: 60,
      },
      timer: {
        fontSize: 48,
        marginBottom: 20,
      },
      button: {
        backgroundColor: '#357',
        padding: 10,
        marginVertical: 5,
        borderRadius: 5,
        justifyContent: 'center',
        alignItems: 'center',
      },
      buttonText: {
        color: '#fff',
        fontSize: 18,
      },
      image: {
        width: 100,
        height: 100,
        marginBottom: 10,
      },
      pageHistoriqueContainer: {
        flex: 1,
        backgroundColor: '#fff',
        paddingTop: 40, // Pour éviter les éléments d'être cachés sous la barre de statut
        paddingHorizontal: 20,
      },
      retourButton: {
        position: 'absolute',
        top: 10,
        left: 10,
        backgroundColor: '#357',
        padding: 10,
        borderRadius: 5,
      },
      scrollView: {
        marginTop: 20,
        paddingHorizontal: 10,
      },
      sessionItem: {
        backgroundColor: '#f0f0f0',
        padding: 15,
        marginBottom: 10,
        borderRadius: 5,
      },
      sessionText: {
        fontSize: 16,
        color: '#333',
      },
      noSessionText: {
        fontSize: 18,
        textAlign: 'center',
        color: '#999',
      },
    });

    // Fonction pour l'enregistrement des notifications
    async function registerForPushNotificationsAsync() {
      let token;

      if (Platform.OS === 'android') {
        await Notifications.setNotificationChannelAsync('default', {
          name: 'default',
          importance: Notifications.AndroidImportance.MAX,
          vibrationPattern: [0, 250, 250, 250],
          lightColor: '#FF231F7C',
        });
      }

      if (Device.isDevice) {
        const { status: existingStatus } = await Notifications.getPermissionsAsync();
        let finalStatus = existingStatus;
        if (existingStatus !== 'granted') {
          const { status } = await Notifications.requestPermissionsAsync();
          finalStatus = status;
        }

        if (finalStatus !== 'granted') {
          alert('Failed to get push token for push notification!');
          return;
        }

        try {
          const projectId =
            Constants?.expoConfig?.extra?.eas?.projectId ?? Constants?.easConfig?.projectId;
          if (!projectId) {
            throw new Error('Project ID not found');
          }
          token = (await Notifications.getExpoPushTokenAsync({ projectId })).data;
          console.log(token);
        } catch (e) {
          token = `${e}`;
        }
      } else {
        alert('Must use physical device for Push Notifications');
      }

      return token;
    }
