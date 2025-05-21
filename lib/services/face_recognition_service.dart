import 'dart:io';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class FaceRecognitionService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      minFaceSize: 0.15,
    ),
  );

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

  Future<bool> compareFaces(File currentImage, File storedImage) async {
    try {
      // Détecter les visages dans les deux images
      final currentFaces = await _faceDetector.processImage(
        InputImage.fromFile(currentImage)
      );
      final storedFaces = await _faceDetector.processImage(
        InputImage.fromFile(storedImage)
      );

      if (currentFaces.isEmpty || storedFaces.isEmpty) {
        return false;
      }

      // Comparaison basique des visages
      // Pour un projet étudiant, nous utilisons une comparaison simple
      // basée sur la taille et la position du visage
      final currentFace = currentFaces.first;
      final storedFace = storedFaces.first;

      // Comparer la taille relative du visage
      final sizeDiff = (currentFace.boundingBox.width - storedFace.boundingBox.width).abs() /
          storedFace.boundingBox.width;

      // Comparer la position relative du visage
      final positionDiff = (currentFace.boundingBox.top - storedFace.boundingBox.top).abs() /
          storedFace.boundingBox.height;

      // Seuil de tolérance (à ajuster selon vos besoins)
      return sizeDiff < 0.2 && positionDiff < 0.2;
    } catch (e) {
      print('Error comparing faces: $e');
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
} 