import 'type.dart';

class TypeArray extends Type {
  Type elementType;
  List<int> dimension = [];

  TypeArray(this.elementType, [super.position = 0]);

  /// True for unsized `T[]` — stored as a fat pointer { ptr, size } in C.
  bool get isSlice => dimension.length == 1 && dimension[0] == 0;

  /// True for a fixed-size inline array `T[N]`.
  bool get isFixed => dimension.isNotEmpty && dimension[0] > 0;

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
