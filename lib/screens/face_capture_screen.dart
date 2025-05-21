import 'dart:io';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tp/providers/auth_provider.dart';
import 'package:camera/camera.dart';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  final _logger = Logger('FaceCaptureScreen');
  html.VideoElement? _videoElement;
  html.CanvasElement? _canvasElement;
  final _videoContainerKey = GlobalKey();
  final _audioPlayer = AudioPlayer();
  bool _isCapturing = false;
  final _picker = ImagePicker();
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    if (widget.isLogin) {
      if (kIsWeb) {
        _initializeWebCamera();
      } else {
        _initializeCamera();
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image != null) {
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
      if (success) {
        await _audioPlayer.play(AssetSource('sounds/success.mp3'));
      } else {
        await _audioPlayer.play(AssetSource('sounds/error.mp3'));
      }
    } catch (e) {
      _logger.warning('Error playing sound: $e');
    }
  }

  Future<void> _initializeWebCamera() async {
    try {
      final stream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720}
        }
      });

      if (stream != null) {
        _videoElement = html.VideoElement()
          ..srcObject = stream
          ..autoplay = true
          ..setAttribute('playsinline', 'true')
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover';

        _canvasElement = html.CanvasElement()
          ..width = 1280
          ..height = 720;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_videoContainerKey.currentContext != null) {
            final container = _videoContainerKey.currentContext!.findRenderObject() as html.HtmlElement;
            container.append(_videoElement!);
          }
        });

        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      _logger.severe('Error initializing web camera', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: $e')),
        );
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      _logger.info('Available cameras: ${cameras.length}');
      
      if (cameras.isEmpty) {
        _logger.severe('No cameras available');
        return;
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      
      _logger.info('Using camera: ${frontCamera.name}');

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      _logger.info('Camera initialized successfully');
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      _logger.severe('Error initializing camera', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: $e')),
        );
      }
    }
  }

  Future<Uint8List?> _captureWebImage() async {
    if (_videoElement == null || _canvasElement == null) {
      _logger.warning('Video or canvas element is null');
      return null;
    }

    try {
      final context = _canvasElement!.context2D;
      context.drawImage(_videoElement!, 0, 0);

      final blob = await _canvasElement!.toBlob();
      if (blob == null) {
        _logger.warning('Failed to create blob from canvas');
        return null;
      }

      final reader = html.FileReader();
      reader.readAsArrayBuffer(blob);
      await reader.onLoad.first;

      final bytes = Uint8List.view(reader.result as ByteBuffer);
      
      _logger.info('Image captured successfully');
      return bytes;
    } catch (e) {
      _logger.severe('Error capturing web image', e);
      return null;
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
        // Mode connexion : utiliser la caméra
        dynamic imageData;
        
        if (kIsWeb) {
          imageData = await _captureWebImage();
          if (imageData == null) {
            throw Exception('Failed to capture image from web camera');
          }
        } else {
          if (_controller == null || !_controller!.value.isInitialized) {
            _logger.warning('Camera not initialized, cannot capture image');
            return;
          }
          final image = await _controller!.takePicture();
          imageData = File(image.path);
        }

        if (!mounted) return;

        bool success;
        if (kIsWeb) {
          final tempFile = File('temp_image.jpg');
          await tempFile.writeAsBytes(imageData as Uint8List);
          success = await context.read<AuthProvider>().signInWithFace(tempFile);
        } else {
          success = await context.read<AuthProvider>().signInWithFace(imageData as File);
        }

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
        // Mode inscription : utiliser l'image sélectionnée
        if (_selectedImage == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Veuillez sélectionner une photo')),
          );
          return;
        }

        final success = await context.read<AuthProvider>().signUpWithEmailAndPassword(
          email: widget.email,
          password: widget.password,
          username: widget.username,
          faceImage: _selectedImage!,
        );

        await _playSound(success);

        if (!mounted) return;

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Inscription réussie !')),
          );
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors de l\'inscription')),
          );
        }
      }
    } catch (e) {
      _logger.severe('Error during submission', e);
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
    _videoElement?.srcObject?.getTracks().forEach((track) => track.stop());
    _videoElement?.remove();
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
              if (kIsWeb && _isCameraInitialized)
                Expanded(
                  child: Container(
                    key: _videoContainerKey,
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.black,
                    child: const Center(
                      child: Text(
                        'Initialisation de la caméra...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                )
              else if (!kIsWeb && !_isCameraInitialized)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Initialisation de la caméra...'),
                  ],
                )
              else if (!kIsWeb && _controller != null && _controller!.value.isInitialized)
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
                onPressed: _isLoading ? null : _submit,
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