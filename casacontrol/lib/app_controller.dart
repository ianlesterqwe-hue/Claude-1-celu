import 'package:flutter/foundation.dart';

import 'adapters/demo/demo_adapter.dart';
import 'adapters/tuya/tuya_adapter.dart';
import 'adapters/yeelight/yeelight_adapter.dart';
import 'core/device_registry.dart';

/// Arma el [DeviceRegistry] según el modo (Demo o dispositivos reales).
class AppController extends ChangeNotifier {
  AppController({this._demoMode = false}) {
    _registry = _build();
  }

  bool _demoMode;
  late DeviceRegistry _registry;

  bool get demoMode => _demoMode;
  DeviceRegistry get registry => _registry;

  TuyaAdapter? get tuya =>
      _registry.adapters.whereType<TuyaAdapter>().firstOrNull;
  YeelightAdapter? get yeelight =>
      _registry.adapters.whereType<YeelightAdapter>().firstOrNull;

  Future<void> start() => _registry.start();

  Future<void> setDemoMode(bool value) async {
    if (value == _demoMode) return;
    _demoMode = value;
    final old = _registry;
    _registry = _build();
    notifyListeners();
    old.dispose();
    await _registry.start();
  }

  DeviceRegistry _build() => DeviceRegistry(
        _demoMode ? [DemoAdapter()] : [YeelightAdapter(), TuyaAdapter()],
      );

  @override
  void dispose() {
    _registry.dispose();
    super.dispose();
  }
}
