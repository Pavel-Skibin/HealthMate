#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Управление Qdrant snapshots — создание, скачивание, восстановление

.DESCRIPTION
    Скрипт для работы с snapshots векторной базы Qdrant.
    Поддерживает: create, download, restore, list, cleanup

.PARAMETER Action
    Действие: create | download | restore | list | cleanup

.PARAMETER SnapshotName
    Имя snapshot (для restore и download)

.PARAMETER BackupDir
    Папка для сохранения snapshots (по умолчанию D:\backups\qdrant_snapshots)

.PARAMETER QdrantUrl
    URL Qdrant API (по умолчанию http://localhost:6333)

.PARAMETER CollectionName
    Имя коллекции (по умолчанию drug_indications_recommendations)

.EXAMPLE
    # Создать snapshot
    .\qdrant-snapshot.ps1 -Action create

    # Скачать последний snapshot
    .\qdrant-snapshot.ps1 -Action download

    # Восстановить из файла
    .\qdrant-snapshot.ps1 -Action restore -SnapshotName "snapshot_name.snapshot"

    # Список всех snapshots на сервере
    .\qdrant-snapshot.ps1 -Action list

    # Удалить старые snapshots (старше 7 дней)
    .\qdrant-snapshot.ps1 -Action cleanup
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("create", "download", "restore", "list", "cleanup")]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [string]$SnapshotName,
    
    [Parameter(Mandatory=$false)]
    [string]$BackupDir = "D:\backups\qdrant_snapshots",
    
    [Parameter(Mandatory=$false)]
    [string]$QdrantUrl = "http://localhost:6333",
    
    [Parameter(Mandatory=$false)]
    [string]$CollectionName = "drug_indications_recommendations"
)

# ============================================================================
# ФУНКЦИИ
# ============================================================================

function Write-Header {
    param([string]$Text)
    Write-Host "`n" -ForegroundColor Gray
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Text)
    Write-Host "✓ $Text" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Text)
    Write-Host "✗ $Text" -ForegroundColor Red
}

function Write-Info {
    param([string]$Text)
    Write-Host "ℹ $Text" -ForegroundColor Yellow
}

function Test-QdrantConnection {
    try {
        $response = Invoke-WebRequest -Uri "$QdrantUrl/health" -Method GET -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Success "Qdrant доступен на $QdrantUrl"
            return $true
        }
    }
    catch {
        Write-Error-Custom "Не удалось подключиться к Qdrant на $QdrantUrl"
        Write-Error-Custom "Ошибка: $_"
        return $false
    }
}

function Invoke-CreateSnapshot {
    Write-Header "СОЗДАНИЕ SNAPSHOT"
    
    if (-not (Test-QdrantConnection)) {
        return $null
    }
    
    Write-Info "Создаю snapshot коллекции '$CollectionName'..."
    
    try {
        $uri = "$QdrantUrl/collections/$CollectionName/snapshots"
        $response = Invoke-WebRequest -Uri $uri -Method POST -ContentType "application/json" -ErrorAction Stop
        $result = $response.Content | ConvertFrom-Json
        
        if ($result.status -eq "ok") {
            $snapshotName = $result.result.name
            $snapshotSize = [math]::Round($result.result.size / 1MB, 2)
            $creationTime = $result.result.creation_time
            
            Write-Success "Snapshot создан успешно"
            Write-Host "  Имя: $snapshotName"
            Write-Host "  Размер: $snapshotSize MB"
            Write-Host "  Создан: $creationTime"
            
            return $snapshotName
        }
        else {
            Write-Error-Custom "Ошибка при создании snapshot: $($result.status)"
            return $null
        }
    }
    catch {
        Write-Error-Custom "Ошибка API: $_"
        return $null
    }
}

function Invoke-ListSnapshots {
    Write-Header "СПИСОК SNAPSHOTS НА СЕРВЕРЕ"
    
    if (-not (Test-QdrantConnection)) {
        return
    }
    
    try {
        $uri = "$QdrantUrl/collections/$CollectionName/snapshots"
        $response = Invoke-WebRequest -Uri $uri -Method GET -ContentType "application/json" -ErrorAction Stop
        $result = $response.Content | ConvertFrom-Json
        
        if ($result.result.Count -eq 0) {
            Write-Info "Snapshots не найдены"
            return
        }
        
        Write-Host "Найдено snapshots: $($result.result.Count)" -ForegroundColor Cyan
        Write-Host ""
        
        $result.result | ForEach-Object {
            $size = [math]::Round($_.size / 1MB, 2)
            Write-Host "  📦 $($_.name)" -ForegroundColor White
            Write-Host "     Размер: $size MB | Создан: $($_.creation_time)" -ForegroundColor Gray
        }
    }
    catch {
        Write-Error-Custom "Ошибка при получении списка: $_"
    }
}

function Invoke-DownloadSnapshot {
    param([string]$Name)
    
    Write-Header "СКАЧИВАНИЕ SNAPSHOT"
    
    if (-not (Test-QdrantConnection)) {
        return $false
    }
    
    # Если не указано имя — берём последний
    if ([string]::IsNullOrEmpty($Name)) {
        Write-Info "Имя не указано, ищу последний snapshot..."
        try {
            $uri = "$QdrantUrl/collections/$CollectionName/snapshots"
            $response = Invoke-WebRequest -Uri $uri -Method GET -ErrorAction Stop
            $snapshots = $response.Content | ConvertFrom-Json | Select-Object -ExpandProperty result
            
            if ($snapshots.Count -eq 0) {
                Write-Error-Custom "Snapshots не найдены на сервере"
                return $false
            }
            
            # Берём первый (обычно он самый свежий)
            $Name = $snapshots[0].name
            Write-Info "Выбран: $Name"
        }
        catch {
            Write-Error-Custom "Ошибка при получении списка: $_"
            return $false
        }
    }
    
    # Создать папку для бэкапов
    if (-not (Test-Path $BackupDir)) {
        Write-Info "Создаю папку: $BackupDir"
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }
    
    $outPath = Join-Path $BackupDir $Name
    
    if (Test-Path $outPath) {
        Write-Error-Custom "Файл уже существует: $outPath"
        return $false
    }
    
    try {
        Write-Info "Скачиваю snapshot..."
        $uri = "$QdrantUrl/collections/$CollectionName/snapshots/$Name"
        Invoke-WebRequest -Uri $uri -OutFile $outPath -ErrorAction Stop
        
        $fileSize = [math]::Round((Get-Item $outPath).Length / 1MB, 2)
        Write-Success "Snapshot скачан успешно"
        Write-Host "  Путь: $outPath"
        Write-Host "  Размер: $fileSize MB"
        
        return $true
    }
    catch {
        Write-Error-Custom "Ошибка при скачивании: $_"
        if (Test-Path $outPath) {
            Remove-Item $outPath -Force
        }
        return $false
    }
}

function Invoke-RestoreSnapshot {
    param([string]$SnapshotPath)
    
    Write-Header "ВОССТАНОВЛЕНИЕ SNAPSHOT"
    
    if (-not (Test-QdrantConnection)) {
        return $false
    }
    
    # Если указано только имя файла (без пути)
    if (-not ([System.IO.Path]::IsPathRooted($SnapshotPath))) {
        $SnapshotPath = Join-Path $BackupDir $SnapshotPath
    }
    
    if (-not (Test-Path $SnapshotPath)) {
        Write-Error-Custom "Файл не найден: $SnapshotPath"
        return $false
    }
    
    $fileSize = [math]::Round((Get-Item $SnapshotPath).Length / 1MB, 2)
    
    Write-Info "Восстанавливаю snapshot..."
    Write-Host "  Файл: $SnapshotPath"
    Write-Host "  Размер: $fileSize MB"
    Write-Host ""
    
    $confirm = Read-Host "Это заменит текущую коллекцию. Продолжить? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Info "Отменено"
        return $false
    }
    
    try {
        $uri = "$QdrantUrl/collections/$CollectionName/snapshots/recover"
        
        # Прямое восстановление через curl (более надёжный вариант)
        Write-Info "Отправляю snapshot на сервер..."
        
        $curlPath = "curl.exe"
        if (-not (Get-Command $curlPath -ErrorAction SilentlyContinue)) {
            Write-Error-Custom "curl не найден в PATH"
            return $false
        }
        
        & $curlPath -X POST `
            -H "Content-Type: application/octet-stream" `
            --data-binary "@$SnapshotPath" `
            "$uri" `
            -s -w "`n%{http_code}" -o $env:TEMP\curl_response.txt
        
        $httpCode = (Get-Content $env:TEMP\curl_response.txt | Select-Object -Last 1)
        $responseBody = Get-Content $env:TEMP\curl_response.txt | Select-Object -SkipLast 1
        
        if ($httpCode -eq 200 -or $httpCode -eq 201) {
            Write-Success "Snapshot восстановлен успешно"
            Write-Host "  HTTP статус: $httpCode"
            
            # Небольшая задержка для синхронизации
            Write-Info "Жду 5 секунд для синхронизации..."
            Start-Sleep -Seconds 5
            
            return $true
        }
        else {
            Write-Error-Custom "Ошибка при восстановлении (HTTP $httpCode)"
            Write-Host "Ответ: $responseBody"
            return $false
        }
    }
    catch {
        Write-Error-Custom "Ошибка: $_"
        return $false
    }
}

function Invoke-CleanupOldSnapshots {
    param([int]$DaysOld = 7)
    
    Write-Header "ОЧИСТКА СТАРЫХ SNAPSHOTS"
    
    if (-not (Test-Path $BackupDir)) {
        Write-Info "Папка не существует: $BackupDir"
        return
    }
    
    $cutoffDate = (Get-Date).AddDays(-$DaysOld)
    $oldFiles = Get-ChildItem -Path $BackupDir -Filter "*.snapshot" | 
                Where-Object { $_.LastWriteTime -lt $cutoffDate }
    
    if ($oldFiles.Count -eq 0) {
        Write-Info "Старых файлов не найдено (старше $DaysOld дней)"
        return
    }
    
    Write-Info "Найдено старых файлов: $($oldFiles.Count)"
    Write-Host ""
    
    $oldFiles | ForEach-Object {
        $size = [math]::Round($_.Length / 1MB, 2)
        Write-Host "  📦 $($_.Name) — $size MB (от $($_.LastWriteTime))" -ForegroundColor Gray
    }
    
    Write-Host ""
    $confirm = Read-Host "Удалить эти файлы? (yes/no)"
    
    if ($confirm -eq "yes") {
        $oldFiles | ForEach-Object {
            Remove-Item $_.FullName -Force
            Write-Success "Удалён: $($_.Name)"
        }
    }
    else {
        Write-Info "Отменено"
    }
}

# ============================================================================
# MAIN
# ============================================================================

try {
    Write-Host ""
    Write-Host "🔄 Qdrant Snapshot Manager" -ForegroundColor Cyan
    Write-Host "────────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "Коллекция: $CollectionName"
    Write-Host "Qdrant URL: $QdrantUrl"
    Write-Host "Backup папка: $BackupDir"
    
    switch ($Action) {
        "create" {
            $name = Invoke-CreateSnapshot
            if ($null -ne $name) {
                Write-Host ""
                $downloadNow = Read-Host "Скачать snapshot сейчас? (yes/no)"
                if ($downloadNow -eq "yes") {
                    Invoke-DownloadSnapshot -Name $name
                }
            }
        }
        
        "download" {
            Invoke-DownloadSnapshot -Name $SnapshotName
        }
        
        "restore" {
            if ([string]::IsNullOrEmpty($SnapshotName)) {
                Write-Error-Custom "Укажите имя snapshot: -SnapshotName имя"
                exit 1
            }
            Invoke-RestoreSnapshot -SnapshotPath $SnapshotName
        }
        
        "list" {
            Invoke-ListSnapshots
        }
        
        "cleanup" {
            Invoke-CleanupOldSnapshots
        }
    }
    
    Write-Host ""
}
catch {
    Write-Error-Custom "Критическая ошибка: $_"
    exit 1
}
