// lib/config/env.dart
class Env {
  // flutter test derlenirken bu sabit true olur
  static const bool isTest = bool.fromEnvironment('FLUTTER_TEST');
}
