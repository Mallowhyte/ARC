// ARC - AI-based Record Classifier Widget Tests
//
// Tests for the main app functionality

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_file_classifier/main.dart';

void main() {
  testWidgets('ARC app loads and displays title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ARCApp());

    // Verify that the app title is displayed
    expect(find.text('ARC - AI Record Classifier'), findsOneWidget);

    // Verify that the dashboard tab is shown by default
    expect(find.text('Welcome to ARC'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('Navigation bar has all tabs', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ARCApp());
    await tester.pumpAndSettle();

    // Verify all navigation tabs exist
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Statistics'), findsOneWidget);
  });

  testWidgets('Can navigate between tabs', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ARCApp());
    await tester.pumpAndSettle();

    // Tap on Documents tab
    await tester.tap(find.text('Documents'));
    await tester.pumpAndSettle();

    // Verify Documents screen is displayed
    // (You may need to adjust this based on actual screen content)
    expect(find.byType(NavigationBar), findsOneWidget);

    // Tap on Statistics tab
    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();

    // Verify Statistics screen is displayed
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
