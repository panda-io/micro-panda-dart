import '../context.dart';
import '../expression/expression.dart';
import 'statement.dart';

class ReturnStatement extends Statement {
  final Expression? value;

  ReturnStatement(this.value, super.position);

  @override
  void validate(Context context) {
    if (value != null) {
      value!.validate(context, context.returnType);
      if (context.returnType != null &&
          !context.typesCompatible(value!.type, context.returnType)) {
        context.error(position,
            "return type mismatch: expected ${Context.typeName(context.returnType)}, "
            "got ${Context.typeName(value!.type)}");
      }
    } else if (context.returnType != null) {
      context.error(position, "missing return value");
    }
  }
}
