import '../context.dart';
import '../type/type.dart';
import 'expression.dart';

class Sizeof extends Expression {
  final Type target;

  Sizeof(this.target, super.position);

  @override
  void validate(Context context, Type? expected) {}
}
