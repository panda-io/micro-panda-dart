import '../../token/token_type.dart';
import '../context.dart';
import '../type/type.dart';
import '../type/type_array.dart';
import '../type/type_builtin.dart';
import '../type/type_ref.dart';
import 'expression.dart';

class Literal extends Expression {
  final TokenType tokenType;
  final String value;

  Literal(this.tokenType, this.value, super.position);

  @override
  void validate(Context context, Type? expected) {
    switch (tokenType) {
      case TokenType.boolLiteral:
        type = TypeBuiltin(TokenType.typeBool);
      case TokenType.charLiteral:
        type = TypeBuiltin(TokenType.typeUint8);
      case TokenType.stringLiteral:
        final arr = TypeArray(TypeBuiltin(TokenType.typeUint8));
        arr.dimension.add(0); // slice
        type = arr;
      case TokenType.typeNull:
        // null is valid for any reference type; default to &void
        type = expected is TypeRef ? expected : TypeRef(TypeBuiltin(TokenType.typeVoid));
      case TokenType.intLiteral:
        // adopt expected if integer or fixed, else default to i32
        if (expected is TypeBuiltin &&
            (expected.token.isIntegerType || expected.token.isFixedType)) {
          type = expected;
        } else {
          type = TypeBuiltin(TokenType.typeInt32);
        }
      case TokenType.floatLiteral:
        // adopt expected if f32 or fixed, else default to f32
        if (expected is TypeBuiltin &&
            (expected.token.isFloatType || expected.token.isFixedType)) {
          type = expected;
        } else {
          type = TypeBuiltin(TokenType.typeFloat);
        }
      default:
        type = null;
    }
  }
}
