import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:motoline/features/circuit_map/offroad_circuit_map_screen.dart';
import 'package:motoline/l10n/app_localizations.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('circuit map lists what a blank survey still needs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: OffroadCircuitMapScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('Outside'), findsOneWidget);
    expect(find.text('Inside'), findsOneWidget);
    expect(find.text('Line'), findsOneWidget);
    expect(find.text('Finish'), findsOneWidget);

    await tester.tap(find.text('Inside'));
    await tester.pump();
    expect(
      find.textContaining('Walk the inside edge'),
      findsOneWidget,
    );

    await tester.tap(find.text("What's missing"));
    await tester.pumpAndSettle();

    expect(find.text('Not a closed circuit yet'), findsOneWidget);
    expect(
      find.textContaining('Walk or mark the outside perimeter'),
      findsOneWidget,
    );
    expect(find.textContaining('inside perimeter'), findsOneWidget);
    expect(find.textContaining('racing line'), findsOneWidget);
  });
}
