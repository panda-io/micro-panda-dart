import '../../token/token_type.dart';
import '../context.dart';
import '../type/type.dart';
import 'expression.dart';

class Literal extends Expression {
  final TokenType tokenType;
  final String value;

  Literal(this.tokenType, this.value, super.position);

  @override
  void validate(Context context, Type? expected) {}
}
