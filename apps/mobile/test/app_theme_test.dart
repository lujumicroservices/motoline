import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/theme/app_theme.dart';
import 'package:motoline/theme/brand_mark.dart';

void main() {
  test('dark theme keeps the asphalt palette and rounds controls', () {
    final theme = AppTheme.dark();

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppTheme.asphalt);
    expect(theme.colorScheme.surface, AppTheme.asphalt);
    expect(theme.colorScheme.primary, AppTheme.line);
    expect(theme.colorScheme.secondary, AppTheme.signal);
    expect(theme.colorScheme.onSurface, AppTheme.mist);
    expect(theme.textTheme.bodyLarge?.fontFamily, AppFonts.uiFamily);
    expect(theme.textTheme.displayLarge?.fontFamily, AppFonts.uiFamily);
    expect(theme.textTheme.displayLarge?.fontSize, 48);
    expect(
      theme.textTheme.displayLarge?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );

    for (final style in [
      theme.filledButtonTheme.style,
      theme.elevatedButtonTheme.style,
      theme.outlinedButtonTheme.style,
      theme.textButtonTheme.style,
    ]) {
      final shape = style?.shape?.resolve(const <WidgetState>{});
      expect(shape, isA<RoundedRectangleBorder>());
      expect(
        (shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(AppRadius.button),
      );
    }

    expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
    expect(theme.dialogTheme.shape, isA<RoundedRectangleBorder>());
    expect(theme.bottomSheetTheme.shape, isA<RoundedRectangleBorder>());
    expect(theme.inputDecorationTheme.border, isA<OutlineInputBorder>());
  });

  testWidgets('header wordmark is Barlow Condensed, one step heavier', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RiderLabMark(size: BrandMarkSize.title)),
      ),
    );

    final rich = tester.widget<Text>(find.byType(Text));
    final span = rich.textSpan! as TextSpan;
    final rider = span.children![0] as TextSpan;
    final lab = span.children![1] as TextSpan;

    expect(rider.text, 'RIDER');
    expect(lab.text, 'LAB');
    expect(rider.style?.fontFamily, AppFonts.brandFamily);
    expect(rider.style?.fontWeight, FontWeight.w800);
    expect(lab.style?.fontWeight, FontWeight.w900);
    expect(lab.style?.color, AppTheme.brand);
  });
}
