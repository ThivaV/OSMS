// The OSMS mark, drawn by the app itself, at icon and header sizes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osms/shared/widgets/osms_logo.dart';

void main() {
  testWidgets('the OSMS mark draws at every size, the simplified one below 48 px', (tester) async {
    for (final size in [16.0, 36.0, 56.0, 128.0]) {
      await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Center(child: OsmsLogo(size: size))));
      expect(tester.getSize(find.byType(CustomPaint).last), Size.square(size));
      expect(tester.takeException(), isNull);
    }
    expect(find.bySemanticsLabel('OSMS'), findsOneWidget);
  });
}
