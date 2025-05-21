import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tp/services/face_recognition_service.dart';
import 'package:tp/services/sound_service.dart';
import 'package:tp/services/supabase_service.dart';
import 'package:logging/logging.dart';

class AuthProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  final FaceRecognitionService _faceService = FaceRecognitionService();
  final SoundService _soundService = SoundService();
  final _logger = Logger('AuthProvider');
  
  User? get user => _supabaseService.currentUser;
  String? _faceImageUrl;

  AuthProvider() {
    _supabaseService.authStateChanges.listen((event) {
      notifyListeners();
    });
  }

  Future<bool> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String username,
    required File faceImage,
  }) async {
    try {
      final response = await _supabaseService.signUp(
        email: email,
        password: password,
        username: username,
      );

      if (response.user != null) {
        // Upload face image
        _faceImageUrl = await _supabaseService.uploadFaceImage(
          faceImage,
          response.user!.id,
        );
        
        if (_faceImageUrl != null) {
          await _soundService.playSuccessSound();
          return true;
        }
      }
      return false;
    } catch (e) {
      _logger.severe('Error during sign up', e);
      await _soundService.playFailureSound();
      return false;
    }
  }

  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      final response = await _supabaseService.signIn(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        await _soundService.playSuccessSound();
        return true;
      }
      return false;
    } catch (e) {
      _logger.severe('Error during sign in', e);
      await _soundService.playFailureSound();
      return false;
    }
  }

  Future<bool> signInWithFace(File currentFaceImage) async {
    try {
      if (_faceImageUrl == null) {
        await _soundService.playFailureSound();
        return false;
      }

      final storedImage = await _supabaseService.downloadFaceImage(_faceImageUrl!);
      if (storedImage == null) {
        await _soundService.playFailureSound();
        return false;
      }

      final isMatch = await _faceService.compareFaces(currentFaceImage, storedImage);
      
      if (isMatch) {
        await _soundService.playSuccessSound();
        return true;
      } else {
        await _soundService.playFailureSound();
        return false;
      }
    } catch (e) {
      _logger.severe('Error during face recognition', e);
      await _soundService.playFailureSound();
      return false;
    }
  }

  Future<void> signOut() async {
    await _supabaseService.signOut();
    _faceImageUrl = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _soundService.dispose();
    super.dispose();
  }
} 