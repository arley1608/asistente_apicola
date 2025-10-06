import 'package:flutter/material.dart';
import '../routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  String get bgPath => 'assets/images/honey_texture.jpg';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Fondo con imagen (tolerante a errores)
          Positioned.fill(
            child: Image.asset(
              bgPath,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) {
                // Si el asset no existe, mostramos un degradado bonito para no romper la UI
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primaryContainer, cs.surface],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                );
              },
            ),
          ),
          // Degradado para legibilidad
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cs.surface.withOpacity(0.25),
                    cs.surface.withOpacity(0.65),
                    cs.surface.withOpacity(0.90),
                  ],
                ),
              ),
            ),
          ),

          // Contenido
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Asistente Apícola',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Registra inspecciones rápido y sin conexión',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: cs.onSurface.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Botón principal: Grabar
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.mic_rounded),
                          label: const Text('Grabar inspección'),
                          onPressed: () =>
                              Navigator.pushNamed(context, Routes.record),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Botón secundario: Grabaciones
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.library_music_rounded),
                          label: const Text('Ver grabaciones'),
                          onPressed: () =>
                              Navigator.pushNamed(context, Routes.recordings),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(
                              color: cs.outline.withOpacity(0.6),
                            ),
                            foregroundColor: cs.onSurface,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Mini info / versión
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.offline_bolt_rounded,
                            size: 18,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Modo offline listo',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: cs.onSurface.withOpacity(0.8),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '•',
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'v0.1.0',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: cs.onSurface.withOpacity(0.6),
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
