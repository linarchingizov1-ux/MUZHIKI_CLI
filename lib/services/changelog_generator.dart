import 'version_manager.dart';

class ChangelogGenerator {
  static String generate({
    required AppVersion version,
    required List<String> commits,
  }) {
    final fixes = <String>[];
    final features = <String>[];
    final breakings = <String>[];
    final perf = <String>[];
    final ref = <String>[];

    for (final commit in commits) {
      if (commit.startsWith("fix:")) {
        fixes.add(commit.replaceFirst("fix:", "").trim());
      } else if (commit.startsWith("feat:")) {
        features.add(commit.replaceFirst("feat:", "").trim());
      } else if (commit.startsWith("breaking:")) {
        breakings.add(commit.replaceFirst("breaking:", "").trim());
      } else if (commit.startsWith("perf:")) {
        perf.add(commit.replaceFirst("perf:", "").trim());
      } else if (commit.startsWith("ref:")) {
        ref.add(commit.replaceFirst("ref:", "").trim());
      }
    }

    final buffer = StringBuffer();
    buffer.writeln(
      '# 📦 Релиз ${version.major}.${version.minor}.${version.patch} от ${_formatDate(DateTime.now())}\n',
    );

    if (features.isNotEmpty) {
      buffer.writeln('## Новые возможности\n');
      for (final item in features) {
        buffer.writeln(item);
      }
      buffer.writeln();
    }

    if (fixes.isNotEmpty) {
      buffer.writeln('## Исправления\n');
      for (final item in fixes) {
        buffer.writeln(item);
      }
      buffer.writeln();
    }

    if (breakings.isNotEmpty) {
      buffer.writeln('## Важные изменения\n');
      for (final item in breakings) {
        buffer.writeln(item);
      }
      buffer.writeln();
    }
    if (perf.isNotEmpty) {
      buffer.writeln('## Оптимизация кода\n');
      for (final item in perf) {
        buffer.writeln(item);
      }
      buffer.writeln();
    }
    if (ref.isNotEmpty) {
      buffer.writeln('## Рефакторинг кода\n');
      for (final item in ref) {
        buffer.writeln(item);
      }
      buffer.writeln();
    }

    if (features.isEmpty &&
        fixes.isEmpty &&
        breakings.isEmpty &&
        perf.isEmpty &&
        ref.isEmpty) {
      buffer.writeln(
        '# ℹ️  Технический релиз без изменений в функциональности',
      );
    }

    return buffer.toString();
  }

  static String _formatDate(DateTime date) {
    final months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
