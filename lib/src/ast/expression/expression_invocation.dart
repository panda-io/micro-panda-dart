import '../context.dart';
import '../type/type.dart';
import 'expression.dart';

class Invocation extends Expression {
  final Expression function;
  final List<Expression> arguments;
  final List<Type> typeArgs;  // generic type arguments, e.g. [TypeName('Point')]

  Invocation(this.function, this.arguments, super.position, {this.typeArgs = const []});

  @override
  void validate(Context context, Type? expected) {}
}
