enum TokenType {
  // Special tokens
  illegal,
  eof,
  comment,
  annotation,
  newline,
  
  // Indentation tokens (Off-side rule support)
  indent,
  dedent,

  // Literals
  literalBegin,
  identifier('identifier'),
  boolLiteral('bool_literal'),
  charLiteral('char_literal'),
  intLiteral('int_literal'),
  floatLiteral('float_literal'),
  stringLiteral('string_literal'),
  literalEnd,

  // Keywords
  keywordBegin,
  kBreak('break'),
  kCase('case'),
  kConst('const'),
  kContinue('continue'),
  kDefault('default'),
  kElse('else'),
  kEnum('enum'),
  kFor('for'),
  kFunction('fun'),
  kIf('if'),
  kImport('import'),
  kReturn('return'),
  kSizeof('sizeof'),
  kStruct('struct'),
  kSwitch('switch'),
  kThis('this'),
  kVal('val'),
  kVar('var'),
  keywordEnd,

  // Scalar types
  scalarBegin,
  typeBool('bool'),
  typeInt8('i8'),
  typeInt16('i16'),
  typeInt32('i32'),
  typeInt64('i64'),
  typeUint8('u8'),
  typeUint16('u16'),
  typeUint32('u32'),
  typeUint64('u64'),
  typeFloat16('f16'),
  typeFloat32('f32'),
  typeFloat64('f64'),
  typeVoid('void'),
  scalarEnd,

  // Operators
  operatorBegin,
  leftParen('('),
  rightParen(')'),
  leftBracket('['),
  rightBracket(']'),
  leftBrace('{'),
  rightBrace('}'),

  plus('+'),
  minus('-'),
  mul('*'),
  div('/'),
  less('<'),
  greater('>'),
  rem('%'),
  bitAnd('&'),
  bitOr('|'),
  bitXor('^'),
  complement('~'),
  not('!'),
  leftShift('<<'),
  rightShift('>>'),

  assignBegin,
  assign('='),
  plusAssign('+='),
  minusAssign('-='),
  mulAssign('*='),
  divAssign('/='),
  remAssign('%='),
  xorAssign('^='),
  andAssign('&='),
  orAssign('|='),
  leftShiftAssign('<<='),
  rightShiftAssign('>>='),
  assignEnd,

  equal('=='),
  notEqual('!='),
  lessEqual('<='),
  greaterEqual('>='),
  and('&&'),
  or('||'),
  plusPlus('++'),
  minusMinus('--'),

  comma(','),
  colon(':'),
  dot('.'),
  cascade('..'),
  operatorEnd;

  final String? literal;
  const TokenType([this.literal]);

  static final Map<String, TokenType> _stringToToken = {
    for (var type in TokenType.values)
      if (type.literal != null) type.literal!: type
  };

  static TokenType fromString(String text) {
    return _stringToToken[text] ?? TokenType.identifier;
  }

  bool get isLiteral => index > literalBegin.index && index < literalEnd.index;
  bool get isKeyword => index > keywordBegin.index && index < keywordEnd.index;
  bool get isScalar  => index > scalarBegin.index  && index < scalarEnd.index;
  bool get isOperator => index > operatorBegin.index && index < operatorEnd.index;
  bool get isAssign => index > assignBegin.index && index < assignEnd.index;

  int get precedence {
    if (isAssign) return 1;
    return switch (this) {
      or => 2,
      and => 3,
      bitOr => 4,
      bitXor => 5,
      bitAnd => 6,
      equal || notEqual => 7,
      less || lessEqual || greater || greaterEqual => 8,
      leftShift || rightShift => 9,
      plus || minus => 10,
      mul || div || rem => 11,
      _ => 0,
    };
  }

  bool get isIntegerType => switch (this) {
    typeInt8 || typeInt16 || typeInt32 || typeInt64 ||
    typeUint8 || typeUint16 || typeUint32 || typeUint64 => true,
    _ => false,
  };

  bool get isFloatType => switch (this) {
    typeFloat16 || typeFloat32 || typeFloat64 => true,
    _ => false,
  };

  int get bits => switch (this) {
    typeBool => 1,
    typeInt8 || typeUint8 => 8,
    typeInt16 || typeUint16 || typeFloat16 => 16,
    typeInt32 || typeUint32 || typeFloat32 => 32,
    typeInt64 || typeUint64 || typeFloat64 => 64,
    _ => 0,
  };

  int get size => switch (this) {
    typeBool || typeInt8 || typeUint8 => 1,
    typeInt16 || typeUint16 || typeFloat16 => 2,
    typeInt32 || typeUint32 || typeFloat32 => 4,
    typeInt64 || typeUint64 || typeFloat64 => 8,
    _ => 0,
  };
}