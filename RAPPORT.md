# Rapport du Projet : Application Flutter avec Reconnaissance Faciale

## Table des matières
1. [Vue d'ensemble](#vue-densemble)
2. [Configuration Supabase](#configuration-supabase)
3. [Structure du Projet](#structure-du-projet)
4. [Packages Utilisés](#packages-utilisés)
5. [Screens et Services](#screens-et-services)
6. [Guide d'Utilisation](#guide-dutilisation)
7. [Configuration des Permissions](#configuration-des-permissions)

## Vue d'ensemble

Cette application Flutter implémente un système d'authentification double :
- Authentification classique par email/mot de passe
- Authentification par reconnaissance faciale

L'application utilise Supabase pour :
- L'authentification (Supabase Auth)
- Le stockage des photos (Supabase Storage)
- La gestion des utilisateurs (Supabase Database)

## Configuration Supabase

1. Créer un projet Supabase sur [supabase.com](https://supabase.com)
2. Obtenir les informations de configuration :
   - URL du projet
   - Clé anon/public
   - Clé service_role (garder secrète)

3. Configurer les politiques de sécurité Supabase Storage :
```sql
-- Politique pour le stockage des photos
CREATE POLICY "Users can upload their own face images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'faces' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Politique pour la lecture des photos
CREATE POLICY "Users can view their own face images"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'faces' AND
  auth.uid()::text = (storage.foldername(name))[1]
);
```

4. Créer un bucket 'faces' dans Supabase Storage

## Structure du Projet

```
lib/
├── main.dart
├── config/
│   └── supabase_config.dart
├── providers/
│   └── auth_provider.dart
├── screens/
│   ├── login_screen.dart
│   ├── face_capture_screen.dart
│   ├── face_login_screen.dart
│   └── home_screen.dart
├── services/
│   ├── face_recognition_service.dart
│   ├── supabase_service.dart
│   └── sound_service.dart
└── assets/
    └── sounds/
        ├── success.mp3
        └── failure.mp3
```

## Packages Utilisés

### Dépendances principales
```yaml
dependencies:
  supabase_flutter: ^2.3.4    # Supabase SDK
  image_picker: ^1.0.7        # Capture photo
  google_mlkit_face_detection: ^0.9.0  # Détection faciale
  image: ^4.1.3              # Traitement d'images
  audioplayers: ^5.2.1       # Sons de feedback
  path: ^1.8.3               # Gestion des chemins
  provider: ^6.1.1           # Gestion d'état
```

## Screens et Services

### 1. LoginScreen (`lib/screens/login_screen.dart`)
- **Fonctionnalités** :
  - Formulaire de connexion/inscription
  - Bascule entre connexion et inscription
  - Option de connexion faciale
- **Packages utilisés** :
  - `provider` pour l'état
  - `supabase_flutter` pour l'authentification

### 2. FaceCaptureScreen (`lib/screens/face_capture_screen.dart`)
- **Fonctionnalités** :
  - Capture de photo avec la caméra frontale
  - Prévisualisation de l'image
  - Validation et envoi pour l'inscription
- **Packages utilisés** :
  - `image_picker` pour la caméra
  - `provider` pour l'état

### 3. FaceLoginScreen (`lib/screens/face_login_screen.dart`)
- **Fonctionnalités** :
  - Capture de photo pour la reconnaissance
  - Vérification faciale automatique
  - Retour à la connexion classique
- **Packages utilisés** :
  - `image_picker` pour la caméra
  - `provider` pour l'état

### 4. Services

#### SupabaseService (`lib/services/supabase_service.dart`)
- **Fonctionnalités** :
  - Gestion de l'authentification Supabase
  - Gestion du stockage des photos
  - Liaison photos-utilisateurs
- **Packages utilisés** :
  - `supabase_flutter`

#### FaceRecognitionService (`lib/services/face_recognition_service.dart`)
- **Fonctionnalités** :
  - Détection de visages
  - Comparaison de visages
  - Gestion du stockage Supabase
- **Packages utilisés** :
  - `google_mlkit_face_detection`
  - `image`

#### SoundService (`lib/services/sound_service.dart`)
- **Fonctionnalités** :
  - Lecture des sons de succès/échec
- **Packages utilisés** :
  - `audioplayers`

## Guide d'Utilisation

### Inscription
1. Sur l'écran de connexion, cliquer sur "Pas de compte ? S'inscrire"
2. Remplir username, email et mot de passe
3. Cliquer sur "S'inscrire"
4. Prendre une photo avec la caméra frontale
5. Valider l'inscription

### Connexion
#### Méthode 1 : Email/Mot de passe
1. Entrer email et mot de passe
2. Cliquer sur "Se connecter"

#### Méthode 2 : Reconnaissance Faciale
1. Cliquer sur "Connexion Faciale"
2. Prendre une photo avec la caméra frontale
3. Attendre la vérification

## Configuration des Permissions

### Android
Dans `android/app/src/main/AndroidManifest.xml` :
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS
Dans `ios/Runner/Info.plist` :
```xml
<key>NSCameraUsageDescription</key>
<string>Cette application nécessite l'accès à la caméra pour la reconnaissance faciale</string>
<key>NSMicrophoneUsageDescription</key>
<string>Cette application nécessite l'accès au microphone pour les sons de feedback</string>
```

## Notes Importantes

1. **Sons** : Placer les fichiers audio dans `assets/sounds/` :
   - `success.mp3` : Son court pour les succès
   - `failure.mp3` : Son court pour les échecs

2. **Sécurité** :
   - Les photos sont stockées de manière sécurisée dans Supabase Storage
   - Chaque utilisateur ne peut accéder qu'à ses propres photos
   - Les photos sont nommées avec l'ID de l'utilisateur

3. **Performance** :
   - La reconnaissance faciale est basique (taille et position)
   - Adaptée pour un projet étudiant
   - Pour une application en production, envisager une solution plus robuste

4. **Migration Firebase vers Supabase** :
   - Remplacer les appels Firebase Auth par Supabase Auth
   - Migrer les données utilisateurs vers Supabase
   - Adapter les règles de sécurité pour Supabase
   - Mettre à jour les services pour utiliser l'API Supabase 