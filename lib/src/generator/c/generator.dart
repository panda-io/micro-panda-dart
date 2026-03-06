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

  // ── symbol tables (populated before generation) ───────────────────────────────
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

  // ── type-tracking scope ───────────────────────────────────────────────────────
  /// Types of global variables (name → Type).
  final Map<String, Type?> _globals = {};

  /// Types of variables in the current function scope (name → Type).
  final Map<String, Type?> _scope = {};

  // ── entry point ───────────────────────────────────────────────────────────────

  String generate(List<Module> modules) {
    _buildSymbolTables(modules);
    _emitIncludes();
    _emitSliceTypedefs();
    _emitForwardDeclarations(modules);
    _emitEnumDefs(modules);
    _emitStructDefs(modules);
    _emitFunctionPrototypes(modules);
    _emitGlobalVars(modules);
    _emitFunctionDefs(modules);
    return _out.toString();
  }

  // ── symbol-table construction ─────────────────────────────────────────────────

  void _buildSymbolTables(List<Module> modules) {
    for (final mod in modules) {
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
      }
      for (final cls in mod.classes) {
        for (final fn in cls.methods) {
          if (fn.isExtern) _externFns['${cls.name}_${fn.name}'] = fn;
        }
      }
    }
    _collectSliceTypes(modules);
    // Collect @include directives, preserving order and deduplicating
    final seen = <String>{};
    for (final mod in modules) {
      for (final inc in mod.includes) {
        if (seen.add(inc)) _moduleIncludes.add(inc);
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
        for (final f in cls.constructorFields) {
          register(f.type);
        }
        for (final f in cls.bodyFields) {
          register(f.type);
        }
        for (final fn in cls.methods) {
          register(fn.returnType);
          for (final p in fn.parameters) {
            register(p.type);
          }
        }
      }
      for (final fn in mod.functions) {
        register(fn.returnType);
        for (final p in fn.parameters) { register(p.type); }
      }
      for (final v in mod.variables) {
        register(v.type);
      }
    }
  }

  /// Best-effort type inference from a literal initializer (for := declarations).
  Type? _inferVarType(Expression? value) {
    if (value == null) return null;
    if (value is Literal) {
      return switch (value.tokenType) {
        TokenType.intLiteral => TypeBuiltin(TokenType.typeInt32),
        TokenType.floatLiteral => TypeBuiltin(TokenType.typeFloat32),
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
    if (value is Invocation && value.function is Identifier) {
      final name = (value.function as Identifier).name;
      if (_classes.containsKey(name)) return TypeName(name);
      // Generic call with type args → return type is pointer to first type arg
      if (value.typeArgs.isNotEmpty) return TypeRef(value.typeArgs.first);
    }
    return null;
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
    if (_sliceElementTypes.isEmpty) return;
    for (final elemCType in _sliceElementTypes) {
      _writeln('typedef struct { $elemCType* ptr; size_t size; } __Slice_$elemCType;');
    }
    _writeln();
  }

  // ── forward declarations ──────────────────────────────────────────────────────

  void _emitForwardDeclarations(List<Module> modules) {
    var any = false;
    for (final mod in modules) {
      for (final cls in mod.classes) {
        _writeln('typedef struct ${cls.name} ${cls.name};');
        any = true;
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
