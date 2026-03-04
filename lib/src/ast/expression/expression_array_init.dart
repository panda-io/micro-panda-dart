import '../context.dart';
import '../type/type.dart';
import 'expression.dart';

/// Array literal initializer: [1, 2, 3]
class ArrayInitializer extends Expression {
  final List<Expression> elements;

  ArrayInitializer(this.elements, super.position);

  @override
  void validate(Context context, Type? expected) {}
}
