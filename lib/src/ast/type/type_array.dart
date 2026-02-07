import 'type.dart';

class TypeArray extends Type {
  Type elementType;
  List<int> dimension = [];

  TypeArray(this.elementType, [super.position = 0]);

  @override
  bool equal(Type type) {
    if (type is TypeArray) {
      if (!elementType.equal(type.elementType)) {
        return false;
      }

      if (dimension.length == type.dimension.length) {
        for (int i = 0; i < dimension.length; i++) {
          if (dimension[i] != type.dimension[i]) return false;
        }
        return true;
      }
    }
    return false;
  }
}
