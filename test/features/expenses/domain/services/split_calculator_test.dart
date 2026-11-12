import 'package:flutter_test/flutter_test.dart';

import 'package:hisaab_brabar/features/expenses/domain/services/split_calculator.dart';

void main() {
  group('SplitCalculator', () {
    test('equal split distributes leftover paise correctly', () {
      final shares = SplitCalculator.equal(
        totalPaise: 10001,
        participants: ['Meera', 'Aarav', 'Kabir'],
      );

      expect(shares['Aarav'], 3334);
      expect(shares['Kabir'], 3334);
      expect(shares['Meera'], 3333);

      expect(shares.values.reduce((a, b) => a + b), 10001);
    });

    test('exact split accepts valid shares', () {
      final shares = SplitCalculator.exact(
        totalPaise: 10000,
        participants: ['Aarav', 'Meera'],
        sharesPaise: {'Aarav': 4000, 'Meera': 6000},
      );

      expect(shares['Aarav'], 4000);
      expect(shares['Meera'], 6000);
    });

    test('exact split rejects incorrect totals', () {
      expect(
        () => SplitCalculator.exact(
          totalPaise: 10000,
          participants: ['Aarav', 'Meera'],
          sharesPaise: {'Aarav': 4000, 'Meera': 5000},
        ),
        throwsArgumentError,
      );
    });

    test('percentage split distributes leftover paise correctly', () {
      final shares = SplitCalculator.percentage(
        totalPaise: 100,
        participants: ['Aarav', 'Kabir', 'Meera'],
        percentagesBasisPoints: {'Aarav': 3334, 'Kabir': 3333, 'Meera': 3333},
      );

      expect(shares['Aarav'], 34);
      expect(shares['Kabir'], 33);
      expect(shares['Meera'], 33);

      expect(shares.values.reduce((a, b) => a + b), 100);
    });

    test('percentage split rejects percentages not totaling 100%', () {
      expect(
        () => SplitCalculator.percentage(
          totalPaise: 10000,
          participants: ['Aarav', 'Meera'],
          percentagesBasisPoints: {'Aarav': 4000, 'Meera': 5000},
        ),
        throwsArgumentError,
      );
    });
  });
}
