# 📋 SCRIPTS DE INSTALAÇÃO - COMPLETAMENTE INTERATIVOS

**Status:** ✅ **TODOS OS SCRIPTS SÃO 100% INTERATIVOS**

---

## 🎯 AWX Installer (04-awx-installer.sh)

### 8 Perguntas Interativas (com padrões)

| # | Pergunta | Tipo | Padrão | Obrigatório |
|---|----------|------|--------|------------|
| 1 | Username administrador | `read` | admin | Não (usa padrão) |
| 2 | Senha administrador | `read -s` (oculta) | auto-gerada | Não |
| 3 | Host PostgreSQL | `read` | 10.31.38.64 | Não (usa padrão) |
| 4 | Porta PostgreSQL | `read` | 5432 | Não (usa padrão) |
| 5 | Database PostgreSQL | `read` | awx | Não (usa padrão) |
| 6 | Username PostgreSQL | `read` | awx | Não (usa padrão) |
| 7 | Senha PostgreSQL | `read -s` (oculta) | — | ✅ **SIM** |
| 8 | Hostname/FQDN | `read` | awx.example.com | Não (usa padrão) |

### Fluxo de Execução AWX

```bash
main() {
    check_prerequisites              # Valida pré-requisitos
    
    # ===== PERGUNTAS INTERATIVAS =====
    ask_admin_credentials           # Pergunta 1 + 2
    ask_postgres_credentials        # Perguntas 3-7
    ask_hostname                    # Pergunta 8
    
    # ===== EXECUÇÃO =====
    download_awx
    create_docker_compose_file
    start_awx_services
    validate_installation
    print_access_info
}
```

### Exemplo de Uso AWX

```bash
$ sudo bash 04-awx-installer.sh

════════════════════════════════════════════════════════════════
INSTALAÇÃO AWX 22.x - INICIADA
════════════════════════════════════════════════════════════════

════════════════════════════════════════════════════════════════
1. CREDENCIAIS ADMINISTRADOR AWX
════════════════════════════════════════════════════════════════
Digite as credenciais do administrador AWX:
(deixe em branco para usar padrão)

Username (padrão: admin): admin             ← USUÁRIO DIGITA
Password: ****                              ← SENHA OCULTA (read -s)

[INFO] Gerando senha aleatória...
[✓] Senha gerada: aBcD1234XyZ+

════════════════════════════════════════════════════════════════
2. CREDENCIAIS POSTGRESQL
════════════════════════════════════════════════════════════════
Configure acesso ao PostgreSQL:

Host (padrão: 10.31.38.64): 10.31.38.64    ← USUÁRIO DIGITA
Port (padrão: 5432): 5432                  ← USUÁRIO DIGITA
Database (padrão: awx): awx                ← USUÁRIO DIGITA
Username (padrão: awx): awx                ← USUÁRIO DIGITA
Password: ****                             ← SENHA OCULTA (obrigatória)

[✓] Credenciais PostgreSQL configuradas

════════════════════════════════════════════════════════════════
3. CONFIGURAÇÃO DE HOSTNAME
════════════════════════════════════════════════════════════════
Configure o hostname/FQDN para AWX:
(será usado para HTTPS e acesso web)

Hostname (padrão: awx.example.com): matos.reisvmr.com   ← USUÁRIO DIGITA

[✓] Hostname configurado: matos.reisvmr.com

════════════════════════════════════════════════════════════════
[INFO] Baixando AWX de: https://github.com/ansible/awx/archive/refs/tags/22.7.0.tar.gz
[✓] Download AWX
[✓] Extrair AWX
[✓] Arquivo docker-compose.yml criado
[✓] Iniciar contêineres
[INFO] Aguardando inicialização dos serviços (pode levar 2-3 minutos)...

════════════════════════════════════════════════════════════════
INFORMAÇÕES DE ACESSO AWX
════════════════════════════════════════════════════════════════

🎉 AWX INSTALADO COM SUCESSO!

Acesso:
  URL:      http://10.31.38.68:80
  HTTPS:    https://10.31.38.68:443
  Hostname: matos.reisvmr.com

Credenciais de Acesso:
  Username: admin
  Password: aBcD1234XyZ+

...
```

---

## 🎯 Grafana Installer (05-grafana-installer.sh)

### 10 Perguntas Interativas (com padrões)

| # | Pergunta | Tipo | Padrão | Obrigatório |
|---|----------|------|--------|------------|
| 1 | Username administrador | `read` | admin | Não (usa padrão) |
| 2 | Senha administrador | `read -s` (oculta) | auto-gerada | Não |
| 3 | Host PostgreSQL | `read` | 10.31.38.64 | Não (usa padrão) |
| 4 | Porta PostgreSQL | `read` | 5432 | Não (usa padrão) |
| 5 | Database PostgreSQL | `read` | grafana | Não (usa padrão) |
| 6 | Username PostgreSQL | `read` | grafana | Não (usa padrão) |
| 7 | Senha PostgreSQL | `read -s` (oculta) | — | ✅ **SIM** |
| 8 | Zabbix API URL | `read` | http://10.31.38.60/api_jsonrpc.php | Não (usa padrão) |
| 9 | Domain/FQDN | `read` | grafana.example.com | Não (usa padrão) |
| 10 | HTTP Port | `read` | 3000 | Não (usa padrão) |

### Fluxo de Execução Grafana

```bash
main() {
    check_prerequisites              # Valida pré-requisitos
    
    # ===== PERGUNTAS INTERATIVAS =====
    ask_admin_credentials           # Pergunta 1 + 2
    ask_postgres_credentials        # Perguntas 3-7
    ask_zabbix_integration          # Pergunta 8
    ask_domain                      # Perguntas 9-10
    
    # ===== EXECUÇÃO =====
    add_grafana_repository
    install_grafana
    configure_grafana
    install_grafana_plugins
    start_grafana_service
    create_postgres_user
    configure_zabbix_datasource
    validate_installation
    print_access_info
}
```

### Exemplo de Uso Grafana

```bash
$ sudo bash 05-grafana-installer.sh

════════════════════════════════════════════════════════════════
INSTALAÇÃO GRAFANA 10.x - INICIADA
════════════════════════════════════════════════════════════════

════════════════════════════════════════════════════════════════
1. CREDENCIAIS ADMINISTRADOR GRAFANA
════════════════════════════════════════════════════════════════
Digite as credenciais do administrador Grafana:

Username (padrão: admin): admin             ← USUÁRIO DIGITA
Password: ****                              ← SENHA OCULTA (read -s)

[INFO] Gerando senha aleatória...
[✓] Senha gerada: XyZ9876AbCd+

════════════════════════════════════════════════════════════════
2. CREDENCIAIS POSTGRESQL (BACKEND)
════════════════════════════════════════════════════════════════
Configure acesso ao PostgreSQL:

Host (padrão: 10.31.38.64): 10.31.38.64    ← USUÁRIO DIGITA
Port (padrão: 5432): 5432                  ← USUÁRIO DIGITA
Database (padrão: grafana): grafana        ← USUÁRIO DIGITA
Username (padrão: grafana): grafana        ← USUÁRIO DIGITA
Password: ****                             ← SENHA OCULTA (obrigatória)

[✓] Credenciais PostgreSQL configuradas

════════════════════════════════════════════════════════════════
3. INTEGRAÇÃO COM ZABBIX
════════════════════════════════════════════════════════════════
Configure integração com Zabbix:

Zabbix API URL (padrão: http://10.31.38.60/api_jsonrpc.php): 
                                            ← ENTER para usar padrão

[✓] Zabbix integração configurada

════════════════════════════════════════════════════════════════
4. CONFIGURAÇÃO DE DOMÍNIO
════════════════════════════════════════════════════════════════
Configure o domínio para Grafana:

Domain/FQDN (padrão: grafana.example.com): matos.reisvmr.com   ← USUÁRIO DIGITA
HTTP Port (padrão: 3000): 3000              ← USUÁRIO DIGITA

[✓] Domain e porta configurados

════════════════════════════════════════════════════════════════
[INFO] Adicionando repositório Grafana...
[✓] Repositório adicionado
[✓] Instalar Grafana
[✓] Arquivo grafana.ini configurado
[INFO] Instalando plugins...

════════════════════════════════════════════════════════════════
INFORMAÇÕES DE ACESSO GRAFANA
════════════════════════════════════════════════════════════════

🎉 GRAFANA INSTALADO COM SUCESSO!

Acesso:
  URL:      http://10.31.38.66:3000
  Domain:   matos.reisvmr.com
  Porta:    3000

Credenciais de Acesso:
  Username: admin
  Password: XyZ9876AbCd+

...
```

---

## 🎛️ Modos de Uso

### Modo 1: Totalmente Interativo (Recomendado)
```bash
sudo bash 04-awx-installer.sh
# Responde as 8 perguntas
```

### Modo 2: Não-Interativo (Automação)
```bash
export AWX_ADMIN_USER="admin"
export AWX_ADMIN_PASSWORD="SenhaSegura123!"
export POSTGRES_HOST="10.31.38.64"
export POSTGRES_PASSWORD="SenhaDB123!"
export INTERACTIVE="false"
bash 04-awx-installer.sh
```

### Modo 3: Híbrido (Alguns valores pré-configurados)
```bash
export AWX_ADMIN_USER="admin"
export INTERACTIVE="true"
bash 04-awx-installer.sh
# Pergunta apenas por senha e PostgreSQL
```

---

## 🔐 Segurança na Entrada de Dados

### Senhas Ocultas
```bash
read -s -p "Password: " input_pass
# ✅ Entrada não é visível na tela
# ✅ Protege contra "shoulder surfing"
```

### Geração Automática de Senhas
```bash
if [ -z "$input_pass" ]; then
    log_warn "Gerando senha aleatória..."
    password=$(openssl rand -base64 12)
    log_info "Senha gerada: $password"
fi
```

### Validação de Entrada Obrigatória
```bash
if [ -z "$input_pass" ]; then
    log_error "Senha do PostgreSQL é obrigatória!"
    return 1
fi
```

---

## 📋 Validação Pré-Requisitos

Antes de aceitar qualquer entrada, os scripts **validam**:

### AWX
- ✅ Docker instalado
- ✅ Docker Compose instalado
- ✅ Python 3 instalado
- ✅ Git instalado
- ✅ 150 GB de espaço em disco
- ✅ Docker daemon rodando

### Grafana
- ✅ Ubuntu detectado
- ✅ Conectividade com internet
- ✅ 50 GB de espaço em disco
- ✅ Mínimo 8 GB RAM

---

## 🎯 Fluxo Completo de Execução

### AWX (40-50 minutos)
```
Início
  ↓
[Pré-requisitos OK?] → ✅ SIM
  ↓
┌─────────────────────────────┐
│  PERGUNTAS INTERATIVAS      │
│ 1. Username admin           │
│ 2. Senha admin              │
│ 3. Host PostgreSQL          │
│ 4. Porta PostgreSQL         │
│ 5. Database                 │
│ 6. Username PostgreSQL      │
│ 7. Senha PostgreSQL (req)   │
│ 8. Hostname/FQDN            │
└─────────────────────────────┘
  ↓
[Senha PostgreSQL fornecida?] → ✅ SIM
  ↓
┌─────────────────────────────┐
│  INSTALAÇÃO AUTOMÁTICA      │
│ • Download AWX 22.x         │
│ • Criar docker-compose.yml  │
│ • Iniciar contêineres       │
│ • Validar instalação        │
│ • Exibir info acesso        │
└─────────────────────────────┘
  ↓
FIM (Sucesso)
```

### Grafana (20-30 minutos)
```
Início
  ↓
[Pré-requisitos OK?] → ✅ SIM
  ↓
┌─────────────────────────────┐
│  PERGUNTAS INTERATIVAS      │
│ 1. Username admin           │
│ 2. Senha admin              │
│ 3. Host PostgreSQL          │
│ 4. Porta PostgreSQL         │
│ 5. Database                 │
│ 6. Username PostgreSQL      │
│ 7. Senha PostgreSQL (req)   │
│ 8. Zabbix API URL           │
│ 9. Domain/FQDN              │
│ 10. HTTP Port               │
└─────────────────────────────┘
  ↓
[Senha PostgreSQL fornecida?] → ✅ SIM
  ↓
┌─────────────────────────────┐
│  INSTALAÇÃO AUTOMÁTICA      │
│ • Adicionar repositório     │
│ • Instalar Grafana          │
│ • Configurar grafana.ini    │
│ • Instalar plugins          │
│ • Iniciar serviço           │
│ • Validar instalação        │
│ • Exibir info acesso        │
└─────────────────────────────┘
  ↓
FIM (Sucesso)
```

---

## 📊 Resumo de Interatividade

| Aspecto | AWX | Grafana |
|---------|-----|---------|
| **Perguntas** | 8 | 10 |
| **Obrigatórias** | 1 (Senha PG) | 1 (Senha PG) |
| **Com padrões** | 7 | 9 |
| **Senhas ocultas** | ✅ Sim (read -s) | ✅ Sim (read -s) |
| **Auto-gerar senha** | ✅ Sim | ✅ Sim |
| **Modo não-interativo** | ✅ Sim (variáveis env) | ✅ Sim (variáveis env) |
| **Validação pré-req** | ✅ Sim | ✅ Sim |

---

## 💡 Exemplos Práticos

### Instalação Rápida AWX (todos padrões)
```bash
sudo bash 04-awx-installer.sh
# Apenas ENTER 7 vezes + senha PostgreSQL

Resultado:
  URL: http://10.31.38.68
  User: admin
  Pass: [auto-gerada]
```

### Instalação Customizada AWX
```bash
sudo bash 04-awx-installer.sh

Username (padrão: admin): meu_usuario       ← Customizado
Password: [auto-gera]
Host (padrão: 10.31.38.64): [ENTER]        ← Padrão
Port (padrão: 5432): [ENTER]               ← Padrão
Database (padrão: awx): [ENTER]            ← Padrão
Username (padrão: awx): [ENTER]            ← Padrão
Password: SenhaSegura123!                   ← Customizado
Hostname: matos.reisvmr.com                ← Customizado

Resultado:
  URL: http://10.31.38.68
  User: meu_usuario
  Pass: [auto-gerada]
  Hostname: matos.reisvmr.com
```

---

## ✅ Garantias de Interatividade

- [x] Cada pergunta usa `read` ou `read -s`
- [x] Cada pergunta tem padrão (exceto senhas obrigatórias)
- [x] Senhas são ocultas (read -s)
- [x] Senhas são auto-geradas se vazias
- [x] Validação de entrada obrigatória
- [x] Modo não-interativo com variáveis ENV
- [x] Pré-requisitos validados antes
- [x] Confirmação antes de instalar

---

**Status:** ✅ **100% INTERATIVO**

**Repositório:** https://github.com/Reisvmr/aeroporto.git
