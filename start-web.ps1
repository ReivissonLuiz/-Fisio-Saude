# start-web.ps1
# Inicia o backend Node.js e o Flutter Web do +Físio +Saúde

$projectRoot = $PSScriptRoot

Write-Host ""
Write-Host "🚀  +Físio +Saúde — Iniciando ambiente de desenvolvimento web..." -ForegroundColor Cyan
Write-Host ""

# 1. Inicia o backend Node.js numa nova janela do terminal
Write-Host "▶  Iniciando backend Node.js em http://localhost:3000 ..." -ForegroundColor Green
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$projectRoot'; node server.js"

# Aguarda 2 segundos para o servidor subir
Start-Sleep -Seconds 2

# 2. Inicia o Flutter Web no Chrome
Write-Host "▶  Iniciando Flutter Web no Chrome em http://localhost:8080 ..." -ForegroundColor Green
Write-Host ""
Write-Host "   Aguarde o Chrome abrir automaticamente..." -ForegroundColor Yellow
Write-Host "   (pressione 'q' neste terminal para encerrar o Flutter)" -ForegroundColor Yellow
Write-Host ""

Set-Location "$projectRoot\flutter_app"
flutter run -d chrome --web-port=8080
