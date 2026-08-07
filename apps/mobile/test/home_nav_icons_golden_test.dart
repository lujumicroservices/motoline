import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/features/home/home_nav_icons.dart';
import 'package:motoline/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('asset icons load and tint', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              AppAssetIcon(asset: AppAssetIcon.rodadas, size: 48),
              AppAssetIcon(asset: AppAssetIcon.lean, size: 48, color: AppTheme.line),
              AppAssetIcon(asset: AppAssetIcon.routes, size: 48),
              AppMotoIcon(size: 48),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
