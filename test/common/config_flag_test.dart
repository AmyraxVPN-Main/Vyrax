import 'package:fl_clash/common/config_flag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('configFlagCode', () {
    test('returns null for names that already carry a flag emoji', () {
      expect(configFlagCode('🇩🇪 Germany 01'), isNull);
      expect(flagIfMissing('🇩🇪 Germany 01'), '🇩🇪 Germany 01');
    });

    test('detects ISO code tokens', () {
      expect(configFlagCode('DE-01'), 'de');
      expect(configFlagCode('NL_2'), 'nl');
      expect(configFlagCode('US-West'), 'us');
      expect(flagIfMissing('DE-01'), '🇩🇪 DE-01');
    });

    test('detects country and city names', () {
      expect(configFlagCode('Germany 01'), 'de');
      expect(configFlagCode('Frankfurt-2'), 'de');
      expect(configFlagCode('United States 1'), 'us');
      expect(configFlagCode('ISTANBUL 04'), 'tr');
      expect(configFlagCode('hong kong host'), 'hk');
      expect(flagIfMissing('Paris 3'), '🇫🇷 Paris 3');
    });

    test('ignores lower-case and mixed-case short tokens', () {
      expect(configFlagCode('node de 1'), isNull);
      expect(configFlagCode('De-1'), isNull);
      expect(configFlagCode('switch-tech'), isNull);
    });

    test('returns null without any location signal', () {
      expect(configFlagCode('My tunnel'), isNull);
      expect(flagIfMissing('My tunnel'), 'My tunnel');
    });
  });
}
