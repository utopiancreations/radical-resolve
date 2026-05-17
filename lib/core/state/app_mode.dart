enum AppMode {
  idle,
  sos,
  journal,
  lesson,
  chat;

  String get promptId => switch (this) {
        AppMode.sos => 'sos_grounding',
        AppMode.journal => 'analytical_planner',
        AppMode.lesson => 'lesson_companion',
        AppMode.chat => 'lesson_companion',
        AppMode.idle => 'lesson_companion',
      };
}
