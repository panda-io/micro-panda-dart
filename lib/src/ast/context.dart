import 'declaration/class_decl.dart';
import 'declaration/enum_decl.dart';
import 'declaration/function_decl.dart';
import 'module.dart';
import 'type/type.dart';
import 'type/type_array.dart';
import 'type/type_builtin.dart';
import 'type/type_function.dart';
import 'type/type_name.dart';
import 'type/type_ref.dart';
import '../token/position.dart';
import '../token/token_type.dart';

class ValidationError {
  final SourceFile? file;
  final int position;
  final String message;
  const ValidationError(this.position, this.message, {this.file});

  @override
  String toString() {
    if (file != null) {
      final (line, col) = file!.getLocation(position);
      return '${file!.name}:$line:$col: error: $message';
    }
    return 'error at offset $position: $message';
  }
}

class Context {
  // ── global symbol tables ──────────────────────────────────────────────────────
  final Map<String, ClassDecl> classes;
  final Map<String, EnumDecl> enums;
  final Map<String, FunctionDecl> globalFunctions;
  final Map<String, Type?> globalVariables;

  /// Maps class name → module path (used for private member access checks).
  final Map<String, String> classModules;

  // ── current file (for error location) ────────────────────────────────────────
  final SourceFile? currentFile;

  // ── current function context ──────────────────────────────────────────────────
  final Type? returnType;          // null = void
  final List<String> typeParams;   // generic type params of current function
  final String? currentClass;      // class name if validating a method

  // ── scope chain ───────────────────────────────────────────────────────────────
  final Context? _parent;
  final Map<String, Type?> _locals = {};
  final Set<String> _valLocals = {};

  // ── error collection (shared across all child contexts) ───────────────────────
  final List<ValidationError> _errors;
  List<ValidationError> get errors => _errors;
  bool get hasErrors => _errors.isNotEmpty;

  Context._({
    required this.classes,
    required this.enums,
    required this.globalFunctions,
    required this.globalVariables,
    required this.classModules,
    required this.currentFile,
    required this.returnType,
    required this.typeParams,
    required this.currentClass,
    required Context? parent,
    required List<ValidationError> errors,
  })  : _parent = parent,
        _errors = errors;

  factory Context.root(List<Module> modules) {
    final classes = <String, ClassDecl>{};
    final enums = <String, EnumDecl>{};
    final functions = <String, FunctionDecl>{};
    final variables = <String, Type?>{};
    final classModules = <String, String>{};
    for (final mod in modules) {
      for (final cls in mod.classes) {
        classes[cls.name] = cls;
        classModules[cls.name] = mod.path;
      }
      for (final enm in mod.enums) {
        enums[enm.name] = enm;
      }
      for (final fn in mod.functions) {
        functions[fn.name] = fn;
      }
      for (final v in mod.variables) {
        variables[v.name] = v.type;
      }
    }
    return Context._(
      classes: classes,
      enums: enums,
      globalFunctions: functions,
      globalVariables: variables,
      classModules: classModules,
      currentFile: null,
      returnType: null,
      typeParams: [],
      currentClass: null,
      parent: null,
      errors: [],
    );
  }

  /// Child scope for a module (sets source file for error location).
  Context forModule(SourceFile file) => Context._(
        classes: classes,
        enums: enums,
        globalFunctions: globalFunctions,
        globalVariables: globalVariables,
        classModules: classModules,
        currentFile: file,
        returnType: null,
        typeParams: [],
        currentClass: null,
        parent: this,
        errors: _errors,
      );

  /// Child scope for a block (inherits function context).
  Context childScope() => Context._(
        classes: classes,
        enums: enums,
        globalFunctions: globalFunctions,
        globalVariables: globalVariables,
        classModules: classModules,
        currentFile: currentFile,
        returnType: returnType,
        typeParams: typeParams,
        currentClass: currentClass,
        parent: this,
        errors: _errors,
      );

  /// Child scope for a function body (sets new function context).
  Context forFunction(FunctionDecl fn, String? className) {
    // Merge class-level type params with function-level type params so that
    // class generics (e.g. T in ArrayList<T>) are visible inside methods.
    final classTypeParams = className != null
        ? (classes[className]?.typeParams ?? const <String>[])
        : const <String>[];
    final mergedTypeParams = [...classTypeParams, ...fn.typeParams];
    return Context._(
        classes: classes,
        enums: enums,
        globalFunctions: globalFunctions,
        globalVariables: globalVariables,
        classModules: classModules,
        currentFile: currentFile,
        returnType: fn.returnType,
        typeParams: mergedTypeParams,
        currentClass: className,
        parent: this,
        errors: _errors,
      );
  }

  // ── variable declarations ─────────────────────────────────────────────────────

  void declare(String name, Type? type, int position, {bool isVal = false}) {
    if (_locals.containsKey(name)) {
      error(position, "variable '$name' already declared in this scope");
      return;
    }
    _locals[name] = type;
    if (isVal) _valLocals.add(name);
  }

  // ── variable lookup ───────────────────────────────────────────────────────────

  /// Look up a variable's type: locals first, then global variables.
  Type? lookupVar(String name) {
    if (_locals.containsKey(name)) return _locals[name];
    if (_parent != null) return _parent.lookupVar(name);
    if (globalVariables.containsKey(name)) return globalVariables[name];
    return null;
  }

  /// True if [name] is declared in local scope chain (not considering fields/globals).
  bool isDeclaredVar(String name) {
    if (_locals.containsKey(name)) return true;
    if (_parent != null) return _parent.isDeclaredVar(name);
    if (globalVariables.containsKey(name)) return true;
    return false;
  }

  /// Look up a class field type (only valid inside a method).
  Type? lookupField(String name) {
    if (currentClass == null) return null;
    final cls = classes[currentClass];
    if (cls == null) return null;
    for (final f in cls.constructorFields) {
      if (f.name == name) return f.type;
    }
    for (final f in cls.bodyFields) {
      if (f.name == name) return f.type;
    }
    return null;
  }

  /// True if [name] is declared in any scope, fields, or global symbols.
  bool isDeclared(String name) {
    if (isDeclaredVar(name)) return true;
    if (lookupField(name) != null) return true;
    if (globalFunctions.containsKey(name)) return true;
    if (classes.containsKey(name)) return true;
    if (enums.containsKey(name)) return true;
    return false;
  }

  /// True if [name] is a val binding (cannot be reassigned).
  bool isValBinding(String name) {
    if (_valLocals.contains(name)) return true;
    if (_parent != null) return _parent!.isValBinding(name);
    return false;
  }

  // ── error reporting ───────────────────────────────────────────────────────────

  void error(int position, String message) {
    _errors.add(ValidationError(position, message, file: currentFile));
  }

  // ── type utilities ────────────────────────────────────────────────────────────

  /// True when two types are compatible (assignment/comparison).
  /// Null = unknown type — always compatible to avoid cascading errors.
  bool typesCompatible(Type? a, Type? b) {
    if (a == null || b == null) return true;
    if (a.equal(b)) return true;
    // void* is compatible with any pointer
    if (a is TypeRef && b is TypeRef) {
      if (_isVoidPtr(a) || _isVoidPtr(b)) return true;
    }
    // null (&void) is compatible with any ref
    if (a is TypeRef && _isVoidPtr(a)) return true;
    if (b is TypeRef && _isVoidPtr(b)) return true;
    // generic type param: skip check
    if (typeParams.isNotEmpty) return true;
    return false;
  }

  bool _isVoidPtr(TypeRef t) =>
      t.elementType is TypeBuiltin &&
      (t.elementType as TypeBuiltin).token == TokenType.typeVoid;

  /// Human-readable type name for error messages.
  static String typeName(Type? t) {
    if (t == null) return '?';
    if (t is TypeBuiltin) return t.token.literal ?? t.token.name;
    if (t is TypeName) return t.name ?? '?';
    if (t is TypeRef) return '&${typeName(t.elementType)}';
    if (t is TypeArray) {
      if (t.isSlice) return '${typeName(t.elementType)}[]';
      return '${typeName(t.elementType)}[${t.dimension.join("][")}]';
    }
    if (t is TypeFunction) {
      final params = t.parameters.map(typeName).join(', ');
      final ret = t.returnTypes.isEmpty ? '' : ' ${typeName(t.returnTypes.first)}';
      return 'fun($params)$ret';
    }
    return '?';
  }
}
