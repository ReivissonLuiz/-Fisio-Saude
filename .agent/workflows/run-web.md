---
description: rodar o app +Físio +Saúde no navegador em modo de desenvolvimento
---

// turbo-all

## Pré-requisitos
- Node.js instalado
- Flutter SDK instalado e no PATH
- Google Chrome instalado

## Passos

1. Instalar dependências do backend (somente se `node_modules` não existir)
```powershell
npm install
```

2. Iniciar o servidor Node.js backend em segundo plano
```powershell
Start-Process powershell -ArgumentList '-NoExit', '-Command', 'cd "c:\Users\breze\Documents\TCC\-Fisio-Saude"; node server.js'
```

3. Iniciar o Flutter Web no Chrome
```powershell
cd flutter_app; flutter run -d chrome --web-port=8080
```

O app estará disponível em:
- 🌐 Flutter Web: http://localhost:8080
- 🔧 API Node.js: http://localhost:3000
