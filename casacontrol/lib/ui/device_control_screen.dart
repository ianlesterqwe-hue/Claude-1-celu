import 'package:flutter/material.dart';

import '../core/device_registry.dart';
import '../core/models/capability.dart';
import '../core/models/command.dart';
import '../core/models/device.dart';
import 'device_info_screen.dart';
import 'home_screen.dart';
import 'labels.dart';

const _transition = Duration(milliseconds: 400);

class DeviceControlScreen extends StatelessWidget {
  const DeviceControlScreen(
      {super.key, required this.registry, required this.deviceId});

  final DeviceRegistry registry;
  final String deviceId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: registry,
      builder: (context, _) {
        final device = registry.byId(deviceId);
        if (device == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Dispositivo no disponible')),
          );
        }
        final caps = device.capabilities;
        final s = device.state;
        final enabled = device.online;
        final transition =
            caps.has<TransitionCapability>() ? _transition : null;
        void send(DeviceCommand c) => runCommand(context, registry, deviceId, c);

        return Scaffold(
          appBar: AppBar(
            title: Text(device.name),
            actions: [
              IconButton(
                tooltip: 'Información del dispositivo',
                icon: const Icon(Icons.info_outline),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        DeviceInfoScreen(registry: registry, device: device),
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ConnectivityBadge(device: device),
              const SizedBox(height: 16),
              if (caps.has<PowerCapability>())
                SwitchListTile(
                  title: Text(stateLines(device).first),
                  secondary: Icon(deviceIcon(device)),
                  value: s.power == true,
                  onChanged: enabled
                      ? (v) => send(SetPower(v, transition: transition))
                      : null,
                ),
              if (caps.has<BrightnessCapability>())
                _SliderTile(
                  label: 'Brillo',
                  icon: Icons.brightness_6_outlined,
                  value: (s.brightness ?? 100).toDouble(),
                  min: 1,
                  max: 100,
                  format: (v) => '${v.round()}%',
                  enabled: enabled,
                  onChangeEnd: (v) =>
                      send(SetBrightness(v.round(), transition: transition)),
                ),
              if (caps.get<ColorTemperatureCapability>() case final ct?)
                _SliderTile(
                  label: ct.approximate
                      ? 'Temperatura (aprox.)'
                      : 'Temperatura de color',
                  icon: Icons.wb_sunny_outlined,
                  value: (s.colorTemperatureK ?? ct.minKelvin)
                      .clamp(ct.minKelvin, ct.maxKelvin)
                      .toDouble(),
                  min: ct.minKelvin.toDouble(),
                  max: ct.maxKelvin.toDouble(),
                  format: (v) => '${v.round()} K · ${whiteLabel(v.round())}',
                  enabled: enabled,
                  onChangeEnd: (v) => send(
                      SetColorTemperature(v.round(), transition: transition)),
                ),
              if (caps.has<ColorCapability>())
                _ColorPicker(
                  color: s.color ?? const HsvColor(0, 100),
                  enabled: enabled,
                  onChanged: (c) => send(SetColor(c, transition: transition)),
                ),
              if (caps.get<EnergyMeterCapability>() case final meter?)
                _EnergyCard(metrics: meter.metrics, values: s.energy),
              if (caps.has<CountdownCapability>())
                _CountdownTile(
                  seconds: s.countdownSeconds ?? 0,
                  enabled: enabled,
                  onSet: (d) => send(SetCountdown(d)),
                ),
              if (caps.has<ScheduleCapability>())
                const ListTile(
                  leading: Icon(Icons.schedule),
                  title: Text('Horarios'),
                  subtitle: Text('Disponible en la Fase 9'),
                  enabled: false,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SliderTile extends StatefulWidget {
  const _SliderTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.format,
    required this.enabled,
    required this.onChangeEnd,
  });

  final String label;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final String Function(double) format;
  final bool enabled;
  final ValueChanged<double> onChangeEnd;

  @override
  State<_SliderTile> createState() => _SliderTileState();
}

class _SliderTileState extends State<_SliderTile> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final v = (_dragging ?? widget.value).clamp(widget.min, widget.max);
    return ListTile(
      leading: Icon(widget.icon),
      title: Text('${widget.label}: ${widget.format(v)}'),
      subtitle: Slider(
        value: v,
        min: widget.min,
        max: widget.max,
        onChanged:
            widget.enabled ? (x) => setState(() => _dragging = x) : null,
        // Se envía sólo al soltar: respeta el límite de 60 comandos/min
        // de Yeelight y evita saturar Tuya/BLE.
        onChangeEnd: (x) {
          setState(() => _dragging = null);
          widget.onChangeEnd(x);
        },
      ),
    );
  }
}

class _ColorPicker extends StatefulWidget {
  const _ColorPicker(
      {required this.color, required this.enabled, required this.onChanged});

  final HsvColor color;
  final bool enabled;
  final ValueChanged<HsvColor> onChanged;

  @override
  State<_ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<_ColorPicker> {
  HsvColor? _editing;

  static const _presets = [
    HsvColor(0, 100),
    HsvColor(30, 100),
    HsvColor(55, 100),
    HsvColor(120, 100),
    HsvColor(180, 100),
    HsvColor(230, 100),
    HsvColor(275, 100),
    HsvColor(320, 80),
  ];

  @override
  Widget build(BuildContext context) {
    final c = _editing ?? widget.color;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.palette_outlined),
              const SizedBox(width: 12),
              Text('Color: ${hueLabel(c)}'),
              const Spacer(),
              CircleAvatar(radius: 12, backgroundColor: colorFromHsv(c)),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _presets)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.enabled ? () => widget.onChanged(p) : null,
                    child: CircleAvatar(
                        radius: 18, backgroundColor: colorFromHsv(p)),
                  ),
              ],
            ),
            const Text('Tono'),
            Slider(
              value: c.hue.toDouble(),
              max: 359,
              activeColor: colorFromHsv(HsvColor(c.hue, 100)),
              onChanged: widget.enabled
                  ? (v) => setState(
                      () => _editing = HsvColor(v.round(), c.saturation))
                  : null,
              onChangeEnd: _commit,
            ),
            const Text('Saturación'),
            Slider(
              value: c.saturation.toDouble(),
              max: 100,
              onChanged: widget.enabled
                  ? (v) =>
                      setState(() => _editing = HsvColor(c.hue, v.round()))
                  : null,
              onChangeEnd: _commit,
            ),
          ],
        ),
      ),
    );
  }

  void _commit(double _) {
    final c = _editing;
    setState(() => _editing = null);
    if (c != null) widget.onChanged(c);
  }
}

class _EnergyCard extends StatelessWidget {
  const _EnergyCard({required this.metrics, required this.values});

  final Set<EnergyMetric> metrics;
  final Map<EnergyMetric, double> values;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          const ListTile(
              leading: Icon(Icons.bolt_outlined), title: Text('Consumo')),
          for (final m in EnergyMetric.values)
            if (metrics.contains(m))
              ListTile(
                dense: true,
                title: Text(m.label),
                trailing: Text(values[m] == null
                    ? '—'
                    : '${_fmt(values[m]!, m)} ${m.unit}'),
              ),
        ],
      ),
    );
  }

  static String _fmt(double v, EnergyMetric m) => switch (m) {
        EnergyMetric.energyKwh => v.toStringAsFixed(3),
        EnergyMetric.currentMa => v.toStringAsFixed(0),
        _ => v.toStringAsFixed(1),
      };
}

class _CountdownTile extends StatelessWidget {
  const _CountdownTile(
      {required this.seconds, required this.enabled, required this.onSet});

  final int seconds;
  final bool enabled;
  final ValueChanged<Duration> onSet;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.timer_outlined),
      title: const Text('Temporizador'),
      subtitle: Text(seconds > 0
          ? 'Cambia de estado en ${(seconds / 60).ceil()} min'
          : 'Sin temporizador'),
      trailing: PopupMenuButton<int>(
        enabled: enabled,
        onSelected: (m) => onSet(Duration(minutes: m)),
        itemBuilder: (_) => [
          for (final m in const [15, 30, 60, 120])
            PopupMenuItem(value: m, child: Text('$m min')),
          const PopupMenuItem(value: 0, child: Text('Cancelar')),
        ],
      ),
    );
  }
}
