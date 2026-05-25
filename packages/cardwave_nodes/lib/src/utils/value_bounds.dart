/// Returns a human-readable "out of bounds" message when [value] is
/// outside `[min, max]`, or null when it is in range. Used by the
/// director-output and card-extension validators so the message format
/// stays consistent across both.
String? boundsProblem(num value, num min, num max) {
  if (value < min || value > max) {
    return '$value is out of bounds [$min, $max]';
  }
  return null;
}
