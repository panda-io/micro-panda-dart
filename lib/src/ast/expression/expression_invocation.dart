import '../context.dart';
import '../type/type.dart';
import 'expression.dart';

class Invocation extends Expression {
  final Expression function;
  final List<Expression> arguments;

  Invocation(this.function, this.arguments, super.position);

  @override
  void validate(Context context, Type? expected) {}
}
