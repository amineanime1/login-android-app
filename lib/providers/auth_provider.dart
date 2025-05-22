import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tp/services/face_recognition_service.dart';
import 'package:tp/services/sound_service.dart';
import 'package:tp/services/supabase_service.dart';
import 'package:logging/logging.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabaseService;
  final FaceRecognitionService _faceService = FaceRecognitionService();
  final SoundService _soundService = SoundService();
  final _logger = Logger('AuthProvider');
  
  User? _user;
  bool _isLoading = false;
  String? _error;

  AuthProvider(this._supabaseService) {
    _initialize();
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  String? _faceImageUrl;

  void _initialize() {
    _supabaseService.authStateChanges.listen((event) {
      _user = event.session?.user;
      notifyListeners();
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    required File faceImage,
  }) async {
    try {
      _logger.info('Starting sign up process');
      await _supabaseService.signUp(
        email: email,
        password: password,
        username: username,
        faceImage: faceImage,
      );
    } catch (e) {
      _logger.severe('Error during sign up', e);
      rethrow;
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _supabaseService.signIn(
        email: email,
        password: password,
      );

      _logger.info('User signed in successfully');
    } catch (e) {
      _error = e.toString();
      _logger.severe('Error during sign in', e);
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String username,
    required File faceImage,
  }) async {
    try {
      _logger.info('Starting sign up with email and password');
      final response = await _supabaseService.signUp(
        email: email,
        password: password,
        username: username,
        faceImage: faceImage,
      );
      _user = response.user;
      notifyListeners();
      return true;
    } catch (e) {
      _logger.severe('Error during sign up', e);
      rethrow;
    }
  }

  Future<bool> signInWithFace(File image, String email) async {
    try {
      _logger.info('Starting face authentication for email: $email');
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      // Get face data from user_faces table
      final faceData = await _supabaseService
          .from('user_faces')
          .select()
          .eq('email', email)
          .single();
      
      if (faceData == null) {
        _logger.warning('No face data found for email: $email');
        return false;
      }

      final storedFaceUrl = faceData['face_image_url'] as String;
      _logger.info('Found stored face URL: $storedFaceUrl');

      // Download stored face image
      final storedFaceBytes = await _supabaseService.downloadFaceImage(storedFaceUrl);
      
      if (storedFaceBytes == null) {
        _logger.warning('Failed to download stored face image');
        return false;
      }

      // Create temporary file for stored face
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_face.jpg');
      await tempFile.writeAsBytes(storedFaceBytes);

      // Compare faces
      final facesMatch = await _faceService.compareFaces(image, tempFile);
      _logger.info('Face similarity: ${facesMatch ? 1.0 : 0.0}');

      // Clean up temporary file
      await tempFile.delete();

      if (facesMatch) {
        try {
          // Use JWT authentication
          await _supabaseService.signInWithFaceToken(email);
          _logger.info('Face authentication successful');
          return true;
        } catch (e) {
          _logger.severe('Error during face authentication', e);
          return false;
        }
      }

      return false;
    } catch (e) {
      _error = e.toString();
      _logger.severe('Error during face authentication', e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<double> _compareImages(File image1, Uint8List image2Bytes) async {
    try {
      // Create a temporary file for the second image
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_face.jpg');
      await tempFile.writeAsBytes(image2Bytes);

      // Use the face recognition service to compare faces
      final isMatch = await _faceService.compareFaces(image1, tempFile);
      
      // Clean up the temporary file
      await tempFile.delete();

      return isMatch ? 1.0 : 0.0;
    } catch (e) {
      _logger.severe('Error comparing images', e);
      return 0;
    }
  }

  Future<bool> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _supabaseService.signIn(
        email: email,
        password: password,
      );

      _logger.info('User signed in successfully');
      return response.user != null;
    } catch (e) {
      _error = e.toString();
      _logger.severe('Error during sign in', e);
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _supabaseService.signOut();
      _user = null;

      _logger.info('User signed out successfully');
    } catch (e) {
      _error = e.toString();
      _logger.severe('Error during sign out', e);
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _soundService.dispose();
    super.dispose();
  }
} 