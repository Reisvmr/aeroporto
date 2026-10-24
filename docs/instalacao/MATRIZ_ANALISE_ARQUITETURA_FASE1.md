# 📊 MATRIZ DE ANÁLISE - ARQUITETURA FASE 1

**Data:** 24/10/2026  
**Objetivo:** Análise completa antes de gerar scripts de instalação automatizada  
**Status:** PRÉ-EXECUÇÃO (Aprovação do usuário requerida)

---

## 🏗️ ARQUITETURA FASE 1 - SERVIDORES DISPONÍVEIS

### Matriz de Servidores

| # | Hostname | IP | Função | SO | CPU | RAM | Disco | Status | Acesso SSH |
|---|----------|----|----|----|----|-----|-------|--------|-----------|
| 1 | pg-01 (pg-primary-01) | 10.31.38.64 | PostgreSQL Primary | Ubuntu/CentOS | 20 vCPU | 96 GB | 800G-1TB NVMe | 🔴 Offline | ❌ Sem SSH |
| 2 | zbx-server-01 | 10.31.38.60 | Zabbix Server | Ubuntu/CentOS | 8 vCPU | 22 GB | 45 GB SSD | ✅ Online | ✅ Sim |
| 3 | zbx-fe-01 | 10.31.38.62 | Zabbix Frontend | Ubuntu/CentOS | 2 vCPU ⚠️ | 7 GB ⚠️ | 11 GB | ✅ Online | ✅ Sim |

---

## 🔗 DEPENDÊNCIAS E RELACIONAMENTOS

```
┌─────────────────────────────────────────────────────┐
│                    FASE 1 (Atual)                   │
├─────────────────────────────────────────────────────┤
│                                                     │
│  PostgreSQL 16                                      │
│  (10.31.38.64:5432)                                 │
│         ↑                    ↑                       │
│         └────────────────────┴─────────┐            │
│                                        │            │
│              Zabbix Server              │            │
│              (zbx-server-01:10051)      │            │
│              ↑                           │            │
│              │ TCP 10051                 │            │
│              │                           │            │
│          Zabbix Frontend                 │            │
│          (zbx-fe-01:80/443) ←────TCP 5432┴───────┘  │
│          ↑                              │            │
│          └─────────────────────────────┴──────→      │
│          (Internet/Users)                           │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Fluxo de Dependências

```
1️⃣  PostgreSQL 16 (PRIMEIRO)
    └─ Sem dependências externas
    └─ Provisiona banco de dados
    └─ Bloqueia: zbx-server, zbx-fe

2️⃣  Zabbix Server (SEGUNDO)
    ├─ Depende de: PostgreSQL 16
    └─ Bloqueia: zbx-fe

3️⃣  Zabbix Frontend (TERCEIRO)
    ├─ Depende de: PostgreSQL 16 + Zabbix Server
    └─ Nenhum bloqueador
```

**Ordem Obrigatória de Instalação:** PostgreSQL → Zabbix Server → Zabbix Frontend

---

## 📋 ANÁLISE POR SERVIDOR

### 1. PostgreSQL Primary (pg-01)

| Aspecto | Informação |
|---------|-----------|
| **Hostname** | pg-primary-01 (ou pg-01) |
| **IP** | 10.31.38.64 (fixo, obrigatório) |
| **Porta** | 5432 |
| **Versão** | PostgreSQL 16 |
| **SO** | Ubuntu 20.04+ / CentOS 8+ / Debian 11+ |
| **CPU** | 20 vCPU (conforme validação) |
| **RAM** | 96 GB (conforme validação) |
| **Disco** | 800GB-1TB **NVMe obrigatório** |
| **Usuários BD** | postgres (root), zabbix (app) |
| **Databases** | zabbix, awx (futuro), grafana (futuro) |
| **Status Atual** | 🔴 Sem SSH após reboot |
| **Ação Imediata** | Recuperação de infraestrutura |
| **Bloqueador** | SIM - afeta todo projeto |

**Pré-requisitos:**
- [x] Acesso SSH restaurado
- [x] NVMe montado em `/var/lib/postgresql` ou `/pgdata`
- [x] NTP sincronizado
- [x] Firewall porta 5432 aberta

**Serviços a Instalar:**
1. PostgreSQL 16 server + client + contrib
2. PostgreSQL development libraries
3. pgBackRest (backup/restore)
4. PostgreSQL monitoring tools

**Configurações Críticas:**
- PostgreSQL.conf (shared_buffers, effective_cache_size, work_mem, etc.)
- pg_hba.conf (ACL para zabbix, zbx-server, zbx-fe)
- SSL/TLS (certificados para conexão segura)
- Backup automation

---

### 2. Zabbix Server (zbx-server-01)

| Aspecto | Informação |
|---------|-----------|
| **Hostname** | zbx-server-01 |
| **IP** | 10.31.38.60 (validado em rede) |
| **Porta** | 10051 (agent), 10050 (listener) |
| **Versão** | Zabbix 7.0 LTS |
| **SO** | Ubuntu 20.04+ / CentOS 8+ / Debian 11+ |
| **CPU** | 8 vCPU (mínimo atendido) |
| **RAM** | 22 GB (> 16 GB recomendado) ✅ |
| **Disco** | 45 GB livres (> 100 GB recomendado) ⚠️ |
| **BD Remota** | PostgreSQL 10.31.38.64:5432 |
| **Status Atual** | ✅ Online, SSH funcional |
| **Ação Imediata** | Preparação + aguardar PostgreSQL |
| **Bloqueador** | Depende de PostgreSQL |

**Pré-requisitos:**
- [x] PostgreSQL remoto acessível (TCP 5432)
- [x] NTP sincronizado (crítico para Zabbix)
- [x] Firewall porta 10051 aberta
- [x] /etc/hosts com pg-01 e zbx-fe-01
- [x] DNS resolvendo entre servidores

**Serviços a Instalar:**
1. Zabbix Server 7.0 LTS (oficial repository)
2. Zabbix Agent 2 (auto-monitoramento)
3. PostgreSQL client (libpq)
4. Perl XML (para custom scripts)

**Configurações Críticas:**
- zabbix_server.conf (DB, pollers, cache, etc.)
- Auto-discovery de hosts
- Template de monitoramento (676 ativos)
- Alerting e notificações

---

### 3. Zabbix Frontend (zbx-fe-01)

| Aspecto | Informação |
|---------|-----------|
| **Hostname** | zbx-fe-01 |
| **IP** | 10.31.38.62 (validado em rede) |
| **Portas** | 80 (HTTP), 443 (HTTPS) |
| **Versão** | Zabbix 7.0 LTS |
| **SO** | Ubuntu 20.04+ / CentOS 8+ / Debian 11+ |
| **CPU** | 2 vCPU ❌ **Insuficiente** (mín: 4) |
| **RAM** | 7 GB ⚠️ (mín: 8 GB recomendado) |
| **Disco** | 11 GB livres (mín: 50 GB) ⚠️ |
| **BD Remota** | PostgreSQL 10.31.38.64:5432 |
| **Server Remoto** | Zabbix Server zbx-server-01:10051 |
| **Status Atual** | ✅ Online, SSH funcional |
| **Ação Imediata** | **Upgrade CPU/RAM obrigatório** |
| **Bloqueador** | Depende de PostgreSQL + Zabbix Server |

**Pré-requisitos:**
- [x] **Upgrade CPU: 2→4 vCPU (CRÍTICO)** ⚠️
- [x] **Upgrade RAM: 7→8+ GB (CRÍTICO)** ⚠️
- [x] PostgreSQL remoto acessível (TCP 5432)
- [x] Zabbix Server remoto acessível (TCP 10051)
- [x] Firewall portas 80/443 abertas
- [x] /etc/hosts configurado
- [x] NTP sincronizado

**Serviços a Instalar:**
1. Nginx web server (ou Apache)
2. PHP-FPM (8.1+) com módulos específicos
3. Zabbix Frontend (PHP)
4. PostgreSQL client
5. SSL/TLS support

**Configurações Críticas:**
- nginx.conf (performance, SSL/TLS)
- php-fpm.conf (workers, memory, timeout)
- zabbix/api.conf (API authentication)
- HTTPS com certificado válido

---

## 🔴 PROBLEMAS IDENTIFICADOS E MITIGAÇÕES

### Problema 1: PostgreSQL Offline (🔴 CRÍTICO)

| Aspecto | Informação |
|---------|-----------|
| **Problema** | Servidor perdeu SSH após reboot |
| **Impacto** | Bloqueia TODA a infraestrutura |
| **Causa Provável** | DHCP não atribuiu IP, SSH não iniciou |
| **Solução** | Recuperação de infraestrutura (IPMI/Console) |
| **Mitigação** | Plano emergencial criado (PLANO_ACAO_EMERGENCIAL_POSTGRESQL.md) |
| **Timeline** | Desconhecido - Depende de infraestrutura |
| **Script de Instalação** | Aguarda servidor online |

---

### Problema 2: Zabbix Frontend - CPU Insuficiente (🟡 CRÍTICO)

| Aspecto | Informação |
|---------|-----------|
| **Problema** | 2 vCPU (mínimo especificado: 4) |
| **Impacto** | Frontend funcionará, mas muito lento |
| **Causa** | Infra provisionou incorreto |
| **Solução** | Upgrade CPU 2→4 vCPU |
| **Timeline** | 30min-2h (contatar virtualização) |
| **Ação Requerida** | Paralelo com recuperação PostgreSQL |
| **Script de Instalação** | Espera upgrade antes de começar |

---

### Problema 3: Zabbix Frontend - RAM Baixa (🟡 CRÍTICO)

| Aspecto | Informação |
|---------|-----------|
| **Problema** | 7 GB (mínimo: 8 GB, recomendado: 16+ GB) |
| **Impacto** | Performance limitada com 676 ativos |
| **Solução** | Upgrade RAM 7→8+ GB |
| **Timeline** | 30min-2h |
| **Ação Requerida** | Paralelo com upgrade CPU |
| **Script de Instalação** | Continua, mas com aviso |

---

### Problema 4: Firewall (6 domínios TCP 443 bloqueados)

| Aspecto | Informação |
|---------|-----------|
| **Problema** | repo.zabbix.com, grafana.com, etc. bloqueados |
| **Impacto** | Impossibilita download de pacotes durante instalação |
| **Solução** | Solicitar liberação ao firewall |
| **Mitigação** | Scripts incluem validação de conectividade |
| **Timeline** | 4-24h |
| **Ação Requerida** | Solicitação formal criada |
| **Script de Instalação** | Valida conectividade antes, para ou continua |

---

### Problema 5: NVMe não detectado em PostgreSQL

| Aspecto | Informação |
|---------|-----------|
| **Problema** | Disco NVMe não aparece (apenas SDA) |
| **Impacto** | PostgreSQL em SSD degradado (performance) |
| **Soluções** | 3 opções documentadas |
| **Timeline** | 5-30 min (procurar) ou 4-48h (solicitar) |
| **Mitigação** | VALIDACAO_DISCO_PG01.md com 3 opções |
| **Script de Instalação** | Valida storage antes de começar |

---

## 📊 RESUMO TÉCNICO

### Fase 1: Arquitetura Simples (Sem HA)

```
Internet
    ↓ HTTPS (80/443)
    ↓
[Zabbix Frontend - zbx-fe-01]
    ├─ Nginx + PHP-FPM
    ├─ Zabbix Web UI
    └─ API REST
        ↓ TCP 5432 (SQL)
        ↓ TCP 10051 (API)
        ↓
    [PostgreSQL Primary - pg-01]
    └─ Base de dados zabbix
        
    [Zabbix Server - zbx-server-01]
    ├─ Processing
    ├─ Alerting
    └─ API
        ↓ TCP 5432 (SQL)
        ↓
    [PostgreSQL Primary - pg-01]
    └─ Base de dados zabbix
```

### Serviços por Servidor

| Servidor | Serviços |
|----------|----------|
| **pg-01** | PostgreSQL 16, pgBackRest, pg_stat_statements |
| **zbx-server-01** | Zabbix Server 7.0, Zabbix Agent 2 |
| **zbx-fe-01** | Nginx, PHP-FPM 8.1, Zabbix Frontend 7.0 |

---

## 🚀 PLANO DE GERAÇÃO DE SCRIPTS

### Estrutura Proposta

```
scripts/
├── automated-install/
│   ├── 01-postgresql.sh          (pg-01)
│   ├── 02-zabbix-server.sh       (zbx-server-01)
│   ├── 03-zabbix-frontend.sh     (zbx-fe-01)
│   ├── common/
│   │   ├── functions.sh          (funções compartilhadas)
│   │   ├── prerequisites.sh      (validações pré-install)
│   │   └── constants.sh          (variáveis configuráveis)
│   ├── validate/
│   │   ├── validate-postgresql.sh
│   │   ├── validate-server.sh
│   │   └── validate-frontend.sh
│   └── config/
│       ├── environment.example
│       ├── postgresql.conf.template
│       ├── zabbix_server.conf.template
│       └── nginx.conf.template
├── docs/
│   ├── INSTALACAO_FASE1.md
│   ├── VALIDACAO_FASE1.md
│   ├── TROUBLESHOOTING.md
│   └── MIGRACAO_PARA_HA.md
└── README.md
```

### Scripts a Gerar

| # | Script | Tipo | Função | Tempo Est. |
|---|--------|------|--------|-----------|
| 1 | `01-postgresql.sh` | Install | PostgreSQL 16 + configuração | 30-45 min |
| 2 | `02-zabbix-server.sh` | Install | Zabbix Server 7.0 | 20-30 min |
| 3 | `03-zabbix-frontend.sh` | Install | Nginx + PHP + Zabbix Frontend | 25-35 min |
| 4 | `validate-*.sh` (3x) | Validate | Pós-instalação validação | 5-10 min |
| 5 | `prerequisites.sh` | Check | Validação pré-requisitos | 5 min |
| 6 | `functions.sh` | Lib | Funções compartilhadas | - |
| 7 | `environment.example` | Config | Template de variáveis | - |
| 8 | `INSTALACAO_FASE1.md` | Docs | Guia step-by-step | - |

**Total de Scripts:** 8 (3 de instalação, 3 de validação, 2 de libs)

---

## ⚠️ INFORMAÇÕES PENDENTES

Estas informações NÃO estão na documentação e serão **variáveis configuráveis**:

| Informação | Valor Padrão | Nota |
|-----------|----------|------|
| Senha PostgreSQL zabbix | ❌ NENHUMA (será solicitada) | Crítico - não hardcodear |
| Timezone | UTC | Configurável em environment |
| NTP Server | pool.ntp.org | Configurável |
| Backup Path | /backups/postgresql | Configurável |
| Zabbix API User | admin | Pode ser customizado |
| Frontend FQDN | zbx.example.com | Variável - usar certificado |
| Email SMTP | ❌ NÃO DEFINIDO | Será configurado post-install |
| Alerting contacts | ❌ NÃO DEFINIDO | Será configurado post-install |
| Histórico retenção | Padrão Zabbix (30 dias) | Configurável |
| Monitoramento de 676 ativos | ❌ NÃO INCLUSO | Templates criados after install |

---

## ✅ CHECKLIST PRÉ-EXECUÇÃO

Antes de gerar scripts, confirme:

- [ ] PostgreSQL será recuperado (aguardando infraestrutura)
- [ ] Zabbix Server tem acesso SSH confirmado
- [ ] Zabbix Frontend será upgraded (CPU 2→4, RAM 7→8)
- [ ] Firewall será solicitado para liberar 6 domínios críticos
- [ ] NVMe será resolvido em PostgreSQL (opção 1, 2 ou 3)
- [ ] Senhas serão definidas em tempo de execução (não hardcodadas)
- [ ] Certificados SSL serão obtidos externamente
- [ ] Backup strategy será definida pós-install
- [ ] Nenhuma alteração destrutiva será feita sem confirmação
- [ ] Scripts serão idempotentes (reutilizáveis)

---

## 🎯 PRÓXIMO PASSO

**Aprovação do Usuário Requerida:**

1. Confirma análise da matriz?
2. Concorda com estrutura de scripts proposta?
3. Autoriza geração de 3 scripts de instalação automatizada?
4. Ordena de prioridade:
   - [ ] PostgreSQL (aguarda online)
   - [ ] Zabbix Server (pode começar agora, espera PG)
   - [ ] Zabbix Frontend (aguarda upgrade CPU/RAM)

---

**Documento:** MATRIZ_ANALISE_ARQUITETURA_FASE1.md  
**Versão:** 1.0  
**Gerado:** 24/10/2026  
**Status:** 🔴 AWAITING USER APPROVAL
