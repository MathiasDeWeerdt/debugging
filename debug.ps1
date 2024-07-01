function DnsLookup {
    $domain = "signal.jimber.io"
    $dnsResult = Resolve-DnsName $domain
    if ($dnsResult) {
        $resolvedIp = $dnsResult.IPAddress
        Write-Host "DNS Resolved IP: $resolvedIp" -ForegroundColor Green
    } else {
        Write-Host "Failed to perform DNS lookup for: $domain" -ForegroundColor Red
    }
}

function PingHost {
    $ip = "185.69.165.125"
    $pingResult = Test-Connection -ComputerName $ip -Count 1
    if ($pingResult) {
        $latency = $pingResult.ResponseTime
        Write-Host "Ping Latency: $latency ms" -ForegroundColor Green
    } else {
        Write-Host "Failed to ping: $ip" -ForegroundColor Red
    }
}

function GetIpInfo {
    $uri = "https://signal.jimber.io/api/v1/ip/me"
    $response = Invoke-RestMethod -Uri $uri
    if ($response) {
        $ip = $response.ip
        Write-Host "Your IP: $ip" -ForegroundColor Green
    } else {
        Write-Host "Failed to retrieve IP information." -ForegroundColor Red
    }
}

function CheckUpdateKey {
    $uri = "https://signal.jimber.io/binaries/updates.json"
    $response = Invoke-RestMethod -Uri $uri
    if ($response.networkcontroller) {
        Write-Host "Successfully fetched updates.json from signal.jimber.io" -ForegroundColor Green
    } else {
        Write-Host "Couldn't reach signal.jimber.io" -ForegroundColor Red
    }
}


function CheckFiles {
    $programFiles = [Environment]::GetFolderPath('ProgramFiles')
    $userHome = [Environment]::GetFolderPath('UserProfile')

    $files = @(
        "$programFiles\Jimber\JimberNetworkIsolation.exe",
        "$programFiles\Jimber\JimberNetworkIsolationLauncher.exe",
        "$programFiles\Jimber\wg.exe",
        "$programFiles\Jimber\jimbersettings.json",
        "$userHome\.jimbersettings.json"
    )

    foreach ($file in $files) {
        $state = if (Test-Path $file) { "[V]" } else { "[X]" }
        $color = if (Test-Path $file) { "Green" } else { "Red" }
        Write-Host -NoNewline "$state " -ForegroundColor $color
        Write-Host "File: $file"

        if ($file -like "*.json" -and (Test-Path $file)) {
            try {
                $jsonContent = Get-Content $file -Raw | ConvertFrom-Json
                $trimmedContent = $jsonContent | Format-List | Out-String
                $trimmedContent = "`n" + $trimmedContent.Trim() + "`n"
                Write-Host $trimmedContent
            } catch {
                Write-Host "Failed to read JSON content from file: $file" -ForegroundColor Red
            }
        }
    }
}

function CheckService {
    $serviceName = "JimberNetworkIsolation"

    $state = if (Get-Service $serviceName -ErrorAction SilentlyContinue) { "[V]" } else { "[X]" }
    $color = if (Get-Service $serviceName -ErrorAction SilentlyContinue) { "Green" } else { "Red" }
    Write-Host -NoNewline "$state " -ForegroundColor $color
    Write-Host "Service: $serviceName"
}

function CheckProcess {
    param($processName)

    $process = Get-Process -Name $processName -ErrorAction SilentlyContinue
    $state = if ($process) { "[V]" } else { "[X]" }
    $color = if ($process) { "Green" } else { "Red" }
    Write-Host -NoNewline "$state " -ForegroundColor $color
    Write-Host "Process: $processName"
}

function CheckPorts {
    $ports = @(10001, 10002, 10003)

    $allConnections = Get-NetTCPConnection -ErrorAction SilentlyContinue

    foreach ($port in $ports) {
        $connectionsForPort = $allConnections | Where-Object { $_.LocalPort -eq $port }

        $bound = ($connectionsForPort | Measure-Object).Count -gt 0
        $status = if ($bound) { "[V]" } else { "[X]" }
        $color = if ($bound) { "Green" } else { "Red" }
        Write-Host -NoNewline "$status " -ForegroundColor $color
        Write-Host "Port: $port"
        if ($bound) {
            $processIds = $connectionsForPort | Select-Object -ExpandProperty OwningProcess -Unique

            foreach ($processId in $processIds) {
                $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
                if ($process) {
                    $processStartInfo = Get-WmiObject Win32_Process -Filter "ProcessId = $processId" -ErrorAction SilentlyContinue
                    if ($processStartInfo) {
                        $owner = $processStartInfo.GetOwner()
                        Write-Host "    Name: $($process.ProcessName), PID: $($process.Id), Started By: $($owner.Domain)\$($owner.User)"
                    }
                }
            }
        }
    }
}

function ReadEnvironmentVariables {
    $envVariables = [System.Environment]::GetEnvironmentVariables([System.EnvironmentVariableTarget]::Machine)

    foreach ($key in $envVariables.Keys) {
        $name = $key
        $value = $envVariables[$key]
        if ($name -like "*jimber*" -or $name -like "*JIMBER*") {
            Write-Host "    ${name}: $value"
        }
    }
}

function ExecuteWgShow {
    $programFiles = [Environment]::GetFolderPath('ProgramFiles')
    $wgExePath = "$programFiles\Jimber\wg.exe"

    if (Test-Path $wgExePath -PathType Leaf) {
        $wgOutput = & $wgExePath show | Out-String
        Write-Host $wgOutput
    } else {
        Write-Host "wg.exe not found." -ForegroundColor Red
    }
}

function JimberVersion {
    $programFiles = [Environment]::GetFolderPath('ProgramFiles')
    $niExePath = "$programFiles\Jimber\JimberNetworkIsolation.exe"

    if (Test-Path $niExePath -PathType Leaf) {
        $NIOutput = & $niExePath version | Out-String
        Write-Host $NIOutput
    } else {
        Write-Host "JimberNetworkIsolation.exe not found." -ForegroundColor Red
    }
}

while ($true) {
    Clear-Host
    Write-Host "Jimber Network Isolation - Debugger"
    Write-Host "---------------------------------------------------"
    DnsLookup
    PingHost
    GetIpInfo
    CheckUpdateKey
    Write-Host "---------------------------------------------------"
    CheckFiles
    Write-Host "---------------------------------------------------"
    CheckService
    Write-Host "---------------------------------------------------"
    CheckProcess -processName "JimberNetworkIsolation"
    CheckProcess -processName "JimberNetworkIsolationLauncher"
    Write-Host "---------------------------------------------------"
    CheckPorts
    Write-Host "---------------------------------------------------"
    ReadEnvironmentVariables
    Write-Host "---------------------------------------------------"
    ExecuteWgShow
    Write-Host "---------------------------------------------------"
    Start-Sleep -Seconds 10
}
