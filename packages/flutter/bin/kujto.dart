import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty || args.first == '--help' || args.first == '-h') {
    _printHelp();
    return;
  }

  switch (args.first) {
    case 'wire':
      _wire(args.skip(1).toList());
      return;
    default:
      stderr.writeln('kujto: unknown command ${args.first}');
      exitCode = 1;
  }
}

void _printHelp() {
  stdout.writeln('''
Kujto

Usage:
  dart run kujto:kujto wire [--memory]

Commands:
  wire   Add a Kujto marker to the current Flutter or Dart repository.
''');
}

void _wire(List<String> args) {
  final includeMemory = args.contains('--memory');
  final root = Directory.current;
  final agents = File('${root.path}/AGENTS.md');

  if (agents.existsSync()) {
    stdout.writeln('AGENTS.md already exists, leaving it');
    return;
  }

  agents.writeAsStringSync('''
# Kujto

This project is prepared for Kujto memory.

Run the full installer from:
https://github.com/peterdsp/kujto
''');

  if (includeMemory) {
    Directory('${root.path}/memory').createSync(recursive: true);
  }

  stdout.writeln('Wired Kujto marker into ${root.path}');
}
