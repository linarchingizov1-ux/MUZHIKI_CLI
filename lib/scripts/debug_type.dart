import '../services/git_service.dart';

class DebugScripts {
  const DebugScripts();

  static Future<void> run() async => await GitService.runDebugProccess();
}
