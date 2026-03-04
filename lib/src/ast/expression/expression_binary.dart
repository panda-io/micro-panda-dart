import '../../token/token_type.dart';
import '../context.dart';
import '../type/type.dart';
import 'expression.dart';

class Binary extends Expression {
  final Expression left;
  final TokenType operator_;
  final Expression right;

  Binary(this.left, this.operator_, this.right, super.position);

  @override
  void validate(Context context, Type? expected) {}
}
