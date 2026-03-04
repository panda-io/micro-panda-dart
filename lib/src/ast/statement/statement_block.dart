import '../context.dart';
import 'statement.dart';

class Block extends Statement {
  final List<Statement> statements;

  Block(this.statements, super.position);

  @override
  void validate(Context context) {}
}
