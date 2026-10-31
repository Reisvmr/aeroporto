# 🐘 TUTORIAL — PostgreSQL 16 Primary
> **Script:** `01-postgresql-primary.sh`  
> **Objetivo:** Instalar e configurar PostgreSQL 16 Primary com Streaming Replication  
> **Servidor:** pg-01 — IP: `10.31.38.64`  
> **Uso:** `sudo ./01-postgresql-primary.sh`

---

## 📋 Pré-requisitos

- Ubuntu **26.04 LTS (resolute)** atualizado
- Mínimo 50 GB em `/var/lib/postgresql`  
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

# Verificar espaço em disco (Ubuntu path)
df -BG /var/lib/postgresql | awk 'NR==2{print $4}'   # Deve ser >= 50G
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
# Adicionar repositório PGDG oficial — Ubuntu 26.04 LTS (resolute-pgdg)
apt-get install -y curl ca-certificates
install -d /usr/share/postgresql-common/pgdg
curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail \
    https://www.postgresql.org/media/keys/ACCC4CF8.asc
sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
# lsb_release -cs retorna "resolute" → entry: resolute-pgdg

# Atualizar cache
apt-get update

# Instalar PostgreSQL 16
DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql-16 postgresql-contrib-16
```

✅ **Verificação:** `psql --version`

> ⚠️ **Nota Ubuntu PGDG:**
> - Config: `/etc/postgresql/16/main/postgresql.conf`
> - Data: `/var/lib/postgresql/16/main/`
> - Serviço real: `postgresql@16-main` (não `postgresql-16` nem `postgresql`)

---

## ETAPA 4 — Configuração de replicação

### 4.1 — Criar usuário de replicação

> ⚠️ **O serviço deve estar RODANDO para executar este passo** — o psql precisa de conexão ativa.

```bash
sudo -u postgres psql <<EOF
CREATE USER replication WITH REPLICATION ENCRYPTED PASSWORD '${REPLICATION_PASS:-repl123}';
EOF
```

### 4.2 — Criar replication slot para o Standby

```bash
sudo -u postgres psql -c "SELECT pg_create_physical_replication_slot('standby_slot');"
```

✅ **Verificação:**
```bash
sudo -u postgres psql -c "SELECT slot_name, slot_type, active FROM pg_replication_slots;"
# Deve mostrar: standby_slot | physical | f
```

### 4.3 — Parar PostgreSQL

```bash
systemctl stop postgresql@16-main
```

### 4.4 — Backup do postgresql.conf original

```bash
PG_CONFIG="/etc/postgresql/16/main"
cp "$PG_CONFIG/postgresql.conf" "$PG_CONFIG/postgresql.conf.backup"
```

### 4.5 — Adicionar configurações de replicação ao postgresql.conf

```bash
cat >> /etc/postgresql/16/main/postgresql.conf << 'EOF'

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURAÇÕES DE REPLICAÇÃO (Phase 2 HA)
# ═══════════════════════════════════════════════════════════════════════════

listen_addresses = '*'

wal_level = replica
max_wal_senders = 10
max_replication_slots = 10
wal_keep_size = 1024
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
log_statement = 'ddl'
log_replication_commands = on

# Sincronização assíncrona (padrão seguro)
# Para modo síncrono, defina também synchronous_standby_names = 'pg-02'
synchronous_commit = local
EOF
```

> ℹ️ `synchronous_commit = local` garante durabilidade local sem bloquear em caso de falha do standby.  
> Para replicação **síncrona** (RPO zero), altere para `remote_apply` **e** adicione `synchronous_standby_names = 'pg-02'`.

### 4.6 — Backup e configuração do pg_hba.conf

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
systemctl start postgresql@16-main
sleep 3
```

✅ **Verificação — PostgreSQL escutando em todas as interfaces (não só localhost):**
```bash
ss -tlnp | grep 5432
# Resultado esperado: 0.0.0.0:5432
# Se aparecer 127.0.0.1:5432, o listen_addresses não foi aplicado — veja nota abaixo
```

> ⚠️ **Se aparecer `127.0.0.1:5432`:** o parâmetro pode ter sido sobrescrito por uma entrada anterior no arquivo.
> Corrija com:
> ```bash
> # Verificar entradas duplicadas / conflitantes
> grep listen_addresses /etc/postgresql/16/main/postgresql.conf
>
> # Forçar a configuração correta (sobrescreve tudo via ALTER SYSTEM)
> sudo -u postgres psql -c "ALTER SYSTEM SET listen_addresses = '*';"
> systemctl restart postgresql@16-main
> sleep 3
> ss -tlnp | grep 5432   # Deve mostrar 0.0.0.0:5432
> ```

```bash
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
systemctl status postgresql@16-main

# Teste de conexão local
sudo -u postgres psql -c "SELECT version();"

# Verificar usuário de replicação
sudo -u postgres psql -c "\du replication"

# Verificar slot criado
sudo -u postgres psql -c "SELECT slot_name, slot_type, active FROM pg_replication_slots;"

# Verificar bancos criados
sudo -u postgres psql -c "\l"

# Verificar configuração wal_level
sudo -u postgres psql -c "SHOW wal_level;"

# Verificar listen_addresses
sudo -u postgres psql -c "SHOW listen_addresses;"
# Esperado: *

# Confirmar porta escutando em todas as interfaces
ss -tlnp | grep 5432
# Esperado: 0.0.0.0:5432

# Verificar replicação (após configurar pg-02)
sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"
```

---

## 📝 Próximos passos

1. Execute o script `02-postgresql-standby.sh` em **pg-02**  
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
