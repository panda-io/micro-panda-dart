import '../context.dart';
import '../type/type.dart';
import 'expression.dart';

class Identifier extends Expression {
  final String name;

  Identifier(this.name, super.position);

  @override
  void validate(Context context, Type? expected) {}
}
