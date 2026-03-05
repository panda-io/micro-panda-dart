import '../context.dart';
import '../type/type.dart';
import '../type/type_name.dart';
import '../type/type_ref.dart';
import 'expression.dart';

class This extends Expression {
  This(super.position);

  @override
  void validate(Context context, Type? expected) {
    if (context.currentClass == null) {
      context.error(position, "'this' used outside of a class method");
      return;
    }
    type = TypeRef(TypeName(context.currentClass!));
  }
}
