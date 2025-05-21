import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tp/providers/auth_provider.dart';
import 'package:camera/camera.dart';
import 'package:logging/logging.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';

class FaceCaptureScreen extends StatefulWidget {
  final String email;
  final String password;
  final String username;
  final bool isLogin;

  const FaceCaptureScreen({
    super.key,
    required this.email,
    required this.password,
    required this.username,
    this.isLogin = false,
  });

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _controller;
  bool _isLoading = false;
  bool _isCameraInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  final _logger = Logger('FaceCaptureScreen');
  final _audioPlayer = AudioPlayer();
  bool _isCapturing = false;
  final _picker = ImagePicker();
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    if (widget.isLogin) {
      // Delay camera initialization to ensure widget is properly mounted
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeCamera();
      });
    }
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

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image != null && mounted) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _logger.severe('Error picking image', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
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
      if (widget.isLogin) {
        if (_controller == null || !_controller!.value.isInitialized) {
          throw Exception('Camera not initialized');
        }

        final image = await _controller!.takePicture();
        final imageFile = File(image.path);

        if (!mounted) return;

        final success = await context.read<AuthProvider>().signInWithFace(imageFile);
        await _playSound(success);

        if (!mounted) return;

        if (success) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Échec de la reconnaissance faciale')),
          );
        }
      } else {
        _logger.info('Starting registration process');
        _logger.info('Email: ${widget.email}');
        _logger.info('Username: ${widget.username}');
        
        if (_selectedImage == null) {
          _logger.warning('No image selected for registration');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Veuillez sélectionner une photo')),
          );
          return;
        }

        _logger.info('Selected image path: ${_selectedImage!.path}');
        _logger.info('Image exists: ${await _selectedImage!.exists()}');
        _logger.info('Image size: ${await _selectedImage!.length()} bytes');

        try {
          _logger.info('Attempting to sign up with email and password');
          final success = await context.read<AuthProvider>().signUpWithEmailAndPassword(
            email: widget.email,
            password: widget.password,
            username: widget.username,
            faceImage: _selectedImage!,
          );

          _logger.info('Sign up result: $success');

          try {
            await _playSound(success);
          } catch (e) {
            _logger.warning('Failed to play sound: $e');
            // Continue execution even if sound fails
          }

          if (!mounted) return;

          if (success) {
            _logger.info('Registration successful, navigating to home');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Inscription réussie !')),
            );
            Navigator.of(context).pushReplacementNamed('/home');
          } else {
            _logger.severe('Registration failed without specific error');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Erreur lors de l\'inscription. Veuillez réessayer.')),
            );
          }
        } catch (e) {
          _logger.severe('Error during registration process', e);
          if (!mounted) return;
          
          String errorMessage = 'Erreur lors de l\'inscription';
          if (e.toString().contains('over_email_send_rate_limit')) {
            errorMessage = 'Veuillez attendre quelques instants avant de réessayer.';
          } else if (e.toString().contains('Bucket not found') || 
                    e.toString().contains('Storage access error')) {
            errorMessage = 'Erreur de configuration. Veuillez contacter le support.';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      _logger.severe('Error during submission', e, stackTrace);
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
        title: Text(widget.isLogin ? 'Reconnaissance Faciale' : 'Capture Photo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.isLogin) ...[
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
            ] else ...[
              if (_selectedImage != null)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo, size: 50),
                  ),
                ),
            ],
            const SizedBox(height: 20),
            if (widget.isLogin)
              ElevatedButton.icon(
                onPressed: _isLoading || _hasError ? null : _submit,
                icon: const Icon(Icons.camera_alt),
                label: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Vérifier le visage'),
              )
            else
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Sélectionner une photo'),
                  ),
                  const SizedBox(height: 10),
                  if (_selectedImage != null)
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: const Icon(Icons.check),
                      label: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Valider'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
} 