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
    if (type is TypeName) return type.name ?? 'void';
    if (type is TypeArray) {
      if (type.isSlice) return '__Slice_${_cType(type.elementType)}';
      return _cType(type.elementType); // fixed array: caller appends dims
    }
    return 'void';
  }

  /// Array dimension suffix string, e.g. "[10][4]". Only for fixed arrays.
  String _arrayDims(Type? type) {
    if (type is TypeArray && type.isFixed) {
      return type.dimension.map((d) => '[$d]').join();
    }
    return '';
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
