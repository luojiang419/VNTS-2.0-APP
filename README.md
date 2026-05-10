# VNTS 2.0 Windows

这是基于 `Flutter + Rust + flutter_rust_bridge` 的 `VNTS 2.0` Windows 便携桌面控制台。

## 目标

- 将 `vnts2.0服务端开发包/web-ui-source` 的 Linux Web UI 原生迁移为 Flutter Windows 桌面端。
- 在本地桌面中统一管理同级 `data` 目录里的 `vnts2` 运行文件、配置文件、日志与桌面控制台登录。
- 支持：
  - 直接使用同级 `data\vnts2_runtime\`
  - 自动补齐 bundled `vnts2.exe + config.toml`

## 目录结构

```text
vnts2.0windows/
├── assets/
├── lib/
├── rust/
├── rust_builder/
├── scripts/
├── windows/
├── pubspec.yaml
└── flutter_rust_bridge.yaml
```

## 构建要求

- Windows 主机
- Flutter 路径：`D:\APPdata\flutter`
- Rust stable 工具链
- Visual Studio 2022 或 Build Tools（包含桌面 C++）

## 构建方式

```bat
cd vnts2.0windows
scripts\build_windows.bat
```

## 导出便携分发包

```bat
cd vnts2.0windows
scripts\export_portable_package.bat
```

## 导出安装版

```bat
cd vnts2.0windows
scripts\export_installer_package.bat
```

## 调试运行

```bat
cd vnts2.0windows
scripts\run_windows.bat
```

## 运行结构

构建完成后，开发构建产物位于：

- `build\windows\x64\runner\Release\vnts2_windows.exe`
- `build\windows\x64\runner\Release\data\vnts2_runtime\`

其中 `data\vnts2_runtime\` 默认包含：

- `vnts2.exe`
- `config.toml`
- `logs\`
- `.backups\`
- `panel\`

这套结构可以直接整体拷贝到其他电脑使用，不依赖 `ProgramData` 或其他外部固定路径。

## 分发产物

用于对外发送的干净便携包位于：

- `dist\portable\VNTS2_Windows_Portable\`
- `dist\portable\VNTS2_Windows_Portable.zip`

用于对外发送的安装版位于：

- `dist\installer\VNTS2_Windows_Setup.exe`

这里的分发包会和开发 `Release\` 区分开：

- `Release\` 允许保留当前机器运行后生成的状态文件，便于本机调试
- `dist\portable\` 只保留首启必需文件，不包含日志、证书、数据库、备份和账号状态文件
- `dist\installer\` 基于便携 ZIP 自动封装为安装程序，默认引导用户选择安装目录后再解压部署

## 首次使用

- 用户解压后直接运行 `vnts2_windows.exe`
- 首次登录默认账号密码仍为：`luojiang / luojiang`
- 首次登录后必须先修改默认账号或密码，完成后才会进入完整控制台
