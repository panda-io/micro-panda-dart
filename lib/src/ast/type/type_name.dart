import 'type.dart';

class TypeName extends Type {
  String? name;
  String? qualifiedName;
  bool isEnum = false;
  String? selector;

  TypeName(this.name, {
    this.qualifiedName,
    this.isEnum = false,
    this.selector,
    int position = 0,
  }) : super(position);

  @override
  bool equal(Type type) {
    if (type is TypeName) {
      return (qualifiedName?.isNotEmpty ?? false) && type.qualifiedName == qualifiedName;
    }
    return false;
  }
}