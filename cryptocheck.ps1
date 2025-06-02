#NinjaOne Powershell script that checks if SSL TLS Settings are best practice
#The script will give output to a custom field ($propertyName = "cryptostatus")  in ninjaone 

$checks = @(
    # DisabledByDefault = 1 (deaktiviert)
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\Multi-Protocol Unified Hello\Client"; Name = "DisabledByDefault"; ExpectedValue = 1 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\PCT 1.0\Client"; Name = "DisabledByDefault"; ExpectedValue = 1 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client"; Name = "DisabledByDefault"; ExpectedValue = 1 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client"; Name = "DisabledByDefault"; ExpectedValue = 1 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client"; Name = "DisabledByDefault"; ExpectedValue = 1 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client"; Name = "DisabledByDefault"; ExpectedValue = 1 },

    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\Multi-Protocol Unified Hello\Server"; Name = "DisabledByDefault"; ExpectedValue = 1 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\PCT 1.0\Server"; Name = "DisabledByDefault"; ExpectedValue = 1 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server"; Name = "DisabledByDefault"; ExpectedValue = 1 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server"; Name = "DisabledByDefault"; ExpectedValue = 1 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server"; Name = "DisabledByDefault"; ExpectedValue = 1 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server"; Name = "DisabledByDefault"; ExpectedValue = 1 },

    # Enabled = 1 (aktiviert)
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"; Name = "Enabled"; ExpectedValue = 1 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server"; Name = "Enabled"; ExpectedValue = 1 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client"; Name = "Enabled"; ExpectedValue = 1 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client"; Name = "Enabled"; ExpectedValue = 1 }
)

function Get-ProtocolInfo {
    param([string]$path)
    $parts = $path -split '\\'
    $protocolIndex = [Array]::IndexOf($parts, "Protocols") + 1
    $protocolName = $parts[$protocolIndex]
    $direction = $parts[$protocolIndex + 1]
    return @{ Protocol = $protocolName; Direction = $direction }
}

$problems = @()

foreach ($check in $checks) {
    $path = $check.Path
    $name = $check.Name
    $expected = $check.ExpectedValue

    if (-not (Test-Path $path)) {
        $info = Get-ProtocolInfo -path $path
        $problems += "$($info.Protocol) $($info.Direction): Registry-Pfad nicht vorhanden."
        continue
    }

    try {
        $value = Get-ItemProperty -Path $path -Name $name -ErrorAction Stop | Select-Object -ExpandProperty $name
    }
    catch {
        $info = Get-ProtocolInfo -path $path
        $problems += "$($info.Protocol) $($info.Direction): Wert '$name' nicht vorhanden."
        continue
    }

    if ($value -ne $expected) {
        $info = Get-ProtocolInfo -path $path
        if ($name -eq "DisabledByDefault" -and $expected -eq 1) {
            $problems += "$($info.Protocol) $($info.Direction) ist nicht deaktiviert (DisabledByDefault=$value)."
        }
        elseif ($name -eq "Enabled" -and $expected -eq 1) {
            $problems += "$($info.Protocol) $($info.Direction) ist nicht aktiviert (Enabled=$value)."
        }
        else {
            $problems += "$($info.Protocol) $($info.Direction): Wert '$name' ist $value, erwartet $expected."
        }
    }
}

$propertyName = "cryptostatus"
if ($problems.Count -eq 0) {
    $message = "Diese Instanz entspricht den aktuellen Best Practices für Verschlüsselung"
} else {
    $message = "Abweichungen gefunden:`n" + ($problems | ForEach-Object { "- $_" } | Out-String)
}

# Korrekte Übergabe an Ninja-Property-Set (ohne Pipe)
Ninja-Property-Set $propertyName $message

# Zusätzlich auf der Konsole ausgeben
Write-Output $message
