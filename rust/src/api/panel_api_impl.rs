use anyhow::{anyhow, bail, Context};
use chrono::Local;
use once_cell::sync::Lazy;
use pbkdf2::pbkdf2_hmac_array;
use regex::Regex;
use serde::{Deserialize, Serialize};
use serde_json::Value as JsonValue;
use sha2::Sha256;
use std::ffi::OsStr;
use std::fs;
use std::io::{BufRead, BufReader, ErrorKind};
#[cfg(target_os = "windows")]
use std::os::windows::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::Mutex;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

const DEFAULT_SERVICE_NAME: &str = "vnts2";
const DEFAULT_PANEL_USERNAME: &str = "luojiang";
const DEFAULT_PANEL_PASSWORD: &str = "luojiang";
const PASSWORD_ITERATIONS: u32 = 120_000;
const DATA_ROOT_OVERRIDE_ENV: &str = "VNTS_PANEL_DATA_ROOT";
#[cfg(target_os = "windows")]
const DETACHED_PROCESS: u32 = 0x00000008;
#[cfg(target_os = "windows")]
const CREATE_NO_WINDOW: u32 = 0x08000000;

static CURRENT_SESSION: Lazy<Mutex<Option<String>>> = Lazy::new(|| Mutex::new(None));
static CONF_ARG_REGEX: Lazy<Regex> =
    Lazy::new(|| Regex::new(r#"(?i)(?:--conf|-c)\s+(?:"([^"]+)"|([^\s]+))"#).expect("regex"));

#[derive(Clone, Debug, Default)]
pub struct PanelSession {
    pub authenticated: bool,
    pub user: Option<String>,
}

#[derive(Clone, Debug, Default)]
pub struct PanelAccountSummary {
    pub username: String,
    pub updated_at: String,
    pub credentials_path: String,
    pub requires_password_change: bool,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct CustomNetItem {
    pub name: String,
    pub cidr: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct StructuredConfig {
    pub tcp_bind: String,
    pub quic_bind: String,
    pub ws_bind: String,
    pub network: String,
    pub white_list: Vec<String>,
    pub lease_duration: i64,
    pub web_bind: String,
    pub username: String,
    pub password: String,
    pub persistence: bool,
    pub cert: String,
    pub key: String,
    pub server_quic_bind: String,
    pub peer_servers: Vec<String>,
    pub server_token: String,
    pub custom_nets: Vec<CustomNetItem>,
}

impl Default for StructuredConfig {
    fn default() -> Self {
        Self {
            tcp_bind: "0.0.0.0:2222".to_string(),
            quic_bind: "0.0.0.0:2222".to_string(),
            ws_bind: "0.0.0.0:2222".to_string(),
            network: "10.26.0.0/24".to_string(),
            white_list: Vec::new(),
            lease_duration: 86400,
            web_bind: String::new(),
            username: String::new(),
            password: String::new(),
            persistence: true,
            cert: String::new(),
            key: String::new(),
            server_quic_bind: String::new(),
            peer_servers: Vec::new(),
            server_token: String::new(),
            custom_nets: Vec::new(),
        }
    }
}

#[derive(Clone, Debug, Default)]
pub struct ConfigSnapshot {
    pub path: String,
    pub raw: String,
    pub structured: StructuredConfig,
    pub updated_at: String,
    pub backup_path: Option<String>,
}

#[derive(Clone, Debug, Default)]
pub struct ServiceProcessInfo {
    pub cpu_display: String,
    pub memory_display: String,
    pub elapsed: String,
    pub command: String,
}

#[derive(Clone, Debug, Default)]
pub struct ServiceStatus {
    pub service_name: String,
    pub description: String,
    pub load_state: String,
    pub active_state: String,
    pub sub_state: String,
    pub unit_file_state: String,
    pub pid: u64,
    pub main_code: String,
    pub main_status: String,
    pub active_since: String,
    pub fragment_path: String,
    pub is_active: bool,
    pub installed: bool,
    pub process: Option<ServiceProcessInfo>,
}

#[derive(Clone, Debug, Default)]
pub struct ServiceDetection {
    pub installed: bool,
    pub runtime_ready: bool,
    pub runtime_issue: String,
    pub service_name: String,
    pub install_dir: String,
    pub config_path: String,
    pub log_path: String,
    pub executable_path: String,
    pub command_line: String,
    pub bundled_executable_path: String,
    pub bundled_config_path: String,
}

#[derive(Clone, Debug, Default)]
pub struct ServiceOverview {
    pub detection: ServiceDetection,
    pub status: ServiceStatus,
    pub summary_endpoints: String,
}

#[derive(Clone, Debug, Default)]
pub struct LogSnapshot {
    pub lines: Vec<String>,
    pub requested: u32,
    pub path: String,
    pub exists: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct StoredCredentials {
    username: String,
    password_hash: String,
    salt: String,
    updated_at: String,
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Clone, Debug, Default)]
struct RuntimeLayoutState {
    runtime_ready: bool,
    runtime_issue: String,
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ServiceJsonStatus {
    pub service_name: String,
    pub description: String,
    pub load_state: String,
    pub active_state: String,
    pub sub_state: String,
    pub unit_file_state: String,
    pub pid: u64,
    pub main_code: String,
    pub main_status: String,
    pub active_since: String,
    pub fragment_path: String,
    pub is_active: bool,
    pub process: Option<ServiceJsonProcess>,
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ServiceJsonProcess {
    pub cpu_display: Option<String>,
    pub memory_display: Option<String>,
    pub elapsed: Option<String>,
    pub command: Option<String>,
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct ServiceQuery {
    #[serde(default)]
    pub installed: bool,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub path_name: String,
    #[serde(default)]
    pub state: String,
    #[serde(default)]
    pub status: String,
    #[serde(default)]
    pub start_mode: String,
    #[serde(default)]
    pub process_id: u64,
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub exit_code: String,
    #[serde(default)]
    pub service_specific_exit_code: String,
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Default, Deserialize)]
pub struct RawConfigToml {
    pub tcp_bind: Option<String>,
    pub quic_bind: Option<String>,
    pub ws_bind: Option<String>,
    pub network: Option<String>,
    pub white_list: Option<Vec<String>>,
    pub lease_duration: Option<i64>,
    pub web_bind: Option<String>,
    pub username: Option<String>,
    pub password: Option<String>,
    pub persistence: Option<bool>,
    pub cert: Option<String>,
    pub key: Option<String>,
    pub server_quic_bind: Option<String>,
    pub peer_servers: Option<Vec<String>>,
    pub server_token: Option<String>,
    pub custom_nets: Option<std::collections::BTreeMap<String, String>>,
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_session() -> PanelSession {
    let user = CURRENT_SESSION.lock().ok().and_then(|guard| guard.clone());
    PanelSession {
        authenticated: user.is_some(),
        user,
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn login(username: String, password: String) -> anyhow::Result<PanelSession> {
    let credentials = load_or_initialize_credentials()?;
    if username.trim() != credentials.username {
        bail!("用户名或密码不正确。");
    }
    if !verify_password(&password, &credentials) {
        bail!("用户名或密码不正确。");
    }
    let mut guard = CURRENT_SESSION
        .lock()
        .map_err(|_| anyhow!("登录会话锁定失败。"))?;
    *guard = Some(credentials.username.clone());
    Ok(PanelSession {
        authenticated: true,
        user: Some(credentials.username),
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn logout() -> anyhow::Result<PanelSession> {
    let mut guard = CURRENT_SESSION
        .lock()
        .map_err(|_| anyhow!("注销会话失败。"))?;
    *guard = None;
    Ok(PanelSession::default())
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_panel_account_summary() -> anyhow::Result<PanelAccountSummary> {
    let credentials = load_or_initialize_credentials()?;
    Ok(PanelAccountSummary {
        requires_password_change: requires_password_change(&credentials),
        username: credentials.username,
        updated_at: credentials.updated_at,
        credentials_path: credentials_path().display().to_string(),
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn update_panel_credentials(
    username: String,
    password: String,
) -> anyhow::Result<PanelAccountSummary> {
    let username = username.trim();
    if username.is_empty() {
        bail!("用户名不能为空。");
    }
    if username.len() < 3 {
        bail!("用户名至少需要 3 个字符。");
    }
    if password.is_empty() {
        bail!("密码不能为空。");
    }
    if password.len() < 4 {
        bail!("密码至少需要 4 个字符。");
    }
    let salt = format!(
        "{:x}",
        SystemTime::now().duration_since(UNIX_EPOCH)?.as_nanos()
    );
    let password_hash = hex::encode(pbkdf2_hmac_array::<Sha256, 32>(
        password.as_bytes(),
        salt.as_bytes(),
        PASSWORD_ITERATIONS,
    ));
    let record = StoredCredentials {
        username: username.to_string(),
        password_hash,
        salt,
        updated_at: now_string(),
    };
    persist_credentials(&record)?;
    if let Ok(mut guard) = CURRENT_SESSION.lock() {
        if guard.is_some() {
            *guard = Some(record.username.clone());
        }
    }
    Ok(PanelAccountSummary {
        requires_password_change: requires_password_change(&record),
        username: record.username,
        updated_at: record.updated_at,
        credentials_path: credentials_path().display().to_string(),
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn detect_existing_service() -> anyhow::Result<ServiceDetection> {
    detect_service()
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_service_overview() -> anyhow::Result<ServiceOverview> {
    build_service_overview()
}

#[flutter_rust_bridge::frb(sync)]
pub fn start_service() -> anyhow::Result<ServiceOverview> {
    run_service_action("start")?;
    build_service_overview()
}

#[flutter_rust_bridge::frb(sync)]
pub fn stop_service() -> anyhow::Result<ServiceOverview> {
    run_service_action("stop")?;
    build_service_overview()
}

#[flutter_rust_bridge::frb(sync)]
pub fn restart_service() -> anyhow::Result<ServiceOverview> {
    run_service_action("restart")?;
    build_service_overview()
}

#[flutter_rust_bridge::frb(sync)]
pub fn install_service(target_dir: String) -> anyhow::Result<ServiceOverview> {
    let _ = target_dir;
    ensure_runtime_layout()?;
    build_service_overview()
}

#[flutter_rust_bridge::frb(sync)]
pub fn uninstall_service() -> anyhow::Result<ServiceOverview> {
    let _ = stop_portable_process();
    let runtime_dir = default_install_dir();
    if runtime_dir.exists() {
        fs::remove_dir_all(&runtime_dir)
            .with_context(|| format!("清理运行目录失败：{}", runtime_dir.display()))?;
    }
    build_service_overview()
}

#[flutter_rust_bridge::frb(sync)]
pub fn load_structured_config() -> anyhow::Result<ConfigSnapshot> {
    load_config_snapshot()
}

#[flutter_rust_bridge::frb(sync)]
pub fn save_structured_config(
    payload: StructuredConfig,
    restart: bool,
) -> anyhow::Result<ConfigSnapshot> {
    validate_structured_config(&payload)?;
    let raw = render_structured_config(&payload);
    let snapshot = write_config_snapshot(&raw)?;
    if restart {
        let detection = detect_service()?;
        if detection.installed {
            restart_service()?;
        }
    }
    Ok(snapshot)
}

#[flutter_rust_bridge::frb(sync)]
pub fn load_raw_config() -> anyhow::Result<ConfigSnapshot> {
    load_config_snapshot()
}

#[flutter_rust_bridge::frb(sync)]
pub fn save_raw_config(raw: String, restart: bool) -> anyhow::Result<ConfigSnapshot> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        bail!("TOML 内容不能为空。");
    }
    let _ = parse_toml(trimmed)?;
    let snapshot = write_config_snapshot(&(trimmed.to_string() + "\n"))?;
    if restart {
        let detection = detect_service()?;
        if detection.installed {
            restart_service()?;
        }
    }
    Ok(snapshot)
}

#[flutter_rust_bridge::frb(sync)]
pub fn read_log_tail(lines: i32) -> anyhow::Result<LogSnapshot> {
    let detection = detect_service()?;
    let requested = lines.clamp(20, 500) as usize;
    let log_path = PathBuf::from(&detection.log_path);
    if !log_path.exists() {
        return Ok(LogSnapshot {
            lines: vec![format!("日志文件不存在：{}", log_path.display())],
            requested: requested as u32,
            path: log_path.display().to_string(),
            exists: false,
        });
    }
    let file = fs::File::open(&log_path)
        .with_context(|| format!("读取日志文件失败：{}", log_path.display()))?;
    let reader = BufReader::new(file);
    let mut all_lines: Vec<String> = reader
        .lines()
        .map(|line| line.unwrap_or_default())
        .filter(|line| !line.trim().is_empty())
        .collect();
    if all_lines.len() > requested {
        all_lines = all_lines.split_off(all_lines.len() - requested);
    }
    Ok(LogSnapshot {
        lines: all_lines,
        requested: requested as u32,
        path: log_path.display().to_string(),
        exists: true,
    })
}

fn build_service_overview() -> anyhow::Result<ServiceOverview> {
    let detection = detect_service()?;
    let status = query_service_status()?;
    let snapshot = load_config_snapshot_for_path(Path::new(&detection.config_path))?;
    let summary_endpoints = summarize_endpoints(&snapshot.structured);
    Ok(ServiceOverview {
        detection,
        status,
        summary_endpoints,
    })
}

fn detect_service() -> anyhow::Result<ServiceDetection> {
    let runtime_state = inspect_runtime_layout();
    let bundled_executable_path = resolve_bundled_asset_source("vnts2.exe")
        .map(|path| path.display().to_string())
        .unwrap_or_default();
    let bundled_config_path = resolve_bundled_asset_source("config.toml")
        .map(|path| path.display().to_string())
        .unwrap_or_default();
    let install_dir = default_install_dir();
    let executable_path = install_dir.join("vnts2.exe");
    let config_path = install_dir.join("config.toml");
    let installed = executable_path.exists() && config_path.exists();
    Ok(ServiceDetection {
        installed,
        runtime_ready: runtime_state.runtime_ready,
        runtime_issue: runtime_state.runtime_issue,
        service_name: DEFAULT_SERVICE_NAME.to_string(),
        install_dir: install_dir.display().to_string(),
        config_path: config_path.display().to_string(),
        log_path: install_dir
            .join("logs")
            .join("vnts2.log")
            .display()
            .to_string(),
        executable_path: executable_path.display().to_string(),
        command_line: if installed {
            format!(
                "\"{}\" --conf \"{}\"",
                executable_path.display(),
                config_path.display()
            )
        } else {
            String::new()
        },
        bundled_executable_path,
        bundled_config_path,
    })
}

fn query_service_status() -> anyhow::Result<ServiceStatus> {
    let detection = detect_service()?;
    if !detection.installed {
        return Ok(ServiceStatus {
            service_name: DEFAULT_SERVICE_NAME.to_string(),
            description: if detection.runtime_issue.trim().is_empty() {
                "便携运行目录尚未完成初始化。".to_string()
            } else {
                detection.runtime_issue.clone()
            },
            load_state: "missing".to_string(),
            active_state: "not_ready".to_string(),
            sub_state: "missing".to_string(),
            unit_file_state: "portable".to_string(),
            installed: false,
            ..ServiceStatus::default()
        });
    }
    let script = format!(
        r#"
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$exePath = '{exe_path}'
$configPath = '{config_path}'
$commandLine = '{command_line}'
$processes = Get-CimInstance Win32_Process -Filter "Name='vnts2.exe'"
$tcpListeners = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue)
$udpListeners = @(Get-NetUDPEndpoint -ErrorAction SilentlyContinue)
$process = $null
$processPayload = $null
$activeSince = ''
$activeState = 'Stopped'
$subState = 'Stopped'
$description = 'Portable VNTS 2.0 runtime'
foreach ($candidate in $processes) {{
  try {{
    $proc = Get-Process -Id $candidate.ProcessId -ErrorAction Stop
    $candidateTcpListeners = @($tcpListeners | Where-Object {{ $_.OwningProcess -eq $candidate.ProcessId }})
    $candidateUdpListeners = @($udpListeners | Where-Object {{ $_.OwningProcess -eq $candidate.ProcessId }})
    $hasListeners = ($candidateTcpListeners.Count -gt 0 -or $candidateUdpListeners.Count -gt 0)
    $matchesExecutablePath = ($candidate.ExecutablePath -eq $exePath)
    $matchesCommandLine = (-not [string]::IsNullOrWhiteSpace($candidate.CommandLine)) -and (
      $candidate.CommandLine -like "*$exePath*" -or
      $candidate.CommandLine -like "*$configPath*"
    )
    $isTargetProcess = $hasListeners -or $matchesExecutablePath -or $matchesCommandLine
    if (-not $isTargetProcess) {{
      continue
    }}
    if ($hasListeners -or $null -eq $process) {{
      $process = $candidate
      $activeSince = $proc.StartTime.ToString('yyyy-MM-dd HH:mm:ss')
      $elapsedSeconds = [int]((Get-Date) - $proc.StartTime).TotalSeconds
      $days = [int]($elapsedSeconds / 86400)
      $hours = [int](($elapsedSeconds % 86400) / 3600)
      $minutes = [int](($elapsedSeconds % 3600) / 60)
      $seconds = [int]($elapsedSeconds % 60)
      $elapsedText = '{{0:00}}.{{1:00}}:{{2:00}}:{{3:00}}' -f $days, $hours, $minutes, $seconds
      $processPayload = [pscustomobject]@{{
        cpuDisplay = if ($null -ne $proc.CPU) {{ '{{0:N1}} s' -f $proc.CPU }} else {{ '' }}
        memoryDisplay = '{{0:N1}} MB' -f ($proc.WorkingSet64 / 1MB)
        elapsed = $elapsedText
        command = if ([string]::IsNullOrWhiteSpace($candidate.CommandLine)) {{ $commandLine }} else {{ $candidate.CommandLine }}
      }}
      if ($hasListeners) {{
        $activeState = 'Running'
        $subState = 'OK'
        break
      }}
      $activeState = 'Starting'
      $subState = 'Starting'
      $description = 'Portable VNTS 2.0 runtime (进程已启动，等待监听端口就绪)'
    }}
  }} catch {{
    continue
  }}
}}
[pscustomobject]@{{
  serviceName = '{service_name}'
  description = $description
  loadState = 'portable'
  activeState = $activeState
  subState = $subState
  unitFileState = 'portable'
  pid = if ($null -ne $process) {{ [uint64]$process.ProcessId }} else {{ [uint64]0 }}
  mainCode = '0'
  mainStatus = '0'
  activeSince = $activeSince
  fragmentPath = $commandLine
  isActive = ($activeState -eq 'Running')
  process = $processPayload
}} | ConvertTo-Json -Depth 4 -Compress
"#,
        exe_path = ps_quote(&detection.executable_path),
        config_path = ps_quote(&detection.config_path),
        command_line = ps_quote(&detection.command_line),
        service_name = ps_quote(DEFAULT_SERVICE_NAME),
    );
    let json = run_powershell_json(&script)?;
    let parsed = serde_json::from_value::<ServiceJsonStatus>(json).context("解析服务状态失败")?;
    Ok(ServiceStatus {
        service_name: parsed.service_name,
        description: parsed.description,
        load_state: parsed.load_state,
        active_state: parsed.active_state,
        sub_state: parsed.sub_state,
        unit_file_state: parsed.unit_file_state,
        pid: parsed.pid,
        main_code: parsed.main_code,
        main_status: parsed.main_status,
        active_since: parsed.active_since,
        fragment_path: parsed.fragment_path,
        is_active: parsed.is_active,
        installed: true,
        process: parsed.process.map(|value| ServiceProcessInfo {
            cpu_display: value.cpu_display.unwrap_or_default(),
            memory_display: value.memory_display.unwrap_or_default(),
            elapsed: value.elapsed.unwrap_or_default(),
            command: value.command.unwrap_or_default(),
        }),
    })
}

fn load_config_snapshot() -> anyhow::Result<ConfigSnapshot> {
    let detection = detect_service()?;
    load_config_snapshot_for_path(Path::new(&detection.config_path))
}

fn load_config_snapshot_for_path(path: &Path) -> anyhow::Result<ConfigSnapshot> {
    let raw = if path.exists() {
        fs::read_to_string(path).with_context(|| format!("读取配置文件失败：{}", path.display()))?
    } else {
        render_structured_config(&StructuredConfig::default())
    };
    let structured = structured_from_raw(&raw)?;
    let updated_at = if path.exists() {
        format_system_time(path.metadata()?.modified().ok())
    } else {
        String::new()
    };
    Ok(ConfigSnapshot {
        path: path.display().to_string(),
        raw,
        structured,
        updated_at,
        backup_path: None,
    })
}

fn write_config_snapshot(raw: &str) -> anyhow::Result<ConfigSnapshot> {
    let detection = detect_service()?;
    let config_path = PathBuf::from(&detection.config_path);
    let backup_dir = config_path
        .parent()
        .unwrap_or(Path::new(""))
        .join(".backups");
    let backup_path = write_with_backup(&config_path, &backup_dir, raw)?;
    let mut snapshot = load_config_snapshot_for_path(&config_path)?;
    snapshot.backup_path = backup_path.map(|path| path.display().to_string());
    Ok(snapshot)
}

fn write_with_backup(
    target_path: &Path,
    backup_dir: &Path,
    raw: &str,
) -> anyhow::Result<Option<PathBuf>> {
    match direct_write_with_backup(target_path, backup_dir, raw) {
        Ok(result) => Ok(result),
        Err(err) if is_permission_error(&err) => {
            elevated_write_with_backup(target_path, backup_dir, raw)
        }
        Err(err) => Err(err),
    }
}

fn direct_write_with_backup(
    target_path: &Path,
    backup_dir: &Path,
    raw: &str,
) -> anyhow::Result<Option<PathBuf>> {
    if let Some(parent) = target_path.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("创建配置目录失败：{}", parent.display()))?;
    }
    let backup_path = if target_path.exists() {
        fs::create_dir_all(backup_dir)
            .with_context(|| format!("创建备份目录失败：{}", backup_dir.display()))?;
        let backup = backup_dir.join(format!(
            "{}-{}.toml",
            target_path
                .file_stem()
                .and_then(OsStr::to_str)
                .unwrap_or("config"),
            Local::now().format("%Y%m%d-%H%M%S")
        ));
        fs::copy(target_path, &backup)
            .with_context(|| format!("备份配置文件失败：{}", backup.display()))?;
        Some(backup)
    } else {
        None
    };
    fs::write(target_path, raw)
        .with_context(|| format!("写入配置文件失败：{}", target_path.display()))?;
    Ok(backup_path)
}

fn elevated_write_with_backup(
    target_path: &Path,
    backup_dir: &Path,
    raw: &str,
) -> anyhow::Result<Option<PathBuf>> {
    let temp_source = temp_file_path("vnts-config", "toml");
    fs::write(&temp_source, raw)
        .with_context(|| format!("写入临时配置文件失败：{}", temp_source.display()))?;
    let backup_path = if target_path.exists() {
        Some(backup_dir.join(format!(
            "{}-{}.toml",
            target_path
                .file_stem()
                .and_then(OsStr::to_str)
                .unwrap_or("config"),
            Local::now().format("%Y%m%d-%H%M%S")
        )))
    } else {
        None
    };
    let script = format!(
        r#"
$ErrorActionPreference = 'Stop'
$target = '{target}'
$source = '{source}'
$backupDir = '{backup_dir}'
$targetDir = Split-Path -Parent $target
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
if ('{backup_path}' -ne '') {{
  New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
  Copy-Item -LiteralPath $target -Destination '{backup_path}' -Force
}}
Copy-Item -LiteralPath $source -Destination $target -Force
"#,
        target = ps_quote(&target_path.display().to_string()),
        source = ps_quote(&temp_source.display().to_string()),
        backup_dir = ps_quote(&backup_dir.display().to_string()),
        backup_path = backup_path
            .as_ref()
            .map(|path| ps_quote(&path.display().to_string()))
            .unwrap_or_default(),
    );
    let result = run_powershell_script(&script, true);
    let _ = fs::remove_file(&temp_source);
    result?;
    Ok(backup_path)
}

fn run_service_action(action: &str) -> anyhow::Result<()> {
    match action {
        "start" => start_portable_process(),
        "stop" => stop_portable_process(),
        "restart" => {
            let _ = stop_portable_process();
            start_portable_process()
        }
        _ => bail!("不支持的服务操作。"),
    }
}

fn load_or_initialize_credentials() -> anyhow::Result<StoredCredentials> {
    let path = credentials_path();
    if path.exists() {
        let raw = fs::read_to_string(&path)
            .with_context(|| format!("读取账号文件失败：{}", path.display()))?;
        if let Ok(record) = serde_json::from_str::<StoredCredentials>(&raw) {
            return Ok(record);
        }
    }
    let salt = format!(
        "{:x}",
        SystemTime::now().duration_since(UNIX_EPOCH)?.as_nanos()
    );
    let record = StoredCredentials {
        username: DEFAULT_PANEL_USERNAME.to_string(),
        password_hash: hex::encode(pbkdf2_hmac_array::<Sha256, 32>(
            DEFAULT_PANEL_PASSWORD.as_bytes(),
            salt.as_bytes(),
            PASSWORD_ITERATIONS,
        )),
        salt,
        updated_at: now_string(),
    };
    Ok(record)
}

fn requires_password_change(record: &StoredCredentials) -> bool {
    record.username == DEFAULT_PANEL_USERNAME && verify_password(DEFAULT_PANEL_PASSWORD, record)
}

fn persist_credentials(record: &StoredCredentials) -> anyhow::Result<()> {
    let path = credentials_path();
    if let Some(parent) = path.parent() {
        match fs::create_dir_all(parent) {
            Ok(_) => {}
            Err(err) if err.kind() == ErrorKind::PermissionDenied => {}
            Err(err) => {
                return Err(err).with_context(|| format!("创建账号目录失败：{}", parent.display()));
            }
        }
    }
    let raw = serde_json::to_string_pretty(record).context("序列化账号配置失败")? + "\n";
    match fs::write(&path, raw.as_bytes()) {
        Ok(_) => Ok(()),
        Err(err) if err.kind() == ErrorKind::PermissionDenied => {
            let temp_source = temp_file_path("vnts-auth", "json");
            fs::write(&temp_source, raw.as_bytes())
                .with_context(|| format!("写入临时账号文件失败：{}", temp_source.display()))?;
            let script = format!(
                r#"
$ErrorActionPreference = 'Stop'
$target = '{target}'
$source = '{source}'
$parent = Split-Path -Parent $target
New-Item -ItemType Directory -Force -Path $parent | Out-Null
Copy-Item -LiteralPath $source -Destination $target -Force
"#,
                target = ps_quote(&path.display().to_string()),
                source = ps_quote(&temp_source.display().to_string()),
            );
            let result = run_powershell_script(&script, true);
            let _ = fs::remove_file(&temp_source);
            result.map(|_| ())
        }
        Err(err) => Err(err).with_context(|| format!("写入账号文件失败：{}", path.display())),
    }
}

fn verify_password(password: &str, record: &StoredCredentials) -> bool {
    let derived = pbkdf2_hmac_array::<Sha256, 32>(
        password.as_bytes(),
        record.salt.as_bytes(),
        PASSWORD_ITERATIONS,
    );
    hex::encode(derived) == record.password_hash
}

fn credentials_path() -> PathBuf {
    default_install_dir().join("panel").join("vnts-auth.json")
}

fn default_install_dir() -> PathBuf {
    portable_data_root().join("vnts2_runtime")
}

fn resolve_bundled_file(file_name: &str) -> anyhow::Result<PathBuf> {
    let runtime_candidate = default_install_dir().join(file_name);
    if runtime_candidate.exists() {
        return Ok(runtime_candidate);
    }
    resolve_bundled_asset_source(file_name)
}

fn resolve_bundled_asset_source(file_name: &str) -> anyhow::Result<PathBuf> {
    let exe_dir = current_exe_dir();
    let candidates = [
        exe_dir
            .join("data")
            .join("flutter_assets")
            .join("assets")
            .join("bundled")
            .join(file_name),
        exe_dir.join("data").join("bundled").join(file_name),
        exe_dir.join("assets").join("bundled").join(file_name),
    ];
    for candidate in candidates {
        if candidate.exists() {
            return Ok(candidate);
        }
    }
    bail!("未找到 bundled 文件：{file_name}")
}

fn structured_from_raw(raw: &str) -> anyhow::Result<StructuredConfig> {
    let parsed = parse_toml(raw)?;
    let custom_nets = parsed
        .custom_nets
        .unwrap_or_default()
        .into_iter()
        .map(|(name, cidr)| CustomNetItem { name, cidr })
        .collect::<Vec<_>>();
    Ok(StructuredConfig {
        tcp_bind: parsed
            .tcp_bind
            .unwrap_or_else(|| StructuredConfig::default().tcp_bind),
        quic_bind: parsed
            .quic_bind
            .unwrap_or_else(|| StructuredConfig::default().quic_bind),
        ws_bind: parsed
            .ws_bind
            .unwrap_or_else(|| StructuredConfig::default().ws_bind),
        network: parsed
            .network
            .unwrap_or_else(|| StructuredConfig::default().network),
        white_list: sanitize_string_list(parsed.white_list.unwrap_or_default()),
        lease_duration: parsed
            .lease_duration
            .unwrap_or_else(|| StructuredConfig::default().lease_duration),
        web_bind: parsed.web_bind.unwrap_or_default(),
        username: parsed.username.unwrap_or_default(),
        password: parsed.password.unwrap_or_default(),
        persistence: parsed
            .persistence
            .unwrap_or_else(|| StructuredConfig::default().persistence),
        cert: parsed.cert.unwrap_or_default(),
        key: parsed.key.unwrap_or_default(),
        server_quic_bind: parsed.server_quic_bind.unwrap_or_default(),
        peer_servers: sanitize_string_list(parsed.peer_servers.unwrap_or_default()),
        server_token: parsed.server_token.unwrap_or_default(),
        custom_nets,
    })
}

fn parse_toml(raw: &str) -> anyhow::Result<RawConfigToml> {
    toml::from_str::<RawConfigToml>(raw).context("TOML 解析失败。")
}

fn validate_structured_config(payload: &StructuredConfig) -> anyhow::Result<()> {
    if payload.network.trim().is_empty() {
        bail!("默认虚拟网段 network 不能为空。");
    }
    if payload.lease_duration <= 0 {
        bail!("IP 租约时长 lease_duration 必须大于 0。");
    }
    if payload.tcp_bind.trim().is_empty()
        && payload.quic_bind.trim().is_empty()
        && payload.ws_bind.trim().is_empty()
    {
        bail!("至少需要启用一个连接监听：tcp_bind、quic_bind、ws_bind。");
    }
    if !payload.web_bind.trim().is_empty()
        && (payload.username.trim().is_empty() || payload.password.trim().is_empty())
    {
        bail!("启用 web_bind 时，username 和 password 也必须填写。");
    }
    for (field, value) in [
        ("tcp_bind", payload.tcp_bind.trim()),
        ("quic_bind", payload.quic_bind.trim()),
        ("ws_bind", payload.ws_bind.trim()),
        ("web_bind", payload.web_bind.trim()),
        ("server_quic_bind", payload.server_quic_bind.trim()),
    ] {
        if !value.is_empty() && !value.contains(':') {
            bail!("{field} 需要使用 host:port 格式。");
        }
    }
    for item in &payload.custom_nets {
        if item.name.trim().is_empty() || item.cidr.trim().is_empty() {
            bail!("自定义网段 custom_nets 的名称和 CIDR 都必须填写。");
        }
        if !item
            .name
            .chars()
            .all(|ch| ch.is_ascii_alphanumeric() || ch == '_' || ch == '-')
        {
            bail!(
                "自定义网段名称 {} 只能包含字母、数字、下划线和中横线。",
                item.name
            );
        }
    }
    Ok(())
}

fn render_structured_config(payload: &StructuredConfig) -> String {
    let mut lines = Vec::new();
    push_optional_string(&mut lines, "tcp_bind", &payload.tcp_bind);
    push_optional_string(&mut lines, "quic_bind", &payload.quic_bind);
    push_optional_string(&mut lines, "ws_bind", &payload.ws_bind);
    push_required_string(&mut lines, "network", &payload.network);
    lines.push(format!(
        "white_list = {}",
        serde_json::to_string(&sanitize_string_list(payload.white_list.clone())).unwrap()
    ));
    lines.push(format!("lease_duration = {}", payload.lease_duration));
    push_optional_string(&mut lines, "web_bind", &payload.web_bind);
    push_optional_string(&mut lines, "username", &payload.username);
    push_optional_string(&mut lines, "password", &payload.password);
    lines.push(format!(
        "persistence = {}",
        if payload.persistence { "true" } else { "false" }
    ));
    push_optional_string(&mut lines, "cert", &payload.cert);
    push_optional_string(&mut lines, "key", &payload.key);
    push_optional_string(&mut lines, "server_quic_bind", &payload.server_quic_bind);
    if !payload.peer_servers.is_empty() {
        lines.push(format!(
            "peer_servers = {}",
            serde_json::to_string(&sanitize_string_list(payload.peer_servers.clone())).unwrap()
        ));
    }
    push_optional_string(&mut lines, "server_token", &payload.server_token);
    lines.push(String::new());
    lines.push("[custom_nets]".to_string());
    for item in &payload.custom_nets {
        lines.push(format!(
            "{} = {}",
            item.name.trim(),
            serde_json::to_string(item.cidr.trim()).unwrap()
        ));
    }
    lines.join("\n").trim_end().to_string() + "\n"
}

fn summarize_endpoints(payload: &StructuredConfig) -> String {
    let parts = [
        payload.tcp_bind.trim(),
        payload.quic_bind.trim(),
        payload.ws_bind.trim(),
    ]
    .into_iter()
    .filter(|value| !value.is_empty())
    .map(ToOwned::to_owned)
    .collect::<Vec<_>>();
    if parts.is_empty() {
        "未配置".to_string()
    } else {
        parts.join(" / ")
    }
}

fn sanitize_string_list(values: Vec<String>) -> Vec<String> {
    values
        .into_iter()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .collect()
}

fn push_optional_string(lines: &mut Vec<String>, key: &str, value: &str) {
    let trimmed = value.trim();
    if !trimmed.is_empty() {
        lines.push(format!(
            "{key} = {}",
            serde_json::to_string(trimmed).unwrap()
        ));
    }
}

fn push_required_string(lines: &mut Vec<String>, key: &str, value: &str) {
    lines.push(format!(
        "{key} = {}",
        serde_json::to_string(value.trim()).unwrap()
    ));
}

fn parse_conf_path(command_line: &str) -> Option<PathBuf> {
    if let Some(captures) = CONF_ARG_REGEX.captures(command_line) {
        if let Some(value) = captures.get(1).or_else(|| captures.get(2)) {
            return Some(PathBuf::from(value.as_str()));
        }
    }
    None
}

fn parse_executable_path(command_line: &str) -> Option<PathBuf> {
    split_windows_command_line(command_line)
        .into_iter()
        .next()
        .map(PathBuf::from)
}

fn split_windows_command_line(command_line: &str) -> Vec<String> {
    let mut args = Vec::new();
    let mut current = String::new();
    let mut in_quotes = false;
    for ch in command_line.chars() {
        match ch {
            '"' => in_quotes = !in_quotes,
            ' ' | '\t' if !in_quotes => {
                if !current.is_empty() {
                    args.push(std::mem::take(&mut current));
                }
            }
            _ => current.push(ch),
        }
    }
    if !current.is_empty() {
        args.push(current);
    }
    args
}

fn run_powershell_json(script: &str) -> anyhow::Result<JsonValue> {
    let output = run_powershell_script(script, false)?;
    serde_json::from_str(&output).context("解析 PowerShell JSON 输出失败")
}

fn run_powershell_script(script: &str, elevated: bool) -> anyhow::Result<String> {
    let script_path = temp_file_path("vnts-ps", "ps1");
    fs::write(&script_path, script.as_bytes())
        .with_context(|| format!("写入 PowerShell 脚本失败：{}", script_path.display()))?;
    let result = if elevated {
        run_elevated_powershell_file(&script_path)
    } else {
        run_standard_powershell_file(&script_path)
    };
    let _ = fs::remove_file(&script_path);
    result
}

fn run_standard_powershell_file(script_path: &Path) -> anyhow::Result<String> {
    let mut command = Command::new("powershell");
    command.args([
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        script_path.to_string_lossy().as_ref(),
    ]);
    configure_hidden_console(&mut command);
    let output = command.output().context("启动 PowerShell 失败")?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
        let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
        bail!("{}", if !stderr.is_empty() { stderr } else { stdout });
    }
    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

fn run_elevated_powershell_file(script_path: &Path) -> anyhow::Result<String> {
    let launcher = format!(
        "$p = Start-Process powershell -Verb RunAs -WindowStyle Hidden -Wait -PassThru -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File','{}'); exit $p.ExitCode",
        ps_quote(&script_path.display().to_string())
    );
    let mut command = Command::new("powershell");
    command.args([
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        &launcher,
    ]);
    configure_hidden_console(&mut command);
    let output = command.output().context("启动提权 PowerShell 失败")?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
        let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
        bail!(
            "{}",
            if !stderr.is_empty() {
                stderr
            } else if !stdout.is_empty() {
                stdout
            } else {
                "管理员提权操作失败。".to_string()
            }
        );
    }
    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

fn ps_quote(value: &str) -> String {
    value.replace('\'', "''")
}

fn format_system_time(time: Option<SystemTime>) -> String {
    time.map(|time| {
        let datetime: chrono::DateTime<Local> = chrono::DateTime::from(time);
        datetime.to_rfc3339_opts(chrono::SecondsFormat::Secs, false)
    })
    .unwrap_or_default()
}

fn now_string() -> String {
    Local::now().to_rfc3339_opts(chrono::SecondsFormat::Secs, false)
}

fn temp_file_path(prefix: &str, extension: &str) -> PathBuf {
    let unique = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|value| value.as_nanos())
        .unwrap_or_default();
    std::env::temp_dir().join(format!("{prefix}-{unique}.{extension}"))
}

fn is_permission_error(error: &anyhow::Error) -> bool {
    error
        .chain()
        .filter_map(|cause| cause.downcast_ref::<std::io::Error>())
        .any(|io_error| io_error.kind() == ErrorKind::PermissionDenied)
}

#[cfg(target_os = "windows")]
fn configure_hidden_console(command: &mut Command) {
    command.creation_flags(CREATE_NO_WINDOW);
}

#[cfg(not(target_os = "windows"))]
fn configure_hidden_console(_command: &mut Command) {}

#[cfg(target_os = "windows")]
fn configure_detached_background(command: &mut Command) {
    command.creation_flags(CREATE_NO_WINDOW | DETACHED_PROCESS);
}

#[cfg(not(target_os = "windows"))]
fn configure_detached_background(_command: &mut Command) {}

fn current_exe_dir() -> PathBuf {
    std::env::current_exe()
        .ok()
        .and_then(|path| path.parent().map(Path::to_path_buf))
        .or_else(|| std::env::current_dir().ok())
        .unwrap_or_else(|| PathBuf::from("."))
}

fn portable_data_root() -> PathBuf {
    std::env::var_os(DATA_ROOT_OVERRIDE_ENV)
        .map(PathBuf::from)
        .unwrap_or_else(|| current_exe_dir().join("data"))
}

fn inspect_runtime_layout() -> RuntimeLayoutState {
    match ensure_runtime_layout() {
        Ok(_) => RuntimeLayoutState {
            runtime_ready: true,
            runtime_issue: String::new(),
        },
        Err(error) => RuntimeLayoutState {
            runtime_ready: false,
            runtime_issue: error.to_string(),
        },
    }
}

fn ensure_runtime_layout() -> anyhow::Result<()> {
    let runtime_dir = default_install_dir();
    let logs_dir = runtime_dir.join("logs");
    let backups_dir = runtime_dir.join(".backups");
    let panel_dir = runtime_dir.join("panel");
    fs::create_dir_all(&logs_dir)
        .with_context(|| format!("创建日志目录失败：{}", logs_dir.display()))?;
    fs::create_dir_all(&backups_dir)
        .with_context(|| format!("创建备份目录失败：{}", backups_dir.display()))?;
    fs::create_dir_all(&panel_dir)
        .with_context(|| format!("创建面板目录失败：{}", panel_dir.display()))?;

    let runtime_exe = runtime_dir.join("vnts2.exe");
    if !runtime_exe.exists() {
        let bundled = resolve_bundled_asset_source("vnts2.exe")?;
        fs::copy(&bundled, &runtime_exe).with_context(|| {
            format!(
                "复制内置 vnts2.exe 到运行目录失败：{} -> {}",
                bundled.display(),
                runtime_exe.display()
            )
        })?;
    }

    let runtime_config = runtime_dir.join("config.toml");
    if !runtime_config.exists() {
        let bundled = resolve_bundled_asset_source("config.toml")?;
        fs::copy(&bundled, &runtime_config).with_context(|| {
            format!(
                "复制内置 config.toml 到运行目录失败：{} -> {}",
                bundled.display(),
                runtime_config.display()
            )
        })?;
    }
    Ok(())
}

fn start_portable_process() -> anyhow::Result<()> {
    ensure_runtime_layout()?;
    let detection = detect_service()?;
    if !detection.runtime_ready {
        bail!("运行目录未就绪：{}", detection.runtime_issue);
    }
    if !Path::new(&detection.executable_path).exists() {
        bail!("未找到运行文件：{}", detection.executable_path);
    }
    if !Path::new(&detection.config_path).exists() {
        bail!("未找到运行配置：{}", detection.config_path);
    }
    let status = query_service_status()?;
    if status.is_active {
        return Ok(());
    }
    let runtime_dir = PathBuf::from(&detection.install_dir);
    let mut command = Command::new(&detection.executable_path);
    command
        .arg("--conf")
        .arg(&detection.config_path)
        .current_dir(&runtime_dir)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    configure_detached_background(&mut command);
    let mut child = command
        .spawn()
        .with_context(|| format!("启动 vnts2.exe 失败：{}", detection.executable_path))?;
    for _ in 0..20 {
        std::thread::sleep(Duration::from_millis(250));
        let status = query_service_status()?;
        if status.is_active {
            return Ok(());
        }
        if child.try_wait().ok().flatten().is_some() {
            break;
        }
    }
    let status = query_service_status()?;
    if status.is_active {
        return Ok(());
    }
    bail!("{}", build_start_failure_message(&detection));
}

fn build_start_failure_message(detection: &ServiceDetection) -> String {
    let mut details = Vec::new();
    if !detection.runtime_issue.trim().is_empty() {
        details.push(detection.runtime_issue.trim().to_string());
    }
    let log_path = Path::new(&detection.log_path);
    if let Some(line) = read_last_log_line(log_path) {
        details.push(format!("最近日志：{line}"));
    }
    if details.is_empty() {
        "VNTS 进程启动失败，可能是端口占用、配置异常或子进程启动后立即退出。".to_string()
    } else {
        format!("VNTS 进程启动失败：{}", details.join("；"))
    }
}

fn read_last_log_line(path: &Path) -> Option<String> {
    let file = fs::File::open(path).ok()?;
    let reader = BufReader::new(file);
    let mut lines = reader
        .lines()
        .map_while(Result::ok)
        .filter(|line| !line.trim().is_empty())
        .collect::<Vec<_>>();
    lines.pop()
}

fn stop_portable_process() -> anyhow::Result<()> {
    let detection = detect_service()?;
    if !detection.installed {
        return Ok(());
    }
    let script = format!(
        r#"
$ErrorActionPreference = 'Stop'
$exePath = '{exe_path}'
$configPath = '{config_path}'
$deadline = (Get-Date).AddSeconds(8)
do {{
  $tcpListeners = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue)
  $udpListeners = @(Get-NetUDPEndpoint -ErrorAction SilentlyContinue)
  $processes = @(
    Get-CimInstance Win32_Process -Filter "Name='vnts2.exe'" | Where-Object {{
      $candidate = $_
      $hasListeners = (
        @($tcpListeners | Where-Object {{ $_.OwningProcess -eq $candidate.ProcessId }}).Count -gt 0 -or
        @($udpListeners | Where-Object {{ $_.OwningProcess -eq $candidate.ProcessId }}).Count -gt 0
      )
      $matchesExecutablePath = ($candidate.ExecutablePath -eq $exePath)
      $matchesCommandLine = ((-not [string]::IsNullOrWhiteSpace($candidate.CommandLine)) -and (
        $candidate.CommandLine -like "*$exePath*" -or
        $candidate.CommandLine -like "*$configPath*"
      ))
      $hasListeners -or $matchesExecutablePath -or $matchesCommandLine
    }}
  )
  if ($processes.Count -eq 0) {{
    break
  }}
  foreach ($process in $processes) {{
    Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
  }}
  Start-Sleep -Milliseconds 300
}} while ((Get-Date) -lt $deadline)
$remaining = @(
  $tcpListeners = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue)
  $udpListeners = @(Get-NetUDPEndpoint -ErrorAction SilentlyContinue)
  Get-CimInstance Win32_Process -Filter "Name='vnts2.exe'" | Where-Object {{
    $candidate = $_
    $hasListeners = (
      @($tcpListeners | Where-Object {{ $_.OwningProcess -eq $candidate.ProcessId }}).Count -gt 0 -or
      @($udpListeners | Where-Object {{ $_.OwningProcess -eq $candidate.ProcessId }}).Count -gt 0
    )
    $matchesExecutablePath = ($candidate.ExecutablePath -eq $exePath)
    $matchesCommandLine = ((-not [string]::IsNullOrWhiteSpace($candidate.CommandLine)) -and (
      $candidate.CommandLine -like "*$exePath*" -or
      $candidate.CommandLine -like "*$configPath*"
    ))
    $hasListeners -or $matchesExecutablePath -or $matchesCommandLine
  }}
)
if ($remaining.Count -gt 0) {{
  throw "Timed out waiting for vnts2.exe to exit."
}}
"#,
        exe_path = ps_quote(&detection.executable_path),
        config_path = ps_quote(&detection.config_path),
    );
    run_powershell_script(&script, false).map(|_| ())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::OsString;

    const TEST_DATA_ROOT_ENV: &str = "VNTS_PANEL_TEST_DATA_ROOT";

    #[test]
    fn parses_conf_path_from_service_command() {
        let command = r#""C:\ProgramData\VNTS2\vnts2.exe" --service --conf "C:\ProgramData\VNTS2\config.toml""#;
        let conf = parse_conf_path(command).expect("conf path");
        assert_eq!(conf, PathBuf::from(r"C:\ProgramData\VNTS2\config.toml"));
    }

    #[test]
    fn renders_and_parses_structured_config_roundtrip() {
        let config = StructuredConfig {
            white_list: vec!["game".to_string()],
            custom_nets: vec![CustomNetItem {
                name: "office".to_string(),
                cidr: "10.99.0.0/24".to_string(),
            }],
            ..StructuredConfig::default()
        };
        let raw = render_structured_config(&config);
        let parsed = structured_from_raw(&raw).expect("parsed");
        assert_eq!(parsed.network, "10.26.0.0/24");
        assert_eq!(parsed.white_list, vec!["game".to_string()]);
        assert_eq!(parsed.custom_nets[0].name, "office");
    }

    #[test]
    fn verifies_password_hash_generated_with_pbkdf2() {
        let salt = "abc123".to_string();
        let record = StoredCredentials {
            username: "luojiang".to_string(),
            password_hash: hex::encode(pbkdf2_hmac_array::<Sha256, 32>(
                b"luojiang",
                salt.as_bytes(),
                PASSWORD_ITERATIONS,
            )),
            salt,
            updated_at: now_string(),
        };
        assert!(verify_password("luojiang", &record));
        assert!(!verify_password("wrong", &record));
    }

    #[test]
    fn initializes_default_credentials_when_file_missing() {
        let temp_root = std::env::temp_dir().join(format!(
            "vnts-panel-test-{}",
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .expect("duration")
                .as_nanos()
        ));
        fs::create_dir_all(&temp_root).expect("temp root");
        std::env::set_var("ProgramData", &temp_root);

        let record = load_or_initialize_credentials().expect("credentials");
        assert_eq!(record.username, DEFAULT_PANEL_USERNAME);
        assert!(requires_password_change(&record));
        assert!(!credentials_path().exists());

        let _ = fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn password_change_requirement_clears_after_non_default_password() {
        let record = StoredCredentials {
            username: DEFAULT_PANEL_USERNAME.to_string(),
            password_hash: hex::encode(pbkdf2_hmac_array::<Sha256, 32>(
                b"not-default",
                b"salt",
                PASSWORD_ITERATIONS,
            )),
            salt: "salt".to_string(),
            updated_at: now_string(),
        };
        assert!(!requires_password_change(&record));
    }

    #[cfg(target_os = "windows")]
    #[test]
    #[ignore = "requires real Windows distribution runtime directory"]
    fn smoke_test_real_distribution_service_control() {
        let data_root = std::env::var(TEST_DATA_ROOT_ENV)
            .expect("VNTS_PANEL_TEST_DATA_ROOT must point to the distribution data directory");
        let original_override: Option<OsString> = std::env::var_os(DATA_ROOT_OVERRIDE_ENV);
        std::env::set_var(DATA_ROOT_OVERRIDE_ENV, &data_root);

        let result = (|| -> anyhow::Result<()> {
            let _ = stop_portable_process();
            std::thread::sleep(Duration::from_millis(700));
            let stopped = query_service_status()?;
            assert!(
                !stopped.is_active,
                "service should be stopped before smoke test"
            );

            start_portable_process()?;
            let running = query_service_status()?;
            assert!(running.is_active, "service should be running after start");
            assert!(running.pid > 0, "running service should expose a pid");

            run_service_action("restart")?;
            let restarted = query_service_status()?;
            assert!(
                restarted.is_active,
                "service should be running after restart"
            );
            assert!(restarted.pid > 0, "restarted service should expose a pid");

            stop_portable_process()?;
            std::thread::sleep(Duration::from_millis(700));
            let stopped_again = query_service_status()?;
            assert!(
                !stopped_again.is_active,
                "service should be stopped after stop"
            );

            start_portable_process()?;
            let running_again = query_service_status()?;
            assert!(
                running_again.is_active,
                "service should be running after final start"
            );
            Ok(())
        })();

        match original_override {
            Some(value) => std::env::set_var(DATA_ROOT_OVERRIDE_ENV, value),
            None => std::env::remove_var(DATA_ROOT_OVERRIDE_ENV),
        }

        result.expect("distribution smoke test");
    }
}
