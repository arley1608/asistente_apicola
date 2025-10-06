import 'dart:async';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../services/recordings_repository.dart';

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

  @override
  void initState() {
    super.initState();
    _future = _repo.listRecordings();
    _onCompleteSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => _playingIndex = null);
    });
  }

  @override
  void dispose() {
    _onCompleteSub?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    // IMPORTANTE: setState con bloque (no devolver Future desde el callback)
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

    // Detén reproducción si es el que está sonando
    if (_playingIndex == idx) {
      await _player.stop();
      _playingIndex = null;
    }

    // Borra el archivo
    await _repo.deleteRecording(item.path);

    if (!mounted) return;

    // Feedback al usuario
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Eliminado: ${item.name}')));

    // Refresca la lista (setState con bloque)
    setState(() {
      _future = _repo.listRecordings();
    });
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
          // Degradado oscuro
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

                    return RepaintBoundary(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final it = items[i];
                          final isPlaying = _playingIndex == i;

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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        it.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
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

                                // Eliminar
                                _RoundIconButton(
                                  icon: Icons.delete_outline_rounded,
                                  onTap: () => _delete(items, i),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
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

/// Tarjeta “glass” con blur + borde translúcido
class _GlassTile extends StatelessWidget {
  final Widget child;
  const _GlassTile({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 6,
          sigmaY: 6,
        ), // blur moderado = mejor perf
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

/// Botón circular translúcido coherente con la pantalla de grabación
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
