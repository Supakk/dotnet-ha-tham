<#
.SYNOPSIS
    Applies the TMS schema migrations, or rolls them back.

.DESCRIPTION
    Reads TMS_SCHEMA_MIGRATION to decide what still has to run, applies each
    outstanding file in order, and records it with the SHA-256 of the file as
    applied.

    The checksum is the part worth having. A migration that has been edited
    since it ran no longer describes what was done to the database, and there
    is no safe way to guess which of the two is right - so the run stops and
    says which version, what was stored, and what the file hashes to now.

    Every migration file manages its own transaction. This script does not wrap
    them: a file that needs to split work across batches (GO) could not run
    inside one from here, and pretending otherwise would give a false sense of
    atomicity.

.PARAMETER WhatIf
    Report what would run. Touches nothing.

.PARAMETER RollbackTo
    Roll back down to and including this version, newest first.

.PARAMETER Force
    Permit a rollback that discards audit or lifecycle history. Never permits
    one that would risk a duplicate delivery - migration 004's outstanding-
    attempt check ignores this deliberately.

.EXAMPLE
    .\Run-Migrations.ps1 -WhatIf
    .\Run-Migrations.ps1
    .\Run-Migrations.ps1 -RollbackTo 004 -Force
#>
[CmdletBinding()]
param(
    [string] $Server = '(localdb)\MSSQLLocalDB',
    [string] $Database = 'MMDEV',
    [switch] $WhatIf,
    [string] $RollbackTo,
    [switch] $Force
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Invoke-Sql {
    param([string] $Query, [string] $File)

    $args = @('-S', $Server, '-d', $Database, '-b', '-l', '30')
    if ($File) { $args += @('-i', $File) } else { $args += @('-Q', $Query) }

    $output = & sqlcmd @args 2>&1
    if ($LASTEXITCODE -ne 0) {
        $output | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        throw "sqlcmd failed (exit $LASTEXITCODE)"
    }
    return $output
}

function Get-Checksum {
    param([string] $Path)
    # Hash the bytes, not the decoded text: a file that differs only in its
    # encoding is still a different file to sqlcmd.
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-Applied {
    if (-not (Invoke-Sql -Query "SET NOCOUNT ON; SELECT CASE WHEN OBJECT_ID('dbo.TMS_SCHEMA_MIGRATION','U') IS NULL THEN 0 ELSE 1 END" |
              Where-Object { $_ -match '^\s*1\s*$' })) {
        return @{}
    }

    $rows = Invoke-Sql -Query "SET NOCOUNT ON; SELECT VERSION + '|' + CHECKSUM FROM dbo.TMS_SCHEMA_MIGRATION ORDER BY VERSION"
    $map = @{}
    foreach ($row in $rows) {
        $line = "$row".Trim()
        if ($line -match '^(\d{3})\|([0-9a-fA-F]{64})$') {
            $map[$Matches[1]] = $Matches[2].ToLowerInvariant()
        }
    }
    return $map
}

# ── plan ────────────────────────────────────────────────────────────────────

$files = Get-ChildItem -Path $here -Filter '???_*.sql' | Sort-Object Name
if ($files.Count -eq 0) { throw "No migration files found in $here" }

Write-Host "TMS migrations - $Database on $Server" -ForegroundColor Cyan
$applied = Get-Applied

# ── rollback ────────────────────────────────────────────────────────────────

if ($RollbackTo) {
    $targets = $files |
        Where-Object { $_.Name.Substring(0, 3) -ge $RollbackTo -and $applied.ContainsKey($_.Name.Substring(0, 3)) } |
        Sort-Object Name -Descending

    if ($targets.Count -eq 0) { Write-Host "Nothing applied at or above $RollbackTo." ; return }

    Write-Host "`nWould roll back (newest first):" -ForegroundColor Yellow
    $targets | ForEach-Object { Write-Host "  $($_.Name.Substring(0,3))  $($_.BaseName)" }
    if ($WhatIf) { return }

    foreach ($file in $targets) {
        $version = $file.Name.Substring(0, 3)
        $undo = Join-Path $here "rollback\$($file.BaseName).undo.sql"
        if (-not (Test-Path $undo)) { throw "Missing rollback script for $version : $undo" }

        Write-Host "`n[$version] rolling back…" -ForegroundColor Yellow

        # -Force is passed to SQL through session context so each rollback can
        # decide for itself what it is willing to discard.
        $prelude = if ($Force) { "EXEC sp_set_session_context @key=N'AllowAuditLoss', @value=1;`nGO`n" } else { '' }
        $temp = [System.IO.Path]::GetTempFileName() + '.sql'
        ($prelude + (Get-Content -Raw -Path $undo)) | Set-Content -Path $temp -Encoding UTF8

        try { Invoke-Sql -File $temp | ForEach-Object { Write-Host "    $_" } }
        finally { Remove-Item $temp -ErrorAction SilentlyContinue }

        Write-Host "[$version] rolled back." -ForegroundColor Green
    }
    return
}

# ── apply ───────────────────────────────────────────────────────────────────

$outstanding = @()
foreach ($file in $files) {
    $version = $file.Name.Substring(0, 3)
    $checksum = Get-Checksum $file.FullName

    if ($applied.ContainsKey($version)) {
        if ($applied[$version] -ne $checksum) {
            Write-Host "`n  version : $version" -ForegroundColor Red
            Write-Host "  stored  : $($applied[$version])" -ForegroundColor Red
            Write-Host "  current : $checksum" -ForegroundColor Red
            throw "Migration $version has changed since it was applied. The file no longer describes what was done to this database. Resolve by hand - this script will not re-apply it or update the record."
        }
        Write-Host "  [$version] already applied - skipped." -ForegroundColor DarkGray
        continue
    }
    $outstanding += [pscustomobject]@{ Version = $version; File = $file; Checksum = $checksum }
}

if ($outstanding.Count -eq 0) { Write-Host "`nUp to date." -ForegroundColor Green ; return }

Write-Host "`nOutstanding:" -ForegroundColor Yellow
$outstanding | ForEach-Object { Write-Host "  $($_.Version)  $($_.File.BaseName)" }
if ($WhatIf) { Write-Host "`n-WhatIf: nothing was applied." -ForegroundColor Cyan ; return }

foreach ($item in $outstanding) {
    Write-Host "`n[$($item.Version)] applying $($item.File.Name)…" -ForegroundColor Yellow
    $started = Get-Date

    Invoke-Sql -File $item.File.FullName | ForEach-Object { Write-Host "    $_" }

    $ms = [int]((Get-Date) - $started).TotalMilliseconds

    # Recorded only after the file's own verification passed - a migration that
    # threw never reaches this line, and never claims to have run.
    $name = $item.File.BaseName -replace "'", "''"
    Invoke-Sql -Query @"
SET NOCOUNT ON;
INSERT INTO dbo.TMS_SCHEMA_MIGRATION (VERSION, NAME, CHECKSUM, DURATIONMS)
VALUES ('$($item.Version)', '$name', '$($item.Checksum)', $ms);
"@ | Out-Null

    Write-Host "[$($item.Version)] applied in ${ms}ms." -ForegroundColor Green
}

Write-Host "`nDone. Run Verify-Migrations.sql to check the result." -ForegroundColor Cyan
