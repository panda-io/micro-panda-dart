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
  /// Named constant dims (stored as dimension == -1) are resolved via [_evalConstExpr].
  String _arrayDims(Type? type) {
    if (type is TypeArray && type.isFixed) {
      final buf = StringBuffer();
      for (int i = 0; i < type.dimension.length; i++) {
        final d = type.dimension[i];
        if (d == -1 && i < type.dimExprs.length && type.dimExprs[i] != null) {
          final val = _evalConstExpr(type.dimExprs[i]);
          buf.write('[${val ?? 1}]');
        } else {
          buf.write('[$d]');
        }
      }
      return buf.toString();
    }
    return '';
  }

  /// Evaluate a constant expression to an integer using [_constInts] for name lookups.
  /// Handles: integer literals, named constants, unary minus, and binary +/-/*//%.
  /// Returns null if the expression cannot be fully resolved to a constant.
  int? _evalConstExpr(Expression? expr) {
    if (expr == null) return null;
    if (expr is Literal && expr.tokenType == TokenType.intLiteral) {
      return int.tryParse(expr.value);
    }
    if (expr is Identifier) {
      return _constInts[expr.name];
    }
    if (expr is Unary && expr.operator_ == TokenType.minus) {
      final v = _evalConstExpr(expr.expression);
      return v != null ? -v : null;
    }
    if (expr is Binary) {
      final a = _evalConstExpr(expr.left);
      final b = _evalConstExpr(expr.right);
      if (a == null || b == null) return null;
      return switch (expr.operator_) {
        TokenType.plus  => a + b,
        TokenType.minus => a - b,
        TokenType.mul   => a * b,
        TokenType.div   => b != 0 ? a ~/ b : null,
        TokenType.rem   => b != 0 ? a % b : null,
        _ => null,
      };
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
