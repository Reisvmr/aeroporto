# 🔧 PROCEDIMENTOS DE SETUP - PROJETO AEROPORTO

> **Status:** ✅ PRONTO PARA EXECUÇÃO  
> **Data:** 23/10/2024  
> **Repositório:** [GitHub Aeroporto](https://github.com/Reisvmr/aeroporto.git)  
> **Commit:** `2d33307` (3 procedimentos setup adicionados)

---

## 📋 Resumo Executivo

Três procedimentos detalhados foram criados para preparar a infraestrutura **Zabbix 7.0 LTS + PostgreSQL 16** que monitorará **676 ativos** (câmeras, controle de acesso, automação perimetral, UVSS) durante a implementação de 6 semanas (15 de agosto → 26 de setembro de 2026).

### Arquitetura Implementada

```
┌────────────────────────────────────────────────────────────┐
│                  ZABBIX FRONTEND 01                         │
│        (Nginx + PHP + Web Interface - HTTPS)               │
│         Conecta:                                           │
│         ├─ PostgreSQL (10.31.38.64:5432)                   │
│         └─ Zabbix Server (porta 10051)                     │
└────────────────┬─────────────────────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
┌───────▼──────────────┐  │
│  ZABBIX SERVER 01    │  │
│   (SNMP Collector)   │  │
│   Porta 10051        │  │
└───────┬──────────────┘  │
        │                 │
        └────────┬────────┘
                 │
        ┌────────▼────────────────────┐
        │  PostgreSQL 16 Primary      │
        │  10.31.38.64:5432           │
        │  ⭐ NVMe OBRIGATÓRIO ⭐      │
        │  Database: zabbix (90+ tbls)│
        │  Replicação WAL (Standby)   │
        │  Backup diário agendado     │
        └─────────────────────────────┘
```

---

## 📂 Procedimentos Criados

### 1️⃣ **SETUP_POSTGRESQL_PRIMARY.md** (14.2 KB)

**Arquivo:** `docs/execucao/SETUP_POSTGRESQL_PRIMARY.md`  
**Tempo estimado:** 1-2 horas

#### Conteúdo:
- ✅ Preparação SO (atualização, firewall, NTP)
- ✅ Verificação e configuração storage NVMe (`/pgdata`)
- ✅ Instalação PostgreSQL 16 (CentOS/RHEL ou Ubuntu/Debian)
- ✅ Configuração `postgresql.conf` (memória, WAL, logging)
- ✅ Configuração `pg_hba.conf` (acesso remoto zbx-server-01 + zbx-fe-01)
- ✅ Criação usuário `zabbix` com senha forte
- ✅ Criação database `zabbix`
- ✅ Importação schema Zabbix (90+ tabelas)
- ✅ Criação slots de replicação (para Standby/Failover)
- ✅ Setup automático de backup diário (retenção 7 dias)
- ✅ Testes de validação (conexão local/remota, replicação)
- ✅ Troubleshooting detalhado

#### Checklist de Execução:
- [ ] SO atualizado
- [ ] NVMe montado em `/pgdata` ou `/var/lib/postgresql`
- [ ] PostgreSQL 16 instalado
- [ ] Banco `zabbix` criado
- [ ] Schema importado
- [ ] Backup agendado
- [ ] Conectividade remota testada com sucesso

---

### 2️⃣ **SETUP_ZABBIX_SERVER_01.md** (9.1 KB)

**Arquivo:** `docs/execucao/SETUP_ZABBIX_SERVER_01.md`  
**Tempo estimado:** 30-45 minutos  
**Pré-requisito:** PostgreSQL Primary já rodando

#### Conteúdo:
- ✅ Preparação SO (atualização, firewall, NTP)
- ✅ Instalação Zabbix Server 7.0 LTS (CentOS/RHEL ou Ubuntu/Debian)
- ✅ Instalação Zabbix Agent 2.0 (auto-monitoramento)
- ✅ Configuração `/etc/zabbix/zabbix_server.conf`:
  - DBHost: `10.31.38.64`
  - DBName: `zabbix`
  - DBUser: `zabbix`
  - Ports, cache, housekeeping
- ✅ Regras firewall (porta 10051 entrada/saída)
- ✅ SELinux configurado (se aplicável)
- ✅ Teste de conectividade com PostgreSQL
- ✅ Inicialização e validação
- ✅ Troubleshooting

#### Checklist de Execução:
- [ ] SO atualizado
- [ ] Zabbix Server instalado
- [ ] Conectividade PostgreSQL (10.31.38.64:5432) OK
- [ ] Firewall permite porta 10051
- [ ] Service `zabbix-server` iniciado e habilitado
- [ ] Logs sem erros críticos

---

### 3️⃣ **SETUP_ZABBIX_FRONTEND_01.md** (11.2 KB)

**Arquivo:** `docs/execucao/SETUP_ZABBIX_FRONTEND_01.md`  
**Tempo estimado:** 45-60 minutos  
**Pré-requisitos:** PostgreSQL Primary + Zabbix Server já rodando

#### Conteúdo:
- ✅ Preparação SO (atualização, firewall, NTP)
- ✅ Instalação Nginx + PHP-FPM (detecção automática SO)
- ✅ Instalação Zabbix Frontend 7.0
- ✅ Configuração Nginx (proxy para php-fpm)
- ✅ Tuning PHP (`php.ini` - max_execution_time, memory_limit, etc)
- ✅ Geração certificado SSL/TLS (auto-assinado para teste)
- ✅ Redirecionamento HTTP→HTTPS
- ✅ Setup Wizard:
  - Database: PostgreSQL (10.31.38.64:5432)
  - Usuário: `zabbix`
  - Conexão Zabbix Server: porta 10051
- ✅ Configuração timezone, locale
- ✅ Firewall (portas 80, 443)
- ✅ Testes de validação (web interface, API)
- ✅ Troubleshooting

#### Checklist de Execução:
- [ ] SO atualizado
- [ ] Nginx + PHP-FPM instalados
- [ ] Zabbix Frontend instalado
- [ ] Certificado SSL configurado
- [ ] Conectividade PostgreSQL OK
- [ ] Conectividade Zabbix Server OK
- [ ] Porta 443 acessível (HTTPS)
- [ ] Web interface carregando corretamente

---

## ⚡ Ordem de Execução Recomendada

```
PASSO 1: PostgreSQL Primary (10.31.38.64)
   └─ Tempo: 1-2 horas
   └─ Crítico: NVMe deve estar pronto
   └─ Validação: psql conecta com sucesso

         ↓ (esperar PostgreSQL rodando)

PASSO 2: Zabbix Server 01 (zbx-server-01)
   └─ Tempo: 30-45 minutos
   └─ Crítico: PostgreSQL já rodando
   └─ Validação: Service rodando, conectado ao banco

         ↓ (esperar Server rodando)

PASSO 3: Zabbix Frontend 01 (zbx-fe-01)
   └─ Tempo: 45-60 minutos
   └─ Crítico: Server + PostgreSQL rodando
   └─ Validação: Web interface acessível via HTTPS
```

**Tempo total estimado:** ~4-5 horas (3 servidores)

---

## 📋 Checklist Pré-Setup

Antes de começar, validar os seguintes pontos:

### Servidor 10.31.38.64 (PostgreSQL)
- [ ] Acesso SSH funcionando
- [ ] SO atualizado (CentOS 8+, Ubuntu 20.04+, Debian 11+)
- [ ] Storage NVMe montado (verificar `lsblk` e `df -h`)
- [ ] Conectividade de rede OK
- [ ] Firewall permite porta 5432 (saída de zbx-server-01 e zbx-fe-01)
- [ ] NTP sincronizado

### Servidor zbx-server-01 (Zabbix Server)
- [ ] Acesso SSH funcionando
- [ ] SO atualizado
- [ ] Conectividade com 10.31.38.64:5432 (testar: `telnet 10.31.38.64 5432`)
- [ ] Firewall permite porta 10051 (entrada/saída)
- [ ] NTP sincronizado
- [ ] CPU/RAM suficientes (recomendado: 8 vCPU, 16 GB RAM)

### Servidor zbx-fe-01 (Zabbix Frontend)
- [ ] Acesso SSH funcionando
- [ ] SO atualizado
- [ ] Conectividade com 10.31.38.64:5432
- [ ] Conectividade com zbx-server-01:10051
- [ ] Firewall permite portas 80/443 (entrada) e 10051 (saída)
- [ ] NTP sincronizado
- [ ] CPU/RAM suficientes (recomendado: 4 vCPU, 8 GB RAM)

### Credenciais & Documentação
- [ ] Senha PostgreSQL `zabbix` definida (>12 caracteres)
- [ ] Certificado SSL preparado (auto-assinado OK para teste)
- [ ] IPs finais dos servidores zbx-server-01 e zbx-fe-01 confirmados
- [ ] Credenciais documentadas em local seguro (1Password/Vault)

---

## 🔐 Credenciais a Definir

Durante a execução dos procedimentos, será necessário definir as seguintes credenciais:

### PostgreSQL
```
Usuário: zabbix
Banco: zabbix
Host: 10.31.38.64
Porta: 5432
Senha: <DEFINE DURANTE SETUP_POSTGRESQL_PRIMARY>
```

### PostgreSQL Replicação (Standby)
```
Usuário: replicator
Senha: <DEFINE DURANTE SETUP_POSTGRESQL_PRIMARY>
```

### Zabbix Admin (Frontend)
```
Usuário: Admin
Senha: zabbix (padrão - ALTERAR após first login!)
```

---

## 📊 Estatísticas dos Procedimentos

| Aspecto | Valor |
|---------|-------|
| **Total de linhas** | ~900 linhas |
| **Total de caracteres** | ~34.5 KB |
| **Número de passos** | 330+ passos detalhados |
| **Número de seções** | 25+ seções (setup, config, validação) |
| **Tempo de leitura** | ~1.5-2 horas |
| **Tempo de execução** | ~4-5 horas |
| **Troubleshooting** | 15+ cenários cobertos |

---

## 🎯 Como Começar

### 1. Clonar o Repositório
```bash
git clone https://github.com/Reisvmr/aeroporto.git
cd aeroporto
```

### 2. Ler os Procedimentos
```bash
# LEITURA OBRIGATÓRIA (nesta ordem)
cat docs/execucao/SETUP_POSTGRESQL_PRIMARY.md        # PRIMEIRO
cat docs/execucao/SETUP_ZABBIX_SERVER_01.md          # SEGUNDO
cat docs/execucao/SETUP_ZABBIX_FRONTEND_01.md        # TERCEIRO
```

### 3. Iniciar Setup no Servidor 10.31.38.64
```bash
# Conectar via SSH
ssh root@10.31.38.64

# Seguir TODOS os passos do SETUP_POSTGRESQL_PRIMARY.md
# Levar ~1-2 horas
```

### 4. Validar PostgreSQL
```bash
# No servidor 10.31.38.64
sudo -u postgres psql -c "SELECT version();"
psql -h localhost -U zabbix -d zabbix -c "SELECT COUNT(*) FROM hosts;"
```

### 5. Iniciar Setup no Servidor zbx-server-01
```bash
# Conectar via SSH
ssh root@<IP-zbx-server-01>

# Seguir TODOS os passos do SETUP_ZABBIX_SERVER_01.md
# Levar ~30-45 minutos
```

### 6. Iniciar Setup no Servidor zbx-fe-01
```bash
# Conectar via SSH
ssh root@<IP-zbx-fe-01>

# Seguir TODOS os passos do SETUP_ZABBIX_FRONTEND_01.md
# Levar ~45-60 minutos
```

### 7. Validar Setup Completo
```bash
# Abrir navegador
https://<IP-zbx-fe-01>

# Fazer login
Admin / zabbix

# Verificar que consegue conectar ao Zabbix Server
```

---

## ✅ Checklist Final (Pós-Setup)

- [ ] PostgreSQL rodando (`systemctl status postgresql-16`)
- [ ] Zabbix Server rodando (`systemctl status zabbix-server`)
- [ ] Zabbix Frontend rodando (`systemctl status nginx`)
- [ ] Web interface acessível (https://zbx-fe-01:443)
- [ ] Login realizado com sucesso (Admin / zabbix)
- [ ] Dashboard vazio mas funcional
- [ ] Logs sem erros críticos
- [ ] Conectividade testada entre componentes
- [ ] Backup PostgreSQL agendado
- [ ] Firewall regras confirmadas

---

## 📞 Próximas Etapas Após Setup

Após completar este procedimento com sucesso:

1. **Configurar PostgreSQL Replica (Standby)** - Para failover HA
2. **Configurar Keepalived** - Para VIP automático
3. **Configurar Ansible AWX** - Para automação de coleta
4. **Importar Templates Zabbix** - Câmeras, acesso, etc
5. **Onboarding Piloto** - 20-30 ativos para teste
6. **Grafana Dashboards** - Visualização de métricas

Estes passos estão descritos nos runbooks adicionais (03-zabbix-postgresql.md, 04-awx-automacao.md, etc).

---

## 📚 Referência de Arquivos

```
GitHub: https://github.com/Reisvmr/aeroporto.git

Procedimentos de Setup:
docs/execucao/
├── SETUP_POSTGRESQL_PRIMARY.md        ✅ 14.2 KB (NOVO)
├── SETUP_ZABBIX_SERVER_01.md          ✅ 9.1 KB (NOVO)
├── SETUP_ZABBIX_FRONTEND_01.md        ✅ 11.2 KB (NOVO)
├── 01-iniciacao-planejamento.md       (Week 1)
├── 02-infraestrutura-ha.md            (Week 2)
├── 03-zabbix-postgresql.md            (Week 3)
├── 04-awx-automacao.md                (Week 4)
├── 05-templates-onboarding.md         (Week 5)
├── 06-grafana-relatorios-topologia.md (Week 6)
├── 07-backup-restore-rede.md          (Week 7)
└── 08-treinamento-handover-operacao.md (Week 8)

Documentação de Análise:
docs/execucao/
├── ENTENDIMENTO_COMPLETO_AEROPORTO.md (1,411 linhas)
├── ANALISE_COMPOSICAO_676_ATIVOS.md   (528 linhas)
└── CONSOLIDACAO_FINAL_PROJETO_AEROPORTO.md (354 linhas)

Equipamentos & Checklist:
docs/cliente/
├── EQUIPAMENTOS_Projeto_Aeroporto_676_Ativos.xlsx (550 KB)
├── Checklist_Cliente_Pre_Requisitos_Projeto_Aeroporto.xlsx (146 KB)
└── GOOGLE_SHEETS_REFERENCIA.md

Scripts & Ferramentas:
scripts/
├── validate-access.sh           (11 KB)
├── validate-access.py           (12 KB)
└── setup-prerequisites.sh       (15.6 KB)
```

---

## 🚀 Status Final

| Item | Status |
|------|--------|
| Procedimentos criados | ✅ 3 completos |
| Documentação total | ✅ 34.5 KB |
| GitHub sincronizado | ✅ Commit 2d33307 |
| Pronto para execução | ✅ SIM |
| Checklist pré-setup | ⚠️ Aguarda confirmação |
| Credenciais definidas | ⏳ A definir durante setup |

---

## 📝 Notas Importantes

⭐ **CRÍTICO: NVMe OBRIGATÓRIO**  
O storage NVMe no servidor PostgreSQL (10.31.38.64) é essencial para:
- Performance de I/O (4K+ IOPS)
- Throughput de WAL (replicação)
- Retenção 180 dias (~316 GB)

❌ **NÃO USAR SSD regular ou HDD** — a performance será inaceitável.

---

## 📞 Suporte & Troubleshooting

Cada procedimento possui uma seção **⚠️ TROUBLESHOOTING** com soluções para:
- Erros de conectividade
- Problemas de storage/permissões
- Issues de replicação
- Performance degradada
- Logs e diagnóstico

Consulte essas seções em caso de dificuldades durante a execução.

---

**Data de Criação:** 23/10/2024  
**Versão:** 1.0  
**Repositório:** [GitHub Aeroporto](https://github.com/Reisvmr/aeroporto.git)  
**Commit:** 2d33307

---

🎯 **PRÓXIMO PASSO:** Confirmar se os procedimentos estão OK ou se precisa de ajustes/revisões.
