import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sy/data/database.dart';
import 'package:sy/data/tracker_config.dart';
import 'package:sy/logic/tracker_calendar_provider.dart';
import 'package:sy/widgets/month_section.dart';

Future<void> _pump(WidgetTester tester, StreakType streakType) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 60,
          height: 60,
          child: DayBlock(
            dayData: DayData(
              date: DateTime(2026, 6, 1),
              amount: 1,
              color: Colors.teal,
              streakGradient: const [Colors.teal, Colors.teal],
              tooltip: '',
            ),
            onTap: () {},
            streakType: streakType,
            columnIndex: 0,
            inputType: InputType.toggle,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('logged toggle day shows a check', (tester) async {
    await _pump(tester, StreakType.continued);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('logged abstinence day (a lapse) shows an x', (tester) async {
    await _pump(tester, StreakType.abstinence);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
  });
}
