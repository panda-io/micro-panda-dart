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
    // Collect all non-generic classes.
    final allNonGeneric = <ClassDecl>[];
    for (final mod in modules) {
      for (final cls in mod.classes) {
        if (cls.typeParams.isEmpty) allNonGeneric.add(cls);
      }
    }

    // Build embedded-field dependency graph.
    // If class A has a non-slice, non-pointer field of type B, B must be defined first.
    Set<String> fieldDeps(ClassDecl cls) {
      final deps = <String>{};
      void scan(Type? t) {
        if (t == null) return;
        if (t is TypeName && t.name != null && _classes.containsKey(t.name)) {
          deps.add(t.name!);
        } else if (t is TypeArray && !t.isSlice) {
          scan(t.elementType);
        }
        // TypeRef = pointer → only forward decl needed, no struct-definition dependency.
      }
      for (final f in cls.constructorFields) {
        scan(f.type);
      }
      for (final f in cls.bodyFields) {
        scan(f.type);
      }
      return deps;
    }

    // Topological sort (Kahn's algorithm).
    final nameToClass = <String, ClassDecl>{
      for (final c in allNonGeneric) c.name: c,
    };
    final inDegree = <String, int>{
      for (final c in allNonGeneric) c.name: 0,
    };
    final dependents = <String, List<String>>{};
    for (final cls in allNonGeneric) {
      for (final dep in fieldDeps(cls)) {
        if (nameToClass.containsKey(dep)) {
          inDegree[cls.name] = (inDegree[cls.name] ?? 0) + 1;
          dependents.putIfAbsent(dep, () => []).add(cls.name);
        }
      }
    }

    final queue = <ClassDecl>[
      ...allNonGeneric.where((c) => inDegree[c.name] == 0),
    ];
    final sorted = <ClassDecl>[];
    while (queue.isNotEmpty) {
      final cls = queue.removeAt(0);
      sorted.add(cls);
      for (final dep in dependents[cls.name] ?? <String>[]) {
        inDegree[dep] = inDegree[dep]! - 1;
        if (inDegree[dep] == 0) queue.add(nameToClass[dep]!);
      }
    }
    // Any remaining (e.g. mutual references via pointers) — emit in original order.
    final emitted = {for (final c in sorted) c.name};
    for (final cls in allNonGeneric) {
      if (!emitted.contains(cls.name)) sorted.add(cls);
    }

    // Emit structs in dependency order, flushing any generic specialization that a
    // non-generic class directly embeds (not via pointer) before emitting the class.
    final emittedSpecs = <String>{};

    void emitGenericDepsOf(ClassDecl cls) {
      void scanField(Type? t) {
        if (t == null) return;
        if (t is TypeName && t.typeArgs.isNotEmpty && t.name != null) {
          final specName = _specializedCName(t.name!, t.typeArgs);
          if (!emittedSpecs.contains(specName)) {
            final genCls = _classes[t.name!];
            if (genCls != null && genCls.typeParams.isNotEmpty) {
              emittedSpecs.add(specName);
              _emitSpecializedStructDef(genCls, t.typeArgs);
            }
          }
        } else if (t is TypeArray && !t.isSlice) {
          scanField(t.elementType);
        }
      }
      for (final f in cls.constructorFields) scanField(f.type);
      for (final f in cls.bodyFields) scanField(f.type);
    }

    for (final cls in sorted) {
      emitGenericDepsOf(cls);
      _emitStructDef(cls);
    }

    // Emit any remaining generic specializations not yet emitted above.
    for (final mod in modules) {
      for (final cls in mod.classes) {
        if (cls.typeParams.isNotEmpty) {
          for (final typeArgs in _genericInstantiations[cls.name] ?? <List<Type>>[]) {
            final specName = _specializedCName(cls.name, typeArgs);
            if (!emittedSpecs.contains(specName)) {
              _emitSpecializedStructDef(cls, typeArgs);
              emittedSpecs.add(specName);
            }
          }
        }
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

  /// Emit a specialized struct for a generic class with concrete type args.
  void _emitSpecializedStructDef(ClassDecl cls, List<Type> typeArgs) {
    final specName = _specializedCName(cls.name, typeArgs);
    _setTypeSubstitution(cls, typeArgs);
    _writeln('struct $specName {');
    for (final f in cls.constructorFields) {
      _writeln('  ${_varDecl(f.name, f.type)};');
    }
    for (final f in cls.bodyFields) {
      _writeln('  ${_varDecl(f.name, f.type)};');
    }
    _writeln('};');
    _writeln();
    _typeSubstitution = {};
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
        if (_fnHasUnerasableReturn(fn)) continue; // only specialized copies emitted later
        _writeln('${_fnPrefix(fn)}${_fnSignature(fn, null, modPath: mod.path)};');
        any = true;
      }
      for (final cls in mod.classes) {
        if (cls.typeParams.isEmpty) {
          for (final fn in cls.methods) {
            if (fn.isExtern) continue;
            if (_fnHasUnerasableReturn(fn)) continue; // only specialized copies emitted later
            _writeln('${_fnPrefix(fn)}${_fnSignature(fn, cls.name)};');
            any = true;
          }
        } else {
          // Generic class: one set of prototypes per instantiation.
          for (final typeArgs in _genericInstantiations[cls.name] ?? <List<Type>>[]) {
            final specName = _specializedCName(cls.name, typeArgs);
            _setTypeSubstitution(cls, typeArgs);
            for (final fn in cls.methods) {
              if (fn.isExtern) continue;
              _writeln('${_fnPrefix(fn)}${_fnSignature(fn, specName)};');
              any = true;
            }
            _typeSubstitution = {};
          }
        }
      }
    }
    // Emit specialized (monomorphized) function prototypes.
    for (final entry in _fnInstantiations.entries) {
      final info = _fnDeclByKey[entry.key]!;
      for (final typeArgs in entry.value) {
        _typeSubstitution = {
          for (var i = 0; i < info.fn.typeParams.length && i < typeArgs.length; i++)
            info.fn.typeParams[i]: typeArgs[i]
        };
        _writeln('${_fnPrefix(info.fn)}${_fnSignatureSpecialized(info.fn, info.className, info.modPath, typeArgs)};');
        _typeSubstitution = {};
        any = true;
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
    final isConst = v.isConst;
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
        if (_fnHasUnerasableReturn(fn)) continue; // only specialized copies emitted later
        _emitFunctionDef(fn, null, mod.path);
      }
      for (final cls in mod.classes) {
        if (cls.typeParams.isEmpty) {
          for (final fn in cls.methods) {
            if (_fnHasUnerasableReturn(fn)) continue; // only specialized copies emitted later
            _emitFunctionDef(fn, cls.name, null);
          }
        } else {
          // Generic class: emit one set of method definitions per instantiation.
          for (final typeArgs in _genericInstantiations[cls.name] ?? <List<Type>>[]) {
            final specName = _specializedCName(cls.name, typeArgs);
            _setTypeSubstitution(cls, typeArgs);
            for (final fn in cls.methods) {
              _emitFunctionDef(fn, specName, null);
            }
            _typeSubstitution = {};
          }
        }
      }
    }

    // Emit all specialized (monomorphized) function definitions.
    _emitFunctionDefsSpecialized();

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

  /// Emit file-scope statics for argc/argv so @extern("__mp_argc") and
  /// @extern("__mp_argv[{i}]") are visible to all function definitions above main.
  void _emitArgcArgvStatics(String? entryModPath) {
    if (entryModPath == null) return;
    final entryMod = _moduleByPath[entryModPath];
    if (entryMod == null) return;
    final hasMain = entryMod.functions.any(
        (fn) => fn.name == 'main' && !fn.isExtern && !fn.isTest);
    if (!hasMain) return;
    // Only emit statics for non-test builds; test runner provides its own main.
    if (entryMod.functions.any((fn) => fn.isTest)) return;
    _writeln('static int32_t __mp_argc = 0;');
    _writeln('static char** __mp_argv = NULL;');
    _writeln();
  }

  /// Emit a thin C `main` that calls the entry module's namespaced main.
  void _emitMainWrapper(String entryModPath) {
    final entryMod = _moduleByPath[entryModPath];
    if (entryMod == null) return;
    final entryFn = entryMod.functions.where(
        (fn) => fn.name == 'main' && !fn.isExtern && !fn.isTest).firstOrNull;
    if (entryFn == null) return;
    final entryFnCName = _cFnName(entryModPath, 'main');
    // If main() returns a value, forward it as the C exit code; otherwise return 0.
    final body = entryFn.returnType != null
        ? 'return $entryFnCName();'
        : '$entryFnCName(); return 0;';
    _writeln('int main(int argc, char** argv) { __mp_argc = argc; __mp_argv = argv; $body }');
    _writeln();
  }

  void _emitFunctionDef(FunctionDecl fn, String? className, String? modPath) {
    if (fn.body == null || fn.isExtern) return; // forward declaration or extern

    // Set member-function context and reset scope.
    _currentClass = className;
    _typeParams = fn.typeParams;
    _scope.clear();
    _currentFnReturnType = fn.returnType;

    if (className != null) {
      _scope['this'] = TypeRef(TypeName(className));
    }
    for (final p in fn.parameters) {
      _scope[p.name] = p.type;
    }

    _writeln('${_fnPrefix(fn)}${_fnSignature(fn, className, modPath: modPath)} {');
    _emitBlock(fn.body!);
    _writeln('}');
    _writeln();

    _currentClass = null;
    _typeParams = [];
    _scope.clear();
    _currentFnReturnType = null;
  }

  /// Emit a monomorphized copy of a generic function for a specific type-arg set.
  void _emitFunctionDefSpecialized(
      FunctionDecl fn, String? className, String? modPath, List<Type> typeArgs) {
    if (fn.body == null || fn.isExtern) return;

    _currentClass = className;
    _typeParams = []; // no erasure — all types are concrete via substitution
    _scope.clear();
    _typeSubstitution = {
      for (var i = 0; i < fn.typeParams.length && i < typeArgs.length; i++)
        fn.typeParams[i]: typeArgs[i]
    };
    _currentFnReturnType = fn.returnType;

    if (className != null) {
      _scope['this'] = TypeRef(TypeName(className));
    }
    for (final p in fn.parameters) {
      _scope[p.name] = p.type;
    }

    _writeln('${_fnPrefix(fn)}${_fnSignatureSpecialized(fn, className, modPath, typeArgs)} {');
    _emitBlock(fn.body!);
    _writeln('}');
    _writeln();

    _currentClass = null;
    _typeParams = [];
    _typeSubstitution = {};
    _scope.clear();
    _currentFnReturnType = null;
  }

  /// Emit all specialized function definitions collected during instantiation analysis.
  void _emitFunctionDefsSpecialized() {
    for (final entry in _fnInstantiations.entries) {
      final info = _fnDeclByKey[entry.key]!;
      for (final typeArgs in entry.value) {
        if (info.modPath != null) {
          final mod = _moduleByPath[info.modPath!];
          if (mod != null) _setupModuleContext(mod);
        }
        _emitFunctionDefSpecialized(info.fn, info.className, info.modPath, typeArgs);
      }
    }
  }

  String _fnSignatureSpecialized(
      FunctionDecl fn, String? className, String? modPath, List<Type> typeArgs) {
    final baseKey = className != null
        ? '${className}_${fn.name}'
        : _cFnName(modPath!, fn.name);
    final specName = _fnSpecializedCName(baseKey, typeArgs);
    final ret = _cType(fn.returnType); // _typeSubstitution active → T→concrete
    final params = _buildParamListSpecialized(fn, className);
    return '$ret $specName($params)';
  }

  String _buildParamListSpecialized(FunctionDecl fn, String? className) {
    final parts = <String>[];
    if (className != null) parts.add('$className* this');
    for (final p in fn.parameters) {
      parts.add(_paramDecl(p));
    }
    // No __sizeof_T params for specialized (concrete) functions.
    return parts.isEmpty ? 'void' : parts.join(', ');
  }

  // ── helpers ───────────────────────────────────────────────────────────────────

  /// Return the C storage/qualifier prefix for a function (`static inline `,
  /// `static `, or empty string).
  String _fnPrefix(FunctionDecl fn) {
    if (fn.isInline) return 'static inline ';
    if (fn.name.startsWith('_')) return 'static ';
    return '';
  }

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
