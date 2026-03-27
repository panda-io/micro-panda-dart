import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../ast/module.dart';
import '../ast/type/type.dart';
import '../token/position.dart';

final _keyRe = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

/// Parse a config file into a key → C-value-string map.
///
/// Supported YAML scalar types:
/// - `int`    → `"42"`
/// - `bool`   → `"1"` / `"0"`
/// - `double` → `"3.14"`
/// - `String` → verbatim string
///
/// Throws [Exception] on parse or validation error.
Map<String, String> parseConfigEntries(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) throw Exception('config file not found: $filePath');

  final doc = loadYaml(file.readAsStringSync());
  if (doc == null) return {};
  if (doc is! YamlMap) {
    throw Exception('${p.basename(filePath)}: expected a YAML mapping at the top level');
  }

  final result = <String, String>{};
  for (final kv in doc.entries) {
    final key = kv.key.toString();
    if (!_keyRe.hasMatch(key)) {
      throw Exception(
          '${p.basename(filePath)}: invalid config key "$key" '
          '(must start with a letter or _, followed by letters, digits, or _)');
    }
    final value = kv.value;
    final String cValue;
    if (value is int) {
      cValue = '$value';
    } else if (value is bool) {
      cValue = value ? '1' : '0';
    } else if (value is double) {
      cValue = '$value';
    } else if (value is String) {
      cValue = value; // verbatim: user writes IRAM_ATTR or "my_string" as needed
    } else {
      throw Exception(
          '${p.basename(filePath)}: unsupported value type for key "$key" '
          '(supported: int, bool, double, string)');
    }
    result[key] = cValue;
  }
  return result;
}

/// Build a [ConfigData] from a merged key → C-value-string map.
///
/// Returns a [ConfigData] containing:
/// - [ConfigData.validatorTypes] — config keys mapped to `null` so the
///   validator accepts them in any numeric/bool context (they are untyped
///   `#define` macros at the C level).
/// - [ConfigData.module] — synthetic `\$config` module whose rawBlocks
///   emit one `#define` line per entry.
ConfigData buildConfigData(Map<String, String> entries) {
  if (entries.isEmpty) return ConfigData({}, _emptyModule('\$config'));
  final defines = entries.entries.map((e) => '#define ${e.key} ${e.value}').toList();
  final validatorTypes = {for (final k in entries.keys) k: null as Type?};
  return ConfigData(validatorTypes, _buildModule('\$config', defines));
}

/// Load and validate a key-value config file. Convenience wrapper.
ConfigData loadConfig(String filePath) =>
    buildConfigData(parseConfigEntries(filePath));

Module _buildModule(String label, List<String> defines) {
  final sf = SourceFile('\$config:$label', 0, 0);
  return Module('\$config', sf, defines, [], [], [], [], [], []);
}

Module _emptyModule(String label) {
  final sf = SourceFile('\$config:$label', 0, 0);
  return Module('\$config', sf, [], [], [], [], [], [], []);
}

/// Result of loading a config file.
class ConfigData {
  /// Config keys with null types — compatible with any type in the validator.
  final Map<String, Type?> validatorTypes;

  /// Synthetic module whose rawBlocks contain the `#define` lines.
  final Module module;

  ConfigData(this.validatorTypes, this.module);
}
