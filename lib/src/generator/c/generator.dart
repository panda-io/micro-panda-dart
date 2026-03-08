import '../../ast/module.dart';
import '../../ast/declaration/class_decl.dart';
import '../../ast/declaration/enum_decl.dart';
import '../../ast/declaration/function_decl.dart';
import '../../ast/declaration/parameter.dart';
import '../../ast/declaration/variable_decl.dart';
import '../../ast/expression/expression.dart';
import '../../ast/expression/expression_array_init.dart';
import '../../ast/expression/expression_binary.dart';
import '../../ast/expression/expression_conversion.dart';
import '../../ast/expression/expression_decrement.dart';
import '../../ast/expression/expression_identifier.dart';
import '../../ast/expression/expression_increment.dart';
import '../../ast/expression/expression_invocation.dart';
import '../../ast/expression/expression_literal.dart';
import '../../ast/expression/expression_member_access.dart';
import '../../ast/expression/expression_ref.dart';
import '../../ast/expression/expression_sizeof.dart';
import '../../ast/expression/expression_subscript.dart';
import '../../ast/expression/expression_this.dart';
import '../../ast/expression/expression_unary.dart';
import '../../ast/statement/statement.dart';
import '../../ast/statement/statement_block.dart';
import '../../ast/statement/statement_assert.dart';
import '../../ast/statement/statement_break.dart';
import '../../ast/statement/statement_continue.dart';
import '../../ast/statement/statement_declaration.dart';
import '../../ast/statement/statement_expression.dart';
import '../../ast/statement/statement_for.dart';
import '../../ast/statement/statement_if.dart';
import '../../ast/statement/statement_match.dart';
import '../../ast/statement/statement_return.dart';
import '../../ast/statement/statement_while.dart';
import '../../ast/type/type.dart';
import '../../ast/type/type_array.dart';
import '../../ast/type/type_builtin.dart';
import '../../ast/type/type_name.dart';
import '../../ast/type/type_ref.dart';
import '../../token/token_type.dart';

part 'generator_type.dart';
part 'generator_expression.dart';
part 'generator_statement.dart';
part 'generator_declaration.dart';

/// Generates a single C source file from a list of parsed modules.
///
/// Emission order (avoids undeclared-identifier errors in C):
///   1. Standard includes
///   2. Struct/tagged-enum forward declarations  (typedef struct X X)
///   3. Plain / value enum type definitions
///   4. Tagged enum type definitions              (tag enum + data structs + main struct)
///   5. Class struct definitions
///   6. Function prototypes                       (prevents ordering issues)
///   7. Global variable definitions
///   8. Function definitions
class CGenerator {
  final StringBuffer _out = StringBuffer();
  int _indent = 0;

  // ── context ──────────────────────────────────────────────────────────────────
  /// Name of the class whose methods are currently being generated.
  String? _currentClass;

  /// Generic type parameter names of the currently generated function.
  List<String> _typeParams = [];

  /// Active type substitution for monomorphized generic class code, e.g. {'T': i32}.
  Map<String, Type> _typeSubstitution = {};

  // ── symbol tables (populated before generation) ───────────────────────────────
  final Map<String, Module> _moduleByPath = {};
  final Map<String, ClassDecl> _classes = {};
  final Map<String, EnumDecl> _enums = {};

  /// Maps a tagged-enum variant name → (enumName, EnumMember).
  final Map<String, ({String enumName, EnumMember member})> _variants = {};

  /// Maps @extern function name → FunctionDecl (for template-based call generation).
  final Map<String, FunctionDecl> _externFns = {};

  /// C element type strings for which a __Slice_T typedef must be emitted.
  final Set<String> _sliceElementTypes = {};

  /// C headers requested via @include("header") across all modules.
  final List<String> _moduleIncludes = [];

  /// For each generic class name, the list of concrete type-arg lists used.
  /// e.g. {'ArrayList': [[TypeBuiltin(i32)], [TypeBuiltin(u8)]]}
  final Map<String, List<List<Type>>> _genericInstantiations = {};

  // ── type-tracking scope ───────────────────────────────────────────────────────
  /// Types of global variables (bare name → Type, best-effort for type inference).
  final Map<String, Type?> _globals = {};

  /// Types of variables in the current function scope (name → Type).
  final Map<String, Type?> _scope = {};

  // ── function-level monomorphization ──────────────────────────────────────────
  /// For each generic fn/method key → list of concrete type-arg lists.
  /// Key: "ClassName_methodName" for methods, "modprefix__fnName" for module fns.
  final Map<String, List<List<Type>>> _fnInstantiations = {};

  /// FunctionDecl info for each fn instantiation key.
  final Map<String, ({FunctionDecl fn, String? className, String? modPath})>
      _fnDeclByKey = {};

  /// Return type of the currently-emitting function (used for null→zero-struct fix).
  Type? _currentFnReturnType;

  // ── namespace / per-module call resolution ────────────────────────────────────
  /// C name prefix of the module containing the test utilities (_test_begin, etc.).
  String? _testModulePrefix;

  /// Active per-module name → C name maps, rebuilt by [_setupModuleContext].
  Map<String, String> _localCallMap = {};   // bare fn name → C name
  Map<String, String> _localVarMap = {};    // bare var name → C name
  Map<String, String> _qualifierToModPath = {}; // import qualifier → module path

  // ── namespace helpers ─────────────────────────────────────────────────────────

  /// Convert a dot-separated module path to a C identifier prefix.
  /// e.g. "util.math" → "util__math"
  String _modulePrefix(String modPath) => modPath.replaceAll('.', '__');

  /// The C name for a module-level function.
  String _cFnName(String modPath, String fnName) =>
      '${_modulePrefix(modPath)}__$fnName';

  /// Set up per-module name resolution tables before emitting a module's code.
  void _setupModuleContext(Module mod) {
    _localCallMap = {};
    _localVarMap = {};
    _qualifierToModPath = {};

    // Own module-level functions (non-extern).
    for (final fn in mod.functions) {
      if (!fn.isExtern) {
        _localCallMap[fn.name] = _cFnName(mod.path, fn.name);
      }
    }
    // Own global variables.
    for (final v in mod.variables) {
      _localVarMap[v.name] = '${_modulePrefix(mod.path)}__${v.name}';
    }

    // Resolve imports.
    for (final imp in mod.imports) {
      if (imp.isWildcard) {
        // `import io::*` — bring all symbols of that module into local scope.
        final srcMod = _moduleByPath[imp.path];
        if (srcMod != null) {
          for (final fn in srcMod.functions) {
            if (!fn.isExtern) {
              _localCallMap[fn.name] = _cFnName(imp.path, fn.name);
            }
          }
          for (final v in srcMod.variables) {
            _localVarMap[v.name] = '${_modulePrefix(imp.path)}__${v.name}';
          }
        }
      } else if (imp.symbol != null) {
        // `import io::print_str` or `import io::MY_CONST` — single symbol.
        final targetName = imp.alias ?? imp.symbol!;
        final srcMod = _moduleByPath[imp.path];
        final isVar = srcMod?.variables.any((v) => v.name == imp.symbol) ?? false;
        if (isVar) {
          _localVarMap[targetName] = '${_modulePrefix(imp.path)}__${imp.symbol}';
        } else {
          _localCallMap[targetName] = _cFnName(imp.path, imp.symbol!);
        }
      } else {
        // `import io` or `import io as m` — module-level import.
        // Accessed as `io.fn()` or `m.fn()` (MemberAccess).
        _qualifierToModPath[imp.qualifier] = imp.path;
      }
    }
  }

  // ── entry point ───────────────────────────────────────────────────────────────

  /// [entryModPath] is the module path of the entry module (e.g. "firmware.main").
  /// A thin C `main` wrapper is emitted in non-test builds so user code can call
  /// `main()` without any namespace qualifier.
  String generate(List<Module> modules, {String? entryModPath}) {
    _buildSymbolTables(modules);
    _collectInstantiations(modules);
    _registerSpecializedClasses();
    _collectFnInstantiations(modules);
    _collectSliceTypes(modules);
    _emitIncludes();
    _emitSliceTypedefs();
    _emitForwardDeclarations(modules);
    _emitEnumDefs(modules);
    _emitStructDefs(modules);
    _emitFunctionPrototypes(modules);
    _emitGlobalVars(modules);
    _emitFunctionDefs(modules, entryModPath: entryModPath);
    return _out.toString();
  }

  // ── symbol-table construction ─────────────────────────────────────────────────

  void _buildSymbolTables(List<Module> modules) {
    for (final mod in modules) {
      _moduleByPath[mod.path] = mod;
      for (final cls in mod.classes) {
        _classes[cls.name] = cls;
      }
      for (final enm in mod.enums) {
        _enums[enm.name] = enm;
        for (final m in enm.members) {
          if (m.isTagged) {
            _variants[m.name] = (enumName: enm.name, member: m);
          }
        }
      }
      for (final v in mod.variables) {
        _globals[v.name] = v.type ?? _inferVarType(v.value);
      }
      for (final fn in mod.functions) {
        if (fn.isExtern) _externFns[fn.name] = fn;
        // Detect the module that contains the test utilities.
        if (fn.name == '_test_begin') {
          _testModulePrefix = _modulePrefix(mod.path);
        }
      }
      for (final cls in mod.classes) {
        for (final fn in cls.methods) {
          if (fn.isExtern) _externFns['${cls.name}_${fn.name}'] = fn;
        }
      }
    }
    // Collect @include directives, preserving order and deduplicating
    final seen = <String>{};
    for (final mod in modules) {
      for (final inc in mod.includes) {
        if (seen.add(inc)) _moduleIncludes.add(inc);
      }
    }
  }

  // ── generic class helpers ─────────────────────────────────────────────────────

  /// C name for a generic class instantiation, e.g. `ArrayList<i32>` → `ArrayList_int32_t`.
  String _specializedCName(String baseName, List<Type> typeArgs) {
    if (typeArgs.isEmpty) return baseName;
    return '${baseName}_${typeArgs.map(_cType).join('_')}';
  }

  /// Apply type substitution for a generic class instantiation.
  void _setTypeSubstitution(ClassDecl cls, List<Type> typeArgs) {
    _typeSubstitution = {
      for (var i = 0; i < cls.typeParams.length && i < typeArgs.length; i++)
        cls.typeParams[i]: typeArgs[i]
    };
  }

  /// Collect all generic class instantiations used across all modules.
  void _collectInstantiations(List<Module> modules) {
    void register(Type? type) {
      if (type == null) return;
      if (type is TypeName && type.typeArgs.isNotEmpty) {
        final cls = _classes[type.name];
        if (cls != null && cls.typeParams.isNotEmpty) {
          final list = _genericInstantiations.putIfAbsent(type.name!, () => []);
          final key = type.typeArgs.map(_cType).join('_');
          if (!list.any((a) => a.map(_cType).join('_') == key)) {
            list.add(List.unmodifiable(type.typeArgs));
          }
        }
      }
      if (type is TypeRef) register(type.elementType);
      if (type is TypeArray) register(type.elementType);
    }

    void registerFromStmt(Statement stmt) {
      if (stmt is DeclarationStatement) {
        register(stmt.type);
      } else if (stmt is IfStatement) {
        registerFromStmt(stmt.body);
        if (stmt.else_ != null) registerFromStmt(stmt.else_!);
      } else if (stmt is WhileStatement) {
        registerFromStmt(stmt.body);
      } else if (stmt is ForRangeStatement) {
        registerFromStmt(stmt.body);
      } else if (stmt is ForInStatement) {
        registerFromStmt(stmt.body);
      } else if (stmt is Block) {
        for (final s in stmt.statements) { registerFromStmt(s); }
      }
    }

    void registerFromBlock(Block block) {
      for (final s in block.statements) { registerFromStmt(s); }
    }

    for (final mod in modules) {
      for (final v in mod.variables) { register(v.type); }
      for (final fn in mod.functions) {
        register(fn.returnType);
        for (final p in fn.parameters) { register(p.type); }
        if (fn.body != null) registerFromBlock(fn.body!);
      }
      for (final cls in mod.classes) {
        for (final f in cls.constructorFields) { register(f.type); }
        for (final f in cls.bodyFields) { register(f.type); }
        for (final fn in cls.methods) {
          register(fn.returnType);
          for (final p in fn.parameters) { register(p.type); }
          if (fn.body != null) registerFromBlock(fn.body!);
        }
      }
    }
  }

  /// Register specialized class names in _classes for field lookup during generation.
  void _registerSpecializedClasses() {
    for (final entry in _genericInstantiations.entries) {
      final genericCls = _classes[entry.key]!;
      for (final typeArgs in entry.value) {
        final specName = _specializedCName(genericCls.name, typeArgs);
        _classes[specName] = genericCls;
      }
    }
  }

  /// Scan all type annotations and register slice element types for typedef emission.
  void _collectSliceTypes(List<Module> modules) {
    void register(Type? type) {
      if (type == null) return;
      if (type is TypeArray && type.isSlice) {
        _sliceElementTypes.add(_cType(type.elementType));
      }
      if (type is TypeRef) register(type.elementType);
      if (type is TypeArray && !type.isSlice) register(type.elementType);
    }

    for (final mod in modules) {
      for (final cls in mod.classes) {
        // Skip generic classes here — they're handled below with type substitution.
        if (cls.typeParams.isNotEmpty) continue;
        for (final f in cls.constructorFields) {
          register(f.type);
        }
        for (final f in cls.bodyFields) {
          register(f.type);
        }
        for (final fn in cls.methods) {
          // Skip generic methods — they use type erasure (void*), not concrete slices.
          if (fn.typeParams.isNotEmpty) continue;
          register(fn.returnType);
          for (final p in fn.parameters) {
            register(p.type);
          }
        }
      }
      for (final fn in mod.functions) {
        // Skip generic functions — they use type erasure (void*), not concrete slices.
        if (fn.typeParams.isNotEmpty) continue;
        register(fn.returnType);
        for (final p in fn.parameters) { register(p.type); }
      }
      for (final v in mod.variables) {
        register(v.type);
      }
    }
    // Also collect slice types from generic class instantiations (with concrete T).
    for (final entry in _genericInstantiations.entries) {
      final cls = _classes[entry.key]!;
      for (final typeArgs in entry.value) {
        _setTypeSubstitution(cls, typeArgs);
        for (final f in cls.constructorFields) { register(f.type); }
        for (final f in cls.bodyFields) { register(f.type); }
        for (final fn in cls.methods) {
          register(fn.returnType);
          for (final p in fn.parameters) { register(p.type); }
        }
        _typeSubstitution = {};
      }
    }
    // Also collect slice types from function-level monomorphization instantiations.
    for (final entry in _fnInstantiations.entries) {
      final info = _fnDeclByKey[entry.key];
      if (info == null) continue;
      for (final typeArgs in entry.value) {
        _typeSubstitution = {
          for (var i = 0; i < info.fn.typeParams.length && i < typeArgs.length; i++)
            info.fn.typeParams[i]: typeArgs[i]
        };
        register(info.fn.returnType);
        for (final p in info.fn.parameters) { register(p.type); }
        _typeSubstitution = {};
      }
    }
  }

  /// Best-effort type inference from a literal initializer (for := declarations).
  Type? _inferVarType(Expression? value) {
    if (value == null) return null;
    // Use the type already resolved by the validator when available.
    if (value.type != null) return value.type;
    if (value is Literal) {
      return switch (value.tokenType) {
        TokenType.intLiteral => TypeBuiltin(TokenType.typeInt32),
        TokenType.floatLiteral => TypeBuiltin(TokenType.typeFloat),
        TokenType.boolLiteral => TypeBuiltin(TokenType.typeBool),
        TokenType.charLiteral => TypeBuiltin(TokenType.typeUint8),
        _ => null,
      };
    }
    if (value is Sizeof) {
      return TypeBuiltin(TokenType.typeUint64); // size_t ≈ uint64_t
    }
    if (value is Conversion) {
      final t = value.targetType;
      // In a generic context, a cast to a type param → void*
      if (t is TypeRef &&
          t.elementType is TypeName &&
          _typeParams.contains((t.elementType as TypeName).name)) {
        return TypeRef(TypeBuiltin(TokenType.typeVoid));
      }
      return t;
    }
    if (value is Invocation) {
      // Method call with type args: look up method return type and substitute.
      if (value.function is MemberAccess && value.typeArgs.isNotEmpty) {
        final ma = value.function as MemberAccess;
        final receiverType = _inferType(ma.parent);
        String? className;
        if (receiverType is TypeName) {
          className = receiverType.name;
        } else if (receiverType is TypeRef && receiverType.elementType is TypeName) {
          className = (receiverType.elementType as TypeName).name;
        }
        if (className != null) {
          final cls = _classes[className];
          if (cls != null) {
            final method = cls.methods.where((m) => m.name == ma.member).firstOrNull;
            if (method != null && method.returnType != null && method.typeParams.isNotEmpty) {
              final subst = {
                for (var i = 0; i < method.typeParams.length && i < value.typeArgs.length; i++)
                  method.typeParams[i]: value.typeArgs[i]
              };
              return _substituteType(method.returnType!, subst);
            }
          }
        }
      }
      if (value.function is Identifier) {
        final name = (value.function as Identifier).name;
        if (_classes.containsKey(name)) return TypeName(name);
        // Generic call with type args → return type is pointer to first type arg
        if (value.typeArgs.isNotEmpty) return TypeRef(value.typeArgs.first);
      }
    }
    return null;
  }

  /// Substitute type parameters in [type] according to [subst].
  Type _substituteType(Type type, Map<String, Type> subst) {
    if (subst.isEmpty) return type;
    if (type is TypeName && subst.containsKey(type.name)) return subst[type.name]!;
    if (type is TypeRef) return TypeRef(_substituteType(type.elementType, subst));
    if (type is TypeArray) {
      final arr = TypeArray(_substituteType(type.elementType, subst));
      arr.dimension = List.of(type.dimension);
      return arr;
    }
    return type;
  }

  // ── low-level output helpers ──────────────────────────────────────────────────

  /// Write text at the current indentation level, followed by a newline.
  void _line(String s) {
    _out.write('  ' * _indent);
    _out.writeln(s);
  }

  /// Write text with NO indentation prefix, followed by a newline.
  void _writeln([String s = '']) => _out.writeln(s);

  // ── includes ──────────────────────────────────────────────────────────────────

  void _emitIncludes() {
    _writeln('#include <stdint.h>');
    _writeln('#include <stdbool.h>');
    _writeln('#include <stddef.h>');
    for (final inc in _moduleIncludes) {
      // system header (no path separator) → <header>, local → "header"
      final tag = inc.contains('/') || inc.contains('\\') ? '"$inc"' : '<$inc>';
      _writeln('#include $tag');
    }
    _writeln();
  }

  void _emitSliceTypedefs() {
    // uint8_t slice is always needed for string literals.
    _sliceElementTypes.add('uint8_t');
    for (final elemCType in _sliceElementTypes) {
      _writeln('typedef struct { $elemCType* ptr; size_t size; } __Slice_$elemCType;');
    }
    _writeln();
  }

  // ── function-level monomorphization helpers ───────────────────────────────────

  /// Specialized C name: "ClassName_method" + [i32] → "ClassName_method_int32_t".
  String _fnSpecializedCName(String baseKey, List<Type> typeArgs) =>
      '${baseKey}_${typeArgs.map(_cType).join('_')}';

  /// Apply a compile-time class substitution map to a type (used during collection).
  Type _applyClassSubst(Type t, Map<String, Type> subst) {
    if (subst.isEmpty) return t;
    if (t is TypeName && t.typeArgs.isEmpty) {
      final n = t.name;
      if (n == null) return t;
      return subst[n] ?? t;
    }
    if (t is TypeRef) {
      final inner = _applyClassSubst(t.elementType, subst);
      return inner == t.elementType ? t : TypeRef(inner);
    }
    if (t is TypeArray) {
      final elem = _applyClassSubst(t.elementType, subst);
      if (elem != t.elementType) {
        final arr = TypeArray(elem, t.position);
        arr.dimension.addAll(t.dimension);
        return arr;
      }
    }
    return t;
  }

  /// Apply the currently active [_typeSubstitution] to a type (for call-site specialization).
  Type _applyActiveSubst(Type t) {
    if (_typeSubstitution.isEmpty) return t;
    if (t is TypeName && t.typeArgs.isEmpty) {
      final n = t.name;
      if (n == null) return t;
      return _typeSubstitution[n] ?? t;
    }
    if (t is TypeRef) {
      final inner = _applyActiveSubst(t.elementType);
      return inner == t.elementType ? t : TypeRef(inner);
    }
    if (t is TypeArray) {
      final elem = _applyActiveSubst(t.elementType);
      if (elem != t.elementType) {
        final arr = TypeArray(elem, t.position);
        arr.dimension.addAll(t.dimension);
        return arr;
      }
    }
    return t;
  }

  /// True when the current function's return type (after active substitution) is a slice.
  bool _isSliceReturnType() {
    final t = _currentFnReturnType;
    if (t == null) return false;
    final resolved = _applyActiveSubst(t);
    return resolved is TypeArray && resolved.isSlice;
  }

  /// True if [type] contains one of [params] anywhere in its structure.
  bool _typeContainsTypeParam(Type type, List<String> params) {
    if (type is TypeName) return params.contains(type.name);
    if (type is TypeRef) return _typeContainsTypeParam(type.elementType, params);
    if (type is TypeArray) return _typeContainsTypeParam(type.elementType, params);
    return false;
  }

  /// True when a generic function's return type cannot be type-erased to void*.
  /// Such functions must only be emitted as specialized (monomorphized) copies.
  /// (e.g., T[] is unerasable; &T is erasable to void*.)
  bool _fnHasUnerasableReturn(FunctionDecl fn) {
    if (fn.typeParams.isEmpty) return false;
    final retType = fn.returnType;
    if (retType == null) return false;
    // &T → void* is erasable
    if (retType is TypeRef &&
        retType.elementType is TypeName &&
        fn.typeParams.contains((retType.elementType as TypeName).name)) {
      return false;
    }
    return _typeContainsTypeParam(retType, fn.typeParams);
  }

  /// Walk all function/method bodies to collect generic function instantiations.
  void _collectFnInstantiations(List<Module> modules) {
    for (final mod in modules) {
      _setupModuleContext(mod);
      for (final fn in mod.functions) {
        if (fn.body != null) _walkBlock(fn.body!, {});
      }
      for (final cls in mod.classes) {
        if (cls.typeParams.isEmpty) {
          for (final fn in cls.methods) {
            if (fn.body != null) _walkBlock(fn.body!, {});
          }
        } else {
          // Generic class: walk each instantiation with its type substitution.
          for (final typeArgs in _genericInstantiations[cls.name] ?? <List<Type>>[]) {
            final Map<String, Type> subst = {
              for (var i = 0; i < cls.typeParams.length && i < typeArgs.length; i++)
                cls.typeParams[i]: typeArgs[i]
            };
            for (final fn in cls.methods) {
              if (fn.body != null) _walkBlock(fn.body!, subst);
            }
          }
        }
      }
    }
  }

  void _walkBlock(Block block, Map<String, Type> classSubst) {
    for (final s in block.statements) { _walkStmt(s, classSubst); }
  }

  void _walkStmt(Statement stmt, Map<String, Type> classSubst) {
    if (stmt is ExpressionStatement) {
      _walkExprForInst(stmt.expression, classSubst);
    } else if (stmt is ReturnStatement) {
      if (stmt.value != null) _walkExprForInst(stmt.value!, classSubst);
    } else if (stmt is DeclarationStatement) {
      if (stmt.value != null) _walkExprForInst(stmt.value!, classSubst);
    } else if (stmt is IfStatement) {
      _walkExprForInst(stmt.condition, classSubst);
      _walkStmt(stmt.body, classSubst);
      if (stmt.else_ != null) _walkStmt(stmt.else_!, classSubst);
    } else if (stmt is WhileStatement) {
      _walkExprForInst(stmt.condition, classSubst);
      _walkStmt(stmt.body, classSubst);
    } else if (stmt is AssertStatement) {
      _walkExprForInst(stmt.condition, classSubst);
    } else if (stmt is Block) {
      _walkBlock(stmt, classSubst);
    } else if (stmt is ForRangeStatement) {
      _walkExprForInst(stmt.start, classSubst);
      _walkExprForInst(stmt.end, classSubst);
      _walkStmt(stmt.body, classSubst);
    } else if (stmt is ForInStatement) {
      _walkExprForInst(stmt.iterable, classSubst);
      _walkStmt(stmt.body, classSubst);
    } else if (stmt is MatchStatement) {
      _walkExprForInst(stmt.expression, classSubst);
      for (final arm in stmt.arms) { _walkStmt(arm.body, classSubst); }
    }
  }

  void _walkExprForInst(Expression expr, Map<String, Type> classSubst) {
    if (expr is Invocation) {
      if (expr.typeArgs.isNotEmpty) _registerFnInst(expr, classSubst);
      _walkExprForInst(expr.function, classSubst);
      for (final arg in expr.arguments) { _walkExprForInst(arg, classSubst); }
    } else if (expr is Binary) {
      _walkExprForInst(expr.left, classSubst);
      _walkExprForInst(expr.right, classSubst);
    } else if (expr is Unary) {
      _walkExprForInst(expr.expression, classSubst);
    } else if (expr is MemberAccess) {
      _walkExprForInst(expr.parent, classSubst);
    } else if (expr is Subscript) {
      _walkExprForInst(expr.parent, classSubst);
      _walkExprForInst(expr.index, classSubst);
    } else if (expr is RefExpression) {
      _walkExprForInst(expr.expression, classSubst);
    } else if (expr is Conversion) {
      _walkExprForInst(expr.value, classSubst);
    } else if (expr is Increment) {
      _walkExprForInst(expr.expression, classSubst);
    } else if (expr is Decrement) {
      _walkExprForInst(expr.expression, classSubst);
    }
  }

  void _registerFnInst(Invocation inv, Map<String, Type> classSubst) {
    // Substitute class type params in typeArgs to get concrete types.
    final concreteTypeArgs =
        inv.typeArgs.map((t) => _applyClassSubst(t, classSubst)).toList();

    if (inv.function is MemberAccess) {
      final ma = inv.function as MemberAccess;

      // Module qualifier call: io.fn<T>()
      if (ma.parent is Identifier) {
        final receiverName = (ma.parent as Identifier).name;
        if (_qualifierToModPath.containsKey(receiverName)) {
          final modPath = _qualifierToModPath[receiverName]!;
          final baseCName = _cFnName(modPath, ma.member);
          final srcMod = _moduleByPath[modPath];
          if (srcMod != null) {
            FunctionDecl? fn;
            for (final f in srcMod.functions) {
              if (f.name == ma.member) { fn = f; break; }
            }
            if (fn != null && fn.typeParams.isNotEmpty) {
              _addFnInst(baseCName, fn, null, modPath, concreteTypeArgs);
            }
          }
          return;
        }
      }

      // Method call: receiver.method<T>()  — use receiver.type set by validator.
      final receiverType = ma.parent.type;
      String? className;
      if (receiverType is TypeRef && receiverType.elementType is TypeName) {
        className = (receiverType.elementType as TypeName).name;
      } else if (receiverType is TypeName) {
        className = receiverType.name;
      }
      if (className != null) {
        final cls = _classes[className];
        if (cls != null) {
          FunctionDecl? fn;
          for (final f in cls.methods) {
            if (f.name == ma.member) { fn = f; break; }
          }
          if (fn != null && fn.typeParams.isNotEmpty) {
            _addFnInst('${className}_${ma.member}', fn, className, null, concreteTypeArgs);
          }
        }
      }
    } else if (inv.function is Identifier) {
      final name = (inv.function as Identifier).name;
      final cName = _localCallMap[name];
      if (cName != null) {
        // Find the FunctionDecl matching this C name.
        outer:
        for (final mod in _moduleByPath.values) {
          for (final f in mod.functions) {
            if (!f.isExtern && _cFnName(mod.path, f.name) == cName) {
              if (f.typeParams.isNotEmpty) {
                _addFnInst(cName, f, null, mod.path, concreteTypeArgs);
              }
              break outer;
            }
          }
        }
      }
    }
  }

  void _addFnInst(String key, FunctionDecl fn, String? className, String? modPath,
      List<Type> typeArgs) {
    final typeKey = typeArgs.map(_cType).join('_');
    final list = _fnInstantiations.putIfAbsent(key, () => []);
    if (!list.any((a) => a.map(_cType).join('_') == typeKey)) {
      list.add(typeArgs);
    }
    _fnDeclByKey.putIfAbsent(
        key, () => (fn: fn, className: className, modPath: modPath));
  }

  // ── forward declarations ──────────────────────────────────────────────────────

  void _emitForwardDeclarations(List<Module> modules) {
    var any = false;
    for (final mod in modules) {
      for (final cls in mod.classes) {
        if (cls.typeParams.isEmpty) {
          // Non-generic class: emit as normal.
          _writeln('typedef struct ${cls.name} ${cls.name};');
          any = true;
        } else {
          // Generic class: emit one forward decl per instantiation.
          for (final typeArgs in _genericInstantiations[cls.name] ?? <List<Type>>[]) {
            final specName = _specializedCName(cls.name, typeArgs);
            _writeln('typedef struct $specName $specName;');
            any = true;
          }
        }
      }
      for (final enm in mod.enums) {
        if (enm.members.any((m) => m.isTagged)) {
          _writeln('typedef struct ${enm.name} ${enm.name};');
          any = true;
        }
      }
    }
    if (any) _writeln();
  }
}
