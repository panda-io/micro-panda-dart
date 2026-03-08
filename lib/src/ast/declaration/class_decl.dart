import '../../token/token_type.dart';
import '../expression/expression.dart';
import '../type/type.dart';
import 'declaration.dart';
import 'function_decl.dart';
import 'parameter.dart';

/// A constructor parameter that also becomes a class field.
/// keyword is kVal (immutable) or kVar (mutable).
class ClassField extends Parameter {
  final TokenType keyword;
  final Expression? defaultValue;

  ClassField(this.keyword, super.name, super.type, this.defaultValue, super.position);

  bool get isMutable => keyword == TokenType.kVar;
}

/// A field declared inside the class body (not a constructor param).
class BodyField {
  final TokenType keyword;
  final String name;
  final Type? type;
  final Expression? defaultValue;
  final int position;

  BodyField(this.keyword, this.name, this.type, this.defaultValue, this.position);
}

class ClassDecl extends Declaration {
  /// Parameters in the class(...) constructor declaration that become fields.
  final List<ClassField> constructorFields;

  /// Additional fields declared in the class body.
  final List<BodyField> bodyFields;

  /// Member functions declared in the class body.
  final List<FunctionDecl> methods;

  /// Generic type parameter names, e.g. ['T', 'U'].
  final List<String> typeParams;

  ClassDecl(
    super.name,
    this.constructorFields,
    this.bodyFields,
    this.methods,
    super.position, {
    this.typeParams = const [],
  });
}
