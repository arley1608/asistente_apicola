// lib/screens/recordings_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../services/recordings_repository.dart';
import '../services/vosk_transcription_service.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({Key? key}) : super(key: key);

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  final _repo = RecordingsRepository();
  late Future<List<RecordingInfo>> _future;
  final _player = AudioPlayer();

  int? _playingIndex;
  StreamSubscription<void>? _onCompleteSub;

  // Servicio Vosk (modelo fijo en assets)
  late final VoskTranscriptionService _vosk;

  @override
  void initState() {
    super.initState();
    _future = _repo.listRecordings();

    _onCompleteSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => _playingIndex = null);
    });

    _vosk = VoskTranscriptionService.assets(
      assetZipPath: 'assets/models/vosk-model-small-es-0.42.zip',
      // grammar: null  // sin gramática => dictado libre
    );

    // Opcional: precalentar el modelo para que la 1ª transcripción sea más rápida
    _vosk.warmUp();
  }

  @override
  void dispose() {
    _onCompleteSub?.cancel();
    _player.stop();
    _player.dispose();
    _vosk.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    // IMPORTANTE: setState con BLOQUE (no flecha) para no devolver Future.
    setState(() {
      _future = _repo.listRecordings();
    });
  }

  String _fmtBytes(int b) {
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = b.toDouble();
    int i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    final fixed = size < 10 ? 1 : 0;
    return '${size.toStringAsFixed(fixed)} ${units[i]}';
  }

  String _fmtDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  String _txtPath(String wavPath) => p.setExtension(wavPath, '.txt');
  bool _hasTranscript(String wavPath) => File(_txtPath(wavPath)).existsSync();

  String? _readTranscriptSync(String wavPath) {
    final f = File(_txtPath(wavPath));
    if (f.existsSync()) return f.readAsStringSync();
    return null;
  }

  Future<void> _saveTranscript(String wavPath, String text) async {
    final f = File(_txtPath(wavPath));
    await f.writeAsString(text);
  }

  Future<void> _togglePlay(List<RecordingInfo> list, int idx) async {
    final item = list[idx];
    if (_playingIndex == idx) {
      await _player.pause();
      setState(() => _playingIndex = null);
      return;
    }
    await _player.stop();
    await _player.play(DeviceFileSource(item.path));
    setState(() => _playingIndex = idx);
  }

  Future<void> _delete(List<RecordingInfo> list, int idx) async {
    final item = list[idx];

    if (_playingIndex == idx) {
      await _player.stop();
      _playingIndex = null;
    }

    // Borra WAV
    await _repo.deleteRecording(item.path);

    // Borra TXT (sidecar)
    final sidecar = File(_txtPath(item.path));
    if (await sidecar.exists()) {
      await sidecar.delete();
    }

    if (!mounted) return;

    // 👉 Ejecuta el trabajo asíncrono FUERA de setState
    final newFuture = _repo.listRecordings();

    // 👉 Actualiza estado SIN devolver Future
    setState(() {
      _future = newFuture;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Eliminado: ${item.name}')));
  }

  Future<void> _transcribe(RecordingInfo it) async {
    // Si ya existe, mostrar directamente
    final cached = _readTranscriptSync(it.path);
    if (cached != null && cached.isNotEmpty) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Transcripción'),
          content: SingleChildScrollView(child: Text(cached)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
      return;
    }

    // Loading modal
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const _LoadingDialog(title: 'Transcribiendo (offline)...'),
    );

    String text = '';
    try {
      text = await _vosk.transcribeFile(it.path);
      await _saveTranscript(it.path, text);
    } catch (e) {
      text = 'Error durante la transcripción:\n$e';
    } finally {
      if (context.mounted) Navigator.pop(context); // cerrar loading
    }

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Transcripción'),
        content: SingleChildScrollView(
          child: Text(text.isEmpty ? '(Vacío)' : text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );

    if (context.mounted) {
      // si quieres refrescar el indicador "Transcrito"
      final newFuture = _repo.listRecordings();
      setState(() {
        _future = newFuture;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Grabaciones', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Volver',
        ),
      ),
      body: Stack(
        children: [
          // Fondo
          Positioned.fill(
            child: Image.asset(
              'assets/images/honey_texture.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: cs.surface),
            ),
          ),
          // Degradado
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.30),
                    Colors.black.withOpacity(0.60),
                    Colors.black.withOpacity(0.85),
                  ],
                ),
              ),
            ),
          ),

          // Contenido
          Positioned.fill(
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: FutureBuilder<List<RecordingInfo>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Error: ${snap.error}',
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    final items = snap.data ?? [];
                    if (items.isEmpty) {
                      return ListView(
                        children: const [SizedBox(height: 120), _EmptyState()],
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final it = items[i];
                        final isPlaying = _playingIndex == i;
                        final hasTxt = _hasTranscript(it.path);

                        return _GlassTile(
                          child: Row(
                            children: [
                              // Play/Pause
                              _RoundIconButton(
                                icon: isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                onTap: () => _togglePlay(items, i),
                              ),
                              const SizedBox(width: 12),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            it.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        if (hasTxt)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.white24,
                                              ),
                                            ),
                                            child: const Text(
                                              'Transcrito',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_fmtDate(it.modified)} • ${_fmtBytes(it.sizeBytes)}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),

                              // Transcribir / Ver
                              _RoundIconButton(
                                icon: hasTxt
                                    ? Icons.text_snippet_rounded
                                    : Icons.subtitles_rounded,
                                onTap: () => _transcribe(it),
                              ),
                              const SizedBox(width: 8),

                              // Eliminar
                              _RoundIconButton(
                                icon: Icons.delete_outline_rounded,
                                onTap: () => _delete(items, i),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: const [
          Icon(Icons.library_music_rounded, size: 72, color: Colors.white70),
          SizedBox(height: 12),
          Text(
            'No hay grabaciones aún',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Graba tu primera inspección desde la pantalla principal.',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _GlassTile extends StatelessWidget {
  final Widget child;
  const _GlassTile({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white60, width: 1.6),
          boxShadow: [
            BoxShadow(color: Colors.white.withOpacity(0.25), blurRadius: 10),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}

class _LoadingDialog extends StatelessWidget {
  final String title;
  const _LoadingDialog({required this.title});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black.withOpacity(0.75),
      contentPadding: const EdgeInsets.all(20),
      content: Row(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
