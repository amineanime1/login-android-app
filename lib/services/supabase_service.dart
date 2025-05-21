import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  final String _bucketName = 'faces';

  // Authentification
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );
      return response;
    } catch (e) {
      print('Error during sign up: $e');
      rethrow;
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      print('Error during sign in: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      print('Error during sign out: $e');
      rethrow;
    }
  }

  // Stockage des photos
  Future<String?> uploadFaceImage(File imageFile, String userId) async {
    try {
      final fileName = 'face_$userId${path.extension(imageFile.path)}';
      final filePath = '$userId/$fileName';

      await _client.storage.from(_bucketName).upload(
        filePath,
        imageFile,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: true,
        ),
      );

      final imageUrl = _client.storage
          .from(_bucketName)
          .getPublicUrl(filePath);

      return imageUrl;
    } catch (e) {
      print('Error uploading face image: $e');
      return null;
    }
  }

  Future<File?> downloadFaceImage(String imageUrl) async {
    try {
      final fileName = path.basename(imageUrl);
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/$fileName');

      final response = await _client.storage
          .from(_bucketName)
          .download(fileName);

      await file.writeAsBytes(response);
      return file;
    } catch (e) {
      print('Error downloading face image: $e');
      return null;
    }
  }

  // Getters
  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
} 