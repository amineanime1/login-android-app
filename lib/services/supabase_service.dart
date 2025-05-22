import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;
  final _logger = Logger('SupabaseService');
  final String _bucketName = 'faces';

  SupabaseQueryBuilder from(String table) {
    return _supabase.from(table);
  }

  // Authentification
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
    required File faceImage,
  }) async {
    try {
      _logger.info('Starting sign up process for email: $email');
      
      // 1. Inscription normale avec Supabase Auth
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );

      if (authResponse.user == null) {
        _logger.severe('User creation failed');
        throw Exception('Failed to create user');
      }

      _logger.info('User created successfully, storing plain password');

      // 2. Stocker le mot de passe en clair dans notre table
      await _supabase
          .from('user_passwords')
          .insert({
            'user_id': authResponse.user!.id,
            'email': email,
            'password': password,
          });

      // 3. Upload de l'image du visage
      final imageUrl = await uploadFaceImage(faceImage, authResponse.user!.id);
      if (imageUrl == null) {
        _logger.severe('Failed to upload face image');
        throw Exception('Failed to upload face image');
      }

      // 4. Insérer dans la table users_faces
      await _supabase
          .from('user_faces')
          .insert({
            'user_id': authResponse.user!.id,
            'email': email,
            'face_image_url': imageUrl,
          });

      _logger.info('Sign up process completed successfully');
      return authResponse;
    } catch (e) {
      _logger.severe('Error during sign up', e);
      rethrow;
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      _logger.severe('Error during sign in', e);
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      _logger.severe('Error during sign out', e);
      rethrow;
    }
  }

  Future<AuthResponse> signInWithFaceToken(String email) async {
    try {
      _logger.info('Starting face token authentication for email: $email');
      
      // Récupérer le mot de passe en clair depuis notre table personnalisée
      final response = await _supabase
          .from('user_passwords')
          .select('password')
          .eq('email', email)
          .single();

      if (response == null) {
        _logger.severe('User not found');
        throw Exception('User not found');
      }

      _logger.info('User found, attempting sign in');

      // Se connecter avec email/mot de passe
      final authResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: response['password'],
      );

      _logger.info('Authentication response received');
      return authResponse;
    } catch (e) {
      _logger.severe('Error during face token authentication', e);
      if (e is AuthException) {
        _logger.severe('Auth error details: ${e.message}');
      }
      rethrow;
    }
  }

  // Stockage des photos
  Future<String?> uploadFaceImage(File image, String userId) async {
    try {
      final fileName = 'face_$userId.jpg';
      final response = await _supabase.storage
          .from('faces')
          .upload(fileName, image);

      if (response.isEmpty) {
        _logger.warning('Failed to upload face image');
        return null;
      }

      final imageUrl = _supabase.storage
          .from('faces')
          .getPublicUrl(fileName);

      return imageUrl;
    } catch (e) {
      _logger.severe('Error uploading face image', e);
      return null;
    }
  }

  Future<Uint8List?> downloadFaceImage(String imageUrl) async {
    try {
      // Extract the file path from the URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      final filePath = pathSegments.sublist(pathSegments.indexOf('faces') + 1).join('/');
      
      _logger.info('Downloading face image from path: $filePath');
      
      final response = await _supabase.storage
          .from(_bucketName)
          .download(filePath);

      return response;
    } catch (e) {
      _logger.severe('Error downloading face image', e);
      return null;
    }
  }

  // Getters
  User? get currentUser => _supabase.auth.currentUser;
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
} 