/// Quy chế giám sát có phiên bản (PLAN_ATTEMPT_INTEGRITY.md mục 1.7). Phải khớp
/// `INTEGRITY_CONSENT_VERSION` của learning; đổi nội dung thì tăng phiên bản ở cả hai.
const integrityConsentVersion = '2026-11-v4';

/// Loại quy chế, để hộp đồng ý chọn icon (Figma S1).
enum IntegrityRuleKind { leaveTab, limit, recorded, teacher, privacy }

List<(IntegrityRuleKind, String)> integrityConsentRules(int maxViolations) => [
  (
    IntegrityRuleKind.leaveTab,
    'Leaving the exam tab (switching tab, window or app, or a pop-up taking focus) '
        'counts as a violation. Turn off notifications and close other apps first.',
  ),
  (
    IntegrityRuleKind.limit,
    'Going over $maxViolations violations automatically suspends the attempt with '
        'a score of 0.',
  ),
  (
    IntegrityRuleKind.recorded,
    'Reloading, opening the attempt in another tab or device, copy and paste are '
        'recorded but not counted. Keeping the "Leave site?" box open for more than '
        '3 seconds counts as leaving the exam. Your teacher sees every record right away.',
  ),
  (
    IntegrityRuleKind.teacher,
    'Your teacher can suspend the attempt at any time, or reinstate the result if '
        'it was a mistake.',
  ),
  (
    IntegrityRuleKind.privacy,
    'Only activity in this exam tab is recorded, nothing else on your computer.',
  ),
];
