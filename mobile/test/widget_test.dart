import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('ResQMatrix dashboard shows core workspaces', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ResQMatrixApp());
    await tester.pump();

    expect(find.text('ResQMatrix'), findsWidgets);
    expect(find.text('Operations workspaces'), findsOneWidget);
    // Each workspace appears in the sidebar and in the dashboard grid on wide screens.
    expect(find.text('Priority triage'), findsWidgets);
    expect(find.text('Resource allocation'), findsWidgets);
    expect(find.text('Emergency request'), findsWidgets);
    expect(find.text('Flood risk prediction'), findsWidgets);
    expect(find.text('Organization portal'), findsWidgets);
    expect(find.text('Administrator console'), findsWidgets);
  });
}
