// The macOS menu bar, through the same platform channel macOS uses: the app sends
// its menus, and choosing "Settings…" opens Settings.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// The menu item labelled [label], searched through every submenu.
Map<Object?, Object?>? findItem(Object? node, String label) {
  if (node is Map) {
    if (node['label'] == label) return node;
    for (final value in node.values) {
      if (findItem(value, label) case final found?) return found;
    }
  } else if (node is List) {
    for (final value in node) {
      if (findItem(value, label) case final found?) return found;
    }
  }
  return null;
}

void main() {
  testWidgets('on macOS: a native menu bar whose Settings… opens Settings', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final sent = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.menu, (call) async {
        sent.add(call);
        return null;
      });
      await start(tester, auth: FakeAuth(signedIn: true), onboarded: true);

      final menus = sent.lastWhere((c) => c.method == 'Menu.setMenus').arguments;
      expect(findItem(menus, 'OSMS'), isNotNull);
      expect(findItem(menus, 'Window'), isNotNull);
      final settings = findItem(menus, 'Settings…')!;
      expect(settings['enabled'], isTrue);

      // macOS reports the chosen item by id.
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.menu.name,
        SystemChannels.menu.codec.encodeMethodCall(MethodCall('Menu.selectedCallback', settings['id'])),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('elsewhere: no menu bar is sent', (tester) async {
    final sent = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.menu, (call) async {
      sent.add(call);
      return null;
    });
    await start(tester, auth: FakeAuth(signedIn: true), onboarded: true);
    expect(sent.where((c) => c.method == 'Menu.setMenus'), isEmpty);
  });
}
