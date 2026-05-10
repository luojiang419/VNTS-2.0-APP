import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show PlatformInt64Util;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'panel_helpers.dart';
import 'src/rust/api/panel_api.dart';
import 'src/rust/frb_generated.dart';

const String _defaultInstallDir = r'.\data\vnts2_runtime';
const Color _lightBackground = Color(0xFFF4F7F9);
const Color _lightPanel = Color(0xFFFFFFFF);
const Color _lightPanelAlt = Color(0xFFF7FAFC);
const Color _darkBackground = Color(0xFF12171D);
const Color _darkPanel = Color(0xFF1A212A);
const Color _accent = Color(0xFF31C48D);
const Color _warning = Color(0xFFF59E0B);
const Color _danger = Color(0xFFEF4444);

ThemeMode resolveStoredThemeMode({
  required String? storedMode,
  required bool? legacyDarkMode,
}) {
  return switch (storedMode) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    'system' => ThemeMode.system,
    _ => legacyDarkMode == null
        ? ThemeMode.system
        : (legacyDarkMode ? ThemeMode.dark : ThemeMode.light),
  };
}

String encodeThemeModePreference(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}

Color sidebarSurfaceColor(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFF171F28)
      : _lightPanelAlt;
}

Color sidebarCardColor(Brightness brightness) {
  return brightness == Brightness.dark ? const Color(0xFF22303B) : _lightPanel;
}

Color panelInputFillColor(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFF111922)
      : const Color(0xFFFDFEFF);
}

Color panelLogSurfaceColor(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFF0D1117)
      : const Color(0xFFF8FAFC);
}

Color panelBorderColor(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFF334155)
      : const Color(0xFFD7E0E8);
}

OutlineInputBorder _panelInputBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color, width: width),
  );
}

ThemeData buildPanelLightTheme() {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0F766E),
    brightness: Brightness.light,
  );
  final scheme = baseScheme.copyWith(
    surface: _lightPanel,
    surfaceContainerHighest: const Color(0xFFE6EDF3),
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: _lightBackground,
    canvasColor: sidebarSurfaceColor(Brightness.light),
    dividerColor: panelBorderColor(Brightness.light),
    textTheme: base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    cardTheme: CardThemeData(
      color: _lightPanel,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: panelBorderColor(Brightness.light)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panelInputFillColor(Brightness.light),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      hintStyle: TextStyle(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
      ),
      border: _panelInputBorder(panelBorderColor(Brightness.light)),
      enabledBorder: _panelInputBorder(panelBorderColor(Brightness.light)),
      focusedBorder: _panelInputBorder(scheme.primary, width: 1.4),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: scheme.primary.withValues(alpha: 0.35),
        disabledForegroundColor: scheme.onPrimary.withValues(alpha: 0.65),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: panelBorderColor(Brightness.light)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      textColor: scheme.onSurface,
      iconColor: scheme.onSurfaceVariant,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
    ),
  );
}

ThemeData buildPanelDarkTheme() {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: _accent,
    brightness: Brightness.dark,
  );
  final scheme = baseScheme.copyWith(
    surface: _darkPanel,
    surfaceContainerHighest: const Color(0xFF23303C),
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: _darkBackground,
    canvasColor: sidebarSurfaceColor(Brightness.dark),
    dividerColor: panelBorderColor(Brightness.dark),
    textTheme: base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    cardTheme: CardThemeData(
      color: _darkPanel,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: panelBorderColor(Brightness.dark)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panelInputFillColor(Brightness.dark),
      labelStyle: TextStyle(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.92),
      ),
      hintStyle: TextStyle(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
      ),
      border: _panelInputBorder(panelBorderColor(Brightness.dark)),
      enabledBorder: _panelInputBorder(panelBorderColor(Brightness.dark)),
      focusedBorder:
          _panelInputBorder(_accent.withValues(alpha: 0.92), width: 1.4),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: const Color(0xFF07130D),
        disabledBackgroundColor: _accent.withValues(alpha: 0.35),
        disabledForegroundColor:
            const Color(0xFF07130D).withValues(alpha: 0.65),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: panelBorderColor(Brightness.dark)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      textColor: scheme.onSurface,
      iconColor: scheme.onSurfaceVariant,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF22303B),
      contentTextStyle: TextStyle(color: scheme.onSurface),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    await windowManager.setTitle('VNTS 2.0 控制台');
    await windowManager.setMinimumSize(const Size(1280, 780));
    windowManager.waitUntilReadyToShow().then((_) async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  runApp(const VntsPanelApp());
}

enum ConsoleSection { overview, structured, raw, logs, settings }

extension ConsoleSectionMeta on ConsoleSection {
  String get label => switch (this) {
        ConsoleSection.overview => '总览',
        ConsoleSection.structured => '参数配置',
        ConsoleSection.raw => '高级 TOML',
        ConsoleSection.logs => '实时日志',
        ConsoleSection.settings => '设置',
      };

  IconData get icon => switch (this) {
        ConsoleSection.overview => Icons.dashboard_outlined,
        ConsoleSection.structured => Icons.tune_outlined,
        ConsoleSection.raw => Icons.code_outlined,
        ConsoleSection.logs => Icons.receipt_long_outlined,
        ConsoleSection.settings => Icons.manage_accounts_outlined,
      };
}

class VntsPanelApp extends StatefulWidget {
  const VntsPanelApp({super.key});

  @override
  State<VntsPanelApp> createState() => _VntsPanelAppState();
}

class _VntsPanelAppState extends State<VntsPanelApp> {
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  ThemeMode _themeMode = ThemeMode.system;
  bool _booting = true;
  bool _busy = false;
  bool _requiresPasswordChange = false;
  ConsoleSection _section = ConsoleSection.overview;
  PanelSession _session = const PanelSession(authenticated: false);
  PanelAccountSummary? _account;
  ServiceOverview? _overview;
  ConfigSnapshot? _configSnapshot;
  LogSnapshot? _logSnapshot;
  Timer? _statusTimer;
  Timer? _logTimer;

  final TextEditingController _loginUsernameController =
      TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();
  final TextEditingController _installTargetController =
      TextEditingController(text: _defaultInstallDir);
  final TextEditingController _rawController = TextEditingController();
  final TextEditingController _accountUsernameController =
      TextEditingController();
  final TextEditingController _accountPasswordController =
      TextEditingController();
  final TextEditingController _accountConfirmController =
      TextEditingController();

  final TextEditingController _tcpBindController = TextEditingController();
  final TextEditingController _quicBindController = TextEditingController();
  final TextEditingController _wsBindController = TextEditingController();
  final TextEditingController _networkController = TextEditingController();
  final TextEditingController _whiteListController = TextEditingController();
  final TextEditingController _leaseDurationController =
      TextEditingController();
  final TextEditingController _webBindController = TextEditingController();
  final TextEditingController _webUsernameController = TextEditingController();
  final TextEditingController _webPasswordController = TextEditingController();
  final TextEditingController _certController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _serverQuicBindController =
      TextEditingController();
  final TextEditingController _peerServersController = TextEditingController();
  final TextEditingController _serverTokenController = TextEditingController();
  bool _persistence = true;
  final List<_CustomNetRow> _customNetRows = <_CustomNetRow>[];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _logTimer?.cancel();
    for (final controller in [
      _loginUsernameController,
      _loginPasswordController,
      _installTargetController,
      _rawController,
      _accountUsernameController,
      _accountPasswordController,
      _accountConfirmController,
      _tcpBindController,
      _quicBindController,
      _wsBindController,
      _networkController,
      _whiteListController,
      _leaseDurationController,
      _webBindController,
      _webUsernameController,
      _webPasswordController,
      _certController,
      _keyController,
      _serverQuicBindController,
      _peerServersController,
      _serverTokenController,
    ]) {
      controller.dispose();
    }
    for (final row in _customNetRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final themeMode = resolveStoredThemeMode(
      storedMode: prefs.getString('vnts_panel_theme_mode'),
      legacyDarkMode: prefs.getBool('vnts_panel_dark_mode'),
    );
    var account = const PanelAccountSummary(
      requiresPasswordChange: true,
      username: 'luojiang',
      updatedAt: '',
      credentialsPath: r'.\data\vnts2_runtime\panel\vnts-auth.json',
    );
    var session = const PanelSession(authenticated: false);
    var bootstrapError = false;

    try {
      account = getPanelAccountSummary();
      session = getSession();
      if (session.authenticated && !requiresForcedPasswordChange(account)) {
        await _refreshAll(showToast: false);
        _startTimers();
      }
    } catch (_) {
      bootstrapError = true;
    }

    _loginUsernameController.text = account.username;
    _accountUsernameController.text = account.username;

    if (!mounted) return;
    setState(() {
      _themeMode = themeMode;
      _account = account;
      _requiresPasswordChange =
          session.authenticated && requiresForcedPasswordChange(account);
      _session = session;
      _booting = false;
    });

    if (bootstrapError || _requiresPasswordChange) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showMessage(
          bootstrapError
              ? '本地账号初始化失败，已回退到默认登录信息。'
              : '首次登录请先修改默认账号或密码，再进入完整控制台。',
          isError: true,
        );
      });
    }
  }

  void _stopTimers() {
    _statusTimer?.cancel();
    _logTimer?.cancel();
  }

  void _startTimers() {
    _stopTimers();
    _statusTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
      if (!_session.authenticated) return;
      await _refreshOverviewOnly();
    });
    _logTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!_session.authenticated) return;
      await _refreshLogs(showToast: false);
    });
  }

  Future<void> _refreshAll({bool showToast = true}) async {
    final overview = getServiceOverview();
    final snapshot = loadStructuredConfig();
    final account = getPanelAccountSummary();
    final logs = readLogTail(lines: 200);
    final forcePasswordChange =
        _session.authenticated && requiresForcedPasswordChange(account);
    if (forcePasswordChange) {
      _stopTimers();
    }
    _applyConfig(snapshot.structured);
    if (!mounted) return;
    setState(() {
      _overview = overview;
      _configSnapshot = snapshot;
      _account = account;
      _requiresPasswordChange = forcePasswordChange;
      _logSnapshot = logs;
      _rawController.text = snapshot.raw;
      _accountUsernameController.text = account.username;
      if (_installTargetController.text.trim().isEmpty ||
          _installTargetController.text == _defaultInstallDir) {
        _installTargetController.text = overview.detection.installDir;
      }
    });
    if (showToast) {
      _showMessage('控制台数据已刷新。');
    }
  }

  Future<void> _refreshOverviewOnly() async {
    try {
      final overview = getServiceOverview();
      if (!mounted) return;
      setState(() {
        _overview = overview;
      });
    } catch (_) {}
  }

  Future<void> _refreshLogs({bool showToast = true}) async {
    try {
      final logs = readLogTail(lines: 200);
      if (!mounted) return;
      setState(() {
        _logSnapshot = logs;
      });
      if (showToast) {
        _showMessage('日志已刷新。');
      }
    } catch (error) {
      if (showToast) {
        _showError(error);
      }
    }
  }

  Future<void> _login() async {
    await _runBusy(() async {
      final session = login(
        username: _loginUsernameController.text.trim(),
        password: _loginPasswordController.text,
      );
      final account = getPanelAccountSummary();
      final forcePasswordChange = requiresForcedPasswordChange(account);
      if (!mounted) return;
      setState(() {
        _account = account;
        _accountUsernameController.text = account.username;
        _requiresPasswordChange = forcePasswordChange;
        _session = session;
        _accountPasswordController.clear();
        _accountConfirmController.clear();
        _loginPasswordController.clear();
      });
      if (forcePasswordChange) {
        _stopTimers();
        _showMessage('首次登录请先修改默认账号或密码。', isError: true);
        return;
      }
      await _refreshAll(showToast: false);
      _startTimers();
      _showMessage('登录成功。');
    });
  }

  Future<void> _logout() async {
    await _runBusy(() async {
      final session = logout();
      _stopTimers();
      if (!mounted) return;
      setState(() {
        _requiresPasswordChange = false;
        _session = session;
      });
      _showMessage('已退出桌面控制台。');
    });
  }

  Future<void> _saveStructured({required bool restart}) async {
    await _runBusy(() async {
      final snapshot = saveStructuredConfig(
        payload: _collectStructuredConfig(),
        restart: restart,
      );
      if (!mounted) return;
      setState(() {
        _configSnapshot = snapshot;
        _rawController.text = snapshot.raw;
      });
      await _refreshOverviewOnly();
      _showMessage(restart ? '结构化配置已保存并重启本地实例。' : '结构化配置已保存。');
    });
  }

  Future<void> _saveRaw({required bool restart}) async {
    await _runBusy(() async {
      final snapshot =
          saveRawConfig(raw: _rawController.text, restart: restart);
      if (!mounted) return;
      setState(() {
        _configSnapshot = snapshot;
      });
      _applyConfig(snapshot.structured);
      await _refreshOverviewOnly();
      _showMessage(restart ? 'TOML 已保存并重启本地实例。' : 'TOML 已保存。');
    });
  }

  Future<void> _saveAccount() async {
    if (_accountPasswordController.text != _accountConfirmController.text) {
      _showMessage('两次输入的密码不一致。', isError: true);
      return;
    }
    if (_requiresPasswordChange &&
        _accountUsernameController.text.trim() == 'luojiang' &&
        _accountPasswordController.text == 'luojiang') {
      _showMessage('首次使用必须修改默认账号或密码。', isError: true);
      return;
    }
    await _runBusy(() async {
      final account = updatePanelCredentials(
        username: _accountUsernameController.text.trim(),
        password: _accountPasswordController.text,
      );
      final forcePasswordChange = requiresForcedPasswordChange(account);
      if (!mounted) return;
      setState(() {
        _account = account;
        _loginUsernameController.text = account.username;
        _accountUsernameController.text = account.username;
        _requiresPasswordChange = forcePasswordChange;
        if (!forcePasswordChange) {
          _accountPasswordController.clear();
          _accountConfirmController.clear();
        }
      });
      if (forcePasswordChange) {
        _stopTimers();
        _showMessage('请修改默认账号或密码后再继续使用。', isError: true);
        return;
      }
      await _refreshAll(showToast: false);
      _startTimers();
      _showMessage('桌面控制台登录账号已更新。');
    });
  }

  Future<void> _controlService(String action) async {
    await _runBusy(() async {
      final ServiceOverview overview = switch (action) {
        'start' => startService(),
        'stop' => stopService(),
        'restart' => restartService(),
        _ => throw Exception('不支持的服务操作。'),
      };
      if (!mounted) return;
      setState(() {
        _overview = overview;
      });
      await _refreshLogs(showToast: false);
      _showMessage('本地实例已执行 $action。');
    });
  }

  Future<void> _installService() async {
    await _runBusy(() async {
      final overview = installService(
        targetDir: _installTargetController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _installTargetController.text = overview.detection.installDir;
      });
      await _refreshAll(showToast: false);
      _showMessage('便携运行目录已初始化完成。');
    });
  }

  Future<void> _uninstallService() async {
    final dialogContext = _navigatorKey.currentContext;
    if (dialogContext == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
          context: dialogContext,
          builder: (context) => AlertDialog(
            title: const Text('清理本地运行目录'),
            content: const Text('这会停止本地 VNTS 实例，并清理同级 data 目录中的运行文件。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('确认卸载'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await _runBusy(() async {
      final overview = uninstallService();
      if (!mounted) return;
      setState(() {
        _overview = overview;
      });
      await _refreshAll(showToast: false);
      _showMessage('便携运行目录已清理。');
    });
  }

  Future<void> _runBusy(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _applyConfig(StructuredConfig config) {
    _tcpBindController.text = config.tcpBind;
    _quicBindController.text = config.quicBind;
    _wsBindController.text = config.wsBind;
    _networkController.text = config.network;
    _whiteListController.text = config.whiteList.join('\n');
    _leaseDurationController.text = config.leaseDuration.toString();
    _webBindController.text = config.webBind;
    _webUsernameController.text = config.username;
    _webPasswordController.text = config.password;
    _certController.text = config.cert;
    _keyController.text = config.key;
    _serverQuicBindController.text = config.serverQuicBind;
    _peerServersController.text = config.peerServers.join('\n');
    _serverTokenController.text = config.serverToken;
    _persistence = config.persistence;
    for (final row in _customNetRows) {
      row.dispose();
    }
    _customNetRows
      ..clear()
      ..addAll(config.customNets.map(_CustomNetRow.fromItem));
    if (_customNetRows.isEmpty) {
      _customNetRows.add(_CustomNetRow.empty());
    }
  }

  StructuredConfig _collectStructuredConfig() {
    final customNets = _customNetRows
        .map((row) => row.toItem())
        .where((item) =>
            item.name.trim().isNotEmpty || item.cidr.trim().isNotEmpty)
        .toList();
    return StructuredConfig(
      tcpBind: _tcpBindController.text.trim(),
      quicBind: _quicBindController.text.trim(),
      wsBind: _wsBindController.text.trim(),
      network: _networkController.text.trim(),
      whiteList: _splitLines(_whiteListController.text),
      leaseDuration: PlatformInt64Util.from(
          int.tryParse(_leaseDurationController.text) ?? 86400),
      webBind: _webBindController.text.trim(),
      username: _webUsernameController.text.trim(),
      password: _webPasswordController.text,
      persistence: _persistence,
      cert: _certController.text.trim(),
      key: _keyController.text.trim(),
      serverQuicBind: _serverQuicBindController.text.trim(),
      peerServers: _splitLines(_peerServersController.text),
      serverToken: _serverTokenController.text.trim(),
      customNets: customNets,
    );
  }

  List<String> _splitLines(String value) {
    return value
        .split(RegExp(r'[\r\n,]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  bool _isDarkTheme(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  IconData _themeToggleIcon(BuildContext context) {
    return _isDarkTheme(context)
        ? Icons.light_mode_outlined
        : Icons.dark_mode_outlined;
  }

  String _themeToggleLabel(BuildContext context, {bool compact = false}) {
    final dark = _isDarkTheme(context);
    if (compact) {
      return dark ? '浅色' : '深色';
    }
    return dark ? '切换到浅色主题' : '切换到深色主题';
  }

  Future<void> _toggleTheme(BuildContext context) async {
    final nextMode = _isDarkTheme(context) ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'vnts_panel_theme_mode',
      encodeThemeModePreference(nextMode),
    );
    await prefs.remove('vnts_panel_dark_mode');
    if (!mounted) return;
    setState(() {
      _themeMode = nextMode;
    });
  }

  ButtonStyle _sidebarNavButtonStyle(
    BuildContext context, {
    required bool selected,
  }) {
    final theme = Theme.of(context);
    final dark = _isDarkTheme(context);
    final background = selected
        ? (dark
            ? _accent.withValues(alpha: 0.18)
            : theme.colorScheme.primaryContainer)
        : sidebarCardColor(theme.brightness);
    final borderColor = selected
        ? (dark
            ? _accent.withValues(alpha: 0.36)
            : theme.colorScheme.primary.withValues(alpha: 0.28))
        : theme.dividerColor.withValues(alpha: dark ? 0.75 : 1);
    return FilledButton.styleFrom(
      backgroundColor: background,
      foregroundColor: theme.colorScheme.onSurface,
      disabledBackgroundColor: background.withValues(alpha: 0.55),
      disabledForegroundColor:
          theme.colorScheme.onSurface.withValues(alpha: 0.55),
      minimumSize: const Size.fromHeight(52),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor),
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? _danger : _accent,
        ),
      );
  }

  void _showError(Object error) {
    _showMessage(error.toString(), isError: true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      title: 'VNTS 2.0 控制台',
      themeMode: _themeMode,
      theme: buildPanelLightTheme(),
      darkTheme: buildPanelDarkTheme(),
      home: Builder(
        builder: (context) {
          if (_booting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return Scaffold(
            body: _session.authenticated
                ? (_requiresPasswordChange
                    ? _buildForcePasswordChange(context)
                    : _buildConsole(context))
                : _buildLogin(context),
          );
        },
      ),
    );
  }

  Widget _buildLogin(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Card(
          elevation: 10,
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '登录 VNTS 控制台',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '桌面端会直接管理同级 data 目录中的 VNTS 运行文件、配置和日志，请先完成本地认证。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _loginUsernameController,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _loginPasswordController,
                  obscureText: true,
                  onSubmitted: (_) => _login(),
                  decoration: const InputDecoration(
                    labelText: '密码',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _login,
                    child: Text(_busy ? '登录中...' : '进入控制台'),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _toggleTheme(context),
                  icon: Icon(_themeToggleIcon(context)),
                  label: Text(_themeToggleLabel(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForcePasswordChange(BuildContext context) {
    final account = _account;
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          elevation: 10,
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '首次使用请先修改默认登录信息',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '当前桌面控制台仍在使用默认账号密码。为了保证你分发给用户后可直接安全使用，必须先完成改密，之后才会开放完整控制台。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                if (account != null) ...[
                  Text(
                    '当前默认账号：${account.username}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _accountUsernameController,
                  decoration: const InputDecoration(
                    labelText: '新登录账号',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _accountPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '新密码',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _accountConfirmController,
                  obscureText: true,
                  onSubmitted: (_) => _saveAccount(),
                  decoration: const InputDecoration(
                    labelText: '确认新密码',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : _saveAccount,
                      child: const Text('保存并进入控制台'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _logout,
                      icon: const Icon(Icons.logout_outlined),
                      label: const Text('退出登录'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _toggleTheme(context),
                      icon: Icon(_themeToggleIcon(context)),
                      label: Text(_themeToggleLabel(context)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConsole(BuildContext context) {
    final overview = _overview;
    final theme = Theme.of(context);
    final sidebarBorder = theme.dividerColor.withValues(
      alpha: _isDarkTheme(context) ? 0.78 : 1,
    );
    final sidebarCard = sidebarCardColor(theme.brightness);
    return Row(
      children: [
        Container(
          width: 286,
          decoration: BoxDecoration(
            color: sidebarSurfaceColor(theme.brightness),
            border: Border(right: BorderSide(color: sidebarBorder)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: sidebarCard,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: sidebarBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VNTS 2.0 控制台',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          serviceSubline(overview ?? _placeholderOverview()),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _StatusPill(overview: overview),
                  const SizedBox(height: 24),
                  for (final section in ConsoleSection.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FilledButton.tonalIcon(
                        onPressed: () => setState(() => _section = section),
                        icon: Icon(section.icon),
                        label: Text(section.label),
                        style: _sidebarNavButtonStyle(
                          context,
                          selected: _section == section,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: sidebarCard,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: sidebarBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _account?.username ?? _session.user ?? '已登录',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          overview?.detection.serviceName ?? 'vnts2',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _toggleTheme(context),
                              icon: Icon(_themeToggleIcon(context)),
                              label: Text(
                                _themeToggleLabel(context, compact: true),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _refreshAll,
                              icon: const Icon(Icons.refresh),
                              label: const Text('刷新'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _logout,
                              icon: const Icon(Icons.logout),
                              label: const Text('退出'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: SafeArea(
            child: _busy
                ? Stack(
                    children: [
                      _buildSectionBody(context),
                      const Align(
                        alignment: Alignment.topCenter,
                        child: LinearProgressIndicator(minHeight: 3),
                      ),
                    ],
                  )
                : _buildSectionBody(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: switch (_section) {
        ConsoleSection.overview => _buildOverviewSection(context),
        ConsoleSection.structured => _buildStructuredSection(context),
        ConsoleSection.raw => _buildRawSection(context),
        ConsoleSection.logs => _buildLogsSection(context),
        ConsoleSection.settings => _buildSettingsSection(context),
      },
    );
  }

  Widget _buildOverviewSection(BuildContext context) {
    final overview = _overview;
    if (overview == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final canControl = canControlInstalledService(overview);
    return ListView(
      children: [
        Text(
          serviceHeadline(overview),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(serviceSubline(overview)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _MetricCard(label: '实例名', value: overview.detection.serviceName),
            _MetricCard(label: 'PID', value: overview.status.pid.toString()),
            _MetricCard(
              label: '运行时长',
              value: overview.status.process?.elapsed.isNotEmpty == true
                  ? overview.status.process!.elapsed
                  : '-',
            ),
            _MetricCard(
              label: 'CPU',
              value: overview.status.process?.cpuDisplay.isNotEmpty == true
                  ? overview.status.process!.cpuDisplay
                  : '-',
            ),
            _MetricCard(
              label: '内存',
              value: overview.status.process?.memoryDisplay.isNotEmpty == true
                  ? overview.status.process!.memoryDisplay
                  : '-',
            ),
            _MetricCard(label: '监听概览', value: overview.summaryEndpoints),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('实例控制', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: canControl && !_busy
                          ? () => _controlService('start')
                          : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('启动'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: canControl && !_busy
                          ? () => _controlService('restart')
                          : null,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('重启'),
                    ),
                    OutlinedButton.icon(
                      onPressed: canControl && !_busy
                          ? () => _controlService('stop')
                          : null,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('停止'),
                    ),
                    FilledButton.icon(
                      onPressed: !canControl && !_busy ? _installService : null,
                      icon: const Icon(Icons.download_done_outlined),
                      label: const Text('初始化运行目录'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          canControl && !_busy ? _uninstallService : null,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('清理运行目录'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _installTargetController,
                  decoration: const InputDecoration(
                    labelText: '运行目录',
                    helperText: '固定使用可执行程序同级 data 目录下的 vnts2_runtime。',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('运行摘要', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _KeyValueRow(
                    label: '运行目录', value: overview.detection.installDir),
                _KeyValueRow(
                    label: '配置文件', value: overview.detection.configPath),
                _KeyValueRow(label: '日志文件', value: overview.detection.logPath),
                _KeyValueRow(
                    label: '启动命令',
                    value: overview.detection.commandLine.isEmpty
                        ? '-'
                        : overview.detection.commandLine),
                _KeyValueRow(
                    label: '内置 vnts2',
                    value: overview.detection.bundledExecutablePath.isEmpty
                        ? '未打包'
                        : overview.detection.bundledExecutablePath),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStructuredSection(BuildContext context) {
    return ListView(
      children: [
        Text('常用参数面板', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('和 Linux Web UI 对齐的结构化配置入口。'),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _FormFieldCard(
                        controller: _tcpBindController, label: 'TCP 监听'),
                    _FormFieldCard(
                        controller: _quicBindController, label: 'QUIC 监听'),
                    _FormFieldCard(
                        controller: _wsBindController, label: 'WebSocket 监听'),
                    _FormFieldCard(
                        controller: _webBindController, label: 'Web 管理端'),
                    _FormFieldCard(
                        controller: _networkController, label: '默认网段'),
                    _FormFieldCard(
                        controller: _leaseDurationController, label: '租约时长（秒）'),
                    _FormFieldCard(
                        controller: _webUsernameController, label: 'Web 用户名'),
                    _FormFieldCard(
                        controller: _webPasswordController, label: 'Web 密码'),
                    _FormFieldCard(
                        controller: _certController, label: 'TLS 证书路径'),
                    _FormFieldCard(
                        controller: _keyController, label: 'TLS 私钥路径'),
                    _FormFieldCard(
                        controller: _serverQuicBindController, label: '服务互联端口'),
                    SizedBox(
                      width: 280,
                      child: Card(
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: CheckboxListTile(
                            value: _persistence,
                            onChanged: (value) =>
                                setState(() => _persistence = value ?? true),
                            title: const Text('启用数据持久化'),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ),
                      ),
                    ),
                    _TextAreaFieldCard(
                      controller: _whiteListController,
                      label: '网络编号白名单',
                    ),
                    _TextAreaFieldCard(
                      controller: _peerServersController,
                      label: '互联服务器列表',
                    ),
                    _FormFieldCard(
                        controller: _serverTokenController, label: '服务互联验证码'),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text('自定义虚拟网段',
                        style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _customNetRows.add(_CustomNetRow.empty());
                      }),
                      icon: const Icon(Icons.add),
                      label: const Text('新增网段'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < _customNetRows.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customNetRows[i].nameController,
                            decoration: const InputDecoration(
                              labelText: '名称',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _customNetRows[i].cidrController,
                            decoration: const InputDecoration(
                              labelText: 'CIDR',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: _customNetRows.length == 1
                              ? null
                              : () => setState(() {
                                    final row = _customNetRows.removeAt(i);
                                    row.dispose();
                                  }),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed:
                          _busy ? null : () => _saveStructured(restart: false),
                      child: const Text('保存'),
                    ),
                    FilledButton.tonal(
                      onPressed:
                          _busy ? null : () => _saveStructured(restart: true),
                      child: const Text('保存并重启'),
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () {
                              if (_configSnapshot != null) {
                                _applyConfig(_configSnapshot!.structured);
                                _showMessage('已恢复到当前配置版本。');
                              }
                            },
                      child: const Text('恢复当前版本'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRawSection(BuildContext context) {
    return ListView(
      children: [
        Text('原始 TOML 编辑器', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('保留 Linux 控制台里的高级配置入口，适合完整修改原始 TOML。'),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                SizedBox(
                  height: 520,
                  child: TextField(
                    controller: _rawController,
                    maxLines: null,
                    expands: true,
                    style:
                        const TextStyle(fontFamily: 'Consolas', fontSize: 13.5),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                      labelText: 'config.toml',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : () => _saveRaw(restart: false),
                      child: const Text('保存 TOML'),
                    ),
                    FilledButton.tonal(
                      onPressed: _busy ? null : () => _saveRaw(restart: true),
                      child: const Text('保存并重启'),
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () {
                              if (_configSnapshot != null) {
                                _rawController.text = _configSnapshot!.raw;
                                _showMessage('已恢复到本地当前版本。');
                              }
                            },
                      child: const Text('恢复当前版本'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogsSection(BuildContext context) {
    final logSnapshot = _logSnapshot;
    return ListView(
      children: [
        Text('实时日志监控', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(logSnapshot == null ? '正在读取日志...' : '当前日志文件：${logSnapshot.path}'),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined),
                    const SizedBox(width: 8),
                    Text(
                      logSnapshot?.exists == true ? '日志追踪中' : '日志文件尚未生成',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _refreshLogs,
                      icon: const Icon(Icons.refresh),
                      label: const Text('刷新日志'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 560,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: panelLogSurfaceColor(Theme.of(context).brightness),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          Theme.of(context).dividerColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      (logSnapshot?.lines.isNotEmpty ?? false)
                          ? logSnapshot!.lines.join('\n')
                          : '暂无日志输出。',
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 13.2,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Text('设置', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          '桌面控制台登录和本地控制行为设置。',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('登录账号', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _FormFieldCard(
                      controller: _accountUsernameController,
                      label: '登录账号',
                    ),
                    _FormFieldCard(
                      controller: _accountPasswordController,
                      label: '新密码',
                      obscureText: true,
                    ),
                    _FormFieldCard(
                      controller: _accountConfirmController,
                      label: '确认密码',
                      obscureText: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _KeyValueRow(
                  label: '账号文件',
                  value: _account?.credentialsPath ?? '-',
                ),
                _KeyValueRow(
                  label: '最近更新',
                  value: _account?.updatedAt ?? '-',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : _saveAccount,
                      child: const Text('保存账号密码'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _toggleTheme(context),
                      icon: Icon(_themeToggleIcon(context)),
                      label: Text(_themeToggleLabel(context)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.overview});

  final ServiceOverview? overview;

  @override
  Widget build(BuildContext context) {
    final text = overview == null
        ? '同步中'
        : overview!.detection.installed
            ? (overview!.status.isActive ? '实例运行中' : '运行文件已就绪但实例未启动')
            : '运行文件未就绪';
    final color = overview == null
        ? _warning
        : !overview!.detection.installed
            ? _warning
            : (overview!.status.isActive ? _accent : _danger);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 12, color: color),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 10),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _FormFieldCard extends StatelessWidget {
  const _FormFieldCard({
    required this.controller,
    required this.label,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _TextAreaFieldCard extends StatelessWidget {
  const _TextAreaFieldCard({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 420,
      child: TextField(
        controller: controller,
        maxLines: 5,
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _CustomNetRow {
  _CustomNetRow({
    required this.nameController,
    required this.cidrController,
  });

  factory _CustomNetRow.empty() => _CustomNetRow(
        nameController: TextEditingController(),
        cidrController: TextEditingController(),
      );

  factory _CustomNetRow.fromItem(CustomNetItem item) => _CustomNetRow(
        nameController: TextEditingController(text: item.name),
        cidrController: TextEditingController(text: item.cidr),
      );

  final TextEditingController nameController;
  final TextEditingController cidrController;

  CustomNetItem toItem() => CustomNetItem(
        name: nameController.text.trim(),
        cidr: cidrController.text.trim(),
      );

  void dispose() {
    nameController.dispose();
    cidrController.dispose();
  }
}

ServiceOverview _placeholderOverview() {
  return ServiceOverview(
    detection: const ServiceDetection(
      installed: false,
      runtimeReady: false,
      runtimeIssue: '',
      serviceName: 'vnts2',
      installDir: _defaultInstallDir,
      configPath: '',
      logPath: '',
      executablePath: '',
      commandLine: '',
      bundledExecutablePath: '',
      bundledConfigPath: '',
    ),
    status: ServiceStatus(
      serviceName: 'vnts2',
      description: '',
      loadState: 'missing',
      activeState: 'not_installed',
      subState: 'missing',
      unitFileState: 'absent',
      pid: BigInt.zero,
      mainCode: '',
      mainStatus: '',
      activeSince: '',
      fragmentPath: '',
      isActive: false,
      installed: false,
      process: null,
    ),
    summaryEndpoints: '未配置',
  );
}
