import 'type.dart';

/// A reference type: &T
class TypeRef extends Type {
  Type elementType;

  TypeRef(this.elementType, [super.position = 0]);

  @override
  bool equal(Type type) =>
      type is TypeRef && elementType.equal(type.elementType);
}
