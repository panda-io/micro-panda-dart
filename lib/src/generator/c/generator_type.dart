part of 'generator.dart';

extension GeneratorType on CGenerator {
  // ── type → C string ───────────────────────────────────────────────────────────

  /// Map a Micro Panda type to a C type string.
  /// For array types, returns only the element type — append [_arrayDims] separately.
  String _cType(Type? type) {
    if (type == null) return 'void';
    if (type is TypeBuiltin) {
      return switch (type.token) {
        TokenType.typeBool    => 'bool',
        TokenType.typeInt8    => 'int8_t',
        TokenType.typeInt16   => 'int16_t',
        TokenType.typeInt32   => 'int32_t',
        TokenType.typeInt64   => 'int64_t',
        TokenType.typeUint8   => 'uint8_t',
        TokenType.typeUint16  => 'uint16_t',
        TokenType.typeUint32  => 'uint32_t',
        TokenType.typeUint64  => 'uint64_t',
        TokenType.typeFloat => 'float',
        TokenType.typeFixed   => 'int32_t',
        TokenType.typeVoid    => 'void',
        _                     => 'void',
      };
    }
    if (type is TypeRef)  return '${_cType(type.elementType)}*';
    if (type is TypeName) {
      // Generic instantiation: ArrayList<i32> → ArrayList_int32_t
      if (type.typeArgs.isNotEmpty) {
        return _specializedCName(type.name ?? 'void', type.typeArgs);
      }
      // Type substitution: T → concrete type (inside specialized method bodies)
      final sub = _typeSubstitution[type.name];
      if (sub != null) return _cType(sub);
      return type.name ?? 'void';
    }
    if (type is TypeArray) {
      if (type.isSlice) return '__Slice_${_cType(type.elementType)}';
      return _cType(type.elementType); // fixed array: caller appends dims
    }
    return 'void';
  }

  /// Array dimension suffix string, e.g. "[10][4]". Only for fixed arrays.
  /// Named constant dims (stored as dimension == -1) are resolved via [_constInts].
  String _arrayDims(Type? type) {
    if (type is TypeArray && type.isFixed) {
      final buf = StringBuffer();
      for (int i = 0; i < type.dimension.length; i++) {
        final d = type.dimension[i];
        if (d == -1 && i < type.dimNames.length && type.dimNames[i] != null) {
          final val = _evalDimExpr(type.dimNames[i]!);
          buf.write('[${val ?? 1}]');
        } else {
          buf.write('[$d]');
        }
      }
      return buf.toString();
    }
    return '';
  }

  /// Evaluate a dimension expression (e.g. "SYS_MAX_TASKS + APP_MAX_TASKS") using [_constInts].
  int? _evalDimExpr(String expr) {
    expr = expr.trim();
    // Single name or integer
    if (!expr.contains('+') && !expr.contains('-')) {
      return _constInts[expr] ?? int.tryParse(expr);
    }
    // Sum: find last '+' or '-' outside of negative literals
    final plusIdx = expr.lastIndexOf('+');
    final minusIdx = expr.lastIndexOf('-');
    final splitIdx = plusIdx > minusIdx ? plusIdx : minusIdx;
    if (splitIdx > 0) {
      final op = expr[splitIdx];
      final a = _evalDimExpr(expr.substring(0, splitIdx));
      final b = _evalDimExpr(expr.substring(splitIdx + 1));
      if (a != null && b != null) return op == '+' ? a + b : a - b;
    }
    return null;
  }

  /// Full C variable declaration fragment: "int32_t name" or "uint8_t buf[32]".
  String _varDecl(String name, Type? type) {
    // Erase generic type parameters: &T → void*, T → void
    if (type is TypeRef && type.elementType is TypeName) {
      final n = (type.elementType as TypeName).name;
      if (n != null && _typeParams.contains(n)) return 'void* $name';
    }
    if (type is TypeArray) {
      if (type.isSlice) return '${_cType(type)} $name'; // __Slice_T name
      return '${_cType(type.elementType)} $name${_arrayDims(type)}'; // fixed array
    }
    return '${_cType(type)} $name';
  }

  /// C function parameter declaration from a Parameter node.
  String _paramDecl(Parameter p) => _varDecl(p.name, p.type);
}
