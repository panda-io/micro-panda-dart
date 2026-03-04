import '../context.dart';
import '../type/type.dart';
import 'expression.dart';

class This extends Expression {
  This(super.position);

  @override
  void validate(Context context, Type? expected) {}
}
