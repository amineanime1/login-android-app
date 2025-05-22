import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';
import 'package:image/image.dart' as img;

class FaceRecognitionService {
  final _logger = Logger('FaceRecognitionService');
  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableLandmarks: true,
      enableContours: false,
      enableClassification: false,
      minFaceSize: 0.1,
    ),
  );

  final SupabaseClient _client = Supabase.instance.client;
  final String _bucketName = 'faces';

  Future<String?> uploadFaceImage(File imageFile, String userId) async {
    try {
      _logger.info('Starting face upload process');
      _logger.info('Image path: ${imageFile.path}');
      _logger.info('Image size: ${await imageFile.length()} bytes');

      final inputImage = await _getInputImage(imageFile);
      final faces = await _faceDetector.processImage(inputImage);
      
      if (faces.isEmpty) {
        _logger.warning('No face detected in image');
        return null;
      }

      _logger.info('Face detected: ${faces.first.boundingBox}');

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
      _logger.severe('Error uploading face image', e);
      return null;
    }
  }

  Future<List<Face>> detectFaces(File imageFile) async {
    try {
      _logger.info('Detecting faces in image: ${imageFile.path}');
      _logger.info('Image size: ${await imageFile.length()} bytes');
      
      final inputImage = await _getInputImage(imageFile);
      final faces = await _faceDetector.processImage(inputImage);
      
      _logger.info('Detected ${faces.length} faces');
      
      if (faces.isNotEmpty) {
        final face = faces.first;
        _logger.info('First face details:');
        _logger.info('- Bounding box: ${face.boundingBox}');
        _logger.info('- Head rotation: ${face.headEulerAngleY}°');
        _logger.info('- Landmarks: ${face.landmarks.length} points');
      } else {
        _logger.warning('No faces detected in image');
      }
      
      return faces;
    } catch (e) {
      _logger.severe('Error detecting faces', e);
      return [];
    }
  }

  Future<InputImage> _getInputImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Log image details
      _logger.info('Image dimensions: ${image.width}x${image.height}');
      
      // Create input image with proper rotation
      final inputImage = InputImage.fromFilePath(imageFile.path);
      return inputImage;
    } catch (e) {
      _logger.severe('Error preparing input image', e);
      rethrow;
    }
  }

  double _comparePoints(FaceLandmark point1, FaceLandmark point2, Rect box1, Rect box2) {
    // Normalize coordinates relative to face bounding box
    final normalizedX1 = (point1.position.x - box1.left) / box1.width;
    final normalizedY1 = (point1.position.y - box1.top) / box1.height;
    final normalizedX2 = (point2.position.x - box2.left) / box2.width;
    final normalizedY2 = (point2.position.y - box2.top) / box2.height;

    // Calculate distance between normalized points
    final dx = normalizedX1 - normalizedX2;
    final dy = normalizedY1 - normalizedY2;
    final distance = (dx * dx + dy * dy).abs();
    
    // Convert distance to similarity score (0 to 1)
    final similarity = 1 / (1 + (distance * 20));
    _logger.info('Point comparison: normalized distance=$distance, similarity=$similarity');
    return similarity;
  }

  Future<bool> compareFaces(File image1, File image2) async {
    try {
      _logger.info('Starting face comparison');
      _logger.info('Image 1: ${image1.path}');
      _logger.info('Image 2: ${image2.path}');

      final faces1 = await detectFaces(image1);
      final faces2 = await detectFaces(image2);

      if (faces1.isEmpty || faces2.isEmpty) {
        _logger.warning('No faces detected in one or both images');
        return false;
      }

      final face1 = faces1.first;
      final face2 = faces2.first;

      // Compare face landmarks
      final landmarks1 = face1.landmarks;
      final landmarks2 = face2.landmarks;

      // Compare face features
      double similarity = 0;
      int featureCount = 0;

      // Compare eye positions
      if (landmarks1[FaceLandmarkType.leftEye] != null && 
          landmarks2[FaceLandmarkType.leftEye] != null) {
        final leftEyeSimilarity = _comparePoints(
          landmarks1[FaceLandmarkType.leftEye]!,
          landmarks2[FaceLandmarkType.leftEye]!,
          face1.boundingBox,
          face2.boundingBox,
        );
        similarity += leftEyeSimilarity;
        featureCount++;
      }

      if (landmarks1[FaceLandmarkType.rightEye] != null && 
          landmarks2[FaceLandmarkType.rightEye] != null) {
        final rightEyeSimilarity = _comparePoints(
          landmarks1[FaceLandmarkType.rightEye]!,
          landmarks2[FaceLandmarkType.rightEye]!,
          face1.boundingBox,
          face2.boundingBox,
        );
        similarity += rightEyeSimilarity;
        featureCount++;
      }

      // Compare nose position
      if (landmarks1[FaceLandmarkType.noseBase] != null && 
          landmarks2[FaceLandmarkType.noseBase] != null) {
        final noseSimilarity = _comparePoints(
          landmarks1[FaceLandmarkType.noseBase]!,
          landmarks2[FaceLandmarkType.noseBase]!,
          face1.boundingBox,
          face2.boundingBox,
        );
        similarity += noseSimilarity;
        featureCount++;
      }

      // Calculate average similarity
      final averageSimilarity = featureCount > 0 ? similarity / featureCount : 0;
      _logger.info('Average face similarity: $averageSimilarity');

      // More lenient threshold for matching
      final isMatch = averageSimilarity > 0.6;
      
      _logger.info('Faces match: $isMatch (threshold: 0.6)');
      return isMatch;
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
      _logger.severe('Error downloading face image', e);
      return null;
    }
  }

  void dispose() {
    _faceDetector.close();
  }
} 