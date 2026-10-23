# 🔧 PROCEDIMENTO DE SETUP - POSTGRESQL 16 (SERVIDOR 10.31.38.64)

**Data:** 23/10/2024  
**Versão:** 1.0  
**Status:** Pronto para execução  
**Ambiente:** Linux (CentOS/RHEL 8+, Ubuntu 20.04+, Debian 11+)

---

## 📋 PRÉ-REQUISITOS

### Informações de Conectividade
- **Servidor PostgreSQL:** `10.31.38.64` (IP fixo obrigatório)
- **Usuário BD Root:** `postgres`
- **Usuário BD Zabbix:** `zabbix` (será criado)
- **Password BD Zabbix:** `(será definida durante setup)`
- **Database:** `zabbix`
- **Porta:** 5432

### Hardware Esperado
- **CPU:** 20 vCPU ⭐
- **RAM:** 96 GB ⭐
- **Disco:** 800GB-1TB ⭐ **NVMe OBRIGATÓRIO** ⭐⭐⭐
- **Rede:** Conectividade com zbx-server-01 e zbx-fe-01

### SO Esperado
- CentOS 8+ / RHEL 8+
- OU Ubuntu 20.04+ / Debian 11+
- Servidor zerado (fresh install)
- **Storage NVMe já montado** em `/var/lib/postgresql` ou `/pgdata`

---

## ✅ PASSO 1: PREPARAÇÃO DO SISTEMA OPERACIONAL

### 1.1 Atualizar o Sistema
```bash
# CentOS/RHEL
sudo yum update -y
sudo yum upgrade -y

# Ubuntu/Debian
sudo apt-get update
sudo apt-get upgrade -y
```

### 1.2 Instalar Ferramentas Básicas
```bash
# CentOS/RHEL
sudo yum install -y \
  wget curl git vim nano htop net-tools \
  ntp ntpdate chrony \
  gcc make \
  openssl openssl-devel

# Ubuntu/Debian
sudo apt-get install -y \
  wget curl git vim nano htop net-tools \
  ntp ntpdate chrony \
  build-essential \
  libssl-dev
```

### 1.3 Configurar NTP (Sincronismo Horário) ⭐ CRÍTICO
```bash
sudo systemctl start chrony
sudo systemctl enable chrony

# Validar sincronismo
chronyc tracking
timedatectl
```

### 1.4 Configurar Firewall
```bash
# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=5432/tcp
sudo firewall-cmd --reload

# Ubuntu/Debian
sudo ufw allow 5432/tcp
sudo ufw enable
```

### 1.5 Configurar Hostname
```bash
sudo hostnamectl set-hostname pg-primary-01
hostname

# Adicionar ao /etc/hosts
sudo nano /etc/hosts
# Adicionar: 10.31.38.64  pg-primary-01
```

---

## ✅ PASSO 2: PREPARAR STORAGE NVMe

### 2.1 Verificar Storage NVMe
```bash
# Listar discos
lsblk
# ou
sudo fdisk -l | grep nvme

# Esperado: /dev/nvme0n1 ou similar (disk ou partition)
```

### 2.2 Criar Partição (se necessário)
```bash
# Se disco não está particionado
sudo fdisk /dev/nvme0n1

# Comandos no fdisk:
# n - nova partição
# p - partição primária
# 1 - número da partição
# [Enter] - start sector padrão
# [Enter] - end sector para usar todo disco
# w - salvar

# Criar filesystem ext4 (preferred) ou xfs
sudo mkfs.ext4 /dev/nvme0n1p1
# ou
sudo mkfs.xfs /dev/nvme0n1p1
```

### 2.3 Montar Storage
```bash
# Criar ponto de montagem
sudo mkdir -p /pgdata

# Montar
sudo mount /dev/nvme0n1p1 /pgdata

# Adicionar ao /etc/fstab para persistência
sudo nano /etc/fstab
# Adicionar linha: /dev/nvme0n1p1  /pgdata  ext4  defaults  0 2
# ou
# /dev/nvme0n1p1  /pgdata  xfs   defaults  0 2

# Validar montagem
df -h /pgdata
# Esperado: ~800GB-1TB disponível
```

### 2.4 Ajustar Permissões
```bash
sudo chmod 700 /pgdata
# Criar subdiretório (após instalar postgres)
sudo mkdir -p /pgdata/postgresql
```

---

## ✅ PASSO 3: PREPARAR REPOSITÓRIOS

### 3.1 Adicionar Repositório PostgreSQL Oficial
```bash
# CentOS/RHEL
sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm

# Ubuntu 20.04
sudo apt-get install -y postgresql-common
# O setup.py já instala o repositório automaticamente

# Debian 11
sudo apt-get install -y postgresql-common
```

### 3.2 Habilitar Repositórios
```bash
# CentOS/RHEL
sudo yum-config-manager --enable pgdg16-updates

# Ubuntu/Debian (apt já faz)
sudo apt-get update
```

---

## ✅ PASSO 4: INSTALAR POSTGRESQL 16

### 4.1 Instalar PostgreSQL Server
```bash
# CentOS/RHEL
sudo yum install -y postgresql16-server postgresql16-contrib postgresql16-libs

# Ubuntu/Debian
sudo apt-get install -y postgresql-16 postgresql-contrib-16
```

### 4.2 Verificar Instalação
```bash
postgres --version
# Esperado: postgres (PostgreSQL) 16.x

psql --version
# Esperado: psql (PostgreSQL) 16.x
```

### 4.3 Localizar Diretório Data
```bash
# Verificar onde PostgreSQL quer usar data
sudo -u postgres psql -c "SHOW data_directory;"

# Deverá ser:
# /var/lib/postgresql/16/main  (Debian/Ubuntu)
# /var/lib/pgsql/16/data       (CentOS/RHEL)
```

---

## ✅ PASSO 5: INICIALIZAR E CONFIGURAR POSTGRESQL

### 5.1 Inicializar Cluster (CentOS/RHEL apenas)
```bash
# Já é feito automaticamente em Ubuntu/Debian

# CentOS/RHEL
sudo /usr/pgsql-16/bin/postgresql-16-setup initdb
```

### 5.2 Iniciar PostgreSQL
```bash
# Verificar status
sudo systemctl status postgresql-16

# Iniciar se não estiver rodando
sudo systemctl start postgresql-16
sudo systemctl enable postgresql-16

# Validar status
sudo systemctl status postgresql-16
# Esperado: "active (running)"
```

### 5.3 Editar postgresql.conf
```bash
# Localizar arquivo
# /etc/postgresql/16/main/postgresql.conf     (Debian/Ubuntu)
# /var/lib/pgsql/16/data/postgresql.conf      (CentOS/RHEL)

sudo nano /etc/postgresql/16/main/postgresql.conf
# ou
sudo nano /var/lib/pgsql/16/data/postgresql.conf
```

### 5.4 Parâmetros Críticos a Configurar
```ini
# Conexão
listen_addresses = '0.0.0.0'           # Escutar em todas as interfaces
port = 5432
max_connections = 200

# Memória (ajustar conforme RAM disponível - 96 GB neste caso)
shared_buffers = 24GB                  # 25% RAM
effective_cache_size = 72GB            # 75% RAM
work_mem = 120MB                       # 200KB * max_connections
maintenance_work_mem = 6GB

# WAL (Write-Ahead Log)
wal_level = replica                    # Para replicação
max_wal_senders = 3
max_replication_slots = 3
wal_keep_size = 2GB

# Checkpoints
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1

# Logging
logging_collector = on
log_directory = 'pg_log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_truncate_on_rotation = on
log_rotation_age = 1d
log_rotation_size = 100MB
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_checkpoints = on
log_connections = on
log_disconnections = on
log_duration = off
log_lock_waits = on
log_min_duration_statement = 1000
log_statement = 'all'
log_temp_files = 0
```

### 5.5 Editar pg_hba.conf (Controle de Acesso)
```bash
sudo nano /etc/postgresql/16/main/pg_hba.conf
# ou
sudo nano /var/lib/pgsql/16/data/pg_hba.conf
```

### 5.6 Adicionar Linhas de Acesso Remoto
```conf
# Adicionar ANTES da linha "local   all             all                                     trust"

# Acesso local (unix socket)
local   all             all                                     trust

# Acesso remoto - Zabbix Server 01
host    zabbix          zabbix          <IP-zbx-server-01>/32       md5

# Acesso remoto - Zabbix Frontend
host    zabbix          zabbix          <IP-zbx-fe-01>/32           md5

# Acesso remoto - Replicação (se houver standby)
host    replication     replicator      <IP-standby>/32             md5

# Acesso local replication
local   replication     all                                     trust
```

### 5.7 Recarregar Configurações
```bash
sudo systemctl reload postgresql-16

# Validar com logs
sudo tail -f /var/log/postgresql/postgresql-16-main.log
```

---

## ✅ PASSO 6: CRIAR BANCO E USUÁRIO ZABBIX

### 6.1 Conectar ao PostgreSQL
```bash
sudo -u postgres psql
```

### 6.2 Criar Usuário Zabbix
```sql
CREATE ROLE zabbix WITH LOGIN PASSWORD '<SENHA_FORTE>';
ALTER ROLE zabbix CREATEDB;
ALTER ROLE zabbix CREATEROLE;
```

### 6.3 Criar Database Zabbix
```sql
CREATE DATABASE zabbix OWNER zabbix ENCODING 'UTF8';
```

### 6.4 Sair do psql
```sql
\q
```

### 6.5 Validar Criação
```bash
# Conectar como usuário zabbix
psql -h localhost -U zabbix -d zabbix

# Deve conectar sem erro
\q
```

---

## ✅ PASSO 7: IMPORTAR SCHEMA ZABBIX

### 7.1 Localizar Arquivo Schema
```bash
# Copiar schema do servidor Zabbix Server
# OU downloa do repositório

# Se já tiver em outro servidor:
scp zabbix@<zbx-server-01>:/usr/share/doc/zabbix-server-pgsql-*/create.sql.gz /tmp/

# Se não tiver:
# Usar backups já preparados no repositório
```

### 7.2 Descompactar e Importar
```bash
cd /tmp

# Descompactar se necessário
gunzip create.sql.gz

# Importar schema
psql -h localhost -U zabbix -d zabbix -f create.sql

# Vai demorar alguns minutos (criando tabelas, índices)
```

### 7.3 Validar Importação
```bash
# Conectar ao banco
psql -h localhost -U zabbix -d zabbix

# Listar tabelas
\dt

# Contar tabelas (esperado: ~90+ tabelas)
SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';

# Sair
\q
```

---

## ✅ PASSO 8: CRIAR SLOTS DE REPLICAÇÃO (Preparar para Standby)

### 8.1 Criar Role de Replicação
```bash
sudo -u postgres psql
```

```sql
CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD '<SENHA_REPLICACAO>';
```

### 8.2 Criar Slot de Replicação
```sql
SELECT * FROM pg_create_physical_replication_slot('pg_replica_slot');
```

### 8.3 Validar
```sql
SELECT * FROM pg_replication_slots;
\q
```

---

## ✅ PASSO 9: CONFIGURAR BACKUP

### 9.1 Criar Script de Backup
```bash
sudo nano /usr/local/bin/zabbix_backup.sh
```

### 9.2 Conteúdo do Script
```bash
#!/bin/bash

BACKUP_DIR="/backups/postgresql"
DB_NAME="zabbix"
DB_USER="zabbix"
DB_HOST="localhost"
RETENTION_DAYS=7

# Criar diretório
mkdir -p $BACKUP_DIR

# Fazer backup
BACKUP_FILE="$BACKUP_DIR/zabbix_$(date +%Y%m%d_%H%M%S).sql.gz"
pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME | gzip > $BACKUP_FILE

# Validar
if [ -f "$BACKUP_FILE" ]; then
    echo "Backup realizado: $BACKUP_FILE"
    ls -lh $BACKUP_FILE
else
    echo "ERRO: Backup falhou!"
    exit 1
fi

# Limpar backups antigos
find $BACKUP_DIR -name "zabbix_*.sql.gz" -mtime +$RETENTION_DAYS -delete

# Log
echo "$(date '+%Y-%m-%d %H:%M:%S') - Backup OK" >> /var/log/zabbix_backup.log
```

### 9.3 Adicionar ao Cron
```bash
# Fazer script executável
sudo chmod +x /usr/local/bin/zabbix_backup.sh

# Adicionar ao crontab
sudo nano /etc/cron.d/zabbix_backup

# Conteúdo (backup diário às 2:00 AM):
0 2 * * * postgres /usr/local/bin/zabbix_backup.sh
```

---

## ✅ PASSO 10: TESTES DE VALIDAÇÃO

### 10.1 Teste de Conexão Local
```bash
psql -h localhost -U zabbix -d zabbix -c "SELECT COUNT(*) FROM hosts;"
```

**Esperado:** 0 (banco vazio)

### 10.2 Teste de Conexão Remota (do Zabbix Server)
```bash
# Do servidor zbx-server-01
psql -h 10.31.38.64 -U zabbix -d zabbix -c "SELECT COUNT(*) FROM hosts;"
```

**Esperado:** 0 (banco vazio)

### 10.3 Teste de Replicação
```bash
# No servidor PostgreSQL
sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"
```

**Esperado:** Vazio (standby ainda não replicando)

### 10.4 Monitorar Logs
```bash
# Seguir logs em tempo real
sudo tail -f /var/log/postgresql/postgresql-16-main.log
```

### 10.5 Verificar Performance
```bash
# Verificar conexões
ps aux | grep postgres | wc -l

# Verificar I/O NVMe
iostat -x nvme0n1 1 5

# Esperado: boas taxas de I/O (4K+ IOPS leitura/escrita)
```

---

## ⚠️ TROUBLESHOOTING

### Erro: "could not open file pg_hba.conf"
```bash
# Verificar localização exata
sudo find / -name pg_hba.conf 2>/dev/null

# Usar caminho correto
sudo nano /var/lib/postgresql/16/data/pg_hba.conf
```

### Erro: "FATAL: remaining connection slots are reserved"
```bash
# Aumentar max_connections em postgresql.conf
max_connections = 300
```

### Erro: "permission denied" no /pgdata
```bash
# Ajustar propriedade
sudo chown postgres:postgres /pgdata
sudo chmod 700 /pgdata
```

### Erro: "out of memory"
```bash
# Reduzir parâmetros de memória em postgresql.conf
shared_buffers = 12GB  # ao invés de 24GB
work_mem = 60MB        # ao invés de 120MB
```

### NVMe não está sendo usado
```bash
# Verificar se está mountado
df -h | grep pgdata

# Verificar se data_directory aponta para NVMe
sudo -u postgres psql -c "SHOW data_directory;"

# Esperar que retorne /pgdata/... (ou caminho NVMe)
```

---

## ✅ CHECKLIST FINAL

- [ ] Sistema operacional atualizado
- [ ] NTP sincronizado
- [ ] Firewall configurado (porta 5432)
- [ ] Storage NVMe montado em /pgdata
- [ ] PostgreSQL 16 instalado
- [ ] postgresql.conf configurado (memória, WAL, logging)
- [ ] pg_hba.conf configurado (acesso remoto)
- [ ] Usuário `zabbix` criado com senha forte
- [ ] Database `zabbix` criado
- [ ] Schema Zabbix importado
- [ ] Slots de replicação criados
- [ ] Script de backup criado e agendado
- [ ] Conectividade local testada
- [ ] Conectividade remota (zbx-server-01) testada
- [ ] Conectividade remota (zbx-fe-01) testada
- [ ] Logs sem erros críticos

---

## 📞 PRÓXIMA ETAPA

Após completar este procedimento com sucesso:
1. Executar setup do Zabbix Server 01 (comunicar com este PostgreSQL)
2. Executar setup do Zabbix Frontend (comunicar com este PostgreSQL)
3. Configurar replicação (Standby - PostgreSQL Replica)
4. Configurar Keepalived para VIP

---

## 📊 REFERÊNCIA RÁPIDA - IPs E PORTAS

```
┌─────────────────────┬──────────────┬────────────────────┐
│ Servidor            │ IP           │ Porta              │
├─────────────────────┼──────────────┼────────────────────┤
│ PostgreSQL Primary  │ 10.31.38.64  │ 5432               │
│ Zabbix Server 01    │ A DEFINIR    │ 10051              │
│ Zabbix Frontend 01  │ A DEFINIR    │ 80/443             │
├─────────────────────┴──────────────┴────────────────────┤
│ PostgreSQL Replica  │ A DEFINIR    │ 5432 (standby)     │
└─────────────────────────────────────────────────────────┘
```

---

**Status:** ✅ Pronto para execução  
**Data:** 23/10/2024  
**Versão:** 1.0  
**⭐ CRÍTICO:** NVMe obrigatório para performance
