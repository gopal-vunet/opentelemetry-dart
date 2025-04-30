import 'dart:io';

void main() async {
  // Test combinations of dependencies
  final versionsToTest = {
    'async': ['2.5.0', '2.11.0'], // Test lowest and highest versions
    'collection': ['1.15.0', '1.18.0'],
    'http': ['0.13.0', '0.13.6'],
    // Add other dependencies as needed
  };

  for (var dep in versionsToTest.entries) {
    for (var version in dep.value) {
      print('Testing ${dep.key} at version $version');

      // Update pubspec.yaml temporarily
      await Process.run('dart', ['pub', 'downgrade', '${dep.key}:$version']);

      // Run tests
      var result = await Process.run('dart', ['test']);

      if (result.exitCode != 0) {
        print('❌ Tests failed for ${dep.key} $version');
        print(result.stderr);
      } else {
        print('✅ Tests passed for ${dep.key} $version');
      }
    }
  }
}
