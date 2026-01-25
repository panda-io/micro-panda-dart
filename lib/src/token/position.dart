class Position {
  final SourceFile file;
  final int offset;

  const Position(this.file, this.offset);

  @override
  String toString() {
    final (line, column) = file.getLocation(offset);
    return "${file.name}:$line:$column";
  }

  int get globalOffset => file.baseOffset + offset;
}

class SourceFile {
  final String name;
  int baseOffset;
  int size;
  
  final List<int> _lineOffsets = [0];

  SourceFile(this.name, this.baseOffset, this.size);

  void addLine(int offset) {
    if (offset > _lineOffsets.last) {
      _lineOffsets.add(offset);
    }
  }

  int get lineCount => _lineOffsets.length;

  (int line, int column) getLocation(int offset) {
    if (offset < 0 || offset > size) return (0, 0);

    int low = 0;
    int high = _lineOffsets.length;
    
    while (low < high) {
      int mid = low + (high - low) ~/ 2;
      if (_lineOffsets[mid] <= offset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    
    int lineIndex = low - 1;
    int line = lineIndex + 1;
    int column = offset - _lineOffsets[lineIndex] + 1;
    
    return (line, column);
  }

  Position getPosition(int offset) => Position(this, offset);
}

class SourceSet {
  final List<SourceFile> _files = [];
  int _currentGlobalOffset = 0;

  SourceFile addFile(String name, int size) {
    if (_files.any((f) => f.name == name)) {
      throw ArgumentError('File $name already added to SourceSet');
    }

    final newFile = SourceFile(name, _currentGlobalOffset, size);
    _currentGlobalOffset += size + 1; 
    _files.add(newFile);
    return newFile;
  }

  SourceFile? getFile(int globalOffset) {
    for (var file in _files) {
      if (globalOffset >= file.baseOffset && 
          globalOffset <= file.baseOffset + file.size) {
        return file;
      }
    }
    return null;
  }

  Position? getPosition(int globalOffset) {
    final file = getFile(globalOffset);
    if (file == null) return null;
    return file.getPosition(globalOffset - file.baseOffset);
  }
}