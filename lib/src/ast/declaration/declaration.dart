import '../node/node.dart';

/// Base for all top-level declarations (variable, function, class, enum).
/// isPublic is derived from naming: identifiers NOT starting with '_' are public.
abstract class Declaration extends Node {
  final String name;

  Declaration(this.name, super.position);

  bool get isPublic => !name.startsWith('_');
}
