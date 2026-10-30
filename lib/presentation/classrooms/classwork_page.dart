/// Màn đang mở trong tab Classwork, lấy từ URL (`/classrooms/:id/classwork/...`).
enum ClassworkView { list, create, edit, gradebook, classGradebook, student }

class ClassworkPage {
  const ClassworkPage(
    this.view, {
    this.assignmentId,
    this.studentId,
    this.fromClassGradebook = false,
  });
  const ClassworkPage.list() : this(ClassworkView.list);

  final ClassworkView view;
  final int? assignmentId;
  final String? studentId;

  /// Gradebook bài mở từ bảng điểm lớp: Back quay lại bảng điểm lớp.
  final bool fromClassGradebook;

  @override
  bool operator ==(Object other) =>
      other is ClassworkPage &&
      other.view == view &&
      other.assignmentId == assignmentId &&
      other.studentId == studentId &&
      other.fromClassGradebook == fromClassGradebook;

  @override
  int get hashCode => Object.hash(view, assignmentId, studentId, fromClassGradebook);
}
