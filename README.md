# Claude 防直连保护

面向 Codex 的 Windows 技能：维护 Claude 的 Clash/Mihomo 分流和指定目标 IP 的防直连规则，附只读核验脚本、备份回滚方法和实际排查经验。

默认按用户选择的范围工作。只需要 Claude 走代理时，保留其他软件的使用方式；不把整机强制代理或默认出站阻止当作前提。

## 包含什么

- **Claude 分流**：从已有用户配置整理的 22 条规则，包含域名、认证/CDN、第三方服务和 IP 兜底。
- **Windows 目标 IP 拦截**：检查、创建或原地维护明确的规则，涵盖浏览器、桌面版和 Claude Code 对相应网段的连接。
- **只读核验**：分别读取 PersistentStore 和 ActiveStore，区分规则存在、明确缺失及查询失败，并显示有效防火墙配置文件和默认出站策略。
- **故障排查与恢复**：处理规则被删除、代理/TUN 路径差异、开启旧防火墙策略后其他网站异常等问题，保留最小变更和准确回滚。

[技能入口](skills/claude-direct-guard/SKILL.md) · [Clash 分流说明](skills/claude-direct-guard/references/clash-routing.md) · [规则示例](skills/claude-direct-guard/examples/clash-verge-rules.yaml) · [Windows 操作与排查](skills/claude-direct-guard/references/windows-firewall.md)

## 安装

克隆或下载本仓库，将 **整个** `skills/claude-direct-guard` 文件夹复制到自己的 Codex 技能目录，保留 `agents`、`examples`、`references`、`scripts` 结构。只转发一个 `SKILL.md` 会缺少随附资源。

Windows PowerShell 示例，在准备放置仓库的目录运行：

```powershell
git clone https://github.com/guxudong0917/claude-direct-guard.git
$skillsRoot = Join-Path $env:USERPROFILE '.codex\skills'
$skillTarget = Join-Path $skillsRoot 'claude-direct-guard'
if (Test-Path -LiteralPath $skillTarget) {
    throw '同名技能已存在，请先检查差异和备份，再迁移更新。'
}
New-Item -ItemType Directory -Path $skillsRoot -Force | Out-Null
Copy-Item -LiteralPath '.\claude-direct-guard\skills\claude-direct-guard' -Destination $skillTarget -Recurse
```

如果已自定义 `CODEX_HOME`，改用该目录下的 `skills`。安装只放置技能文件，不会立即修改 Clash、防火墙或代理。

## 使用

在 Codex 中用 `$claude-direct-guard` 调用，例如：

```text
使用 $claude-direct-guard，只读检查我的 Claude 分流和防直连规则是否还在。
```

```text
使用 $claude-direct-guard，把随附的分流适配到我的 Clash 代理组；先核对现有规则和实际使用范围。
```

规则示例沿用 `🤖AI服务` 代理组名；应用前应改成目标订阅已有的代理组。它是 Clash Verge Rev 的**规则扩展**，不是完整订阅或全局 Merge。规则模式中、被核心接管的连接才按这些匹配指令选路。

## 两层配置各管什么

| 配置 | 随附值 / 案例值 | 作用 |
|---|---|---|
| 原有 Clash IP 兜底 | `160.79.104.0/23`、`2607:6bc0::/48` | 匹配后送入指定代理组 |
| 案例中用户选定的防火墙范围 | `160.79.104.0/21`、`2607:6bc0::/32` | 阻止对应目的网段的本机直接出站 |

分流和阻止直连是不同层。静态网段内换 IP 仍受覆盖，移到网段外需要复核；官方 API/Console 的地址文档也不覆盖所有网页关联服务。第三方监控、认证或客服域名可能共享，不要把其解析地址直接加入 Claude 阻止列表。

开启原本关闭的防火墙可能同时激活已有规则或默认出站限制。技能要求先核对这些策略，避免影响 ChatGPT、代理核心和其他应用。

## 只读核验脚本

从仓库根目录运行，替换实际的规则名称：

```powershell
& '.\skills\claude-direct-guard\scripts\Get-DestinationGuardState.ps1' -RuleName @('实际IPv4规则名','实际IPv6规则名')
```

退出码：`0` 为查询成功且名称存在，`2` 为有明确缺失，`1` 为查询/过滤读取失败。仍需核对动作、方向、范围及有效配置；退出码 `0` 不代表已经完成端到端连接验证。

## 来源与经验边界

分流来自用户自有的规则扩展；经验来自一次 Windows/Clash 实际配置与排查。范围和来源带有日期，不应当作永久地址清单。项目不提供节点、订阅或账号，也不承诺规避风控或封号。

- [Claude Code 官方网络配置](https://code.claude.com/docs/en/network-config)
- [Anthropic 官方 IP 文档](https://platform.claude.com/docs/en/api/ip-addresses)
- [Net.Coffee 分流建议](https://ip.net.coffee/claude/site.html)
