# 🐘 TUTORIAL — PostgreSQL 16 Standby
> **Script:** `01-postgresql-standby.sh`  
> **Objetivo:** Instalar PostgreSQL 16 Standby com replicação streaming desde pg-01  
> **Servidor:** pg-02 — IP: `10.31.38.65`  
> **Uso:** `sudo ./01-postgresql-standby.sh`

---

## 📋 Pré-requisitos

- **pg-01 (Primary) já instalado e rodando** — execute este script somente após concluir `01-postgresql-primary.sh`  
- IP estático: `10.31.38.65`  
- Conectividade TCP na porta 5432 com pg-01 (`10.31.38.64`)  

---

## 🔧 Variáveis — defina antes de executar

```bash
# Usar a MESMA senha definida no Primary
export REPLICATION_PASS="SUA_SENHA_REPL_AQUI"
```

---

## ETAPA 1 — Verificação de pré-requisitos

```bash
# Verificar IP do servidor
hostname -I | awk '{print $1}'   # Deve retornar: 10.31.38.65

# Verificar conectividade com Primary (pg-01)
timeout 5 bash -c '</dev/tcp/10.31.38.64/5432' && echo "✓ pg-01:5432 acessível" || echo "✗ pg-01:5432 INACESSÍVEL"

# Verificar espaço em disco
df -BG /var | awk 'NR==2{print $4}'   # Deve ser >= 50G
```

✅ **Verificação:** IP = `10.31.38.65`, pg-01:5432 acessível, >= 50GB livres

---

## ETAPA 2 — Atualização do sistema

```bash
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
```

---

## ETAPA 3 — Instalação do PostgreSQL 16

```bash
# Adicionar repositório oficial
sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget -q -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql-16 postgresql-contrib-16
```

✅ **Verificação:** `psql --version`

---

## ETAPA 4 — Configurar Standby via pg_basebackup

### 4.1 — Parar PostgreSQL

```bash
systemctl stop postgresql
```

### 4.2 — Limpar o data directory

```bash
# ⚠️ ATENÇÃO: isso apaga todos os dados locais — o Standby é recriado a partir do Primary
sudo -u postgres rm -rf /var/lib/postgresql/16/main/*
```

### 4.3 — Executar pg_basebackup desde o Primary

```bash
# Isso copia toda a base do Primary para o Standby
# -P = progresso, -v = verbose, -R = cria standby.signal + postgresql.auto.conf
# --slot = cria replication slot no Primary
sudo -u postgres pg_basebackup     -h 10.31.38.64     -D /var/lib/postgresql/16/main     -U replication     -P -v     -W -R --slot=standby_slot --create-slot
```

> 💬 Será solicitada a senha do usuário `replication` — insira `${REPLICATION_PASS:-repl123}`

✅ **Verificação após conclusão:**
```bash
ls -la /var/lib/postgresql/16/main/standby.signal   # Deve existir
```

### 4.4 — Adicionar configurações ao postgresql.conf

```bash
cat >> /etc/postgresql/16/main/postgresql.conf << 'EOF'

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURAÇÕES DE STANDBY (Phase 2 HA)
# ═══════════════════════════════════════════════════════════════════════════

wal_level = replica
hot_standby = on
hot_standby_feedback = on
max_standby_streaming_delay = 300s
wal_receiver_timeout = 60s
wal_retrieve_retry_interval = 5s

# Performance
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 16MB
maintenance_work_mem = 64MB

# Logging
log_connections = on
log_disconnections = on
log_replication_commands = on
EOF
```

### 4.5 — Verificar/criar standby.signal

```bash
# Se o -R do pg_basebackup não criou:
if [[ ! -f /var/lib/postgresql/16/main/standby.signal ]]; then
    touch /var/lib/postgresql/16/main/standby.signal
    chown postgres:postgres /var/lib/postgresql/16/main/standby.signal
    echo "standby.signal criado manualmente"
fi
```

---

## ETAPA 5 — Iniciar PostgreSQL Standby

```bash
systemctl start postgresql
sleep 5

# Verificar status
systemctl status postgresql

# Ver logs de inicialização
journalctl -u postgresql --no-pager -n 30
```

✅ **Esperado nos logs:** `started streaming WAL from primary`

---

## ETAPA 6 — Configurar firewall

```bash
ufw allow 5432/tcp from 10.31.38.64 comment "Primary pg-01"
```

---

## ETAPA 7 — Verificação de replicação

```bash
# No Standby (pg-02) — verificar modo
sudo -u postgres psql -c "SELECT pg_is_in_recovery();"   # Deve retornar: t (true)

# Verificar lag de replicação
sudo -u postgres psql -c "SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag;"

# No Primary (pg-01) — verificar se Standby está conectado
# Execute este comando NO pg-01:
# sudo -u postgres psql -c "SELECT client_addr, state, sent_lsn, replay_lsn FROM pg_stat_replication;"
```

---

## 📝 Próximos passos

1. Valide no **pg-01**: `SELECT * FROM pg_stat_replication;` → deve aparecer pg-02  
2. Monitore o lag de replicação periodicamente  
3. Prossiga com a instalação do VIP (`06-vip-haproxy-keepalived.sh`)  

---

## 🔍 Monitoramento contínuo

```bash
# Log em tempo real
tail -f /var/log/postgresql/postgresql-16-main.log

# Status de replicação
sudo -u postgres psql -c "SELECT pg_is_in_recovery(), pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn();"
```
