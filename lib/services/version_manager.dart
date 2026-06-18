import 'dart:io';

enum VersionType { major, minor, patch }

class AppVersion {
  final int major;
  final int minor;
  final int patch;
  final int build;

  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.build,
  });

  @override
  String toString() => '$major.$minor.$patch+$build';
}

class VersionManager {
  static Future<AppVersion> getVersionProject() async {
    final file = File("pubspec.yaml");

    if (!await file.exists()) {
      throw Exception('Файл pubspec.yaml не найден');
    }

    final content = await file.readAsString();

    final regExp = RegExp(r'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)');
    final match = regExp.firstMatch(content);

    if (match == null) {
      throw Exception(
        'Не удалось найти версию в pubspec.yaml. Проверьте формат version: x.x.x+x',
      );
    }

    return AppVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      build: int.parse(match.group(4)!),
    );
  }

  static Future<void> setVersion(AppVersion version) async {
    final file = File("pubspec.yaml");

    final content = await file.readAsString();

    final updated = content.replaceFirst(
      RegExp(r'version:\s*\d+\.\d+\.\d+\+\d+'),
      'version: $version',
    );

    await file.writeAsString(updated);
  }

  static Future<AppVersion> bumpVersion(VersionType type) async {
    final current = await getVersionProject();

    switch (type) {
      case VersionType.major:
        return AppVersion(
          major: current.major + 1,
          minor: 0,
          patch: 0,
          build: current.build + 1,
        );

      case VersionType.minor:
        return AppVersion(
          major: current.major,
          minor: current.minor + 1,
          patch: 0,
          build: current.build + 1,
        );

      case VersionType.patch:
        return AppVersion(
          major: current.major,
          minor: current.minor,
          patch: current.patch + 1,
          build: current.build + 1,
        );
    }
  }
}
