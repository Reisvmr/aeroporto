# 🐘 TUTORIAL — PostgreSQL 16 Primary
> **Script:** `01-postgresql-primary.sh`  
> **Objetivo:** Instalar e configurar PostgreSQL 16 Primary com Streaming Replication  
> **Servidor:** pg-01 — IP: `10.31.38.64`  
> **Uso:** `sudo ./01-postgresql-primary.sh`

---

## 📋 Pré-requisitos

- Ubuntu/Debian atualizado  
- Mínimo 50 GB em `/var`  
- IP estático configurado: `10.31.38.64`  
- pg-02 (`10.31.38.65`) acessível na rede  

---

## 🔧 Variáveis — defina antes de executar

```bash
export POSTGRES_PASS="SUA_SENHA_POSTGRES_AQUI"    # Senha do superusuário postgres
export REPLICATION_PASS="SUA_SENHA_REPL_AQUI"     # Senha do usuário de replicação
```

> ⚠️ Padrões dos scripts: `postgres123` / `repl123` — **trocar em produção!**

---

## ETAPA 1 — Verificação de pré-requisitos

```bash
# Verificar se é root
id

# Verificar IP
hostname -I | awk '{print $1}'   # Deve retornar: 10.31.38.64

# Verificar espaço em /var
df -BG /var | awk 'NR==2{print $4}'   # Deve ser >= 50G
```

✅ **Verificação:** IP deve ser `10.31.38.64`, espaço >= 50GB

---

## ETAPA 2 — Atualização do sistema

```bash
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
```

---

## ETAPA 3 — Instalação do PostgreSQL 16

```bash
# Adicionar repositório oficial PostgreSQL
sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget -q -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

# Atualizar cache
apt-get update

# Instalar PostgreSQL 16
DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql-16 postgresql-contrib-16
```

✅ **Verificação:** `psql --version`

---

## ETAPA 4 — Configuração de replicação

### 4.1 — Parar PostgreSQL

```bash
systemctl stop postgresql
```

### 4.2 — Criar usuário de replicação

```bash
sudo -u postgres psql <<EOF
CREATE USER replication WITH REPLICATION ENCRYPTED PASSWORD '${REPLICATION_PASS:-repl123}';
EOF
```

### 4.3 — Backup do postgresql.conf original

```bash
PG_CONFIG="/etc/postgresql/16/main"
cp "$PG_CONFIG/postgresql.conf" "$PG_CONFIG/postgresql.conf.backup"
```

### 4.4 — Adicionar configurações de replicação ao postgresql.conf

```bash
cat >> /etc/postgresql/16/main/postgresql.conf << 'EOF'

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURAÇÕES DE REPLICAÇÃO (Phase 2 HA)
# ═══════════════════════════════════════════════════════════════════════════

wal_level = replica
max_wal_senders = 10
max_replication_slots = 10
wal_keep_segments = 64
hot_standby = on
hot_standby_feedback = on

# Performance
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 16MB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB

# Logging
log_connections = on
log_disconnections = on
log_lock_waits = on
log_statement = 'all'
log_replication_commands = on

# Sincronização
synchronous_commit = remote_apply
EOF
```

### 4.5 — Backup e configuração do pg_hba.conf

```bash
cp /etc/postgresql/16/main/pg_hba.conf /etc/postgresql/16/main/pg_hba.conf.backup

# Adicionar acesso de replicação para pg-02
cat >> /etc/postgresql/16/main/pg_hba.conf << EOF

# Replicação de pg-02 (10.31.38.65)
host    replication     replication    10.31.38.65/32    md5

# Acesso das aplicações
host    all             all            10.31.38.60/32    md5
host    all             all            10.31.38.61/32    md5
host    all             all            10.31.38.66/32    md5
host    all             all            10.31.38.67/32    md5
host    all             all            10.31.38.68/32    md5
host    all             all            10.31.38.69/32    md5
EOF
```

---

## ETAPA 5 — Criação dos bancos de dados

```bash
# Iniciar PostgreSQL
systemctl start postgresql
sleep 3

# Criar bancos
sudo -u postgres psql -c "CREATE DATABASE zabbix OWNER postgres;"
sudo -u postgres psql -c "CREATE DATABASE grafana OWNER postgres;"
sudo -u postgres psql -c "CREATE DATABASE awx OWNER postgres;"
```

✅ **Verificação:**
```bash
sudo -u postgres psql -c "\l"
```

---

## ETAPA 6 — Configuração do firewall (UFW)

```bash
# Replicação (pg-02)
ufw allow 5432/tcp from 10.31.38.65 comment "PostgreSQL replication pg-02"

# Aplicações
ufw allow 5432/tcp from 10.31.38.60 comment "Zabbix node1"
ufw allow 5432/tcp from 10.31.38.61 comment "Zabbix node2"
ufw allow 5432/tcp from 10.31.38.66 comment "Grafana node1"
ufw allow 5432/tcp from 10.31.38.67 comment "Grafana node2"
ufw allow 5432/tcp from 10.31.38.68 comment "AWX node1"
ufw allow 5432/tcp from 10.31.38.69 comment "AWX node2"
```

---

## ETAPA 7 — Verificação final

```bash
# Status do serviço
systemctl status postgresql

# Teste de conexão local
sudo -u postgres psql -c "SELECT version();"

# Verificar usuário de replicação
sudo -u postgres psql -c "\du replication"

# Verificar bancos criados
sudo -u postgres psql -c "\l"

# Verificar configuração wal_level
sudo -u postgres psql -c "SHOW wal_level;"

# Verificar replicação (após configurar pg-02)
sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"
```

---

## 📝 Próximos passos

1. Execute o script `01-postgresql-standby.sh` em **pg-02**  
2. Valide a replicação: `SELECT * FROM pg_stat_replication;`  
3. Monitore o lag: `SELECT now() - pg_last_xact_replay_timestamp();` (no standby)  

---

## 🔍 Monitoramento contínuo

```bash
# Status de replicação no Primary
sudo -u postgres psql -c "SELECT client_addr, state, sent_lsn, write_lsn, flush_lsn, replay_lsn FROM pg_stat_replication;"

# Log em tempo real
tail -f /var/log/postgresql/postgresql-16-main.log
```
