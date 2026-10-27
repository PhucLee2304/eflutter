/// Quy chế giám sát có phiên bản (PLAN_ATTEMPT_INTEGRITY.md mục 1.7). Phải khớp
/// `INTEGRITY_CONSENT_VERSION` của learning; đổi nội dung thì tăng phiên bản ở cả hai.
const integrityConsentVersion = '2026-10-v2';

List<String> integrityConsentRules(int maxViolations) => [
  'Before you start, turn off notifications and close other apps. Any time the '
      'exam tab loses focus (switching tab, window or app, or a pop-up taking '
      'focus) counts as a violation immediately.',
  'You are allowed $maxViolations violations; going over that automatically '
      'suspends the attempt with a score of 0.',
  'The system also records reloading the page, opening the attempt in another tab '
      'or device, copy and paste. Your teacher sees every record immediately.',
  'Your teacher can suspend the attempt at any time, or reinstate the result if a '
      'suspension was a mistake.',
  'Browsers do not give websites access to your computer. Only activity in this '
      'exam tab is recorded.',
];
