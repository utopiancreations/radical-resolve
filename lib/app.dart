import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/inference/engine_lifecycle.dart';
import 'features/chat/chat_screen.dart';
import 'features/journal/journal_screen.dart';
import 'features/lessons/lessons_screen.dart';
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
        scaffoldBackgroundColor: const Color(0xFFF7F3EE),
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
      appBar: AppBar(
        title: const Text('Radical Resolve'),
        backgroundColor: const Color(0xFFF7F3EE),
      ),
      body: engine.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Model unavailable',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        data: (_) => const _Home(),
      ),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
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
            onPressed: () => _push(context, const SosScreen()),
            child: const Text(
              'SOS — Ground me right now',
              style: TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(height: 24),
          _NavTile(
            icon: Icons.menu_book_outlined,
            title: 'Lessons',
            subtitle: 'Walk through a radical-acceptance lesson',
            onTap: () => _push(context, const LessonsScreen()),
          ),
          const SizedBox(height: 12),
          _NavTile(
            icon: Icons.edit_note_outlined,
            title: 'Journal',
            subtitle: 'Untangle facts from the story you\'re telling',
            onTap: () => _push(context, const JournalScreen()),
          ),
          const SizedBox(height: 12),
          _NavTile(
            icon: Icons.chat_bubble_outline,
            title: 'Open Chat',
            subtitle: 'Talk through whatever\'s on your mind',
            onTap: () => _push(context, const ChatScreen()),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEDE4D6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1F1B16), size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF1F1B16),
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF5C5650),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF5C5650),
            ),
          ],
        ),
      ),
    );
  }
}
