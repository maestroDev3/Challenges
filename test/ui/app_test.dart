import 'package:challenges/ui/app.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/german_device.dart';

void main() {
  testWidgets('App startet', (tester) async {
    useGermanDevice(tester);
    await tester.pumpWidget(ChallengesApp(repository: FakeChallengeRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Entdecken'), findsWidgets);
  });
}
