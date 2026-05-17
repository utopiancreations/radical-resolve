import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_mode.dart';

class AppModeController extends StateNotifier<AppMode> {
  AppModeController() : super(AppMode.idle);

  void enterSos() => state = AppMode.sos;
  void enterJournal() => state = AppMode.journal;
  void enterLesson() => state = AppMode.lesson;
  void enterChat() => state = AppMode.chat;
  void exitToIdle() => state = AppMode.idle;
}

final appModeControllerProvider =
    StateNotifierProvider<AppModeController, AppMode>(
  (ref) => AppModeController(),
);
