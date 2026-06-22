import '../lib/scripts/debug_type.dart';
import '../lib/scripts/help_type.dart';
import '../lib/scripts/release_type.dart';
import '../lib/utils/script_logger.dart';
import '../lib/utils/script_type.dart';
import '../lib/scripts/fix_type.dart';

Future<void> main(List<String> arguments) async {
  switch (arguments.runner) {
    case ScriptType.debug:
      await DebugScripts.run();

    case ScriptType.release:
      await ReleaseScripts.run();

    case ScriptType.help:
      await HelpScript.run();

    case ScriptType.none:
      ScriptLogger.showError(
        'Не обнаружен префикс для запуска скрипта.\n'
        'Используйте:\n'
        '--debug\n'
        '--release\n'
        '--help',
      );
    case ScriptType.fix:
      await FixType.fix();
  }
}
