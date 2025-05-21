import 'package:audioplayers/audioplayers.dart';
import 'package:logging/logging.dart';

class SoundService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final _logger = Logger('SoundService');
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      _isInitialized = true;
      _logger.info('Sound service initialized successfully');
    } catch (e) {
      _logger.severe('Error initializing sound service', e);
      rethrow;
    }
  }

  Future<void> playSound(String soundPath) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      await _audioPlayer.play(AssetSource(soundPath));
      _logger.info('Playing sound: $soundPath');
    } catch (e) {
      _logger.severe('Error playing sound: $soundPath', e);
      rethrow;
    }
  }

  Future<void> stopSound() async {
    try {
      await _audioPlayer.stop();
      _logger.info('Sound stopped');
    } catch (e) {
      _logger.severe('Error stopping sound', e);
      rethrow;
    }
  }

  Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
      _isInitialized = false;
      _logger.info('Sound service disposed');
    } catch (e) {
      _logger.severe('Error disposing sound service', e);
      rethrow;
    }
  }
} 