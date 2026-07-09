import 'package:flutter_test/flutter_test.dart';
import 'package:office_core/src/premium/premium_status_provider.dart';

void main() {
  group('FakePremiumProvider', () {
    test('initial value is respected', () {
      final provider = FakePremiumProvider(initialPro: true);
      expect(provider.isPro, true);
      provider.dispose();
    });

    test('setPro updates isPro', () {
      final provider = FakePremiumProvider(initialPro: false);
      expect(provider.isPro, false);
      provider.setPro(true);
      expect(provider.isPro, true);
      provider.dispose();
    });

    test('isProStream emits on setPro', () async {
      final provider = FakePremiumProvider(initialPro: false);
      final events = <bool>[];
      final sub = provider.isProStream.listen(events.add);

      provider.setPro(true);
      provider.setPro(false);
      provider.setPro(true);

      await Future.delayed(Duration.zero);
      expect(events, [true, false, true]);

      await sub.cancel();
      provider.dispose();
    });
  });
}
