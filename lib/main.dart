import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vless/flutter_vless.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'default_config.dart';

void main() {
  runApp(const EvelynVpnApp());
}

class EvelynVpnApp extends StatelessWidget {
  const EvelynVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Evelyn VPN',
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4CAF50),
          secondary: Color(0xFF81C784),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
      ),
      // کل رابط کاربری راست‌به‌چپ و فارسی است.
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HomePage(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ValueNotifier<VlessStatus> _status =
      ValueNotifier<VlessStatus>(VlessStatus());

  late final FlutterVless _vless = FlutterVless(
    onStatusChanged: (status) {
      _status.value = status;
    },
  );

  List<String> _links = [defaultVlessLink];
  int _selected = 0;
  bool _busy = false;
  bool _ready = false;
  String? _error;
  String? _coreVersion;
  int? _pingMs;
  bool _pinging = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _loadSavedLinks();
    } catch (_) {
      // اگر حافظهٔ محلی در دسترس نبود، همان کانفیگ پیش‌فرض می‌ماند.
    }
    try {
      await _vless.initializeVless(
        notificationIconResourceType: 'mipmap',
        notificationIconResourceName: 'ic_launcher',
        providerBundleIdentifier: 'com.evelyn.evelyn_vpn',
        groupIdentifier: 'group.com.evelyn.evelyn_vpn',
      );
      _coreVersion = await _vless.getCoreVersion();
    } catch (e) {
      _error = 'خطا در راه‌اندازی: $e';
    }
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _loadSavedLinks() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('vpn_links');
    if (saved != null && saved.isNotEmpty) {
      _links = saved;
      _selected = prefs.getInt('vpn_selected') ?? 0;
      if (_selected < 0 || _selected >= _links.length) _selected = 0;
    }
  }

  Future<void> _saveLinks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('vpn_links', _links);
    await prefs.setInt('vpn_selected', _selected);
  }

  bool get _isConnected =>
      _status.value.connectionState == VlessConnectionState.connected;
  bool get _isConnecting =>
      _status.value.connectionState == VlessConnectionState.connecting;

  String get _currentLink =>
      _links.isEmpty ? defaultVlessLink : _links[_selected];

  /// نام نمایشی سرور از روی بخش # لینک (مثلاً همان ایموجی و اسم کانفیگ).
  String _remarkOf(String link) {
    try {
      final remark = FlutterVless.parse(link).remark.trim();
      if (remark.isNotEmpty) return remark;
    } catch (_) {}
    try {
      final uri = Uri.parse(link);
      return uri.host.isEmpty ? 'سرور' : uri.host;
    } catch (_) {
      return 'سرور';
    }
  }

  String _hostOf(String link) {
    try {
      final uri = Uri.parse(link);
      if (uri.host.isEmpty) return '';
      return '${uri.host}:${uri.hasPort ? uri.port : 443}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _toggle() async {
    if (_isConnected || _isConnecting) {
      await _disconnect();
    } else {
      await _connect();
    }
  }

  Future<void> _connect() async {
    if (_busy || !_ready) return;
    setState(() {
      _busy = true;
      _error = null;
      _pingMs = null;
    });
    try {
      final parsed = FlutterVless.parse(_currentLink);
      final remark =
          parsed.remark.trim().isEmpty ? 'Evelyn VPN' : parsed.remark;
      final config = parsed.getFullConfiguration();

      // روی اندروید این دیالوگ سیستمی VPN را نشان می‌دهد؛ اگر دسترسی
      // از قبل داده شده باشد، true برمی‌گردد و مستقیم وصل می‌شود.
      final granted = await _vless.requestPermission();
      if (!granted) {
        setState(() => _error = 'دسترسی VPN داده نشد.');
        return;
      }
      await _vless.startVless(
        remark: remark,
        config: config,
        notificationDisconnectButtonName: 'قطع اتصال',
      );
    } catch (e) {
      setState(() => _error = 'اتصال برقرار نشد: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _vless.stopVless();
    } catch (e) {
      setState(() => _error = 'قطع اتصال ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// تست تاخیر (پینگ) سرور انتخاب‌شده.
  /// getConnectedServerDelay روی اندروید پشتیبانی نمی‌شود (-1 می‌دهد)،
  /// پس از getServerDelay با همان کانفیگ استفاده می‌کنیم.
  Future<void> _testPing() async {
    if (_pinging) return;
    setState(() {
      _pinging = true;
      _pingMs = null;
    });
    try {
      final parsed = FlutterVless.parse(_currentLink);
      final ms = await _vless.getServerDelay(config: parsed.getFullConfiguration());
      setState(() => _pingMs = ms);
    } catch (_) {
      setState(() => _pingMs = -1);
    } finally {
      if (mounted) setState(() => _pinging = false);
    }
  }

  Future<void> _addLinkDialog() async {
    final controller = TextEditingController();
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('افزودن کانفیگ'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            hintText: 'vless://...',
            hintTextDirection: TextDirection.ltr,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final data = await Clipboard.getData('text/plain');
              final text = data?.text?.trim() ?? '';
              if (text.isNotEmpty) controller.text = text;
            },
            child: const Text('چسباندن'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    if (saved == null || saved.isEmpty) return;
    try {
      FlutterVless.parse(saved); // اعتبارسنجی لینک
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لینک معتبر نیست.')),
      );
      return;
    }
    setState(() {
      _links = [..._links, saved];
      _selected = _links.length - 1;
    });
    await _saveLinks();
  }

  Future<void> _removeLink(int index) async {
    if (_isConnected || _isConnecting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اول اتصال را قطع کن.')),
      );
      return;
    }
    setState(() {
      _links.removeAt(index);
      if (_links.isEmpty) _links = [defaultVlessLink];
      if (_selected >= _links.length) _selected = 0;
    });
    await _saveLinks();
  }

  // ---------- فرمت‌دهی ----------

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    double value = bytes.toDouble();
    int i = 0;
    while (value >= 1024 && i < units.length - 1) {
      value /= 1024;
      i++;
    }
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[i]}';
  }

  String _formatSpeed(int bytesPerSecond) => '${_formatBytes(bytesPerSecond)}/s';

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  String _statusText(VlessConnectionState state) {
    return switch (state) {
      VlessConnectionState.connected => 'متصل',
      VlessConnectionState.connecting => 'در حال اتصال…',
      VlessConnectionState.disconnecting => 'در حال قطع…',
      VlessConnectionState.disconnected => 'قطع',
      VlessConnectionState.unknown => 'نامشخص',
    };
  }

  Color _statusColor(VlessConnectionState state) {
    return switch (state) {
      VlessConnectionState.connected => Colors.green,
      VlessConnectionState.connecting ||
      VlessConnectionState.disconnecting => Colors.orange,
      VlessConnectionState.disconnected => Colors.grey,
      VlessConnectionState.unknown => Colors.grey,
    };
  }

  // ---------- رابط کاربری ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evelyn VPN'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.speed),
            tooltip: 'تست تاخیر',
            onPressed: _pinging ? null : _testPing,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusCard(),
              const SizedBox(height: 16),
              _buildPowerButton(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              _buildSpeedRow(),
              const SizedBox(height: 16),
              _buildServersCard(),
              const SizedBox(height: 12),
              Text(
                'نسخه هسته Xray: ${_coreVersion ?? '…'}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<VlessStatus>(
          valueListenable: _status,
          builder: (context, st, _) {
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _statusColor(st.connectionState),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _statusText(st.connectionState),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _remarkOf(_currentLink),
                  style: const TextStyle(fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                Text(
                  _hostOf(_currentLink),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _miniStat('مدت اتصال', _formatDuration(st.duration)),
                    _miniStat(
                      'تاخیر',
                      _pinging
                          ? '…'
                          : _pingMs == null
                              ? '—'
                              : _pingMs! < 0
                                  ? 'ناموفق'
                                  : '${_pingMs!} ms',
                    ),
                    _miniStat('مجموع دانلود', _formatBytes(st.download)),
                    _miniStat('مجموع آپلود', _formatBytes(st.upload)),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildPowerButton() {
    return ValueListenableBuilder<VlessStatus>(
      valueListenable: _status,
      builder: (context, st, _) {
        final connected = _isConnected || _isConnecting;
        return SizedBox(
          height: 64,
          child: FilledButton.icon(
            onPressed: (_busy || !_ready) ? null : _toggle,
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.power_settings_new, size: 28),
            label: Text(
              connected ? 'قطع اتصال' : 'اتصال',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              backgroundColor:
                  connected ? Colors.redAccent : const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpeedRow() {
    return ValueListenableBuilder<VlessStatus>(
      valueListenable: _status,
      builder: (context, st, _) {
        return Row(
          children: [
            Expanded(
              child: _speedCard(
                'دانلود',
                Icons.arrow_downward,
                Colors.lightBlueAccent,
                _formatSpeed(st.downloadSpeed),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _speedCard(
                'آپلود',
                Icons.arrow_upward,
                Colors.orangeAccent,
                _formatSpeed(st.uploadSpeed),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _speedCard(String label, IconData icon, Color color, String value) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServersCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            ListTile(
              title: const Text(
                'سرورها',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'افزودن کانفیگ',
                onPressed: _addLinkDialog,
              ),
            ),
            const Divider(height: 1),
            ...List.generate(_links.length, (i) {
              final link = _links[i];
              final selected = i == _selected;
              return ListTile(
                leading: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? Colors.green : Colors.grey,
                ),
                title: Text(
                  _remarkOf(link),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _hostOf(link),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                ),
                onTap: (_isConnected || _isConnecting)
                    ? null
                    : () async {
                        setState(() => _selected = i);
                        await _saveLinks();
                      },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'حذف',
                  onPressed: () => _removeLink(i),
                ),
              );
            }),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                'برای عوض کردن سرور، اول اتصال را قطع کن.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _status.dispose();
    super.dispose();
  }
}
