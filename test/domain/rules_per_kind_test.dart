import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('allowedRules', () {
    test('passend zur Art', () {
      const all = {StreakRule.relaxed, StreakRule.joker, StreakRule.strict};
      const soft = {StreakRule.relaxed, StreakRule.joker};
      expect(allowedRules(const DailyKind(days: 21)), all);
      expect(allowedRules(const DailyKind()), soft);
      expect(allowedRules(const JournalKind()), soft);
      expect(allowedRules(const WeeklyGoalKind(3, unit: WeeklyUnit.times)), soft);
      expect(allowedRules(const WeeklyGoalKind(120)), soft);
      expect(allowedRules(const OneTimeKind(Duration(hours: 24))), isEmpty);
    });

    test('ruleFor setzt Unpassendes auf Locker', () {
      expect(ruleFor(const DailyKind(days: 21), StreakRule.strict),
          StreakRule.strict);
      expect(ruleFor(const DailyKind(), StreakRule.strict), StreakRule.relaxed);
      expect(ruleFor(const DailyKind(), StreakRule.joker), StreakRule.joker);
      expect(ruleFor(const OneTimeKind(Duration(hours: 24)), StreakRule.joker),
          StreakRule.relaxed);
    });
  });

  test('hasStreak: nicht bei einmaligen Challenges', () {
    expect(hasStreak(const OneTimeKind(Duration(hours: 24))), isFalse);
    expect(hasStreak(const DailyKind()), isTrue);
    expect(hasStreak(const WeeklyGoalKind(120)), isTrue);
  });
}
