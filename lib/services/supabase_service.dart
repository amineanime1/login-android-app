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
  }) async {
    try {
      return await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );
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
      final response = await _supabase.storage
          .from('faces')
          .download(imageUrl);

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