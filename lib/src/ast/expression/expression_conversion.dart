import '../context.dart';
import '../type/type.dart';
import 'expression.dart';

/// Explicit type cast: i64(x), f32(val)
class Conversion extends Expression {
  final Type targetType;
  final Expression value;

  Conversion(this.targetType, this.value, super.position);

  @override
  void validate(Context context, Type? expected) {}
}
