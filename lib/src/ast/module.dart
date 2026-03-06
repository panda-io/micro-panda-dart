import 'declaration/class_decl.dart';
import 'declaration/enum_decl.dart';
import 'declaration/function_decl.dart';
import 'declaration/variable_decl.dart';
import '../token/position.dart';

/// A single import statement.
class Import {
  /// Dot-separated module path, e.g. "util.math"
  final String path;

  /// Specific symbol imported, e.g. "min" from "import util.math::min"
  /// Null when importing the whole module.
  final String? symbol;

  /// Alias for the module or symbol, e.g. "m" from "import util.math as m"
  /// When null and symbol is null, the last path segment is used as alias.
  final String? alias;

  /// True when the import uses the wildcard form: `import util.math::*`
  final bool isWildcard;

  final int position;

  Import(this.path, {this.symbol, this.alias, this.isWildcard = false, required this.position});

  /// The qualifier used to reference this import in code.
  String get qualifier {
    if (alias != null) return alias!;
    if (symbol != null) return symbol!;
    return path.split('.').last;
  }
}

/// A parsed source file (module).
class Module {
  /// File path used as module identifier.
  final String path;

  /// Source file — used to resolve offsets to line:column for error reporting.
  final SourceFile sourceFile;

  /// C headers requested via @include("header") at module level.
  final List<String> includes;

  final List<Import> imports;
  final List<VariableDecl> variables;
  final List<FunctionDecl> functions;
  final List<ClassDecl> classes;
  final List<EnumDecl> enums;

  Module(this.path, this.sourceFile, this.includes, this.imports, this.variables, this.functions, this.classes, this.enums);
}
