enum Token {
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
  nullLiteral('null'),
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
  kPointer('pointer'),
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
  logicalAnd('&&'),
  logicalOr('||'),
  plusPlus('++'),
  minusMinus('--'),

  comma(','),
  colon(':'),
  dot('.'),
  cascade('..'), // Dart-style cascade operator
  operatorEnd;

  /// The string representation used in source code
  final String? literal;
  const Token([this.literal]);

  /// Pre-computed map for fast lookup of keywords and operators
  static final Map<String, Token> _stringToToken = {
    for (var type in Token.values)
      if (type.literal != null) type.literal!: type
  };

  /// Lookup a token type from a string literal (e.g., "if" -> kIf)
  static Token fromString(String text) {
    return _stringToToken[text] ?? Token.identifier;
  }

  // Range checks using the built-in index property
  bool get isLiteral => index > literalBegin.index && index < literalEnd.index;
  bool get isKeyword => index > keywordBegin.index && index < keywordEnd.index;
  bool get isScalar  => index > scalarBegin.index  && index < scalarEnd.index;
  bool get isOperator => index > operatorBegin.index && index < operatorEnd.index;
  bool get isAssign => index > assignBegin.index && index < assignEnd.index;

  /// Returns the operator precedence (higher = binds tighter)
  int get precedence {
    if (isAssign) return 1;
    return switch (this) {
      logicalOr => 2,
      logicalAnd => 3,
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
}