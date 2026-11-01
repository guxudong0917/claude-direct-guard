[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$RuleName,
    [ValidateSet('PersistentStore', 'ActiveStore')]
    [string[]]$PolicyStore = @('PersistentStore', 'ActiveStore')
)

$ErrorActionPreference = 'Stop'
foreach ($name in $RuleName) {
    if ([string]::IsNullOrWhiteSpace($name) -or [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($name)) {
        throw 'Supply exact, nonempty rule names without wildcard characters.'
    }
}
$names = @($RuleName | Select-Object -Unique)
$stores = @($PolicyStore | Select-Object -Unique)
$rows = @()
foreach ($store in $stores) {
    foreach ($name in $names) {
        try {
            $found = @(Get-NetFirewallRule -PolicyStore $store -Name $name -ErrorAction Stop)
            if ($found.Count -ne 1) {
                throw ('Expected exactly one matching rule; returned ' + $found.Count + '.')
            }
            $rule = $found[0]
            $address = $rule | Get-NetFirewallAddressFilter -ErrorAction Stop
            $application = $rule | Get-NetFirewallApplicationFilter -ErrorAction Stop
            $port = $rule | Get-NetFirewallPortFilter -ErrorAction Stop
            $rows += [pscustomobject]@{
                Name = $name
                Store = $store
                Status = 'Present'
                Exists = $true
                DisplayName = $rule.DisplayName
                Group = $rule.Group
                Enabled = $rule.Enabled.ToString()
                Action = $rule.Action.ToString()
                Direction = $rule.Direction.ToString()
                Profile = $rule.Profile.ToString()
                Program = $application.Program
                Package = $application.Package
                Protocol = $port.Protocol
                LocalPort = @($port.LocalPort)
                RemotePort = @($port.RemotePort)
                LocalAddress = @($address.LocalAddress)
                RemoteAddress = @($address.RemoteAddress)
                Error = $null
            }
        } catch {
            $isMissing = $_.CategoryInfo.Category -eq 'ObjectNotFound' -and $_.FullyQualifiedErrorId -match '^CmdletizationQuery_NotFound_(Name|InstanceID),Get-NetFirewallRule$'
            $rows += [pscustomobject]@{
                Name = $name
                Store = $store
                Status = if ($isMissing) {'Missing'} else {'QueryError'}
                Exists = if ($isMissing) {$false} else {$null}
                Error = $_.Exception.Message
                ErrorId = $_.FullyQualifiedErrorId
                ErrorCategory = $_.CategoryInfo.Category.ToString()
            }
        }
    }
}
$profiles = @()
$profileError = $null
try {
    $profiles = @(Get-NetFirewallProfile -PolicyStore ActiveStore -ErrorAction Stop | ForEach-Object {
        [pscustomobject]@{
            Name = $_.Name
            Enabled = $_.Enabled.ToString()
            DefaultOutboundAction = if ($null -eq $_.DefaultOutboundAction) {$null} else {$_.DefaultOutboundAction.ToString()}
            AllowLocalFirewallRules = if ($null -eq $_.AllowLocalFirewallRules) {$null} else {$_.AllowLocalFirewallRules.ToString()}
        }
    })
} catch {
    $profileError = $_.Exception.Message
}
$queryError = @($rows | Where-Object {$_.Status -eq 'QueryError'}).Count -gt 0 -or $null -ne $profileError
$allPresent = @($rows | Where-Object {$_.Status -ne 'Present'}).Count -eq 0
[pscustomobject]@{
    ReportVersion = 1
    CapturedAt = (Get-Date).ToString('o')
    RequestedRuleNames = $names
    AllQueriesSucceeded = -not $queryError
    AllRequestedRulesPresent = $allPresent
    Rules = $rows
    Profiles = $profiles
    ProfilesError = $profileError
    Note = 'Read-only configuration snapshot; this does not test traffic or assert complete protection.'
} | ConvertTo-Json -Depth 8
if ($queryError) {exit 1}
if (-not $allPresent) {exit 2}
exit 0
