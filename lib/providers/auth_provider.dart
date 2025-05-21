import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tp/services/face_recognition_service.dart';
import 'package:tp/services/sound_service.dart';
import 'package:tp/services/supabase_service.dart';
import 'package:logging/logging.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';

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
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _supabaseService.signUp(
        email: email,
        password: password,
        username: username,
      );

      _logger.info('User signed up successfully');
    } catch (e) {
      _error = e.toString();
      _logger.severe('Error during sign up', e);
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
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
      _logger.info('Starting sign up process');
      final response = await _supabaseService.signUp(
        email: email,
        password: password,
        username: username,
      );

      if (response.user == null) {
        _logger.severe('Sign up failed: No user returned');
        return false;
      }

      _logger.info('User created, uploading face image');
      final imageUrl = await _supabaseService.uploadFaceImage(
        faceImage,
        response.user!.id,
      );

      if (imageUrl == null) {
        _logger.severe('Failed to upload face image');
        return false;
      }

      // Store face data in user_faces table
      final faceData = {
        'user_id': response.user!.id,
        'email': email,
        'face_image_url': imageUrl,
        'created_at': DateTime.now().toIso8601String(),
        'face_auth_token': response.user!.id, // Use user ID as face auth token
      };

      await _supabaseService.from('user_faces').insert(faceData);

      _logger.info('Sign up completed successfully');
      return true;
    } catch (e) {
      _logger.severe('Error during sign up', e);
      rethrow;
    }
  }

  Future<bool> signInWithFace(File image, String email) async {
    try {
      _logger.info('Starting face authentication for email: $email');
      
      // Get the stored face image for this email
      final response = await _supabaseService
          .from('user_faces')
          .select()
          .eq('email', email)
          .single();
      
      if (response == null) {
        _logger.warning('No face data found for email: $email');
        return false;
      }

      final storedFaceUrl = response['face_image_url'] as String;
      _logger.info('Found stored face URL: $storedFaceUrl');

      // Download the stored face image
      final storedFaceBytes = await _supabaseService.downloadFaceImage(storedFaceUrl);
      
      if (storedFaceBytes == null) {
        _logger.warning('Failed to download stored face image');
        return false;
      }

      // Compare the images
      final similarity = await _compareImages(image, storedFaceBytes);
      _logger.info('Face similarity: $similarity');

      if (similarity >= 0.7) {
        // Sign in the user with their face auth token
        final authResponse = await _supabaseService.signIn(
          email: email,
          password: response['face_auth_token'], // Use the stored face auth token
        );
        
        if (authResponse.user != null) {
          _user = authResponse.user;
          notifyListeners();
          return true;
        }
      }

      return false;
    } catch (e) {
      _logger.severe('Error during face authentication', e);
      rethrow;
    }
  }

  Future<double> _compareImages(File image1, Uint8List image2Bytes) async {
    try {
      // Read the images
      final bytes1 = await image1.readAsBytes();
      
      final img1 = img.decodeImage(bytes1);
      final img2 = img.decodeImage(image2Bytes);

      if (img1 == null || img2 == null) {
        throw Exception('Failed to decode images');
      }

      // Resize images to same dimensions for comparison
      final resized1 = img.copyResize(img1, width: 100, height: 100);
      final resized2 = img.copyResize(img2, width: 100, height: 100);

      // Convert to grayscale
      final gray1 = img.grayscale(resized1);
      final gray2 = img.grayscale(resized2);

      // Calculate similarity using pixel-by-pixel comparison
      double totalDiff = 0;
      int totalPixels = 0;

      for (var y = 0; y < gray1.height; y++) {
        for (var x = 0; x < gray1.width; x++) {
          final pixel1 = gray1.getPixel(x, y);
          final pixel2 = gray2.getPixel(x, y);
          
          // Calculate difference in grayscale values
          final diff = (img.getLuminance(pixel1) - img.getLuminance(pixel2)).abs();
          totalDiff += diff;
          totalPixels++;
        }
      }

      // Calculate similarity score (0 to 1, where 1 is identical)
      final avgDiff = totalDiff / totalPixels;
      final similarity = 1 - (avgDiff / 255);
      
      return similarity;
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