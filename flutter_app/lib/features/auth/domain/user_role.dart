/// Matches the three user classes in the Use Case Diagram (Figure H-2):
/// Researcher/Operator (full access), Annotator (blind, limited),
/// Course Instructor / Adjudicator (blind, limited).
enum UserRole { operator, annotator, adjudicator }

extension UserRoleX on UserRole {
  static UserRole fromString(String value) {
    switch (value) {
      case 'operator':
        return UserRole.operator;
      case 'annotator':
        return UserRole.annotator;
      case 'adjudicator':
        return UserRole.adjudicator;
      default:
        throw ArgumentError('Unknown role: $value');
    }
  }

  String get label {
    switch (this) {
      case UserRole.operator:
        return 'Researcher / Operator';
      case UserRole.annotator:
        return 'Annotator';
      case UserRole.adjudicator:
        return 'Course Instructor / Adjudicator';
    }
  }

  /// Which top-level frontend modules (Figure H-1) this role may open.
  bool canAccess(String moduleRoute) {
    switch (this) {
      case UserRole.operator:
        return true; // full access
      case UserRole.annotator:
        return moduleRoute == '/annotation'; // Annotation + My Labels only
      case UserRole.adjudicator:
        return moduleRoute == '/annotation'; // Adjudication view only
    }
  }
}
