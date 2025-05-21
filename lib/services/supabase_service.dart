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

      if (response.user == null) {
        throw Exception('Failed to create user account');
      }

      return response;
    } catch (e) {
      if (e is AuthException) {
        if (e.message.contains('over_email_send_rate_limit')) {
          throw Exception('Please wait a moment before trying again. This is a security measure.');
        }
      }
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
      // Check if bucket exists and create it if it doesn't
      try {
        await _client.storage.getBucket(_bucketName);
      } catch (e) {
        print('Bucket not found, attempting to create it');
        try {
          await _client.storage.createBucket(_bucketName);
          print('Bucket created successfully');
        } catch (createError) {
          print('Error creating bucket: $createError');
          throw Exception('Failed to create storage bucket. Please contact support.');
        }
      }

      final fileName = 'face_$userId${path.extension(imageFile.path)}';
      final filePath = '$userId/$fileName';

      // Upload the image to storage
      try {
        await _client.storage.from(_bucketName).upload(
          filePath,
          imageFile,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: true,
          ),
        );
      } catch (e) {
        print('Error during upload: $e');
        if (e.toString().contains('violates row-level security policy')) {
          throw Exception('Storage access error. Please contact support.');
        }
        rethrow;
      }

      // Get the public URL
      final imageUrl = _client.storage
          .from(_bucketName)
          .getPublicUrl(filePath);

      // Store metadata in user_faces table
      try {
        await _client.from('user_faces').upsert({
          'user_id': userId,
          'face_image_url': imageUrl,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        print('Error storing face metadata: $e');
        // Continue even if metadata storage fails
      }

      return imageUrl;
    } catch (e) {
      print('Error uploading face image: $e');
      rethrow;
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