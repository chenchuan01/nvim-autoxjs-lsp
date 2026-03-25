# WSL2 端口转发脚本（在 Windows PowerShell 管理员模式下运行）
# 运行方式: powershell -ExecutionPolicy Bypass -File .\wsl2-portforward.ps1

$port = 9317
$wsl2Ip = (wsl hostname -I).Trim().Split(" ")[0]

Write-Host "WSL2 IP: $wsl2Ip"

# 删除旧规则后重新添加（保证最新）
netsh interface portproxy delete v4tov4 listenport=$port listenaddress=0.0.0.0 2>$null
netsh interface portproxy add v4tov4 listenport=$port listenaddress=0.0.0.0 connectport=$port connectaddress=$wsl2Ip
Write-Host "端口转发规则已设置"

# 添加防火墙规则（忽略已存在的错误）
netsh advfirewall firewall delete rule name="WSL2 AutoX $port" 2>$null
netsh advfirewall firewall add rule name="WSL2 AutoX $port" dir=in action=allow protocol=TCP localport=$port
Write-Host "防火墙规则已设置"

$winIp = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "WLAN*" -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
if (-not $winIp) {
    $winIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.*" } | Select-Object -First 1).IPAddress
}

Write-Host ""
Write-Host "完成！手机连接地址: ${winIp}:${port}"
Write-Host "（如果 IP 不对，请用 ipconfig 查看 WLAN 的 IPv4 地址）"
