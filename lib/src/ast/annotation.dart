/// An annotation attached to a declaration.
///
/// Syntax:
///   @extern                         → Annotation('extern', null)
///   @extern("malloc")               → Annotation('extern', 'malloc')
///   @extern("assert({a} == {b})")   → Annotation('extern', 'assert({a} == {b})')
class Annotation {
  final String name;

  /// Optional C template string.
  /// - null          → call by function name with args in order
  /// - no '{'        → C rename, pass args in order: template(args...)
  /// - with '{name}' → substitute named parameters: each {paramName} replaced by arg expr
  final String? template;

  Annotation(this.name, {this.template});
}
