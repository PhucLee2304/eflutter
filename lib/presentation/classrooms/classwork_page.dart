/// Màn đang mở trong tab Classwork, lấy từ URL (`/classrooms/:id/classwork/...`).
enum ClassworkView { list, create, edit, gradebook, classGradebook, student }

class ClassworkPage {
  const ClassworkPage(this.view, {this.assignmentId, this.studentId, this.backTo});
  const ClassworkPage.list() : this(ClassworkView.list);

  final ClassworkView view;
  final int? assignmentId;
  final String? studentId;

  /// Màn đã mở gradebook bài (bảng điểm lớp, tiến độ học sinh): Back quay lại đó.
  final String? backTo;

  @override
  bool operator ==(Object other) =>
      other is ClassworkPage &&
      other.view == view &&
      other.assignmentId == assignmentId &&
      other.studentId == studentId &&
      other.backTo == backTo;

  @override
  int get hashCode => Object.hash(view, assignmentId, studentId, backTo);
}
