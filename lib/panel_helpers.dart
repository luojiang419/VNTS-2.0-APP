import 'src/rust/api/panel_api.dart';

String summarizeEndpoints(StructuredConfig config) {
  final parts = <String>[
    config.tcpBind.trim(),
    config.quicBind.trim(),
    config.wsBind.trim(),
  ].where((item) => item.isNotEmpty).toList();
  return parts.isEmpty ? '未配置' : parts.join(' / ');
}

String serviceHeadline(ServiceOverview overview) {
  if (!overview.detection.installed) {
    return '本地 VNTS 运行环境未就绪';
  }
  if (overview.status.isActive) {
    return '本地 VNTS 实例正在运行';
  }
  return '本地 VNTS 实例当前未运行';
}

String serviceSubline(ServiceOverview overview) {
  if (overview.detection.runtimeIssue.trim().isNotEmpty) {
    return overview.detection.runtimeIssue.trim();
  }
  if (!overview.detection.installed) {
    return '程序会优先使用可执行文件同级 data 目录中的内置 vnts2 运行环境。';
  }
  return overview.status.description.isNotEmpty
      ? overview.status.description
      : '当前已切换到便携独立运行模式，可直接管理启停、配置与日志。';
}

bool canControlInstalledService(ServiceOverview overview) {
  return overview.detection.installed;
}

bool requiresForcedPasswordChange(PanelAccountSummary? account) {
  return account?.requiresPasswordChange ?? false;
}
