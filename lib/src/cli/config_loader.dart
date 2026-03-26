import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../ast/module.dart';
import '../ast/type/type.dart';
import '../ast/type/type_builtin.dart';
import '../token/position.dart';
import '../token/token_type.dart';

/// Validated and parsed config entry.
class _Entry {
  final String key;
  final Type type;
  final String cValue; // C literal string for #define

  _Entry(this.key, this.type, this.cValue);
}

final _keyRe = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

/// Load and validate a key-value config file.
///
/// Returns a [ConfigData] containing the validator type map and the
/// synthetic `\$config` module (with `#define` raw blocks) to prepend
/// to the module list.
///
/// Throws [Exception] on parse or validation error.
ConfigData loadConfig(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) throw Exception('config file not found: $filePath');

  final doc = loadYaml(file.readAsStringSync());
  if (doc == null) return ConfigData({}, _emptyModule(filePath));
  if (doc is! YamlMap) {
    throw Exception('${p.basename(filePath)}: expected a YAML mapping at the top level');
  }

  final entries = <_Entry>[];
  for (final kv in doc.entries) {
    final key = kv.key.toString();
    if (!_keyRe.hasMatch(key)) {
      throw Exception(
          '${p.basename(filePath)}: invalid config key "$key" '
          '(must start with a letter or _, followed by letters, digits, or _)');
    }

    final value = kv.value;
    if (value is int) {
      entries.add(_Entry(key, TypeBuiltin(TokenType.typeInt32), '$value'));
    } else if (value is bool) {
      entries.add(_Entry(key, TypeBuiltin(TokenType.typeBool), value ? '1' : '0'));
    } else {
      throw Exception(
          '${p.basename(filePath)}: unsupported value type for key "$key" '
          '(only int and bool are supported)');
    }
  }

  final validatorTypes = {for (final e in entries) e.key: e.type as Type};
  final defines = entries.map((e) => '#define ${e.key} ${e.cValue}').toList();
  final module = _buildModule(filePath, defines);
  return ConfigData(validatorTypes, module);
}

Module _buildModule(String filePath, List<String> defines) {
  final sf = SourceFile('\$config:$filePath', 0, 0);
  return Module('\$config', sf, defines, [], [], [], [], []);
}

Module _emptyModule(String filePath) {
  final sf = SourceFile('\$config:$filePath', 0, 0);
  return Module('\$config', sf, [], [], [], [], [], []);
}

/// Result of loading a config file.
class ConfigData {
  /// Types to inject into the validator's global scope.
  final Map<String, Type> validatorTypes;

  /// Synthetic module whose rawBlocks contain the `#define` lines.
  final Module module;

  ConfigData(this.validatorTypes, this.module);
}
