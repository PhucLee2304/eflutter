/// Màn đang mở trong tab Classwork, lấy từ URL (`/classrooms/:id/classwork/...`).
enum ClassworkView { list, create, edit, gradebook, classGradebook, student, review }

class ClassworkPage {
  const ClassworkPage(this.view, {this.assignmentId, this.studentId, this.attemptId, this.backTo});
  const ClassworkPage.list() : this(ClassworkView.list);

  final ClassworkView view;
  final int? assignmentId;
  final String? studentId;

  /// Bài làm đang xem lại (view review).
  final int? attemptId;

  /// Màn đã mở gradebook bài (bảng điểm lớp, tiến độ học sinh): Back quay lại đó.
  final String? backTo;

  @override
  bool operator ==(Object other) =>
      other is ClassworkPage &&
      other.view == view &&
      other.assignmentId == assignmentId &&
      other.studentId == studentId &&
      other.attemptId == attemptId &&
      other.backTo == backTo;

  @override
  int get hashCode => Object.hash(view, assignmentId, studentId, attemptId, backTo);
}
