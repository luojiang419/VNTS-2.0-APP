import 'package:flutter_test/flutter_test.dart';
import 'package:vnts_panel_windows/panel_helpers.dart';
import 'package:vnts_panel_windows/src/rust/api/panel_api.dart';

void main() {
  const detectionMissing = ServiceDetection(
    installed: false,
    runtimeReady: false,
    runtimeIssue: '未找到运行文件：D:\\apps\\VNTS\\data\\vnts2_runtime\\vnts2.exe',
    serviceName: 'vnts2',
    installDir: r'D:\apps\VNTS\data\vnts2_runtime',
    configPath: r'D:\apps\VNTS\data\vnts2_runtime\config.toml',
    logPath: r'D:\apps\VNTS\data\vnts2_runtime\logs\vnts2.log',
    executablePath: r'D:\apps\VNTS\data\vnts2_runtime\vnts2.exe',
    commandLine: '',
    bundledExecutablePath: 'bundle/vnts2.exe',
    bundledConfigPath: 'bundle/config.toml',
  );
  final statusMissing = ServiceStatus(
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
  );
  final statusRunning = ServiceStatus(
    serviceName: 'vnts2',
    description: 'VNTS 2.0 server for Windows',
    loadState: 'loaded',
    activeState: 'Running',
    subState: 'OK',
    unitFileState: 'Auto',
    pid: BigInt.from(1204),
    mainCode: '0',
    mainStatus: '0',
    activeSince: '2026-05-09 18:00:00',
    fragmentPath: r'D:\apps\VNTS\data\vnts2_runtime\vnts2.exe',
    isActive: true,
    installed: true,
    process: null,
  );

  test('summarize endpoints joins configured listeners', () {
    const config = StructuredConfig(
      tcpBind: '0.0.0.0:2222',
      quicBind: '0.0.0.0:2222',
      wsBind: '',
      network: '10.26.0.0/24',
      whiteList: <String>[],
      leaseDuration: 86400,
      webBind: '',
      username: '',
      password: '',
      persistence: true,
      cert: '',
      key: '',
      serverQuicBind: '',
      peerServers: <String>[],
      serverToken: '',
      customNets: <CustomNetItem>[],
    );

    expect(summarizeEndpoints(config), '0.0.0.0:2222 / 0.0.0.0:2222');
  });

  test('service headline reflects installation and running state', () {
    final missingOverview = ServiceOverview(
      detection: detectionMissing,
      status: statusMissing,
      summaryEndpoints: '未配置',
    );
    final runningOverview = ServiceOverview(
      detection: const ServiceDetection(
        installed: true,
        runtimeReady: true,
        runtimeIssue: '',
        serviceName: 'vnts2',
        installDir: r'D:\apps\VNTS\data\vnts2_runtime',
        configPath: r'D:\apps\VNTS\data\vnts2_runtime\config.toml',
        logPath: r'D:\apps\VNTS\data\vnts2_runtime\logs\vnts2.log',
        executablePath: r'D:\apps\VNTS\data\vnts2_runtime\vnts2.exe',
        commandLine:
            '"D:\\apps\\VNTS\\data\\vnts2_runtime\\vnts2.exe" --conf "D:\\apps\\VNTS\\data\\vnts2_runtime\\config.toml"',
        bundledExecutablePath: 'bundle/vnts2.exe',
        bundledConfigPath: 'bundle/config.toml',
      ),
      status: statusRunning,
      summaryEndpoints: '0.0.0.0:2222',
    );

    expect(serviceHeadline(missingOverview), '本地 VNTS 运行环境未就绪');
    expect(serviceHeadline(runningOverview), '本地 VNTS 实例正在运行');
    expect(
      serviceSubline(missingOverview),
      '未找到运行文件：D:\\apps\\VNTS\\data\\vnts2_runtime\\vnts2.exe',
    );
    expect(canControlInstalledService(missingOverview), isFalse);
    expect(canControlInstalledService(runningOverview), isTrue);
  });

  test('password change helper reflects backend summary flag', () {
    const defaultAccount = PanelAccountSummary(
      requiresPasswordChange: true,
      username: 'luojiang',
      updatedAt: '',
      credentialsPath: r'.\data\vnts2_runtime\panel\vnts-auth.json',
    );
    const customAccount = PanelAccountSummary(
      requiresPasswordChange: false,
      username: 'operator',
      updatedAt: '2026-05-10 10:00:00',
      credentialsPath: r'.\data\vnts2_runtime\panel\vnts-auth.json',
    );

    expect(requiresForcedPasswordChange(defaultAccount), isTrue);
    expect(requiresForcedPasswordChange(customAccount), isFalse);
    expect(requiresForcedPasswordChange(null), isFalse);
  });
}
