$envFile = Join-Path (Get-Location) ".env"
if (!(Test-Path $envFile)) {
  throw "Не найден .env в корне: $envFile"
}

Get-Content $envFile | ForEach-Object {
  $line = $_.Trim()
  if ($line.Length -eq 0) { return }
  if ($line.StartsWith("#")) { return }

  $parts = $line -split "=", 2
  if ($parts.Count -ne 2) { return }

  $name  = $parts[0].Trim()
  $value = $parts[1].Trim().Trim('"').Trim("'")

  # экспорт в текущее окружение
  Set-Item -Path "Env:$name" -Value $value
}

# привести YC_SERVICE_ACCOUNT_KEY_FILE к абсолютному пути, если он относительный
if ($env:YC_SERVICE_ACCOUNT_KEY_FILE -and !(Split-Path $env:YC_SERVICE_ACCOUNT_KEY_FILE -IsAbsolute)) {
  $candidate = Join-Path (Get-Location) $env:YC_SERVICE_ACCOUNT_KEY_FILE
  if (Test-Path $candidate) {
    $env:YC_SERVICE_ACCOUNT_KEY_FILE = (Resolve-Path $candidate).Path
  }
}

Write-Host "Loaded .env OK"
Write-Host "YC_CLOUD_ID=$env:YC_CLOUD_ID"
Write-Host "YC_FOLDER_ID=$env:YC_FOLDER_ID"
Write-Host "YC_ZONE=$env:YC_ZONE"
Write-Host "YC_SERVICE_ACCOUNT_KEY_FILE=$env:YC_SERVICE_ACCOUNT_KEY_FILE"
