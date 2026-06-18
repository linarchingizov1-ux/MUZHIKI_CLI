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

  static Future<String> getDefaultBranch() async {
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
  final branchResult = await run("git", ["branch", "--show-current"]);
  final currentBranch = branchResult.stdout.toString().trim();

  if (!currentBranch.startsWith("debug/")) {
    ScriptLogger.showError("Release можно запускать только из debug ветки");
    return;
  }

  final version = currentBranch.replaceFirst("debug/", "");
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

  final releaseNotes = ChangelogGenerator.generate(
    version: newVersion,
    commits: commits,
  );


  final file = File("CHANGELOG.md");

  final oldContent = await file.exists()
      ? await file.readAsString()
      : "";

  await file.writeAsString("""
$releaseNotes
$oldContent
""");


  await run("git", ["checkout", "-b", releaseBranch]);

  await run("git", ["add", "pubspec.yaml", "CHANGELOG.md"]);

  await run(
    "git",
    ["commit", "-m", "chore: release $versionString"],
  );

  await run("git", ["tag", "-a", releaseTag, "-m", "Release $releaseTag"]);

  await run("git", ["push", "-u", "origin", releaseBranch]);
  await run("git", ["push", "origin", releaseTag]);

  await File(".release_notes.md").writeAsString(releaseNotes);
  await run("git", ["checkout", "master"]);

  await run("git", ["branch", "-D", currentBranch]);

  await run("git", [
    "push",
    "origin",
    "--delete",
    currentBranch,
  ]).catchError((e) {
    ScriptLogger.showError("Ошибка при удалении ветки в репозитории: $e");
  });

  await run("gh", [
    "pr",
    "create",
    "--base",
    "master",
    "--head",
    releaseBranch,
    "--title",
    "Release $releaseTag",
    "--body-file",
    ".release_notes.md",
  ]);

  ScriptLogger.showSuccess(
    "Release готов: $releaseTag (${commits.length} commits)",
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
