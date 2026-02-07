import 'package:micro_panda/src/ast/node/node.dart';
import 'package:micro_panda/src/token/token_type.dart';
import 'type_array.dart';
import 'type_builtin.dart';
import 'type_function.dart';
import 'type_name.dart';

abstract class Type extends Node {
  Type(super.position);
  bool equal(Type type);

  // Static common types
  static final TypeBuiltin typeBool = TypeBuiltin(TokenType.typeBool);
  static final TypeBuiltin typeU8 = TypeBuiltin(TokenType.typeUint8);
  static final TypeBuiltin typeU32 = TypeBuiltin(TokenType.typeUint32);
  static final TypeBuiltin typeI32 = TypeBuiltin(TokenType.typeInt32);
  static final TypeBuiltin typeF16 = TypeBuiltin(TokenType.typeFloat16);
  static final TypeBuiltin typeF32 = TypeBuiltin(TokenType.typeFloat32);

  bool get isInteger => this is TypeBuiltin && (this as TypeBuiltin).token.isIntegerType;

  bool get isFloat => this is TypeBuiltin && (this as TypeBuiltin).token.isFloatType;

  bool get isNumber => isInteger || isFloat;

  bool get isBool => this is TypeBuiltin && (this as TypeBuiltin).token == TokenType.typeBool;

  bool get isClass => this is TypeName && !(this as TypeName).isEnum;

  bool get isEnum => this is TypeName && (this as TypeName).isEnum;

  bool get isArray => this is TypeArray;

  bool get isFunction => this is TypeFunction;

  int get builtinBits => this is TypeBuiltin ? (this as TypeBuiltin).token.bits : 0;

  int get builtinSize => this is TypeBuiltin ? (this as TypeBuiltin).token.size : 0;
}