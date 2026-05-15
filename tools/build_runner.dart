// Runs `dart run build_runner build` (or any other build_runner subcommand)
// in every workspace member that uses code generators (@JsonSerializable,
// etc.). Saves you from cd-ing into each package after a model edit.
//
// Usage (from app/):
//   dart run tools/build_runner.dart                 # build (default)
//   dart run tools/build_runner.dart watch           # watch the root only;
//                                                    # for watching a single
//                                                    # package, cd in instead
//   dart run tools/build_runner.dart build --delete-conflicting-outputs
//
// Update [_members] when a new generator-using package is added to the
// workspace.

import 'dart:io';

const _members = [
  '.',
  'packages/cardwave_llm',
  'packages/cardwave_names',
];

Future<void> main(List<String> args) async {
  final passthrough = args.isEmpty ? const ['build'] : args;
  for (final dir in _members) {
    stdout.writeln('\n==> dart run build_runner ${passthrough.join(' ')} '
        '(in $dir)');
    final proc = await Process.start(
      'dart',
      ['run', 'build_runner', ...passthrough],
      workingDirectory: dir,
      mode: ProcessStartMode.inheritStdio,
      runInShell: true,
    );
    final code = await proc.exitCode;
    if (code != 0) {
      stderr.writeln('build_runner failed in $dir (exit $code)');
      exit(code);
    }
  }
  stdout.writeln('\nAll builds succeeded.');
}
