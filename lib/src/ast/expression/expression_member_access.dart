import '../../token/token_type.dart';
import '../context.dart';
import '../type/type.dart';
import '../type/type_builtin.dart';
import '../type/type_name.dart';
import '../type/type_ref.dart';
import 'expression.dart';
import 'expression_identifier.dart';

class MemberAccess extends Expression {
  final Expression parent;
  final String member;

  MemberAccess(this.parent, this.member, super.position);

  @override
  void validate(Context context, Type? expected) {
    parent.validate(context, null);

    // Enum member: Color.Red → type is the enum itself (u32-like)
    if (parent is Identifier) {
      final name = (parent as Identifier).name;
      if (context.enums.containsKey(name)) {
        final enm = context.enums[name]!;
        final hasMember = enm.members.any((m) => m.name == member);
        if (!hasMember) {
          context.error(position, "enum '$name' has no member '$member'");
        }
        type = TypeBuiltin(TokenType.typeInt32); // enum values are int-like
        return;
      }
    }

    // Struct/class field: dereference pointer if needed
    var parentType = parent.type;
    if (parentType is TypeRef) parentType = parentType.elementType;

    if (parentType is TypeName) {
      final cls = context.classes[parentType.name];
      if (cls != null) {
        // Look for field in constructor fields and body fields
        for (final f in cls.constructorFields) {
          if (f.name == member) {
            type = f.type;
            return;
          }
        }
        for (final f in cls.bodyFields) {
          if (f.name == member) {
            type = f.type;
            return;
          }
        }
        // Look for method
        for (final m in cls.methods) {
          if (m.name == member) {
            type = null; // method reference
            return;
          }
        }
        context.error(position,
            "'${parentType.name}' has no field '$member'");
        return;
      }
    }

    // Could not resolve — leave type null (avoid cascading errors)
    type = null;
  }
}
