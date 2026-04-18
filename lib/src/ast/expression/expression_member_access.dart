import '../context.dart';
import '../type/type.dart';
import '../type/type_array.dart';
import '../type/type_name.dart';
import '../type/type_ref.dart';
import 'expression.dart';
import 'expression_identifier.dart';

class MemberAccess extends Expression {
  final Expression parent;
  final String member;

  MemberAccess(this.parent, this.member, super.position);

  @override
  void validate(Context context, Type? expected) {
    parent.validate(context, null);

    // Enum member: Color.Red → type is the enum itself (u32-like)
    if (parent is Identifier) {
      final name = (parent as Identifier).name;
      if (context.enums.containsKey(name)) {
        final enm = context.enums[name]!;
        final hasMember = enm.members.any((m) => m.name == member);
        if (!hasMember) {
          context.error(position, "enum '$name' has no member '$member'");
        }
        type = TypeName(name, isEnum: true); // enum member has the enum's type
        return;
      }
    }

    // Module-qualified access: file.WRITE (variable) or string.format_int (function in callee pos).
    // Only apply when the identifier is not a local variable (locals shadow module qualifiers).
    if (parent is Identifier) {
      final qualifier = (parent as Identifier).name;
      if (context.moduleQualifiers.contains(qualifier) && !context.isDeclaredVar(qualifier)) {
        if (context.calleePosition) {
          // Function call — type resolution is handled in Invocation.validate.
          type = null;
          return;
        }
        final modVars = context.qualifiedVariables[qualifier];
        if (modVars != null && modVars.containsKey(member)) {
          type = modVars[member];
        } else {
          context.error(position,
              "module '$qualifier' has no member '$member'");
          type = null;
        }
        return;
      }
    }

    // Struct/class field: dereference pointer if needed
    var parentType = parent.type;
    if (parentType is TypeRef) parentType = parentType.elementType;

    // Slice fields .ptr and .size are only valid on slices, not fixed arrays
    if (parentType is TypeArray) {
      if (parentType.isFixed && member == 'ptr') {
        context.error(position,
            "cannot access '.ptr' on fixed array '${Context.typeName(parentType)}'; "
            "use a slice '${Context.typeName(parentType.elementType)}[]' instead");
        type = null;
        return;
      }
      // Valid slice field access
      if (parentType.isSlice && member == 'ptr') {
        type = TypeRef(parentType.elementType);
        return;
      }
      type = null;
      return;
    }

    if (parentType is TypeName) {
      final cls = context.classes[parentType.name];
      if (cls != null) {
        // Private member check: names starting with '_' are module-private.
        if (member.startsWith('_')) {
          final ownerModule = context.classModules[parentType.name];
          final currentModule = context.currentModulePath;
          if (ownerModule != null && ownerModule != currentModule) {
            context.error(position,
                "member '$member' of '${parentType.name}' is private");
            type = null;
            return;
          }
        }

        // Look for field in constructor fields and body fields
        for (final f in cls.constructorFields) {
          if (f.name == member) {
            type = f.type;
            return;
          }
        }
        for (final f in cls.bodyFields) {
          if (f.name == member) {
            type = f.type;
            return;
          }
        }
        // Look for method
        for (final m in cls.methods) {
          if (m.name == member) {
            if (!context.calleePosition) {
              context.error(position,
                  "'${parentType.name}.$member' is a class method and cannot be used as a function reference (no 'this' capture)");
            }
            type = null; // method reference, type handled at call site
            return;
          }
        }
        context.error(position,
            "'${parentType.name}' has no field '$member'");
        return;
      }
    }

    // Could not resolve — leave type null (avoid cascading errors)
    type = null;
  }
}
