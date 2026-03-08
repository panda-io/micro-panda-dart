import 'type.dart';

class TypeName extends Type {
  String? name;
  String? qualifiedName;
  @override
  bool isEnum = false;
  String? selector;
  List<Type> typeArgs;  // concrete type arguments for generic class instantiation

  TypeName(this.name, {
    this.qualifiedName,
    this.isEnum = false,
    this.selector,
    this.typeArgs = const [],
    int position = 0,
  }) : super(position);

  @override
  bool equal(Type type) {
    if (type is TypeName) {
      if ((qualifiedName?.isNotEmpty ?? false) && type.qualifiedName == qualifiedName) return true;
      return name != null && name == type.name;
    }
    return false;
  }
}