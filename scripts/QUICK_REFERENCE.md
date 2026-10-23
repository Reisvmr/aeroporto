#!/bin/bash

################################################################################
# Projeto Aeroporto - Guia Rápido de Validação de Acessos
# 
# Arquivo: scripts/QUICK_REFERENCE.md
# Descrição: Referência rápida para usar os scripts de validação
# 
################################################################################

# Validação de Acessos - Referência Rápida

## ⚡ TL;DR (Use agora)

```bash
# Teste rápido (< 30 segundos)
bash scripts/validate-access.sh --quiet

# Teste com relatório JSON
python3 scripts/validate-access.py --format=json --output=report.json

# Teste com timeout maior (para redes lentas)
bash scripts/validate-access.sh --timeout=10
```

---

## 📋 Scripts Disponíveis

### Bash (`validate-access.sh`)
- ✅ Sem dependências externas
- ✅ Rápido e leve
- ✅ Relatórios TXT/JSON
- **Executar:** `bash scripts/validate-access.sh`

### Python (`validate-access.py`)
- ✅ Mais recursos (CSV, proxy, métricas detalhadas)
- ✅ Melhor formatação JSON
- **Executar:** `python3 scripts/validate-access.py`

---

## 🎯 Casos de Uso Comuns

### 1. Validar tudo (padrão)
```bash
bash scripts/validate-access.sh
```
**Saída:** Detalhado com cores, salva relatórios TXT e JSON

### 2. Validação silenciosa (CI/CD)
```bash
bash scripts/validate-access.sh --quiet
```
**Saída:** Apenas sumário
**Exit code:** 0 = OK, 1 = Falha

### 3. Exportar para JSON (programático)
```bash
python3 scripts/validate-access.py --format=json --output=report.json
```
**Saída:** `report.json` com timestamp, status, tempos

### 4. Exportar para CSV (planilha)
```bash
python3 scripts/validate-access.py --format=csv --output=report.csv
```
**Saída:** `report.csv` pronto para Excel/Sheets

### 5. Teste de conectividade (redes lentas)
```bash
bash scripts/validate-access.sh --timeout=15
```
**Nota:** Aumenta timeout de DNS/TCP/HTTPS

### 6. Apenas sumário, sem arquivos
```bash
bash scripts/validate-access.sh --quiet
echo $?  # 0 = sucesso, 1 = falha
```

---

## ✅ Checklist Rápido (Antes de Deploy)

```bash
#!/bin/bash
set -e

echo "🔍 Validando acessos do Projeto Aeroporto..."

# 1. Teste Bash
if ! bash scripts/validate-access.sh --quiet; then
    echo "❌ Validação falhou!"
    exit 1
fi

echo "✓ Todos os acessos OK - Projeto pronto para deploy!"
```

---

## 🔍 Interpretando Resultados

### Status Possíveis

| Símbolo | Significado | Ação |
|---------|------------|------|
| `✓` | Acesso OK | Nenhuma |
| `⚠` | TCP OK, HTTPS com aviso | Verificar certificado (geralmente OK) |
| `✗` | Falha (DNS/TCP) | Verifique firewall, DNS, conectividade |

### Exemplo de Saída

```
✓  Zabbix Repository (repo.zabbix.com:443)          → OK
⚠  Docker Registry (registry-1.docker.io:443)        → TCP OK, HTTPS aviso
✗  Custom Domain (custom.example.com:443)            → TCP FALHOU (bloqueado?)
```

---

## 🚨 Troubleshooting Rápido

### "curl: command not found"
```bash
apt-get install curl  # Ubuntu/Debian
dnf install curl      # RHEL/CentOS
```

### "nc: command not found"
```bash
apt-get install netcat-openbsd  # Ubuntu/Debian
dnf install nmap-ncat            # RHEL/CentOS
```

### "Connection refused"
- Firewall pode estar bloqueando
- Teste: `telnet dominio.com 443`
- Verifique liberar porta 443

### "Resolução DNS falhou"
- Teste: `nslookup dominio.com 8.8.8.8`
- Verifique `/etc/resolv.conf`
- Pode estar offline

### "HTTPS erro mas TCP OK"
- Certificado pode estar expirado/auto-assinado
- Teste: `openssl s_client -connect dominio.com:443`
- **Geralmente NÃO é bloqueio**, apenas aviso

---

## 📊 Saída JSON (estrutura)

```json
{
  "timestamp": "2024-10-23T17:45:30",
  "timeout": 5,
  "results": [
    {
      "component": "Zabbix Repository",
      "domain": "repo.zabbix.com",
      "port": 443,
      "status": "SUCCESS",
      "reason": "OK",
      "dns_time_ms": 12.34,
      "tcp_time_ms": 45.67,
      "https_time_ms": 78.90
    },
    ...
  ]
}
```

**Parseando em bash:**
```bash
cat report.json | grep -o '"status":"[^"]*"' | sort | uniq -c
```

**Parseando em Python:**
```python
import json
with open('report.json') as f:
    data = json.load(f)
    for r in data['results']:
        print(f"{r['domain']}: {r['status']}")
```

---

## 🔄 Automatizar Testes Periódicos

### Cron (diário às 8:00 AM)
```bash
0 8 * * * cd /path/to/aeroporto && bash scripts/validate-access.sh > /tmp/validate.log 2>&1
```

### GitHub Actions (scheduled)
```yaml
name: Validar Acessos
on:
  schedule:
    - cron: '0 8 * * *'  # Diariamente às 8:00 UTC

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: bash scripts/validate-access.sh --quiet
```

### GitLab CI (pipeline scheduled)
```yaml
validate:access:
  script:
    - bash scripts/validate-access.sh --quiet
  only:
    - schedules
```

---

## 📈 Monitoramento Contínuo

### Comparar antes/depois de firewall
```bash
# Antes
bash scripts/validate-access.sh > before.log 2>&1

# [Fazer alterações de firewall]

# Depois
bash scripts/validate-access.sh > after.log 2>&1
diff before.log after.log
```

### Alertar se falhar
```bash
if ! bash scripts/validate-access.sh --quiet; then
    # Enviar email, Slack, PagerDuty, etc
    curl -X POST https://hooks.slack.com/... -d "Acesso falhou!"
fi
```

---

## 🎓 Exemplos Práticos

### Validar antes de iniciar Zabbix
```bash
#!/bin/bash
if bash scripts/validate-access.sh --quiet; then
    systemctl start zabbix-server
else
    echo "❌ Acessos não validados!"
    exit 1
fi
```

### Relatório semanal
```bash
#!/bin/bash
date=$(date '+%Y-W%V')
python3 scripts/validate-access.py --format=csv \
    --output="reports/access-report-$date.csv"
```

### Health check para load balancer
```bash
#!/bin/bash
if bash scripts/validate-access.sh --quiet 2>/dev/null; then
    echo "OK"
    exit 0
else
    echo "FAIL"
    exit 1
fi
```

---

## 🔐 Notas de Segurança

- Scripts **não armazenam senhas** ou credenciais
- TLS verification desabilitada apenas para **validação de conectividade**
- Relatórios contêm apenas status, não dados sensíveis
- Seguro para rodar em CI/CD público

---

## 📞 Ajuda Rápida

```bash
# Ver ajuda
bash scripts/validate-access.sh --help
python3 scripts/validate-access.py --help

# Ver README completo
cat scripts/README.md

# Editar lista de domínios
nano scripts/validate-access.sh  # Buscar ACCESSES
nano scripts/validate-access.py  # Buscar ACCESSES
```

---

## 🎯 Sumário de Comandos

| Comando | Uso |
|---------|-----|
| `bash scripts/validate-access.sh` | Teste completo com relatório |
| `bash scripts/validate-access.sh --quiet` | Teste silencioso (CI/CD) |
| `python3 scripts/validate-access.py` | Teste com Python |
| `python3 scripts/validate-access.py --format=json` | Saída JSON |
| `python3 scripts/validate-access.py --format=csv` | Saída CSV |
| `cat access-validation-report.txt` | Ver último relatório |
| `cat access-validation-report.json` | Ver último JSON |

---

**Versão:** 1.0.0  
**Última atualização:** 23/10/2024  
**Projeto:** Aeroporto
