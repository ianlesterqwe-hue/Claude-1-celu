import 'dart:async';

import 'package:flutter/services.dart';

/// Espejo Dart de `TuyaPlatformService` (Kotlin), que envuelve el
/// SmartLife App SDK oficial de Tuya.
///
/// Contrato de seguridad: la capa nativa NUNCA envía a Dart local keys,
/// tokens de sesión ni secretos. Sólo metadatos, esquema y valores de DP.
class TuyaPlatform {
  TuyaPlatform({
    MethodChannel? methods,
    EventChannel? events,
  })  : _methods = methods ?? const MethodChannel('casacontrol/tuya'),
        _events = events ?? const EventChannel('casacontrol/tuya/events');

  final MethodChannel _methods;
  final EventChannel _events;
  Stream<Map<Object?, Object?>>? _eventStream;

  /// `{configured: bool, sdkVersion: String?}`. configured=false cuando el
  /// APK se compiló sin credenciales del SDK (ver docs/TUYA_SETUP.md).
  Future<Map<Object?, Object?>> initialize() async =>
      (await _methods.invokeMapMethod<Object?, Object?>('initialize')) ?? {};

  Future<bool> isLoggedIn() async =>
      (await _methods.invokeMethod<bool>('isLoggedIn')) ?? false;

  Future<void> sendEmailCode(String countryCode, String email) =>
      _methods.invokeMethod('sendEmailCode', {
        'countryCode': countryCode,
        'email': email,
      });

  Future<void> registerWithEmail(
          String countryCode, String email, String password, String code) =>
      _methods.invokeMethod('registerWithEmail', {
        'countryCode': countryCode,
        'email': email,
        'password': password,
        'code': code,
      });

  Future<void> login(String countryCode, String email, String password) =>
      _methods.invokeMethod('login', {
        'countryCode': countryCode,
        'email': email,
        'password': password,
      });

  Future<void> logout() => _methods.invokeMethod('logout');

  /// `[{homeId: int, name: String, role: String}]`
  Future<List<Map<Object?, Object?>>> getHomes() async =>
      _listOfMaps(await _methods.invokeListMethod<Object?>('getHomes'));

  Future<int> createHome(String name) async =>
      (await _methods.invokeMethod<int>('createHome', {'name': name}))!;

  /// Ver `TuyaPlatformService.deviceToMap` para el formato.
  Future<List<Map<Object?, Object?>>> getDevices(int homeId) async =>
      _listOfMaps(await _methods
          .invokeListMethod<Object?>('getDevices', {'homeId': homeId}));

  /// Prepara el canal de control (BLE/Beacon/Mesh) si hace falta.
  Future<void> connectDevice(String devId) =>
      _methods.invokeMethod('connectDevice', {'devId': devId});

  Future<void> publishDataPoints(String devId, Map<String, Object> dps) =>
      _methods.invokeMethod('publishDataPoints', {'devId': devId, 'dps': dps});

  /// Eventos: `{type: dpUpdate|online|removed|infoUpdate, devId, ...}`.
  Stream<Map<Object?, Object?>> subscribeDeviceState() =>
      _eventStream ??= _events
          .receiveBroadcastStream()
          .map((e) => (e as Map).cast<Object?, Object?>());

  Future<void> createSchedule({
    required String devId,
    required String time,
    required String loops,
    required Map<String, Object> dps,
    String? alias,
  }) =>
      _methods.invokeMethod('createSchedule', {
        'devId': devId,
        'time': time,
        'loops': loops,
        'dps': dps,
        'alias': ?alias,
      });

  Future<List<Map<Object?, Object?>>> getSchedules(String devId) async =>
      _listOfMaps(await _methods
          .invokeListMethod<Object?>('getSchedules', {'devId': devId}));

  Future<void> removeSchedule(String devId, String timerId) =>
      _methods.invokeMethod(
          'removeSchedule', {'devId': devId, 'timerId': timerId});

  /// OWNER: genera un código de invitación a la Home (Home Sharing oficial).
  Future<String> shareHome(int homeId) async =>
      (await _methods.invokeMethod<String>('shareHome', {'homeId': homeId}))!;

  /// MEMBER: se une a una Home con el código recibido.
  Future<void> joinHome(String invitationCode) =>
      _methods.invokeMethod('joinHome', {'code': invitationCode});

  Future<List<Map<Object?, Object?>>> getMembers(int homeId) async =>
      _listOfMaps(await _methods
          .invokeListMethod<Object?>('getMembers', {'homeId': homeId}));

  static List<Map<Object?, Object?>> _listOfMaps(List<Object?>? list) => [
        for (final e in list ?? const []) (e as Map).cast<Object?, Object?>(),
      ];
}
