// lib/screens/record_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../services/recorder_service.dart';
import '../widgets/audio_bars.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({Key? key}) : super(key: key);

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final _recorder = RecorderService();
  final _stopwatch = Stopwatch();
  Timer? _uiTimer;
  Amplitude _amp = Amplitude(current: -160, max: -160);

  // barras tipo WhatsApp
  final int _maxBars = 120;
  final List<double> _levels = [];

  // nombre planeado y bloqueado
  String? _plannedName; // vista previa del siguiente nombre
  String? _lockedName; // nombre usado en la grabación actual

  @override
  void initState() {
    super.initState();
    _refreshPlannedName();

    // stream de amplitud para las barras
    _recorder.amplitude().listen((a) {
      if (!mounted) return;
      setState(() {
        _amp = a;
        final v = ((_amp.current + 60).clamp(0, 60)) / 60.0;
        _levels.add(v);
        if (_levels.length > _maxBars) _levels.removeAt(0);
      });
    });

    // refrescar nombre sugerido cada segundo cuando no se graba
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_stopwatch.isRunning) _refreshPlannedName();
      setState(() {}); // refresca cronómetro
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshPlannedName() async {
    final name = await _recorder.previewNextFileName();
    if (mounted) setState(() => _plannedName = name);
  }

  Future<void> _ensureMic() async {
    final status = await Permission.microphone.status;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      throw Exception('Micrófono bloqueado. Habilítalo en Ajustes.');
    }
    if (status.isDenied) {
      final res = await Permission.microphone.request();
      if (!res.isGranted) throw Exception('Permiso de micrófono denegado.');
    }
  }

  Future<void> _startRecording() async {
    try {
      await _ensureMic();
      final name = _plannedName ?? await _recorder.previewNextFileName();
      final dir = await getApplicationDocumentsDirectory();
      final fullPath = '${dir.path}/$name';
      await _recorder.startWithPath(fullPath);
      _lockedName = name;
      _stopwatch
        ..reset()
        ..start();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al iniciar: $e')));
    }
  }

  Future<void> _pauseRecording() async {
    await _recorder.pause();
    _stopwatch.stop();
    setState(() {});
  }

  Future<void> _resumeRecording() async {
    await _recorder.resume();
    _stopwatch.start();
    setState(() {});
  }

  Future<void> _stopRecording() async {
    try {
      final saved = await _recorder.stop();
      _stopwatch.stop();
      _lockedName = null;
      await _refreshPlannedName();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Grabación guardada:\n$saved')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al detener: $e')));
    }
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isRecording = _stopwatch.isRunning;
    final hasAnyRecording = _stopwatch.elapsed != Duration.zero;
    final isPaused = !isRecording && hasAnyRecording;

    final displayName = _lockedName ?? _plannedName ?? 'inspeccion_...wav';

    // tamaños
    const double micBtn = 110;
    const double smallBtn = 78;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Volver',
        ),
        title: const Text('Grabación', style: TextStyle(color: Colors.white)),
        centerTitle: true,
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 72, 20, 24),
                child: Column(
                  children: [
                    // Nombre de archivo y cronómetro
                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _fmt(_stopwatch.elapsed),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),

                    const SizedBox(height: 24),
                    // Barras de audio
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: AudioBars(
                        levels: _levels,
                        height: 64,
                        barWidth: 3,
                        spacing: 2,
                        minBar: 0.12,
                      ),
                    ),

                    const SizedBox(height: 60),

                    // ======= BOTONES CENTRALES (mic arriba, pausa/detener abajo) =======
                    SizedBox(
                      height:
                          220, // espacio vertical reservado para evitar solaparse
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Fila de botones pequeños al fondo del bloque
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _RoundBtn(
                                  size: smallBtn,
                                  icon: Icons.pause_rounded,
                                  enabled: isRecording, // solo si está grabando
                                  onTap: _pauseRecording,
                                ),
                                const SizedBox(width: 70),
                                _RoundBtn(
                                  size: smallBtn,
                                  icon: Icons.stop_rounded,
                                  enabled:
                                      hasAnyRecording, // cuando hubo alguna grabación
                                  onTap: _stopRecording,
                                ),
                              ],
                            ),
                          ),

                          // Botón de micrófono más grande en la parte superior del bloque
                          const Positioned(
                            top: 0,
                            child: SizedBox(height: 1),
                          ), // truca para reservar top
                          Positioned(
                            top: 0,
                            child: _RoundBtn(
                              size: micBtn,
                              icon: isPaused || !hasAnyRecording
                                  ? Icons
                                        .mic_rounded // iniciar o reanudar
                                  : Icons
                                        .mic_none_rounded, // grabando (deshabilitado)
                              enabled:
                                  !isRecording, // cuando no está grabando (inicio o reanudar)
                              onTap: () async {
                                if (!hasAnyRecording) {
                                  await _startRecording();
                                } else if (isPaused) {
                                  await _resumeRecording();
                                }
                              },
                              glow: true,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ================================================================
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Botón redondo translúcido y consistente
class _RoundBtn extends StatelessWidget {
  final double size;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  final bool glow;

  const _RoundBtn({
    required this.size,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = Colors.white;
    final color = enabled ? baseColor : baseColor.withOpacity(0.45);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.08), // translúcido
          border: Border.all(color: color.withOpacity(0.65), width: 2),
          boxShadow: glow && enabled
              ? [BoxShadow(color: color.withOpacity(0.55), blurRadius: 18)]
              : [],
        ),
        child: Icon(icon, color: color, size: size * 0.46),
      ),
    );
  }
}
