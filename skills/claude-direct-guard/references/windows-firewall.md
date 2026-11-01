# Windows 防火墙操作与规则消失排查

## 操作前后不变量

宿主系统访问权限和 Windows 管理员权限是两层；工具允许访问宿主机不等于进程已提权。只读查询能做就先做；修改规则需要管理员。不要反复申请已获授权的业务范围。

只处理明确名称的规则。先查是否唯一存在、Group 是否属于本任务、方向/动作/启用状态，以及地址、程序、协议、端口、配置文件、接口/服务等过滤条件是否符合预期。查询报错不等于不存在。

备份将修改的原始字段，保留 RemoteAddress 数组类型，使用唯一文件名，放在用户可写工作目录。新建规则时记录本轮创建的名称；不要导出无关凭据或重置全局防火墙。

已有规则修改的正确参数形式：

```powershell
# 先把变量绑定到已核验的具体名称、用户同意的网段及显示名。
Set-NetFirewallRule -Name $ruleName -PolicyStore PersistentStore `
  -RemoteAddress $approvedRange -NewDisplayName $newLabel -Description $description
```

`-DisplayName` 是另一种选择规则的参数，不能和 `-Name` 拼在一起当作改名。用 `Get-Command Set-NetFirewallRule` 核对本机参数集；`-WhatIf` 或语法解析都不能证明规则已经生效。

如果确实需要新建，先确定名称未占用且查询成功：

```powershell
New-NetFirewallRule -Name $ruleName -DisplayName $label -Group $taskGroup `
  -PolicyStore PersistentStore -Direction Outbound -Action Block -Enabled True `
  -Profile Any -Protocol Any -RemoteAddress $approvedRange
```

不传 Program 的规则适用于所有程序到该目标网段的连接；不是“所有程序的所有外网连接”。共享同一 IP 的其他服务也可能受影响。不要擅自扩大到共享 CDN 的完整网段。

开启配置文件前，先记录有效配置文件的 Enabled、DefaultOutboundAction、AllowLocalFirewallRules，并检查对浏览器、代理核心及其依赖连接适用的既有阻止规则。原本关闭的防火墙一旦开启，既有默认出站阻止和旧规则也可能同时生效，影响 ChatGPT 或其他网站。不能把这个动作当成只启用新增的目标 IP 规则。

NotConfigured 或查询不到值不等于明确 Allow；需要确认实际有效策略。按现有授权处理必要的开启，不擅自改默认出站策略，不靠添加 Allow 规则假定能覆盖已有 Block。不要重新添加已撤销的 Chrome、Claude 桌面版或 Claude Code 强制代理设置。

另一台电脑执行同一技能后其他网站异常时，先取得那台电脑的实际修改记录和完整报错。核对本轮规则的 RemoteAddress 是否误成 Any、共享服务网段，是否另加程序限制、修改代理/TUN/DNS，以及是否刚开启旧防火墙策略。本机正常不能证明另一台也正常；技能是操作指导，不保证每次实际生成的配置完全相同。先保存证据，再根据原因仅回滚相关变更，不直接关闭整个防火墙或重置网络。

修改报错时，先核对是否发生任何改变；按已完成的变更恢复对应字段，报告回滚错误。外部程序已把规则删掉时，不循环重建。恢复默认策略、服务、客户端设置不属于单条规则回滚。

## 提权执行与结果

使用宿主权限调用时，仍需检查 Windows 身份是否为管理员。需要 UAC 时，通过 `Start-Process -Verb RunAs -WindowStyle Hidden` 启动具体、可审查的 PowerShell 脚本；不要降低 UAC、安全策略或可执行文件 ACL。

父进程返回 Started 或 PID 只证明启动，不证明脚本成功。要求脚本保存时间、实际核验字段、错误及回滚情况。读取结果时核对时间，避免把上次结果当成本次结果。脚本应在错误时非零退出，不能只写成功文案。

修改后分别核对 PersistentStore 与 ActiveStore。IPv4 `160.79.104.0/255.255.248.0` 和 `/21` 等价；`/255.255.254.0` 和 `/23` 等价。比较网络语义或允许已知的等价形式，不按显示字符串制造假失败。

随附只读脚本未宣称规则满足预期地址或动作；根据输出逐项对照已批准配置。Missing 是明确的查无此规则；QueryError 是无法查询，尤其不要把权限错误当成规则删除。脚本退出码 0 表示查询成功且名称存在，2 表示有明确缺失，1 表示查询或过滤读取失败；0 不代表防直连已被端到端证实。

## 规则消失时

先排除读权限、策略存储和精确名称错误，再看事件。Windows 日志通道：

`Microsoft-Windows-Windows Firewall With Advanced Security/Firewall`

用本轮变更的开始时间、明确名称和有限条数筛选；需要时查事件 XML，保留时间、事件 ID、记录号、规则名称及 ModifyingApplication。此案例所见 2097 是添加、2052 是删除；不要假定所有 Windows 版本 ID 完全相同，也不要把查不到事件当成没有删除。

服务/程序的签名、路径、进程和服务配置可只读核对。事件归因不等于根因，不因软件名字或单条记录就诊断恶意软件。不要自动卸载、永久停用、杀进程、关闭 Defender，或启动持续重建规则的后台程序。

若已被明确授权做某个服务的短时对照测试：
- 记录准确服务名、原 State/StartMode，定义实际时间截止点；计入查询和等待耗时。
- 用 try/finally 恢复原状态，避免更改启动类型；必要时预先准备独立恢复措施。
- 独立读取恢复后的 State 和 StartMode，不能仅凭“进入 finally”或写出 ServiceRestored 阶段名宣称成功。
- 服务恢复后仅做有限被动观察。进程退出或部分样本不等于计划全部完成。
- 新操作若涉及另一服务或永久设置，判断现有授权是否覆盖；不覆盖时先形成可审查方案再取得具体授权。

Windows Home 的本地策略试验不能仅因写入某个 PolicyStore 就当成功；必须在 ActiveStore 验证。试验无效时只清理本轮资源，优先报告局限，不改用未经核验的注册表捷径。

## 参考文档

需要确认当前参数或策略语义时阅读官方文档：
- https://learn.microsoft.com/en-us/powershell/module/netsecurity/set-netfirewallrule
- https://learn.microsoft.com/en-us/powershell/module/netsecurity/get-netfirewallrule
- https://learn.microsoft.com/en-us/powershell/module/netsecurity/get-netfirewalladdressfilter
