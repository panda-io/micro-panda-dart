import '../context.dart';
import '../type/type.dart';
import 'expression.dart';

class MemberAccess extends Expression {
  final Expression parent;
  final String member;

  MemberAccess(this.parent, this.member, super.position);

  @override
  void validate(Context context, Type? expected) {}
}
