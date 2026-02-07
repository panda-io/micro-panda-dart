import 'package:micro_panda/src/token/position.dart';

class RuneReader {
  static const int eof = -1;

  final SourceFile file;
  final String _source;
  int _offset = 0;
  int _cutIn = 0;

  RuneReader(this.file, this._source);

  int consume() {
    if (isAtEnd) return eof;
    
    int rune = _source.codeUnitAt(_offset);
    
    if (rune == 10) { // '\n'
      file.addLine(_offset + 1);
    }
    
    _offset++;
    return rune;
  }

  void back([int step = 1]) {
    if (_offset >= step) {
      _offset -= step;
    }
  }

  int peek() {
    if (isAtEnd) return eof;
    return _source.codeUnitAt(_offset);
  }

  void cutIn() {
    _cutIn = _offset;
  }

  String cutOut() {
    return _source.substring(_cutIn, _offset);
  }

  bool get isAtEnd => _offset >= _source.length;
  int get offset => _offset;
}

extension RuneExt on int {
  bool get isLetter {
    return (this == 95) || // '_'
           (this >= 97 && this <= 122) || // 'a'-'z'
           (this >= 65 && this <= 90);    // 'A'-'Z'
  }

  bool get isDecimal {
    return this >= 48 && this <= 57; // '0'-'9'
  }

  int toLower() {
    if (this >= 65 && this <= 90) {
      return this + 32;
    }
    return this;
  }

  int get digitValue {
    if (isDecimal) return this - 48;
    int lower = toLower();
    if (lower >= 97 && lower <= 102) { // 'a'-'f'
      return lower - 97 + 10;
    }
    return 16;
  }
}