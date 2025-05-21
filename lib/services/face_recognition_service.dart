import 'dart:io';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';

class FaceRecognitionService {
  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      minFaceSize: 0.15,
    ),
  );
  final _logger = Logger('FaceRecognitionService');

  final SupabaseClient _client = Supabase.instance.client;
  final String _bucketName = 'faces';

  Future<String?> uploadFaceImage(File imageFile, String userId) async {
    try {
      // Vérifier si un visage est détecté
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await _faceDetector.processImage(inputImage);
      
      if (faces.isEmpty) {
        return null;
      }

      // Stocker l'image dans Supabase Storage
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

      return _client.storage.from(_bucketName).getPublicUrl(filePath);
    } catch (e) {
      print('Error uploading face image: $e');
      return null;
    }
  }

  Future<bool> detectFace(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        _logger.warning('No face detected in image');
        return false;
      }

      if (faces.length > 1) {
        _logger.warning('Multiple faces detected in image');
        return false;
      }

      final face = faces.first;
      
      // Check if face is properly aligned
      if (face.headEulerAngleY != null && face.headEulerAngleY!.abs() > 20) {
        _logger.warning('Face is not properly aligned');
        return false;
      }

      // Check if eyes are open
      if (face.leftEyeOpenProbability != null && 
          face.rightEyeOpenProbability != null) {
        final leftEyeOpen = face.leftEyeOpenProbability! > 0.5;
        final rightEyeOpen = face.rightEyeOpenProbability! > 0.5;
        
        if (!leftEyeOpen || !rightEyeOpen) {
          _logger.warning('Eyes are not open');
          return false;
        }
      }

      return true;
    } catch (e) {
      _logger.severe('Error detecting face', e);
      return false;
    }
  }

  Future<bool> compareFaces(File image1, File image2) async {
    try {
      final inputImage1 = InputImage.fromFile(image1);
      final inputImage2 = InputImage.fromFile(image2);

      final faces1 = await _faceDetector.processImage(inputImage1);
      final faces2 = await _faceDetector.processImage(inputImage2);

      if (faces1.isEmpty || faces2.isEmpty) {
        _logger.warning('No face detected in one or both images');
        return false;
      }

      if (faces1.length > 1 || faces2.length > 1) {
        _logger.warning('Multiple faces detected in one or both images');
        return false;
      }

      final face1 = faces1.first;
      final face2 = faces2.first;

      // Compare face landmarks
      final landmarks1 = face1.landmarks;
      final landmarks2 = face2.landmarks;

      if (landmarks1.isEmpty || landmarks2.isEmpty) {
        _logger.warning('No landmarks detected in one or both faces');
        return false;
      }

      // Simple comparison of face width and height
      final width1 = face1.boundingBox.width;
      final height1 = face1.boundingBox.height;
      final width2 = face2.boundingBox.width;
      final height2 = face2.boundingBox.height;

      final widthRatio = width1 / width2;
      final heightRatio = height1 / height2;

      // Allow for some variation in size
      if (widthRatio < 0.8 || widthRatio > 1.2 || 
          heightRatio < 0.8 || heightRatio > 1.2) {
        _logger.warning('Faces have significantly different sizes');
        return false;
      }

      return true;
    } catch (e) {
      _logger.severe('Error comparing faces', e);
      return false;
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

  void dispose() {
    _faceDetector.close();
  }
} 