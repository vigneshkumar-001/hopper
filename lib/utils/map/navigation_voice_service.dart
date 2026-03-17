import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

class NavigationVoiceService {
  NavigationVoiceService._();
  static final NavigationVoiceService instance = NavigationVoiceService._();

  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<bool> mutedNotifier = ValueNotifier<bool>(true);
  DateTime _lastSpoken = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastLine = '';
  bool _inited = false;

  bool get isMuted => mutedNotifier.value;

  Future<void> _ensureInit() async {
    if (_inited) return;
    _inited = true;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(false);
  }

  Future<void> speakTurn(String line) async {
    final now = DateTime.now();
    if (line.trim().isEmpty) return;
    if (isMuted) return;
    if (line == _lastLine && now.difference(_lastSpoken).inSeconds < 12) return;
    if (now.difference(_lastSpoken).inSeconds < 6) return;

    await _ensureInit();
    _lastLine = line;
    _lastSpoken = now;
    await _tts.speak(line);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  Future<void> setMuted(bool muted) async {
    if (mutedNotifier.value == muted) return;
    mutedNotifier.value = muted;
    if (muted) {
      await stop();
    }
  }

  Future<void> toggleMuted() => setMuted(!mutedNotifier.value);
}
