import 'package:ansi_colorizer/ansi_colorizer.dart';

class ScriptLogger {
  static final showBuild =
      const AnsiColorizer(
        foreground: Ansi24BitColor.fromRGB(85, 85, 255),
        modifiers: {AnsiModifier.bold},
      ).createPrinter(
        prefix: (_) => const AnsiColorizer(
          foreground: Ansi24BitColor.fromRGB(85, 85, 255),
          modifiers: {AnsiModifier.bold},
        )("[СБОРКА]: "),
      );
  static final showSuccess =
      const AnsiColorizer(
        foreground: Ansi24BitColor.fromRGB(0, 170, 0),
        modifiers: {AnsiModifier.bold},
      ).createPrinter(
        prefix: (_) => const AnsiColorizer(
          foreground: Ansi24BitColor.fromRGB(0, 170, 0),
          modifiers: {AnsiModifier.bold},
        )("[УСПЕШНО]: "),
      );
  static final showError =
      const AnsiColorizer(
        foreground: Ansi24BitColor.fromRGB(170, 0, 0),
        modifiers: {AnsiModifier.bold},
      ).createPrinter(
        prefix: (_) => const AnsiColorizer(
          foreground: Ansi24BitColor.fromRGB(170, 0, 0),
          modifiers: {AnsiModifier.bold},
        )("[ОШИБКА]: "),
      );
}
