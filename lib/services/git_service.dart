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

  static Future<void> fix() async {
    for (final branch in ['master', 'main', 'developer', 'dev']) {
      try {
        await run('git', ['checkout', branch]);
        break;
      } catch (_) {}
    }

    try {
      await run('git', ['fetch', '--tags']);
    } catch (_) {}
    String? localDebug;
    String? localRelease;
    String? localDebugTag;
    String? localReleaseTag;

    try {
      final res = await run('git', [
        'branch',
        '--list',
        'debug/v*',
        '--sort=v:refname',
      ]);
      final out = res.stdout.toString().trim();
      if (out.isNotEmpty)
        localDebug = out.split('\n').last.replaceAll('*', '').trim();
    } catch (_) {}

    try {
      final res = await run('git', [
        'branch',
        '--list',
        'release/v*',
        '--sort=v:refname',
      ]);
      final out = res.stdout.toString().trim();
      if (out.isNotEmpty)
        localRelease = out.split('\n').last.replaceAll('*', '').trim();
    } catch (_) {}

    try {
      final res = await run('git', [
        'tag',
        '--list',
        '*debug*v*-build-*',
        '--sort=v:refname',
      ]);
      final out = res.stdout.toString().trim();
      if (out.isNotEmpty) localDebugTag = out.split('\n').last.trim();
    } catch (_) {}

    try {
      final res = await run('git', [
        'tag',
        '--list',
        '*release*v*-build-*',
        '--sort=v:refname',
      ]);
      final out = res.stdout.toString().trim();
      if (out.isNotEmpty) localReleaseTag = out.split('\n').last.trim();
    } catch (_) {}

    bool hasRemoteDebug = false;
    bool hasRemoteRelease = false;
    bool hasRemoteDebugTag = false;
    bool hasRemoteReleaseTag = false;

    if (localDebug != null) {
      try {
        final res = await run('git', [
          'ls-remote',
          '--heads',
          'origin',
          localDebug,
        ]);
        hasRemoteDebug = res.stdout.toString().trim().isNotEmpty;
      } catch (_) {}
    }
    if (localRelease != null) {
      try {
        final res = await run('git', [
          'ls-remote',
          '--heads',
          'origin',
          localRelease,
        ]);
        hasRemoteRelease = res.stdout.toString().trim().isNotEmpty;
      } catch (_) {}
    }
    if (localDebugTag != null) {
      try {
        final res = await run('git', [
          'ls-remote',
          '--tags',
          'origin',
          localDebugTag,
        ]);
        hasRemoteDebugTag = res.stdout.toString().trim().isNotEmpty;
      } catch (_) {}
    }
    if (localReleaseTag != null) {
      try {
        final res = await run('git', [
          'ls-remote',
          '--tags',
          'origin',
          localReleaseTag,
        ]);
        hasRemoteReleaseTag = res.stdout.toString().trim().isNotEmpty;
      } catch (_) {}
    }

    String fmt(String? name) =>
        (name ?? 'Не найдено').padRight(26).substring(0, 26);
    String status(bool exist) => exist ? '[ ✓ ]' : '[ ✗ ]';

    ScriptLogger.showBuild(
      "[СБОРКА]: \n"
      "┌─────────────────────────────────┬────────────┐\n"
      "│ КОМПОНЕНТ (ЛОКАЛЬНО)            │ НА СЕРВЕРЕ │\n"
      "├─────────────────────────────────┼────────────┤\n"
      "│ 📁 debug:   ${fmt(localDebug)} │  ${status(hasRemoteDebug)}   │\n"
      "│ 📁 release: ${fmt(localRelease)} │  ${status(hasRemoteRelease)}   │\n"
      "│ 🏷️  tag dgb: ${fmt(localDebugTag)} │  ${status(hasRemoteDebugTag)}   │\n"
      "│ 🏷️  tag rel: ${fmt(localReleaseTag)} │  ${status(hasRemoteReleaseTag)}   │\n"
      "└─────────────────────────────────┴────────────┘",
    );
    ScriptLogger.showError(
      "Если есть проблемы с выполнением команд удали свои последние tag которые ты создал в процессе debug скрипта",
    );
  }

  static Future<String> getMainBranch() async {
    final result = await run("git", [
      "symbolic-ref",
      "refs/remotes/origin/HEAD",
    ]);

    return result.stdout.toString().trim().split("/").last;
  }

  static Future<String> getCurrentBranch() async {
    final result = await run("git", ["branch", "--show-current"]);

    return result.stdout.toString().trim();
  }

  static Future<bool> checkout() async {
    try {
      final defaultBranch = await getMainBranch();

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
🛠 Восстановление релиза
─────────────────────────────────────────
muzhiki --fix
• Используется после неудачного релиза
• Находит последнюю release ветку
• Автоматически определяет связанный тег
• Удаляет release ветку локально и в origin
• Удаляет release тег локально и в origin
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

  static Future<void> runReleaseProccess() async {
    final mainBranch = await getMainBranch();

    ScriptLogger.showBuild("Берем текущую главную ветку...");
    ScriptLogger.showSuccess("Успешно, текущая главная ветка $mainBranch");

    final currentBranch = await getCurrentBranch();

    if (!currentBranch.startsWith("debug/")) {
      ScriptLogger.showError("Release можно запускать только из debug ветки");
      return;
    }

    final debugBranch = currentBranch;
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
        .where(
          (e) =>
              e.startsWith("feat:") ||
              e.startsWith("fix:") ||
              e.startsWith("breaking:"),
        )
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
        "${newVersion.major}."
        "${newVersion.minor}."
        "${newVersion.patch}";

    final releaseTag = "v$versionString";

    final releaseBranch = "release/$releaseTag-build-${newVersion.build}";

    ScriptLogger.showBuild("Идет процесс создания релизной ветки");

    final branchExists = await run("git", ["branch", "--list", releaseBranch]);

    if (branchExists.stdout.toString().trim().isNotEmpty) {
      ScriptLogger.showError("Релизная ветка уже существует");
      return;
    }

    final tagExists = await run("git", ["tag", "-l", releaseTag]);

    if (tagExists.stdout.toString().trim().isNotEmpty) {
      ScriptLogger.showError("Тег $releaseTag уже существует");
      return;
    }

    ScriptLogger.showSuccess("Успешно, текущая релизная ветка $releaseBranch");

    final releaseNotes = ChangelogGenerator.generate(
      version: newVersion,
      commits: commits,
    );

    ScriptLogger.showBuild("Генерируем и берем текущий CHANGELOG.md");

    final changelogFile = File("CHANGELOG.md");

    final oldContent = await changelogFile.exists()
        ? await changelogFile.readAsString()
        : "";

    await changelogFile.writeAsString("""
$releaseNotes

$oldContent
""");

    await run("git", ["checkout", "-b", releaseBranch]);

    ScriptLogger.showBuild("Переключаемся на релизную ветку $releaseBranch");

    ScriptLogger.showBuild("Добавляем версию и изменения в релиз");

    await run("git", ["add", "pubspec.yaml", "CHANGELOG.md"]);

    final status = await run("git", ["status", "--porcelain"]);

    if (status.stdout.toString().trim().isNotEmpty) {
      await run("git", ["commit", "-m", "chore: release $versionString"]);
    }

    ScriptLogger.showBuild("Добавляем релизный тег");

    await run("git", ["tag", "-a", releaseTag, "-m", "Release $releaseTag"]);

    ScriptLogger.showBuild(
      "Отправляем на удаленный репозиторий релизную ветку",
    );

    await run("git", ["push", "-u", "origin", releaseBranch]);

    ScriptLogger.showBuild("Отправляем на удаленный репозиторий релизный тег");

    await run("git", ["push", "origin", releaseTag]);

    ScriptLogger.showBuild("Создаем PR");
    ScriptLogger.showBuild("Генерируем release notes...");

    final releaseNotesFile = File(".release_notes.md");
    await releaseNotesFile.writeAsString(releaseNotes);

    await run("gh", [
      "pr",
      "create",
      "--base",
      mainBranch,
      "--head",
      releaseBranch,
      "--title",
      "Release $releaseTag",
      "--body-file",
      ".release_notes.md",
    ]);

    if (await releaseNotesFile.exists()) {
      await releaseNotesFile.delete();
    }
    ScriptLogger.showBuild("Переключаемся на ветку $mainBranch");

    await run("git", ["checkout", mainBranch]);

    ScriptLogger.showBuild("Удаляем локально ветку $debugBranch");

    try {
      await run("git", ["branch", "-D", debugBranch]);
    } catch (e) {
      ScriptLogger.showError(
        "Не удалось удалить локальную ветку "
        "$debugBranch: $e",
      );
    }

    ScriptLogger.showBuild("Удаляем удаленную ветку $debugBranch");

    try {
      await run("git", ["push", "origin", "--delete", debugBranch]);
    } catch (e) {
      ScriptLogger.showError(
        "Не удалось удалить удаленную ветку "
        "$debugBranch: $e",
      );
    }

    ScriptLogger.showSuccess(
      "Успешно! Релиз $releaseTag создан "
      "(${commits.length} commits). "
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
