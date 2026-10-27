# Plano de Refatoração - Projeto Aeroporto HA

## 📋 Visão Geral da Refatoração

Este documento descreve a refatoração dos scripts de instalação e automação para suportar a arquitetura de **Alta Disponibilidade (HA)** do Projeto Aeroporto.

**Data:** 24/10/2026  
**Versão:** 2.0 (HA)  
**Status:** Planejado

---

## 🎯 Objetivos da Refatoração

### Fase 1: PostgreSQL HA
- ✅ Configurar pg-01 como Primary com Streaming Replication
- ✅ Configurar pg-02 como Standby/Replica
- ✅ Implementar failover automático
- ✅ Monitorar lag de replicação
- **Impacto:** Scripts: `01-postgresql-primary.sh`, `01-postgresql-standby.sh`

### Fase 2: Zabbix Server HA
- ✅ Instalar zbx-server-01 e zbx-server-02 em cluster
- ✅ Configurar Shared Database (PostgreSQL)
- ✅ Sincronizar configurações entre nodes
- ✅ Load Balancing via VIP
- **Impacto:** Scripts: `02-zabbix-server-ha.sh`

### Fase 3: Grafana HA
- ✅ Instalar grafana-01 e grafana-02 em cluster
- ✅ Backend: PostgreSQL (pg-01)
- ✅ Sessões: Persistent (banco de dados)
- ✅ Load Balancing via VIP
- **Impacto:** Scripts: `05-grafana-ha.sh`

### Fase 4: AWX HA
- ✅ Instalar awx-01 e awx-02 em cluster
- ✅ Backend: PostgreSQL (pg-01) + Docker Compose
- ✅ Executores distribuídos
- ✅ Load Balancing via VIP
- **Impacto:** Scripts: `04-awx-ha.sh`

### Fase 5: VIP/Load Balancer
- ✅ Instalar HAProxy em vip-01 e vip-02
- ✅ Instalar Keepalived para failover
- ✅ Health checks automáticos
- ✅ Sincronização de estado
- **Impacto:** Scripts: `06-vip-haproxy-keepalived.sh`

---

## 📁 Estrutura de Scripts Refatorados

```
scripts/automated-install/
├── phase-2-ha/                           # NOVO - Scripts HA
│   ├── 01-postgresql-primary.sh          # Primary com replication
│   ├── 01-postgresql-standby.sh          # Standby com recovery
│   ├── 02-zabbix-server-ha.sh            # Zabbix cluster
│   ├── 03-zabbix-frontend-ha.sh          # Frontend via VIP
│   ├── 04-awx-ha.sh                      # AWX cluster
│   ├── 05-grafana-ha.sh                  # Grafana cluster
│   ├── 06-vip-haproxy-keepalived.sh      # Load balancer HA
│   │
│   ├── ha-sync/                          # Scripts de sincronização
│   │   ├── sync-postgres-replication.sh
│   │   ├── sync-zabbix-cluster.sh
│   │   ├── sync-grafana-cluster.sh
│   │   ├── sync-awx-cluster.sh
│   │   └── sync-vip-state.sh
│   │
│   ├── ha-validate/                      # Scripts de validação
│   │   ├── validate-postgres-sync.sh
│   │   ├── validate-zabbix-cluster.sh
│   │   ├── validate-grafana-cluster.sh
│   │   ├── validate-awx-cluster.sh
│   │   └─ validate-vip-failover.sh
│   │
│   ├── ha-failover/                      # Scripts de failover
│   │   ├── promote-postgres-replica.sh
│   │   ├── failover-vip.sh
│   │   └─ restore-ha-state.sh
│   │
│   └── docs/
│       ├── HA_ARCHITECTURE.md
│       ├── POSTGRESQL_HA.md
│       ├── ZABBIX_HA.md
│       ├── GRAFANA_HA.md
│       ├── AWX_HA.md
│       ├── VIP_HAPROXY.md
│       └─ FAILOVER_PROCEDURES.md

├── phase-1/                              # MANTIDO - Scripts original
│   ├── 01-postgresql.sh                  # (pode ser descontinuado)
│   ├── 02-zabbix-server.sh
│   ├── 03-zabbix-frontend.sh
│   ├── 04-awx-installer.sh
│   └─ 05-grafana-installer.sh
```

---

## 🔄 Mudanças nos Inventários Ansible

### Novos Grupos

```yaml
# ANTES (Fase 1)
all:
  children:
    cameras
    access_control
    gates
    uvss
    infrastructure

# DEPOIS (Fase 2 - HA)
all:
  children:
    cameras
    access_control
    gates
    uvss
    postgresql_cluster:
      children:
        postgresql_primary      # pg-01
        postgresql_standby      # pg-02
    zabbix_cluster:
      children:
        zabbix_server_nodes     # zbx-server-01, zbx-server-02
        zabbix_frontend_nodes   # Via VIP
    grafana_cluster             # grafana-01, grafana-02
    awx_cluster                 # awx-01, awx-02
    vip_nodes                   # vip-01, vip-02
```

---

## 🔧 Componentes HA Detalhados

### PostgreSQL HA

**Componentes:**
- Primary: pg-01 (10.31.38.64)
- Standby: pg-02 (10.31.38.65)
- Método: Streaming Replication com WAL
- Failover: Automático via promove script

**Configuração:**
```bash
# pg-01 (Primary)
max_wal_senders = 10
wal_keep_size = 1GB
wal_level = replica

# pg-02 (Standby)
recovery_target_timeline = 'latest'
restore_command = 'cp /var/lib/postgresql/wal_archive/%f %p'
```

---

### Zabbix Server HA

**Componentes:**
- Node 1: zbx-server-01 (10.31.38.60)
- Node 2: zbx-server-02 (10.31.38.61)
- Backend: PostgreSQL (pg-01 - HA)
- Frontend: Via VIP (10.31.38.70)

**Sincronização:**
- DB compartilhado (ambos acessam pg-01)
- Configurações: Uma cópia (master-master não suportado)
- Coletores: Independentes em cada node

---

### Grafana HA

**Componentes:**
- Node 1: grafana-01 (10.31.38.66)
- Node 2: grafana-02 (10.31.38.67)
- Backend: PostgreSQL (pg-01 - HA)
- Sessions: Persistent (BD)

**Sincronização:**
- Automática via banco de dados
- Dashboards: Sincronizados
- Alertas: Sincronizados
- Usuários: Sincronizados

---

### AWX HA

**Componentes:**
- Node 1: awx-01 (10.31.38.68)
- Node 2: awx-02 (10.31.38.69)
- Backend: PostgreSQL (pg-01 - HA)
- Redis: Local (ou cluster mode)

**Sincronização:**
- Docker Compose: Configuração idêntica
- Base de dados: Compartilhada
- Executores: Distribuídos
- Configurações: Via ansible_user automático

---

### VIP/HAProxy/Keepalived

**Componentes:**
- Master: vip-01 (10.31.38.70)
- Backup: vip-02 (10.31.38.71)
- VIP: 10.31.38.70 (atributo floating)

**Health Checks:**
- Zabbix Frontend: TCP:80 + HTTP GET /health
- Grafana: TCP:3000 + HTTP GET /health
- AWX: TCP:8080 + HTTP GET /health

**Failover:**
- Tempo: < 5 segundos
- Automático
- Script: keepalived com notify

---

## 📊 Matriz de Compatibilidade Refatorada

| Serviço | Fase 1 | Fase 2 | Compatibilidade |
|---------|--------|--------|-----------------|
| PostgreSQL | Single | HA Replication | Upgrade inline ✅ |
| Zabbix Server | Single | Cluster (Shared DB) | Nova instalação |
| Zabbix Frontend | Single | Via VIP | Nova instalação |
| Grafana | Single | Cluster (Shared DB) | Upgrade inline ✅ |
| AWX | Single | Cluster (Shared DB) | Upgrade com Docker |
| Load Balancer | N/A | HAProxy + Keepalived | Nova instalação |

---

## ⚠️ Considerações de Migração

### De Fase 1 → Fase 2

**PostgreSQL:**
- ✅ Backup antes de tudo
- ✅ pg_basebackup para pg-02
- ✅ Configurar streaming replication
- ⚠️ RTO: ~30 minutos | RPO: ~5 minutos

**Zabbix Server:**
- ⚠️ Requer nova instalação em zbx-server-02
- ✅ Configuração pode ser importada
- ⚠️ RTO: ~1 hora | RPO: ~1 minuto

**Grafana:**
- ✅ Pode ser upgradado (Shared DB)
- ✅ Instalação de grafana-02 paralela
- ⚠️ RTO: ~30 minutos | RPO: ~1 minuto

**AWX:**
- ⚠️ Requer nova instalação em awx-02
- ✅ Configurações migram via DB
- ⚠️ RTO: ~1 hora | RPO: ~5 minutos

**VIP/LB:**
- ✅ Nova instalação (não interfere com Fase 1)
- ✅ Pode ser configurado antes
- ⚠️ RTO: ~10 minutos

---

## 🎯 Ordem de Implementação Recomendada

1. **Semana 1 - PostgreSQL HA**
   - Backup pg-01
   - Instalar pg-02
   - Configurar replication
   - Validar sincronização

2. **Semana 2 - VIP/LB**
   - Instalar HAProxy em vip-01, vip-02
   - Configurar Keepalived
   - Testar failover

3. **Semana 3 - Zabbix HA**
   - Instalar zbx-server-02
   - Configurar cluster
   - Migrar frontend para VIP

4. **Semana 4 - Grafana HA**
   - Instalar grafana-02
   - Configurar Shared DB
   - Migrar para VIP

5. **Semana 5 - AWX HA**
   - Instalar awx-02
   - Configurar Docker Sync
   - Testar cluster

6. **Semana 6 - Validação e Testes**
   - Testes de failover completos
   - Testes de carga
   - Documentação final

---

## 📈 Impacto Esperado

### Disponibilidade

| Métrica | Fase 1 | Fase 2 | Ganho |
|---------|--------|--------|-------|
| Disponibilidade | 99% | 99.99% | +0.99% |
| RTO (Recovery Time Objective) | N/A | < 5s (VIP failover) | Automático |
| RPO (Recovery Point Objective) | N/A | < 1s (replication) | Mínimo |
| MTBF (Mean Time Between Failures) | N/A | Aumenta em ~100x | Maior confiabilidade |

### Performance

| Métrica | Impacto |
|---------|---------|
| Latência Zabbix | +5-10ms (Shared DB) |
| Latência Grafana | +2-5ms (Shared DB) |
| Latência AWX | +10-20ms (Docker sync) |
| Latência Frontend | -50ms (Load Balancer) |

---

## 🔐 Segurança HA

### Replication Segment

```bash
# pg_hba.conf
host    replication     replication     10.31.38.65/32      md5
```

### HAProxy Configuration

```bash
# ACL rules
acl allowed_hosts src 10.31.38.0/24
http-request deny if !allowed_hosts
```

### Keepalived VRRP

```bash
# Authentication
authentication {
    auth_type PASS
    auth_pass aeroporto-ha-2026
}
```

---

## 📚 Documentação a Criar

1. **HA_ARCHITECTURE.md** - Diagrama e visão geral
2. **POSTGRESQL_HA.md** - Setup e troubleshooting
3. **ZABBIX_HA.md** - Cluster setup
4. **GRAFANA_HA.md** - Cluster setup
5. **AWX_HA.md** - Cluster setup
6. **VIP_HAPROXY.md** - Load balancer config
7. **FAILOVER_PROCEDURES.md** - Procedimentos de failover
8. **MIGRATION_GUIDE.md** - Guia de migração Fase 1 → Fase 2

---

## ✅ Checklist de Implementação

- [ ] PostgreSQL HA instalado e validado
- [ ] VIP/LB instalado e validado
- [ ] Zabbix Server HA instalado e validado
- [ ] Grafana HA instalado e validado
- [ ] AWX HA instalado e validado
- [ ] Testes de failover executados
- [ ] Testes de carga executados
- [ ] Documentação finalizada
- [ ] Equipe treinada
- [ ] Produção atualizada

---

**Próximos passos:**
1. Criar scripts de instalação PostgreSQL HA
2. Criar scripts de instalação VIP/LB
3. Atualizar inventários Ansible
4. Atualizar playbooks AWX
5. Criar scripts de validação HA

---

**Versão:** 2.0 (HA)  
**Data:** 24/10/2026  
**Status:** Pronto para Implementação
