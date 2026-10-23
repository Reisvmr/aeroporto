# Scripts de Validação - Projeto Aeroporto

## Visão Geral

Este diretório contém scripts para validar a conectividade aos domínios críticos do Projeto Aeroporto.

Os scripts testam:
- **Resolução DNS** - Verifica se o domínio é resolvido
- **Conectividade TCP** - Verifica abertura da porta
- **Handshake HTTPS** - Verifica certificado e conectividade SSL/TLS

---

## Scripts Disponíveis

### 1. `validate-access.sh` (Bash)

Script em Bash puro, sem dependências externas além de ferramentas padrão.

#### Pré-requisitos
```bash
# Linux padrão já possui:
# - curl ou wget
# - nc (netcat) ou bash /dev/tcp
# - timeout

# Opcional (recomendado):
apt-get install curl netcat-openbsd  # Ubuntu/Debian
dnf install curl nmap-ncat            # RHEL/CentOS
brew install curl netcat              # macOS
```

#### Uso

**Execução padrão (verbose + relatório):**
```bash
./scripts/validate-access.sh
```

**Execução silenciosa:**
```bash
./scripts/validate-access.sh --quiet
```

**Com timeout customizado:**
```bash
./scripts/validate-access.sh --timeout=10
```

**Saída JSON:**
```bash
./scripts/validate-access.sh --output=json
```

**Combinado:**
```bash
./scripts/validate-access.sh --timeout=5 --output=json --quiet
```

#### Saída

Gera dois arquivos de relatório:
- `access-validation-report.txt` - Relatório em texto
- `access-validation-report.json` - Relatório em JSON

#### Exemplo de Saída

```
================================ VALIDAÇÃO DE ACESSOS ================================
Projeto: Aeroporto
Data/Hora: 2024-10-23 17:45:30
Timeout: 5s
========================================================================================

ℹ  Testando: Zabbix Repository (repo.zabbix.com:443)
✓  Zabbix Repository (repo.zabbix.com:443)
ℹ  Testando: Zabbix Website (www.zabbix.com:443)
✓  Zabbix Website (www.zabbix.com:443)
...

================================ RELATÓRIO DE RESULTADOS ================================

Total de acessos testados: 20
Sucessos: 20
Falhas: 0

✓ Todos os acessos foram validados com sucesso!
```

---

### 2. `validate-access.py` (Python)

Script em Python com suporte a múltiplos formatos de saída e relatórios detalhados.

#### Pré-requisitos

```bash
# Python 3.6+
python3 --version

# Apenas stdlib (sem dependências externas!)
# Já inclui: socket, ssl, json, csv, argparse
```

#### Uso

**Execução padrão:**
```bash
python3 scripts/validate-access.py
```

**Modo silencioso:**
```bash
python3 scripts/validate-access.py --quiet
```

**Exportar JSON:**
```bash
python3 scripts/validate-access.py --format=json --output=report.json
```

**Exportar CSV:**
```bash
python3 scripts/validate-access.py --format=csv --output=report.csv
```

**Com timeout customizado:**
```bash
python3 scripts/validate-access.py --timeout=10
```

**Suporte a proxy:**
```bash
python3 scripts/validate-access.py --proxy=http://proxy.example.com:8080
```

**Combinado:**
```bash
python3 scripts/validate-access.py --timeout=10 --format=json --output=report.json --quiet
```

#### Exemplo de Saída (JSON)

```json
{
  "timestamp": "2024-10-23T17:45:30.123456",
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

#### Exemplo de Saída (CSV)

```csv
Component,Domain,Port,Status,Reason,DNS Time (ms),TCP Time (ms),HTTPS Time (ms)
Zabbix Repository,repo.zabbix.com,443,SUCCESS,OK,12.34,45.67,78.90
Zabbix Website,www.zabbix.com,443,SUCCESS,OK,15.42,52.18,81.23
...
```

---

## Domínios Validados

| Componente | Domínio | Porta |
|---|---|---|
| Zabbix | repo.zabbix.com | 443 |
| Zabbix | www.zabbix.com | 443 |
| Grafana | rpm.grafana.com | 443 |
| Grafana | apt.grafana.com | 443 |
| Grafana | grafana.com | 443 |
| PostgreSQL | download.postgresql.org | 443 |
| GitHub | github.com | 443 |
| GitHub | api.github.com | 443 |
| GitHub | raw.githubusercontent.com | 443 |
| GitHub | objects.githubusercontent.com | 443 |
| GitHub | release-assets.githubusercontent.com | 443 |
| Quay.io | quay.io | 443 |
| Ansible Galaxy | galaxy.ansible.com | 443 |
| Docker Hub | auth.docker.io | 443 |
| Docker Hub | registry-1.docker.io | 443 |
| Kubernetes | registry.k8s.io | 443 |

**Total: 20 domínios**

---

## Testes Realizados

Para cada domínio, o script realiza:

### 1. **DNS Resolution**
- Testa se o domínio resolve para um IP
- Timeout: conforme configurado (padrão 5s)
- Falha = o domínio não foi encontrado

### 2. **TCP Connection**
- Testa conexão TCP à porta especificada (443)
- Timeout: conforme configurado
- Falha = porta bloqueada ou servidor down

### 3. **HTTPS Handshake**
- Testa SSL/TLS handshake
- Valida certificado (sem verificação de CA para simplicidade)
- Aviso = TCP OK mas HTTPS com erro

---

## Códigos de Saída

| Código | Significado |
|--------|------------|
| `0` | Sucesso - todos os acessos validados |
| `1` | Falha - um ou mais acessos falharam |

Exemplo:
```bash
./scripts/validate-access.sh
if [ $? -eq 0 ]; then
    echo "✓ Todos os acessos OK"
else
    echo "✗ Alguns acessos falharam"
fi
```

---

## Troubleshooting

### "Comando não encontrado: curl"
```bash
# Ubuntu/Debian
sudo apt-get install curl

# RHEL/CentOS
sudo dnf install curl

# macOS
brew install curl
```

### "nc: command not found"
```bash
# Ubuntu/Debian
sudo apt-get install netcat-openbsd

# RHEL/CentOS
sudo dnf install nmap-ncat

# macOS
brew install netcat
```

### "DNS falhou para domínio.com"
- Verifique conectividade de rede
- Teste manualmente: `nslookup dominio.com 8.8.8.8`
- Verifique resolvers em `/etc/resolv.conf`

### "Conexão TCP falhou"
- Verifique firewall: `sudo iptables -L` ou `sudo firewall-cmd --list-all`
- Teste manualmente: `telnet dominio.com 443`
- Verifique se há proxy no caminho

### "HTTPS falhou mas TCP OK"
- Certificado pode estar expirado ou inválido
- Pode ser certificado auto-assinado
- Teste manualmente: `openssl s_client -connect dominio.com:443`

---

## Integração com CI/CD

### GitHub Actions

```yaml
name: Validate Access

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Validate Aeroporto Access
        run: |
          bash scripts/validate-access.sh --quiet
          if [ $? -ne 0 ]; then
            echo "❌ Access validation failed"
            exit 1
          fi
          echo "✓ All accesses validated"
```

### GitLab CI

```yaml
validate:access:
  image: ubuntu:latest
  script:
    - apt-get update && apt-get install -y curl netcat-openbsd
    - bash scripts/validate-access.sh --quiet
  artifacts:
    paths:
      - access-validation-report.*
    expire_in: 30 days
```

---

## Notas de Segurança

### TLS Verification

Os scripts **desabilitam verificação de TLS** (`CERT_NONE`) para:
- Permitir testes com certificados auto-assinados
- Funcionar em ambientes de staging/desenvolvimento
- Focar apenas em conectividade, não em segurança

**Para uso em produção**, remover as linhas:
```python
context.check_hostname = False
context.verify_mode = ssl.CERT_NONE
```

E adicionar o CA da sua organização ao trust store.

### Logs

Os scripts não armazenam credenciais ou dados sensíveis. Os relatórios contêm apenas:
- Domínios testados
- Status de conectividade
- Tempos de resposta

---

## Métricas Coletadas

Ambos os scripts coletam:
- **Timestamp** - Data/hora de execução
- **Domínio** - FQDN testado
- **Porta** - Porta TCP
- **Status** - SUCCESS / WARNING / FAILED
- **Razão** - DNS / TCP Connection / HTTPS
- **Tempos** - DNS resolve, TCP connect, HTTPS handshake (em ms)

---

## Manutenção

### Adicionar Novo Domínio

**Bash:**
```bash
# Adicionar ao final de validate_all()
validate_access "Descrição do Componente" "novo.dominio.com" "443"
```

**Python:**
```python
# Adicionar à tupla ACCESSES
("Descrição do Componente", "novo.dominio.com", 443),
```

### Alterar Timeout Padrão

**Bash:**
```bash
TIMEOUT=10  # linha 14
```

**Python:**
```python
parser.add_argument('--timeout', type=int, default=10, ...)
```

---

## Performance

### Tempos Típicos

- DNS: 10-50ms
- TCP: 20-100ms
- HTTPS: 50-200ms
- **Total por domínio: 80-350ms**

Com 20 domínios: **1.6 - 7 segundos total**

### Otimizações

Executar em paralelo (para mais de 50 domínios):
```bash
# Bash paralelo
cat domains.txt | xargs -P 5 -I {} ./validate-access.sh --domain {}

# Python paralelo (requires ThreadPoolExecutor)
# Implementação futura
```

---

## Versioning

- **v1.0** - Release inicial
  - Suporte a 20 domínios principais
  - Bash + Python
  - Relatórios TXT, JSON, CSV

---

## Suporte

Para problemas ou sugestões:
1. Verifique a seção de Troubleshooting
2. Teste manualmente com `curl`, `nslookup`, `telnet`
3. Verifique logs de firewall/proxy
4. Consulte a equipe de Infraestrutura

---

**Última atualização:** 23/10/2024
**Versão:** 1.0.0
