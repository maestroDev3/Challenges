import 'package:challenges/ui/app.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';

void main() {
  testWidgets('App startet', (tester) async {
    await tester.pumpWidget(ChallengesApp(repository: FakeChallengeRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Entdecken'), findsWidgets);
  });
}
