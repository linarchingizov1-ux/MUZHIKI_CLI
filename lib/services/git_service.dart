import 'dart:convert';
import 'dart:io';
import '../utils/script_logger.dart';
import 'version_manager.dart';
import 'changelog_generator.dart';

class GitService {
  static Future<ProcessResult> run(
    String command,
    List<String> arguments,
  ) async {
    final result = await Process.run(
      command,
      arguments,
      runInShell: true,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

    if (result.exitCode != 0) {
      throw Exception(result.stderr.toString());
    }

    return result;
  }

  static Future<String> getMainBranch() async {
    final result = await run("git", [
      "symbolic-ref",
      "refs/remotes/origin/HEAD",
    ]);

    return result.stdout.toString().trim().split("/").last;
  }

  static Future<bool> checkout() async {
    try {
      final defaultBranch = await getDefaultBranch();

      ScriptLogger.showBuild("Переключаемся на ветку $defaultBranch");

      await run("git", ["checkout", defaultBranch]);

      ScriptLogger.showSuccess("Успешно");

      ScriptLogger.showBuild("Получаем изменения из origin/$defaultBranch");

      await run("git", ["pull", "origin", defaultBranch]);

      ScriptLogger.showSuccess("Успешно");

      return true;
    } catch (_) {
      ScriptLogger.showError(
        "У вас есть незакоммиченные изменения "
        "или конфликт при переключении ветки",
      );

      return false;
    }
  }

  static Future<void> runHelpProccess() async {
    ScriptLogger.showBuild('''
  🔧 Debug ветка
  ─────────────────────────────────────────
  muzhiki --debug
  • Синхронизирует main с origin
  • Проверяет чистоту рабочего дерева
  • Создает ветку: debug/vX.Y.Z-build-N
  ''');

    ScriptLogger.showBuild('''
  🚀 Релиз
  ─────────────────────────────────────────
  muzhiki --release
  • Анализ: сканирует коммиты на feat, fix, breaking
  • Версия: автоматически повышает SemVer
  • Следы: генерирует CHANGELOG.md и создает release ветку
  • Git: автоматически открывает Pull Request в master
  ''');

    ScriptLogger.showBuild('''
  📝 Правила коммитов
  ─────────────────────────────────────────
  Система определяет масштаб обновления по префиксам:

  ╔═══════════════╦═════════════════════════╦═════════════════╗
  ║ Префикс       ║ Тип изменения           ║ Уровень SemVer  ║
  ╠═══════════════╬═════════════════════════╬═════════════════╣
  ║ breaking:     ║ Критические изменения   ║ MAJOR (1.0.0)   ║
  ║ feat:         ║ Новая функциональность  ║ MINOR (0.1.0)   ║
  ║ fix:          ║ Исправление багов       ║ PATCH (0.0.1)   ║
  ╚═══════════════╩═════════════════════════╩═════════════════╝
  ''');

    ScriptLogger.showSuccess('Скрипт готов к использованию!');
  }

static Future runReleaseProccess() async {
  final mainBranch = await getDefaultBranch();
  
  ScriptLogger.showSuccess(
    "Успешно, текущая главная ветка $mainBranch",
  );
  ScriptLogger.showBuild("Берем текущую главную ветку...");
  final branchResult = await run("git", ["branch", "--show-current"]);
  final currentBranch = branchResult.stdout.toString().trim();
  
  if (!currentBranch.startsWith("debug/")) {
    ScriptLogger.showError("Release можно запускать только из debug ветки");
    return;
  }
  ScriptLogger.showBuild("Идет процесс создания релизной ветки");
  final version = currentBranch.replaceFirst("debug/", "");
  final debugBranch = currentBranch;

  final debugTag = "debug-start-$version";

  ScriptLogger.showBuild("Получаем список коммитов релиза");

  final commitsResult = await run("git", [
    "log",
    "$debugTag..HEAD",
    "--pretty=format:%s",
  ]);

  final commits = commitsResult.stdout
      .toString()
      .split("\n")
      .map((e) => e.trim())
      .where((e) =>
          e.startsWith("feat:") ||
          e.startsWith("fix:") ||
          e.startsWith("breaking:"))
      .toList();

  if (commits.isEmpty) {
    ScriptLogger.showError("Не найдено feat/fix/breaking коммитов");
    return;
  }

  VersionType bump = VersionType.patch;

  if (commits.any((e) => e.startsWith("breaking:"))) {
    bump = VersionType.major;
  } else if (commits.any((e) => e.startsWith("feat:"))) {
    bump = VersionType.minor;
  }

  final newVersion = await VersionManager.bumpVersion(bump);
  await VersionManager.setVersion(newVersion);

  final versionString =
      "${newVersion.major}.${newVersion.minor}.${newVersion.patch}";

  final releaseTag = "v$versionString";

  final releaseBranch =
      "release/$releaseTag-build-${newVersion.build}";
  ScriptLogger.showSuccess("Успешно, текущая релизная ветка $releaseBranch");

  final releaseNotes = ChangelogGenerator.generate(
    version: newVersion,
    commits: commits,
  );

  ScriptLogger.showBuild("Генерируем и берем текущий CHANGELOG.md");

  final file = File("CHANGELOG.md");
  ScriptLogger.showBuild("Берем все что нашли...");
  final oldContent = await file.exists()
      ? await file.readAsString()
      : "";
  ScriptLogger.showBuild("Формируем новый вместе со старыми изменения версий ...");
  await file.writeAsString("""
$releaseNotes
$oldContent
""");
  try {
    await run("git", ["checkout", "-b", releaseBranch]);
  } catch (_) {
    ScriptLogger.showError(
      "Релизная ветка уже существует",
    );
    return;
  }
  ScriptLogger.showBuild("Переключаемся на релизную ветку $releaseBranch...");
 ScriptLogger.showBuild("Добавляем версию и изменения в релиз...");
await run("git", ["add", "pubspec.yaml", "CHANGELOG.md"]);

await run("git", [
  "commit",
  "-m",
  "chore: release $versionString",
]);

ScriptLogger.showBuild("Добавляем релизный тег...");
await run("git", [
  "tag",
  "-a",
  releaseTag,
  "-m",
  "Release $releaseTag",
]);

ScriptLogger.showBuild("Отправляем на удаленный репозиторий релизную ветку...");
await run("git", ["push", "-u", "origin", releaseBranch]);

ScriptLogger.showBuild("Отправляем на удаленный репозиторий релизный тег...");
await run("git", ["push", "origin", releaseTag]);

ScriptLogger.showBuild("Генерируем release notes...");
await File(".release_notes.md").writeAsString(releaseNotes);

ScriptLogger.showBuild("Создаем PR...");
await run("gh", [
  "pr",
  "create",
  "--base",
  mainBranch,
  "--head",
  releaseBranch,
  "--title",
  "Release $releaseTag",
  "--body",
  releaseNotes,
]);

final releaseNotesFile = File(".release_notes.md");
if (await releaseNotesFile.exists()) {
  await releaseNotesFile.delete();
}

ScriptLogger.showBuild("Переключаемся на ветку $mainBranch");

try {
  await run("git", ["checkout", mainBranch]);
} catch (e) {
  ScriptLogger.showError(
    "Не удалось переключиться на ветку $mainBranch: $e",
  );
  return;
}

ScriptLogger.showBuild("Удаляем локально ветку $debugBranch");

try {
  await run("git", ["branch", "-D", debugBranch]);
} catch (e) {
  ScriptLogger.showError(
    "Не удалось удалить локальную ветку $debugBranch: $e",
  );
}

ScriptLogger.showBuild("Удаляем удаленную ветку $debugBranch");

try {
  await run("git", [
    "push",
    "origin",
    "--delete",
    debugBranch,
  ]);
} catch (e) {
  ScriptLogger.showError(
    "Не удалось удалить удаленную ветку $debugBranch: $e",
  );
}

ScriptLogger.showSuccess(
  "Успешно! Релиз $releaseTag создан (${commits.length} commits). "
  "Pull Request создан, debug ветка удалена.",
);
}
  static Future<void> runDebugProccess() async {
    final result = await checkout();

    if (!result) return;

    ScriptLogger.showBuild("Получаем текущую версию проекта");

    final currentVersion = await VersionManager.getVersionProject();

    final version =
        "v${currentVersion.major}"
        ".${currentVersion.minor}"
        ".${currentVersion.patch}"
        "-build-${currentVersion.build}";

    final debugBranch = "debug/$version";

    final debugTag = "debug-start-$version";

    ScriptLogger.showSuccess("Версия проекта: $version");

    ScriptLogger.showBuild("Создаем debug ветку");

    await run("git", ["checkout", "-b", debugBranch]);

    ScriptLogger.showSuccess("Ветка $debugBranch создана");

    ScriptLogger.showBuild("Создаем стартовый тег");

    await run("git", ["tag", debugTag]);

    ScriptLogger.showSuccess("Тег $debugTag создан");

    ScriptLogger.showBuild("Публикуем ветку");

    await run("git", ["push", "-u", "origin", debugBranch]);

    ScriptLogger.showSuccess("Ветка опубликована");

    ScriptLogger.showBuild("Публикуем тег");

    await run("git", ["push", "origin", debugTag]);

    ScriptLogger.showSuccess("Тег опубликован");
  }
}
