import '../expression/expression.dart';
import 'declaration.dart';
import 'parameter.dart';

/// A single member of an enum.
class EnumMember {
  final String name;

  /// For value enums: the explicit integer value (e.g. Add = 1).
  final Expression? value;

  /// For tagged enums: the field list (e.g. Binary(left: &Expr, op: OpCode, right: &Expr)).
  /// Null for plain and value enums.
  final List<Parameter>? fields;

  final int position;

  EnumMember(this.name, {this.value, this.fields, required this.position});

  bool get isTagged => fields != null;
  bool get hasValue => value != null;
}

class EnumDecl extends Declaration {
  final List<EnumMember> members;

  EnumDecl(super.name, this.members, super.position);
}
