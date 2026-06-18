import 'package:muzhiki_cli/scripts/debug_type.dart';
import 'package:muzhiki_cli/scripts/help_type.dart';
import 'package:muzhiki_cli/scripts/release_type.dart';
import 'package:muzhiki_cli/utils/script_logger.dart';
import 'package:muzhiki_cli/utils/script_type.dart';

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
  }
}
