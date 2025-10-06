import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class RecordingInfo {
  final String path;
  final String name;
  final DateTime modified;
  final int sizeBytes;

  RecordingInfo({
    required this.path,
    required this.name,
    required this.modified,
    required this.sizeBytes,
  });
}

class RecordingsRepository {
  /// Busca archivos *.wav generados por el RecorderService en la carpeta de documentos de la app
  Future<List<RecordingInfo>> listRecordings() async {
    final dir = await getApplicationDocumentsDirectory();
    final root = Directory(dir.path);

    final List<RecordingInfo> items = [];
    if (await root.exists()) {
      await for (final entity in root.list(followLinks: false)) {
        if (entity is File &&
            p.extension(entity.path).toLowerCase() == '.wav') {
          final stat = await entity.stat();
          items.add(
            RecordingInfo(
              path: entity.path,
              name: p.basename(entity.path),
              modified: stat.modified,
              sizeBytes: stat.size,
            ),
          );
        }
      }
    }

    // Ordenar por fecha de modificación descendente
    items.sort((a, b) => b.modified.compareTo(a.modified));
    return items;
  }

  Future<void> deleteRecording(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
