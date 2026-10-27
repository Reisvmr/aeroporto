# Projeto Aeroporto - Monitoramento HA & Automação

Repositório para centralizar documentos, cronogramas, scripts, runbooks e artefatos do projeto de implantação da solução de monitoramento e automação para **676 ativos** com **arquitetura em alta disponibilidade (HA)**.

---

## 🎯 Objetivo

Implantar uma plataforma completa de monitoramento e automação baseada em:
- **Zabbix 7.0 LTS** - Monitoramento em cluster HA (2 nodes)
- **PostgreSQL 16** - Banco de dados em replicação streaming (Primary/Standby)
- **Grafana 10.x** - Visualização em cluster HA (2 nodes)
- **Ansible AWX 22.x** - Automação em cluster HA (2 nodes) com Docker
- **HAProxy + Keepalived** - Load balancing com failover automático <5s
- **Retenção de dados:** 180 dias
- **Volume estimado:** ~316 GB úteis

---

## 📦 Estrutura do Repositório

```
aeroporto/
├── README.md (este arquivo)
├── PLANO_REFATORACAO_HA.md               ← Estratégia Phase 2 HA
├── README_HA_ANALISE.md                  ← Análise técnica detalhada
│
├── docs/
│   ├── cliente/                          ← Checklists e pré-requisitos
│   ├── cronogramas/                      ← Gantt, WBS, RACI
│   ├── execucao/                         ← Runbooks passo a passo
│   ├── propostas/                        ← Propostas e planos
│   └── referencias/                      ← Materiais técnicos
│
├── scripts/automated-install/
│   ├── phase-2-ha/                       ← ⭐ FASE 2 HA (NOVA)
│   │   ├── 00-prerequisitos-validacao.sh (462 linhas) - Validação
│   │   ├── 01-postgresql-primary.sh      (356 linhas) - DB Primary
│   │   ├── 01-postgresql-standby.sh      (359 linhas) - DB Standby
│   │   ├── 02-zabbix-server-ha.sh        (443 linhas) - Zabbix HA 🆕
│   │   ├── 04-awx-ha.sh                  (477 linhas) - AWX HA 🆕
│   │   ├── 05-grafana-ha.sh              (380 linhas) - Grafana HA 🆕
│   │   ├── 06-vip-haproxy-keepalived.sh  (494 linhas) - Load Balancer
│   │   ├── README.md                     (358 linhas) - Guia de uso
│   │   └── INICIO-RAPIDO.sh              (199 linhas) - Helper
│   │
│   └── phase-1-standalone/               ← Fase 1 (obsoleto, manter para ref)
│       └── (scripts antigos)
│
├── awx_automacoes/
│   └── inventories/
│       ├── postgresql_ha.yml             ← PostgreSQL Primary + Standby
│       ├── zabbix_ha.yml                 ← Zabbix 2 nodes
│       ├── grafana_ha.yml                ← Grafana 2 nodes
│       ├── awx_ha.yml                    ← AWX 2 nodes
│       └── vip_lb_ha.yml                 ← VIP + Load Balancer
│
├── zabbix_templates/                    ← Templates Zabbix
├── grafana_dashboards/                  ← Dashboards Grafana
└── awx_playbooks/                       ← Playbooks Ansible
```

---

## 🏗️ Arquitetura Phase 2 HA (10 Servidores)

```
CAMADA 1: ARMAZENAMENTO HA
├── PostgreSQL Primary    (pg-01 / 10.31.38.64)
├── PostgreSQL Standby    (pg-02 / 10.31.38.65)
└── Replicação: Streaming WAL + Failover automático

CAMADA 2: MONITORAMENTO HA
├── Zabbix Server 1       (zbx-server-01 / 10.31.38.60)
├── Zabbix Server 2       (zbx-server-02 / 10.31.38.61)
├── Shared DB: PostgreSQL HA
├── Frontend: Via VIP (10.31.38.70:10051)
└── 676 dispositivos monitorados

CAMADA 3: VISUALIZAÇÃO HA
├── Grafana 1             (grafana-01 / 10.31.38.66)
├── Grafana 2             (grafana-02 / 10.31.38.67)
├── Shared DB: PostgreSQL HA
├── Sessions: PostgreSQL
└── Frontend: Via VIP (10.31.38.70:3000)

CAMADA 4: AUTOMAÇÃO HA
├── AWX 1                 (awx-01 / 10.31.38.68)
├── AWX 2                 (awx-02 / 10.31.38.69)
├── Shared DB: PostgreSQL HA
├── Docker Compose (Postgres + Redis + AWX)
└── Frontend: Via VIP (10.31.38.70:8080)

CAMADA 5: LOAD BALANCER HA
├── VIP Master            (vip-01 / 10.31.38.70)
├── VIP Backup            (vip-02 / 10.31.38.71)
├── HAProxy 2.x
├── Keepalived VRRP
└── Failover: <5s automático
```

---

## 📚 Documentação Principal

### Phase 2 HA (NOVA - 27/10/2026)

**Planejamento Estratégico:**
- [`PLANO_REFATORACAO_HA.md`](./PLANO_REFATORACAO_HA.md) - Estratégia completa (399 linhas)
  - 3 fases de refatoração
  - 6 semanas de timeline
  - 6 camadas de impacto
  - Matriz de decisões técnicas

**Análise Técnica:**
- [`README_HA_ANALISE.md`](./README_HA_ANALISE.md) - Análise detalhada
  - Arquitetura HA completa
  - Configurações por componente
  - Fluxos de failover
  - Estimativas de capacidade

**Scripts de Instalação:**
- [`scripts/automated-install/phase-2-ha/README.md`](./scripts/automated-install/phase-2-ha/README.md) - Guia completo
  - Como usar cada script
  - Ordem de execução
  - Validações esperadas
  - Troubleshooting

### Documentação Original (Fase 1)

- `docs/propostas/` - Propostas originais
- `docs/cronogramas/` - Cronogramas Gantt
- `docs/execucao/` - Runbooks originais
- `docs/referencias/` - Materiais técnicos

---

## 🚀 Como Usar - Phase 2 HA

### Pré-requisitos
- Ubuntu 20.04 ou 22.04 LTS
- Servidores zerados (fresh install)
- 10 VMs conforme especificação acima
- Conectividade entre servers
- Acesso root/sudo

### Ordem de Instalação (Semanas 1-5)

**SEMANA 0: Validação de Pré-requisitos**
```bash
cd scripts/automated-install/phase-2-ha/
sudo chmod +x *.sh
sudo ./00-prerequisitos-validacao.sh
```

**SEMANA 1: PostgreSQL HA**
```bash
# Em pg-01 (10.31.38.64)
ssh root@10.31.38.64
sudo ./01-postgresql-primary.sh

# Em pg-02 (10.31.38.65)
ssh root@10.31.38.65
sudo ./01-postgresql-standby.sh
```

**SEMANA 2: VIP / Load Balancer**
```bash
# Em vip-01 (10.31.38.70) - Master
ssh root@10.31.38.70
sudo ./06-vip-haproxy-keepalived.sh master

# Em vip-02 (10.31.38.71) - Backup
ssh root@10.31.38.71
sudo ./06-vip-haproxy-keepalived.sh backup
```

**SEMANA 3: Zabbix Server HA**
```bash
# Em zbx-server-01 (10.31.38.60)
ssh root@10.31.38.60
sudo ./02-zabbix-server-ha.sh node1

# Em zbx-server-02 (10.31.38.61)
ssh root@10.31.38.61
sudo ./02-zabbix-server-ha.sh node2
```

**SEMANA 4: Grafana HA**
```bash
# Em grafana-01 (10.31.38.66)
ssh root@10.31.38.66
sudo ./05-grafana-ha.sh node1

# Em grafana-02 (10.31.38.67)
ssh root@10.31.38.67
sudo ./05-grafana-ha.sh node2
```

**SEMANA 5: AWX HA**
```bash
# Em awx-01 (10.31.38.68)
ssh root@10.31.38.68
sudo ./04-awx-ha.sh node1

# Em awx-02 (10.31.38.69)
ssh root@10.31.38.69
sudo ./04-awx-ha.sh node2
```

### Guia Rápido
Veja [`scripts/automated-install/phase-2-ha/INICIO-RAPIDO.sh`](./scripts/automated-install/phase-2-ha/INICIO-RAPIDO.sh) para comandos prontos.

---

## 📊 Estatísticas Phase 2 HA

| Item | Valor |
|------|-------|
| **Scripts de instalação** | 7 (validação + 6 componentes) |
| **Total de linhas** | 3.169 linhas de bash |
| **Tamanho total** | 108 KB de scripts + 30 KB de docs |
| **Servidores suportados** | 10 VMs |
| **Commits GitHub** | 2 commits (a0d7568, 3762ab7) |
| **Data conclusão** | 27/10/2026 |
| **Semanas cobertas** | 0-5 (6 opcional) |

---

## ✨ Características Principais - Phase 2 HA

### ✅ Alta Disponibilidade Completa
- **PostgreSQL:** Streaming replication + failover automático
- **Zabbix:** Cluster 2 nodes com shared database
- **Grafana:** Cluster 2 nodes com session persistence
- **AWX:** Cluster 2 nodes com executor distribuído
- **VIP:** Failover automático <5s via Keepalived

### ✅ Automação Total
- Scripts parametrizados (node1/node2)
- Sem credenciais hardcoded
- Health checks em cada componente
- Sincronização automática de config
- Firewall pré-configurado

### ✅ Monitoramento de Escala
- **676 dispositivos** simultâneos
- **180 dias** de retenção de dados
- **~316 GB** de storage estimado
- **Múltiplas** datasources (SNMP, API, etc)

### ✅ Operação Resiliente
- Failover automático <5s
- Dados persistem em PostgreSQL HA
- Sessions sobrevivem reinicios
- Sincronização cross-node
- Logs centralizados

---

## 🔗 Acessos VIP (Após Instalação)

| Serviço | URL | Port | Credenciais |
|---------|-----|------|-------------|
| **Zabbix Frontend** | http://10.31.38.70:10051 | 10051 | Admin / (defina) |
| **Grafana** | http://10.31.38.70:3000 | 3000 | admin / (defina) |
| **AWX** | http://10.31.38.70:8080 | 8080 | admin / (defina) |
| **PostgreSQL** | 10.31.38.64:5432 | 5432 | awx / (defina) |

---

## 📋 Scripts Disponíveis

### Phase 2 HA (Atual - FUNCIONAL)

| Script | Linhas | Função | Status |
|--------|--------|--------|--------|
| `00-prerequisitos-validacao.sh` | 462 | Validação de pré-requisitos | ✅ |
| `01-postgresql-primary.sh` | 356 | PostgreSQL Primary | ✅ |
| `01-postgresql-standby.sh` | 359 | PostgreSQL Standby | ✅ |
| `02-zabbix-server-ha.sh` | 443 | Zabbix Server HA | ✅ |
| `04-awx-ha.sh` | 477 | AWX HA | ✅ |
| `05-grafana-ha.sh` | 380 | Grafana HA | ✅ |
| `06-vip-haproxy-keepalived.sh` | 494 | Load Balancer HA | ✅ |

### Phase 1 Standalone (Obsoleto - Referência)
Mantidos em `scripts/automated-install/phase-1-standalone/` para referência histórica.

---

## 🔐 Segurança & Credenciais

⚠️ **IMPORTANTE:**
- Nenhum script contém credenciais hardcoded
- Todas as senhas são parametrizáveis via:
  - Variáveis de ambiente
  - Argumentos de script
  - Arquivos `.env` locais
- Usar 1Password ou gerenciador de segredos para credenciais reais
- Mudar senhas padrão (admin) imediatamente após primeira login

---

## 📞 Suporte & Contribuições

### Problemas?
1. Verifique os logs em `/tmp/awx-ha-install-*.log` (cada script gera log)
2. Leia [`scripts/automated-install/phase-2-ha/README.md`](./scripts/automated-install/phase-2-ha/README.md)
3. Consulte [`PLANO_REFATORACAO_HA.md`](./PLANO_REFATORACAO_HA.md) para decisões técnicas
4. Abra uma issue no repositório

### Contribuições
- Pull requests são bem-vindos
- Mantenha o padrão de scripts (bash com validações)
- Documente mudanças significativas
- Teste em servidor zerado antes de submeter

---

## 📅 Histórico de Releases

### Phase 2 HA (v2.0) - 27/10/2026
- ✅ 7 scripts de instalação
- ✅ 5 inventários Ansible HA
- ✅ Documentação estratégica
- ✅ 3.169 linhas de código bash
- **Status:** Pronto para implementação (Semanas 1-5)

### Phase 1 Standalone (v1.x) - Anterior
- Descontinuado em favor de Phase 2 HA
- Manter apenas para referência histórica

---

## 📖 Referências Rápidas

**Documentação:**
- [`PLANO_REFATORACAO_HA.md`](./PLANO_REFATORACAO_HA.md) - Estratégia Phase 2
- [`README_HA_ANALISE.md`](./README_HA_ANALISE.md) - Análise técnica
- [`scripts/automated-install/phase-2-ha/README.md`](./scripts/automated-install/phase-2-ha/README.md) - Guia scripts
- [`scripts/automated-install/phase-2-ha/INICIO-RAPIDO.sh`](./scripts/automated-install/phase-2-ha/INICIO-RAPIDO.sh) - Comandos prontos

**Inventários:**
- `awx_automacoes/inventories/postgresql_ha.yml` - PostgreSQL
- `awx_automacoes/inventories/zabbix_ha.yml` - Zabbix
- `awx_automacoes/inventories/grafana_ha.yml` - Grafana
- `awx_automacoes/inventories/awx_ha.yml` - AWX

---

## 🎉 Status

✅ **Phase 2 HA: 100% CONCLUÍDA**
- Planejamento estratégico ✅
- Análise arquitetura ✅
- Scripts Semana 0 ✅
- Scripts Semana 1 ✅
- Scripts Semana 2 ✅
- Scripts Semana 3 ✅
- Scripts Semana 4 ✅
- Scripts Semana 5 ✅
- Documentação ✅
- GitHub sincronizado ✅

**Próximas ações:**
- Semana 6: Testes de failover (scripts opcionais)
- Semana 7+: Testes de carga e validação

---

**Repositório:** https://github.com/Reisvmr/aeroporto.git  
**Última atualização:** 27/10/2026  
**Versão:** Phase 2 HA v2.0  
**Autor:** Vinicius Reis <reisvmr@gmail.com>

---

## 📝 Licença

Todos os scripts são fornecidos AS-IS para uso interno no Projeto Aeroporto.
