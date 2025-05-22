import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tp/providers/auth_provider.dart';
import 'package:camera/camera.dart';
import 'package:logging/logging.dart';
import 'package:audioplayers/audioplayers.dart';

class FaceLoginScreen extends StatefulWidget {
  final String email;

  const FaceLoginScreen({
    super.key,
    required this.email,
  });

  @override
  State<FaceLoginScreen> createState() => _FaceLoginScreenState();
}

class _FaceLoginScreenState extends State<FaceLoginScreen> {
  CameraController? _controller;
  bool _isLoading = false;
  bool _isCameraInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  final _logger = Logger('FaceLoginScreen');
  final _audioPlayer = AudioPlayer();
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final cameras = await availableCameras();
      _logger.info('Available cameras: ${cameras.length}');
      
      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      
      _logger.info('Using camera: ${frontCamera.name}');

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      
      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isCameraInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      _logger.severe('Error initializing camera', e);
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error initializing camera: $e';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: $e')),
        );
      }
    }
  }

  Future<void> _playSound(bool success) async {
    try {
      final soundFile = success ? 'sounds/success.mp3' : 'sounds/error.mp3';
      _logger.info('Attempting to play sound: $soundFile');
      
      try {
        if (success) {
          await _audioPlayer.play(AssetSource('sounds/success.mp3'));
        } else {
          await _audioPlayer.play(AssetSource('sounds/error.mp3'));
        }
        _logger.info('Sound played successfully');
      } catch (e) {
        _logger.warning('Failed to play sound: $e');
        // Continue execution even if sound fails
      }
    } catch (e, stackTrace) {
      _logger.warning('Error playing sound: $e', e, stackTrace);
      // Don't rethrow the error as sound is not critical
    }
  }

  Future<void> _submit() async {
    if (_isCapturing) return;

    setState(() {
      _isLoading = true;
      _isCapturing = true;
    });

    try {
      if (_controller == null || !_controller!.value.isInitialized) {
        throw Exception('Camera not initialized');
      }

      final image = await _controller!.takePicture();
      final imageFile = File(image.path);

      if (!mounted) return;

      final success = await context.read<AuthProvider>().signInWithFace(
        imageFile,
        widget.email,
      );
      await _playSound(success);

      if (!mounted) return;

      if (success) {
        if (!mounted) return;
        try {
          await Navigator.of(context).pushReplacementNamed('/home');
        } catch (e) {
          _logger.severe('Navigation error', e);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur de navigation. Veuillez réessayer.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Échec de la reconnaissance faciale')),
        );
      }
    } catch (e) {
      _logger.severe('Error during face verification', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCapturing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reconnaissance Faciale'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initialisation de la caméra...'),
                ],
              )
            else if (_hasError)
              Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(_errorMessage ?? 'Unknown error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initializeCamera,
                    child: const Text('Réessayer'),
                  ),
                ],
              )
            else if (_controller != null && _controller!.value.isInitialized)
              Expanded(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: CameraPreview(_controller!),
                ),
              )
            else
              const Text('Erreur: Caméra non initialisée'),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isLoading || _hasError ? null : _submit,
              icon: const Icon(Icons.camera_alt),
              label: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Vérifier le visage'),
            ),
          ],
        ),
      ),
    );
  }
} 