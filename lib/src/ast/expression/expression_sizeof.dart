import '../../token/token_type.dart';
import '../context.dart';
import '../type/type.dart';
import '../type/type_builtin.dart';
import 'expression.dart';

class Sizeof extends Expression {
  final Type target;

  Sizeof(this.target, super.position);

  @override
  void validate(Context context, Type? expected) {
    isConst = true;
    type = TypeBuiltin(TokenType.typeUint64); // size_t ≈ u64
  }
}
