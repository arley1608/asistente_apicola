// lib/services/recorder_service.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecorderService {
  final AudioRecorder _rec = AudioRecorder();
  String? _currentPath;

  Future<String> start() async {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = await _buildNextFilePath(dir.path);
    return startWithPath(filePath);
  }

  Future<String> startWithPath(String filePath) async {
    if (!await _rec.hasPermission()) {
      throw Exception('Sin permiso de micrófono');
    }
    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
      ),
      path: filePath,
    );
    _currentPath = filePath;
    return filePath;
  }

  Future<String> stop() async {
    final path = await _rec.stop();
    return path ?? _currentPath ?? '';
  }

  Future<void> pause() => _rec.pause();
  Future<void> resume() => _rec.resume();
  Future<bool> isRecording() => _rec.isRecording();

  Stream<Amplitude> amplitude([
    Duration interval = const Duration(milliseconds: 200),
  ]) => _rec.onAmplitudeChanged(interval);

  Future<String> previewNextFileName() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = await _buildNextFilePath(dir.path);
    return p.basename(path);
  }

  // ----------------------------------------------------------------------

  Future<String> _buildNextFilePath(String dirPath) async {
    // Solo la fecha (YYYYMMDD)
    final dateStr = _dateStamp();
    final base = 'inspeccion_$dateStr';
    final existing = await _findExistingWithBase(dirPath, base);

    final nextIndex = (existing.isEmpty)
        ? 1
        : (existing
                  .map(_extractIndex)
                  .whereType<int>()
                  .fold<int>(0, (a, b) => a > b ? a : b) +
              1);

    final indexStr = nextIndex.toString().padLeft(3, '0');
    final fileName = '$base\_$indexStr.wav';
    return p.join(dirPath, fileName);
  }

  Future<List<FileSystemEntity>> _findExistingWithBase(
    String dirPath,
    String base,
  ) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];

    final reg = RegExp(
      '^${RegExp.escape(base)}_(\\d{3})\\.wav\$',
      caseSensitive: false,
    );
    final List<FileSystemEntity> matches = [];
    await for (final ent in dir.list(followLinks: false)) {
      if (ent is File && p.extension(ent.path).toLowerCase() == '.wav') {
        final name = p.basename(ent.path);
        if (reg.hasMatch(name)) matches.add(ent);
      }
    }
    return matches;
  }

  int? _extractIndex(FileSystemEntity fse) {
    final name = p.basename(fse.path);
    final reg = RegExp(r'_(\d{3})\.wav$', caseSensitive: false);
    final m = reg.firstMatch(name);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  /// Devuelve la fecha actual en formato YYYYMMDD
  String _dateStamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}';
  }
}
