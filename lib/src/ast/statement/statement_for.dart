import '../../token/token_type.dart';
import '../context.dart';
import '../expression/expression.dart';
import '../type/type.dart';
import '../type/type_array.dart';
import '../type/type_builtin.dart';
import 'statement.dart';

/// for i in range(start, end)
class ForRangeStatement extends Statement {
  final String variable;
  final Expression start;
  final Expression end;
  final Statement body;

  ForRangeStatement(this.variable, this.start, this.end, this.body, super.position);

  @override
  void validate(Context context) {
    start.validate(context, TypeBuiltin(TokenType.typeInt32));
    end.validate(context, TypeBuiltin(TokenType.typeInt32));
    final loopCtx = context.childScope();
    loopCtx.declare(variable, TypeBuiltin(TokenType.typeInt32), position);
    body.validate(loopCtx);
  }
}

/// for item in iterable
/// for index, item in iterable
class ForInStatement extends Statement {
  final String? index;   // null if single-variable form
  final String item;
  final Expression iterable;
  final Statement body;

  ForInStatement(this.index, this.item, this.iterable, this.body, super.position);

  @override
  void validate(Context context) {
    iterable.validate(context, null);
    final loopCtx = context.childScope();
    // Determine element type from iterable
    Type? elemType;
    if (iterable.type is TypeArray) {
      elemType = (iterable.type as TypeArray).elementType;
    }
    loopCtx.declare(item, elemType, position);
    if (index != null) {
      loopCtx.declare(index!, TypeBuiltin(TokenType.typeUint64), position);
    }
    body.validate(loopCtx);
  }
}
