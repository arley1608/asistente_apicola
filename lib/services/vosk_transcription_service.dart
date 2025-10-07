import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:vosk_flutter_2/vosk_flutter_2.dart';

enum VoskModelSource { network, assets }

class VoskTranscriptionService {
  final _plugin = VoskFlutterPlugin.instance();

  final VoskModelSource source;
  final String location; // URL (network) o ruta ZIP en assets (assets)
  final List<String>? grammar; // déjala null para dictado libre

  Model? _model;
  Recognizer? _rec;
  int? _recSampleRate;

  VoskTranscriptionService.assets({required String assetZipPath, this.grammar})
    : source = VoskModelSource.assets,
      location = assetZipPath;

  VoskTranscriptionService.network({required String modelUrl, this.grammar})
    : source = VoskModelSource.network,
      location = modelUrl;

  Future<void> warmUp() async {
    await _ensureModelLoaded();
    await _ensureRecognizer(sampleRate: 16000);
  }

  Future<void> _ensureModelLoaded() async {
    if (_model != null) return;
    final loader = ModelLoader();
    final modelPath = (source == VoskModelSource.assets)
        ? await loader.loadFromAssets(location)
        : await loader.loadFromNetwork(location);
    _model = await _plugin.createModel(modelPath);
  }

  Future<void> _ensureRecognizer({required int sampleRate}) async {
    if (_rec != null && _recSampleRate == sampleRate) return;
    if (_rec != null) {
      await _rec!.dispose();
      _rec = null;
    }
    _rec = await _plugin.createRecognizer(
      model: _model!,
      sampleRate: sampleRate,
      grammar: grammar, // null => vocabulario abierto
    );
    _recSampleRate = sampleRate;
  }

  Future<String> transcribeFile(String wavPath) async {
    await _ensureModelLoaded();

    final raw = await File(wavPath).readAsBytes();
    final info = _parseWavIfAny(raw);
    final Uint8List pcm = info.isWav ? _extractPcm(raw, info) : raw;
    final int sr = info.isWav ? info.sampleRate : (_recSampleRate ?? 16000);

    await _ensureRecognizer(sampleRate: sr);

    const int chunk = 8192;
    int pos = 0;
    while (pos + chunk < pcm.length) {
      await _rec!.acceptWaveformBytes(
        Uint8List.sublistView(pcm, pos, pos + chunk),
      );
      pos += chunk;
    }
    await _rec!.acceptWaveformBytes(Uint8List.sublistView(pcm, pos));

    final finalJson = await _rec!.getFinalResult(); // {"text":"..."}
    try {
      final map = jsonDecode(finalJson) as Map<String, dynamic>;
      return (map['text'] as String? ?? '').trim();
    } catch (_) {
      return finalJson.toString().trim();
    }
  }

  Future<void> dispose() async {
    if (_rec != null) {
      await _rec!.dispose();
      _rec = null;
    }
    _recSampleRate = null;
    if (_model != null) {
      _model!.dispose();
      _model = null;
    }
  }

  // ---------- WAV helpers ----------
  _WavInfo _parseWavIfAny(Uint8List bytes) {
    if (bytes.length < 44) return const _WavInfo(false, 16000, 0, 0);
    if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF') {
      return const _WavInfo(false, 16000, 0, 0);
    }
    if (String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
      return const _WavInfo(false, 16000, 0, 0);
    }
    int pos = 12;
    int? sampleRate;
    int? dataOffset;
    int? dataLength;

    while (pos + 8 <= bytes.length) {
      final tag = String.fromCharCodes(bytes.sublist(pos, pos + 4));
      final size = _le32(bytes, pos + 4);
      final next = pos + 8 + size;
      if (next > bytes.length) break;

      if (tag == 'fmt ') {
        if (size >= 16) {
          sampleRate = _le32(bytes, pos + 12);
          // podrías validar canales/bits aquí si quisieras
        }
      } else if (tag == 'data') {
        dataOffset = pos + 8;
        dataLength = size;
      }
      pos = next + (size.isOdd ? 1 : 0);
      if (sampleRate != null && dataOffset != null) break;
    }

    if (sampleRate == null || dataOffset == null || dataLength == null) {
      return const _WavInfo(false, 16000, 0, 0);
    }
    return _WavInfo(true, sampleRate!, dataOffset, dataLength);
  }

  Uint8List _extractPcm(Uint8List bytes, _WavInfo info) {
    final end = (info.dataOffset + info.dataLength).clamp(0, bytes.length);
    return Uint8List.sublistView(bytes, info.dataOffset, end);
  }

  int _le32(Uint8List b, int i) =>
      b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24);
}

class _WavInfo {
  final bool isWav;
  final int sampleRate;
  final int dataOffset;
  final int dataLength;
  const _WavInfo(this.isWav, this.sampleRate, this.dataOffset, this.dataLength);
}
