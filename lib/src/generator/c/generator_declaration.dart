part of 'generator.dart';

extension GeneratorDeclaration on CGenerator {
  // ── enum definitions ──────────────────────────────────────────────────────────

  void _emitEnumDefs(List<Module> modules) {
    for (final mod in modules) {
      for (final enm in mod.enums) {
        if (enm.members.any((m) => m.isTagged)) {
          _emitTaggedEnumDef(enm);
        } else {
          _emitPlainEnumDef(enm);
        }
      }
    }
  }

  /// Plain / value enum → C typedef enum.
  ///
  ///   enum Color { Red, Green, Blue }
  ///   →  typedef enum { Color_Red = 0, Color_Green = 1, Color_Blue = 2, } Color;
  void _emitPlainEnumDef(EnumDecl enm) {
    _writeln('typedef enum {');
    int auto = 0;
    for (final m in enm.members) {
      if (m.hasValue) {
        _writeln('  ${enm.name}_${m.name} = ${_expr(m.value!)},');
        if (m.value is Literal) auto = (int.tryParse((m.value as Literal).value) ?? auto) + 1;
      } else {
        _writeln('  ${enm.name}_${m.name} = ${auto++},');
      }
    }
    _writeln('} ${enm.name};');
    _writeln();
  }

  /// Tagged enum (discriminated union) → tag enum + data structs + main struct.
  ///
  ///   enum Expr { Binary(left: &Expr, right: &Expr), Num(value: i32) }
  ///
  ///   typedef enum { Expr_Binary, Expr_Num } Expr_Tag;
  ///   typedef struct { Expr* left; Expr* right; } Expr_Binary_Data;
  ///   typedef struct { int32_t value; }          Expr_Num_Data;
  ///   struct Expr { Expr_Tag tag; union { Expr_Binary_Data Binary; ... } data; };
  void _emitTaggedEnumDef(EnumDecl enm) {
    // 1. Tag enum
    _writeln('typedef enum {');
    for (final m in enm.members) {
      _writeln('  ${enm.name}_${m.name},');
    }
    _writeln('} ${enm.name}_Tag;');
    _writeln();

    // 2. Per-variant data structs (only for variants that carry fields)
    for (final m in enm.members) {
      final fields = m.fields;
      if (m.isTagged && fields != null && fields.isNotEmpty) {
        _writeln('typedef struct {');
        for (final f in fields) {
          _writeln('  ${_varDecl(f.name, f.type)};');
        }
        _writeln('} ${enm.name}_${m.name}_Data;');
        _writeln();
      }
    }

    // 3. Main struct with tag + union
    _writeln('struct ${enm.name} {');
    _writeln('  ${enm.name}_Tag tag;');
    _writeln('  union {');
    for (final m in enm.members) {
      final fields = m.fields;
      if (m.isTagged && fields != null && fields.isNotEmpty) {
        _writeln('    ${enm.name}_${m.name}_Data ${m.name};');
      }
    }
    _writeln('  } data;');
    _writeln('};');
    _writeln();
  }

  // ── struct definitions ────────────────────────────────────────────────────────

  void _emitStructDefs(List<Module> modules) {
    for (final mod in modules) {
      for (final cls in mod.classes) {
        _emitStructDef(cls);
      }
    }
  }

  /// Class → C struct body.
  ///
  ///   class Point(val x: i32, val y: i32)
  ///   →  struct Point { int32_t x; int32_t y; };
  void _emitStructDef(ClassDecl cls) {
    _writeln('struct ${cls.name} {');
    for (final f in cls.constructorFields) {
      _writeln('  ${_varDecl(f.name, f.type)};');
    }
    for (final f in cls.bodyFields) {
      _writeln('  ${_varDecl(f.name, f.type)};');
    }
    _writeln('};');
    _writeln();
  }

  // ── function prototypes ───────────────────────────────────────────────────────

  void _emitFunctionPrototypes(List<Module> modules) {
    final isTestMode = modules
        .any((m) => m.functions.any((fn) => fn.isTest));
    var any = false;
    for (final mod in modules) {
      for (final fn in mod.functions) {
        if (fn.isExtern) continue;
        if (isTestMode && fn.name == 'main') continue;
        final isPrivate = fn.name.startsWith('_');
        _writeln('${isPrivate ? 'static ' : ''}${_fnSignature(fn, null, modPath: mod.path)};');
        any = true;
      }
      for (final cls in mod.classes) {
        for (final fn in cls.methods) {
          if (fn.isExtern) continue;
          final isPrivate = fn.name.startsWith('_');
          _writeln('${isPrivate ? 'static ' : ''}${_fnSignature(fn, cls.name)};');
          any = true;
        }
      }
    }
    if (any) _writeln();
  }

  // ── global variables ──────────────────────────────────────────────────────────

  void _emitGlobalVars(List<Module> modules) {
    var any = false;
    for (final mod in modules) {
      _setupModuleContext(mod);
      for (final v in mod.variables) {
        _emitGlobalVar(v, mod.path);
        any = true;
      }
    }
    if (any) _writeln();
  }

  void _emitGlobalVar(VariableDecl v, String modPath) {
    final cVarName = '${_modulePrefix(modPath)}__${v.name}';
    final isPrivate = v.name.startsWith('_');
    final isConst = v.isConst || v.keyword == TokenType.kVal;
    final prefix =
        '${isPrivate ? 'static ' : ''}${isConst ? 'const ' : ''}';

    // Infer type for := declarations.
    final type = v.type ?? _inferVarType(v.value);

    if (v.value != null) {
      // Class constructor call → zero-initialize the struct.
      if (v.value is Invocation) {
        final inv = v.value as Invocation;
        if (inv.function is Identifier) {
          final name = (inv.function as Identifier).name;
          if (_classes.containsKey(name)) {
            final effType = type ?? TypeName(name);
            _writeln('$prefix${_varDecl(cVarName, effType)} = {0};');
            return;
          }
        }
      }
      _writeln('$prefix${_varDecl(cVarName, type)} = ${_expr(v.value!)};');
    } else {
      _writeln('$prefix${_varDecl(cVarName, type)};');
    }
  }

  // ── function definitions ──────────────────────────────────────────────────────

  void _emitFunctionDefs(List<Module> modules, {String? entryModPath}) {
    // First pass: collect all @test functions across all modules (with their module).
    final testFns = <(Module, FunctionDecl)>[];
    for (final mod in modules) {
      for (final fn in mod.functions) {
        if (fn.isTest) testFns.add((mod, fn));
      }
    }
    final isTestMode = testFns.isNotEmpty;

    // Second pass: emit non-test functions (suppressing main() in test mode).
    for (final mod in modules) {
      _setupModuleContext(mod);
      for (final fn in mod.functions) {
        if (fn.isTest) continue;
        if (isTestMode && fn.name == 'main') continue; // test runner provides main
        _emitFunctionDef(fn, null, mod.path);
      }
      for (final cls in mod.classes) {
        for (final fn in cls.methods) {
          _emitFunctionDef(fn, cls.name, mod.path);
        }
      }
    }

    if (isTestMode) {
      _emitTestFunctions(testFns);
      _emitTestMain(testFns);
    } else if (entryModPath != null) {
      _emitMainWrapper(entryModPath);
    }
  }

  void _emitTestFunctions(List<(Module, FunctionDecl)> testFns) {
    for (final (mod, fn) in testFns) {
      _setupModuleContext(mod);
      _emitFunctionDef(fn, null, mod.path);
    }
  }

  void _emitTestMain(List<(Module, FunctionDecl)> testFns) {
    final tpfx = _testModulePrefix != null ? '${_testModulePrefix}__' : '';
    _writeln('int main(void) {');
    for (final (mod, fn) in testFns) {
      final cName = _cFnName(mod.path, fn.name);
      final nameSlice =
          '(__Slice_uint8_t){(uint8_t*)"${fn.name}", ${fn.name.length}}';
      _writeln('    ${tpfx}_test_begin($nameSlice);');
      _writeln('    $cName();');
      _writeln('    ${tpfx}_test_end();');
    }
    _writeln('    return ${tpfx}_report();');
    _writeln('}');
    _writeln();
  }

  /// Emit a thin C `main` that calls the entry module's namespaced main.
  void _emitMainWrapper(String entryModPath) {
    final entryMod = _moduleByPath[entryModPath];
    if (entryMod == null) return;
    final hasMain = entryMod.functions.any(
        (fn) => fn.name == 'main' && !fn.isExtern && !fn.isTest);
    if (!hasMain) return;
    final entryFnCName = _cFnName(entryModPath, 'main');
    _writeln('int main(void) { return $entryFnCName(); }');
    _writeln();
  }

  void _emitFunctionDef(FunctionDecl fn, String? className, String modPath) {
    if (fn.body == null || fn.isExtern) return; // forward declaration or extern

    // Set member-function context and reset scope.
    _currentClass = className;
    _typeParams = fn.typeParams;
    _scope.clear();

    if (className != null) {
      _scope['this'] = TypeRef(TypeName(className));
    }
    for (final p in fn.parameters) {
      _scope[p.name] = p.type;
    }

    final isPrivate = fn.name.startsWith('_');
    final prefix = isPrivate ? 'static ' : '';
    _writeln('$prefix${_fnSignature(fn, className, modPath: modPath)} {');
    _emitBlock(fn.body!);
    _writeln('}');
    _writeln();

    _currentClass = null;
    _typeParams = [];
    _scope.clear();
  }

  // ── helpers ───────────────────────────────────────────────────────────────────

  /// Build the C function signature (without trailing `;` or `{`).
  /// [modPath] prefixes the function name for module-level functions.
  String _fnSignature(FunctionDecl fn, String? className, {String? modPath}) {
    // Generic function: if return type is &T where T is a type param → void*
    String ret;
    final retType = fn.returnType;
    if (fn.typeParams.isNotEmpty &&
        retType is TypeRef &&
        retType.elementType is TypeName &&
        fn.typeParams.contains((retType.elementType as TypeName).name)) {
      ret = 'void*';
    } else {
      ret = _cType(retType);
    }
    final rawName = className != null ? '${className}_${fn.name}' : fn.name;
    final name = modPath != null ? '${_modulePrefix(modPath)}__$rawName' : rawName;
    final params = _buildParamList(fn, className);
    return '$ret $name($params)';
  }

  /// Build the comma-separated parameter list for a function.
  /// Member functions receive `ClassName* this` as the first parameter.
  /// Generic functions receive `size_t __sizeof_T` for each type param.
  String _buildParamList(FunctionDecl fn, String? className) {
    final parts = <String>[];
    if (className != null) parts.add('$className* this');
    for (final p in fn.parameters) {
      parts.add(_paramDecl(p));
    }
    for (final tp in fn.typeParams) {
      parts.add('size_t __sizeof_$tp');
    }
    return parts.isEmpty ? 'void' : parts.join(', ');
  }
}
