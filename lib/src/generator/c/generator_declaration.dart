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
    var any = false;
    for (final mod in modules) {
      for (final fn in mod.functions) {
        final isPrivate = fn.name.startsWith('_');
        _writeln('${isPrivate ? 'static ' : ''}${_fnSignature(fn, null)};');
        any = true;
      }
      for (final cls in mod.classes) {
        for (final fn in cls.methods) {
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
      for (final v in mod.variables) {
        _emitGlobalVar(v);
        any = true;
      }
    }
    if (any) _writeln();
  }

  void _emitGlobalVar(VariableDecl v) {
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
            _writeln('$prefix${_varDecl(v.name, effType)} = {0};');
            return;
          }
        }
      }
      _writeln('$prefix${_varDecl(v.name, type)} = ${_expr(v.value!)};');
    } else {
      _writeln('$prefix${_varDecl(v.name, type)};');
    }
  }

  // ── function definitions ──────────────────────────────────────────────────────

  void _emitFunctionDefs(List<Module> modules) {
    for (final mod in modules) {
      for (final fn in mod.functions) {
        _emitFunctionDef(fn, null);
      }
      for (final cls in mod.classes) {
        for (final fn in cls.methods) {
          _emitFunctionDef(fn, cls.name);
        }
      }
    }
  }

  void _emitFunctionDef(FunctionDecl fn, String? className) {
    if (fn.body == null) return; // forward declaration only

    // Set member-function context and reset scope.
    _currentClass = className;
    _scope.clear();

    if (className != null) {
      _scope['this'] = TypeRef(TypeName(className));
    }
    for (final p in fn.parameters) {
      _scope[p.name] = p.type;
    }

    final isPrivate = fn.name.startsWith('_');
    final prefix = isPrivate ? 'static ' : '';
    _writeln('$prefix${_fnSignature(fn, className)} {');
    _emitBlock(fn.body!);
    _writeln('}');
    _writeln();

    _currentClass = null;
    _scope.clear();
  }

  // ── helpers ───────────────────────────────────────────────────────────────────

  /// Build the C function signature (without trailing `;` or `{`).
  String _fnSignature(FunctionDecl fn, String? className) {
    final ret = _cType(fn.returnType);
    final name = className != null ? '${className}_${fn.name}' : fn.name;
    final params = _buildParamList(fn, className);
    return '$ret $name($params)';
  }

  /// Build the comma-separated parameter list for a function.
  /// Member functions receive `ClassName* this` as the first parameter.
  String _buildParamList(FunctionDecl fn, String? className) {
    final parts = <String>[];
    if (className != null) parts.add('$className* this');
    for (final p in fn.parameters) {
      parts.add(_paramDecl(p));
    }
    return parts.isEmpty ? 'void' : parts.join(', ');
  }
}
