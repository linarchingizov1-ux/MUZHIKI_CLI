import '../services/git_service.dart';

class HelpScript {
  const HelpScript();

  static Future<void> run() async => await GitService.runHelpProccess();
}
