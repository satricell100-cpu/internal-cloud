import 'package:flutter_test/flutter_test.dart';
import 'package:internal_cloud/services/app_config.dart';

void main() {
  test('AppConfig.baseUrl valid (http + port)', () {
    final u = Uri.parse(AppConfig.baseUrl);
    expect(u.scheme, 'http');
    expect(u.port, 3000);
    expect(u.host.isNotEmpty, true);
  });
}
