import '../context.dart';
import '../type/type.dart';
import 'expression.dart';

class Subscript extends Expression {
  final Expression parent;
  final Expression index;

  Subscript(this.parent, this.index, super.position);

  @override
  void validate(Context context, Type? expected) {}
}
