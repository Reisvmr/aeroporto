# Setup Automático de Pré-Requisitos

## 📋 Visão Geral

O script `setup-prerequisites.sh` valida e instala automaticamente todas as dependências necessárias para executar os scripts de validação de acessos do Projeto Aeroporto.

## 🎯 Funcionalidades

### ✅ Validações Realizadas

1. **Bash** - Verifica se Bash 4.0+ está instalado
2. **Python3** - Verifica se Python 3.6+ está instalado
3. **curl** - Verifica se curl está disponível
4. **netcat (nc)** - Verifica se netcat está instalado
5. **nslookup/dig/getent** - Verifica ferramentas DNS
6. **DNS** - Testa resolução DNS (nslookup google.com)
7. **Internet** - Testa conectividade HTTPS (curl https://github.com)
8. **Scripts** - Verifica se scripts de validação existem
9. **Permissões** - Verifica se scripts são executáveis

### 🛠️ Instalações Automáticas

O script detecta seu SO e instala automaticamente:

```
Sistemas Suportados:
├── Linux
│   ├── Ubuntu / Debian
│   ├── CentOS / RHEL / Fedora
│   ├── Alpine
│   └── Arch / Manjaro
├── macOS
└── Windows (WSL2)
```

**Pacotes Instalados:**
- bash, python3, curl, netcat, dnsutils/bind-utils

## 🚀 Como Usar

### Modo Interativo (Padrão)

```bash
bash scripts/setup-prerequisites.sh
```

**Comportamento:**
- Valida cada pré-requisito
- Pergunta antes de instalar faltantes
- Exibe relatório detalhado
- Salva log em arquivo

### Modo Automático (Sem Perguntas)

```bash
bash scripts/setup-prerequisites.sh --auto
```

**Comportamento:**
- Instala automaticamente tudo que falta
- Sem confirmações do usuário
- Ideal para CI/CD e scripts

### Apenas Verificação

```bash
bash scripts/setup-prerequisites.sh --check-only
```

**Comportamento:**
- Apenas valida, não instala nada
- Útil para auditoria
- Mostra status de cada item

### Validar Sem Instalar

```bash
bash scripts/setup-prerequisites.sh --skip-install
```

**Comportamento:**
- Valida tudo
- Não tenta instalar
- Mostra o que está faltando

## 📊 Saída Esperada

### Status Geral

```
✓ Bash: GNU bash, version 5.2.21(1)-release
✓ Python3: Python 3.10.6
✓ curl: curl 7.68.0
✓ netcat (nc): Instalado
✓ nslookup: Instalado
✓ DNS: Funcionando
✓ Internet: HTTPS funcionando
✓ Scripts: Encontrados
✓ Permissões: Scripts executáveis

✓ Todos os pré-requisitos estão OK!
```

### Resumo

```
Total verificado:    9
Passou:              9
Falhou:              0
Instalados:          0
```

## 🔍 Detalhes de Cada Verificação

### Bash
```bash
Verifica: Bash 4.0+
Comando: bash --version
Saída: GNU bash, version X.X.X
```

### Python3
```bash
Verifica: Python 3.6+
Comando: python3 --version
Saída: Python X.X.X
```

### curl
```bash
Verifica: curl instalado
Comando: curl --version
Saída: curl X.X.X
```

### netcat (nc)
```bash
Verifica: netcat disponível
Comando: command -v nc
Alternativa: bash /dev/tcp (built-in)
```

### nslookup / dig / getent
```bash
Verifica: Ferramentas DNS
Comandos: nslookup, dig, ou getent
```

### DNS
```bash
Verifica: DNS funcionando
Teste: nslookup google.com 8.8.8.8
Esperado: Retorna IP (ex: 142.250.78.206)
```

### Internet
```bash
Verifica: Conectividade HTTPS
Teste: curl https://github.com
Esperado: HTTP 200 ou redirecionamento
```

### Scripts
```bash
Verifica: Arquivos existem
Caminho: scripts/validate-access.sh
         scripts/validate-access.py
```

### Permissões
```bash
Verifica: Scripts executáveis
Teste: [ -x scripts/validate-access.sh ]
Fix: chmod +x scripts/*.sh
```

## 🐧 Instalação por SO

### Ubuntu/Debian

O script executa:
```bash
apt-get update
apt-get install -y bash python3 curl netcat-openbsd dnsutils
```

### CentOS/RHEL/Fedora

O script executa:
```bash
dnf install -y bash python3 curl nmap-ncat bind-utils
```

### Alpine

O script executa:
```bash
apk add bash python3 curl netcat-openbsd bind-tools
```

### macOS

O script executa:
```bash
brew install bash python3 curl netcat bind
```

### Windows (WSL2)

Use Ubuntu/Debian dentro do WSL:
```bash
apt-get update
apt-get install -y bash python3 curl netcat-openbsd dnsutils
```

## 📝 Relatório de Log

Cada execução cria um arquivo de log:

```
setup-prerequisites-1792792548.log
```

**Conteúdo do Log:**
- Timestamp de execução
- SO detectado
- Status de cada verificação
- Pacotes instalados
- Resumo final

**Ver log:**
```bash
cat setup-prerequisites-1792792548.log
```

## 🚨 Cenários de Erro

### "bash: sudo: command not found"

**Problema:** O script tenta usar `sudo` mas você não tem permissão

**Solução:**
```bash
# Opção 1: Use com sudo
sudo bash scripts/setup-prerequisites.sh --auto

# Opção 2: Instale manualmente
apt-get install -y curl netcat-openbsd dnsutils
```

### "Connection refused ou timeout"

**Problema:** Internet ou DNS não funcionando

**Teste manual:**
```bash
curl https://github.com
nslookup google.com 8.8.8.8
```

**Solução:**
- Verifique conexão de rede
- Verifique firewall
- Verifique DNS em `/etc/resolv.conf`

### "netcat: command not found"

**Problema:** netcat não foi instalado

**Solução (manual):**
```bash
# Ubuntu/Debian
sudo apt-get install netcat-openbsd

# CentOS/RHEL
sudo dnf install nmap-ncat

# macOS
brew install netcat
```

## ⏱️ Tempo de Execução

| Modo | Tempo Esperado |
|------|---|
| check-only | < 3 segundos |
| validate (sem instalar) | < 5 segundos |
| interactive | 10-30 segundos (depende de resposta) |
| auto (com instalação) | 30-120 segundos |

## 🔗 Integração com CI/CD

### GitHub Actions

```yaml
name: Setup

jobs:
  setup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: bash scripts/setup-prerequisites.sh --auto
      - run: bash scripts/validate-access.sh --quiet
```

### GitLab CI

```yaml
setup:
  script:
    - bash scripts/setup-prerequisites.sh --auto
    - bash scripts/validate-access.sh --quiet
```

### Antes de Deploy

```bash
#!/bin/bash
set -e

# Validar pré-requisitos
bash scripts/setup-prerequisites.sh --check-only

# Se passou, continuar
echo "Iniciando validação de acessos..."
bash scripts/validate-access.sh
```

## 📊 Estrutura do Código

### Detecção de SO

```bash
detect_os()
```
- Detecta: Linux (vários distros), macOS, Windows (WSL)
- Define: $OS_TYPE, $OS_VERSION

### Verificações

```bash
check_bash()         # Bash 4.0+
check_python3()      # Python 3.6+
check_curl()         # curl disponível
check_netcat()       # netcat/nc
check_nslookup()     # DNS tools
check_dns()          # DNS funcionando
check_internet()     # HTTPS funcionando
check_scripts_exist()     # Scripts presentes
check_scripts_executable() # Scripts executáveis
```

### Instalações

```bash
install_package()         # Interface genérica
install_package_linux()   # Detecta pkg manager
install_package_macos()   # Usa brew
```

## 🎓 Exemplos Práticos

### Exemplo 1: Setup Automático em Novo Sistema

```bash
$ bash scripts/setup-prerequisites.sh --auto

Setup de Pré-Requisitos - Projeto Aeroporto
...
→ Instalando Python3...
✓ Python3 instalado com sucesso
→ Instalando curl...
✓ curl instalado com sucesso
...
✓ Todos os pré-requisitos estão OK!
```

### Exemplo 2: Verificação em CI/CD

```bash
$ bash scripts/setup-prerequisites.sh --check-only

✓ Bash: GNU bash, version 5.2.21
✓ Python3: Python 3.10.6
✓ curl: curl 7.68.0
✓ netcat (nc): Instalado
✓ nslookup: Instalado
✓ DNS: Funcionando
✓ Internet: HTTPS funcionando
✓ Scripts: Encontrados
✓ Permissões: Scripts executáveis

✓ Todos os pré-requisitos estão OK!
```

### Exemplo 3: Troubleshooting

```bash
$ bash scripts/setup-prerequisites.sh

...
✗ curl não encontrado
? Deseja instalar curl? (s/n): s
→ Instalando curl...
✓ curl instalado com sucesso

...
✓ Todos os pré-requisitos estão OK!

Pode executar os scripts de validação:
  bash scripts/validate-access.sh
  python3 scripts/validate-access.py
```

## 📞 Troubleshooting

### O script não tem permissão de execução

```bash
chmod +x scripts/setup-prerequisites.sh
```

### Precisa de sudo mas não tem

```bash
# Execute com sudo
sudo bash scripts/setup-prerequisites.sh --auto

# OU

# Peça ao admin para instalar as dependências
```

### Quer ver logs detalhados

```bash
cat setup-prerequisites-*.log | tail -50
```

### Quer reexecutar sem fazer nada

```bash
bash scripts/setup-prerequisites.sh --check-only
```

## ✨ Resumo

| Feature | Status |
|---------|--------|
| Detecta SO | ✅ Linux, macOS, WSL2 |
| Instala automático | ✅ apt-get, dnf, yum, apk, brew |
| Valida pré-requisitos | ✅ 9 verificações |
| Log de auditoria | ✅ Arquivo + stdout |
| CI/CD ready | ✅ Modo --auto |
| Interativo | ✅ Pede confirmação |
| Mensagens claras | ✅ Cores + símbolos |

---

**Versão:** 1.0.0  
**Data:** 23/10/2024  
**Projeto:** Aeroporto - Validação de Acessos
