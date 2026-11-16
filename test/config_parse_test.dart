import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vless/flutter_vless.dart';

import 'package:evelyn_vpn/default_config.dart';

void main() {
  test('default VLESS link parses to a valid Xray config', () {
    final parsed = FlutterVless.parse(defaultVlessLink);
    expect(parsed.remark, isNotEmpty);
    final config = parsed.getFullConfiguration();
    expect(config, contains('trx.koomeh.net'));
    expect(config, contains('443'));
    expect(config, contains('reality'));
    expect(config, contains('fb759958-b17f-4da2-84ac-03796206eb12'));
  });
}
