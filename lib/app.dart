import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/inference/engine_lifecycle.dart';
import 'core/state/app_mode_controller.dart';
import 'features/sos/sos_screen.dart';

class RadicalResolveApp extends StatelessWidget {
  const RadicalResolveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radical Resolve',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C5CFF)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(engineReadyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Radical Resolve')),
      body: engine.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Model unavailable: $e')),
        data: (_) => const _Home(),
      ),
    );
  }
}

class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E1116),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () {
              ref.read(appModeControllerProvider.notifier).enterSos();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SosScreen()),
              );
            },
            child: const Text('SOS — Ground me right now',
                style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () =>
                ref.read(appModeControllerProvider.notifier).enterJournal(),
            child: const Text('Journal'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () =>
                ref.read(appModeControllerProvider.notifier).enterLesson(),
            child: const Text('Lessons'),
          ),
        ],
      ),
    );
  }
}
