import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/widgets/app_toast.dart';

Widget _app(Widget home) {
  return MaterialApp(
    builder: (context, child) => AppToastHost(
      key: appToastHostKey,
      child: child ?? const SizedBox.shrink(),
    ),
    home: home,
  );
}

void main() {
  testWidgets('empty toast is not shown', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showAppSnack(context, '   '),
              child: const Text('go'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.byKey(const Key('app-toast-close')), findsNothing);
  });

  testWidgets('toast appears at top and can be closed', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showAppSnack(context, 'Ruta armada'),
              child: const Text('go'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('Ruta armada'), findsOneWidget);
    await tester.tap(find.byKey(const Key('app-toast-close')));
    await tester.pump();
    expect(find.text('Ruta armada'), findsNothing);
  });

  testWidgets('info toast hides after its linger duration', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showAppSnack(context, 'Listo'),
              child: const Text('go'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('Listo'), findsOneWidget);
    await tester.pump(AppToastTone.info.linger);
    await tester.pump();
    expect(find.text('Listo'), findsNothing);
  });
}
