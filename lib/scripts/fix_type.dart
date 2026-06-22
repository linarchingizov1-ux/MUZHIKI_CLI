import '../services/git_service.dart';

class FixType {
  const FixType();

  static Future<void> fix() async => await GitService.fix();
}
