import '../services/git_service.dart';

class ReleaseScripts {
  const ReleaseScripts();

  static Future<void> run() async => await GitService.runReleaseProccess();
}
