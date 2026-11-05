import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests normally render every font as the 1:1 "Ahem" test font, which
/// makes text far wider than on a phone and hides or invents layout bugs. Load
/// the bundled fonts so text is measured with real metrics.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _load('BricolageGrotesque', const ['BricolageGrotesque-Bold.ttf']);
  await _load('PlusJakartaSans', const [
    'PlusJakartaSans-Medium.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
  ]);
  await testMain();
}

Future<void> _load(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = await File('assets/fonts/$f').readAsBytes();
    loader.addFont(
      Future.value(ByteData.sublistView(Uint8List.fromList(bytes))),
    );
  }
  await loader.load();
}
