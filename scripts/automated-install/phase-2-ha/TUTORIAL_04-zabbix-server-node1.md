# 📊 TUTORIAL 04 — Zabbix Server 7.0 · NODE 1 (zbx-server-01)

> **Servidor:** zbx-server-01 — IP `10.31.38.60`  
> **Objetivo:** Instalar e configurar o Zabbix Server 7.0 LTS no primeiro nó do cluster HA  
> **Pré-requisito:** TUTORIAL_01 (pg-01) e TUTORIAL_03 (vip-01/vip-02) concluídos

---

## 📋 Pré-requisitos

- PostgreSQL HA (pg-01 `10.31.38.64`) já instalado e rodando
- VIP (`10.31.38.70/71`) já configurado via HAProxy + Keepalived
- IP estático `10.31.38.60` já configurado no servidor

---

## 🔧 Variável — defina antes de executar

```bash
export DB_PASS="TROQUEPELASENHADOBANCO"   # Senha do banco zabbix (mesma usada no pg-01)
```

---

## ETAPA 1 — Verificar pré-requisitos

```bash
# Confirmar IP do node
hostname -I | awk '{print $1}'
# Esperado: 10.31.38.60

# Testar conectividade com PostgreSQL Primary
timeout 5 bash -c '</dev/tcp/10.31.38.64/5432' && echo "✓ pg-01 acessível" || echo "✗ pg-01 INACESSÍVEL"

# Verificar espaço em /var (mínimo 20GB)
df -BG /var | awk 'NR==2{print $4}'
```

---

## ETAPA 2 — Atualizar sistema

```bash
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
```

---

## ETAPA 3 — Instalar Zabbix Server 7.0

> ℹ️ **Frontend não instalado aqui** — o Zabbix Frontend vai nos servidores zbx-fe-01/02 (TUTORIAL_04b).  
> ℹ️ **Ubuntu 26.04 (resolute):** o pacote `zabbix-release` aponta para `noble` — corrigir sources.list após instalação.

```bash
# Remover repositório antigo (se existir)
rm -f /etc/apt/sources.list.d/zabbix.list
rm -f /usr/share/keyrings/zabbix-archive-keyring.gpg

# Instalar pacote de release oficial do Zabbix para Ubuntu 26.04
wget https://repo.zabbix.com/zabbix/7.0/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest+ubuntu26.04_all.deb
dpkg -i zabbix-release_latest+ubuntu26.04_all.deb

# Corrigir sources.list: trocar 'noble' por 'resolute'
sed -i 's/noble/resolute/g' /etc/apt/sources.list.d/zabbix.list

# Verificar
grep resolute /etc/apt/sources.list.d/zabbix.list

apt-get update

# Instalar Zabbix Server + Agent2 + sql-scripts
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    zabbix-server-pgsql \
    zabbix-agent2 \
    zabbix-sql-scripts
```

✅ **Verificação:** `zabbix_server --version`

---

## ETAPA 4 — Criar banco e usuário no PostgreSQL

> ⚠️ **Execute este bloco em pg-01 (`10.31.38.64`) — NÃO no zbx-server-01!**  
> O usuário `postgres` só existe onde o PostgreSQL está instalado.

```bash
# Conectar em pg-01
ssh administrator@10.31.38.64

# Criar banco e usuário (substitua TROQUEPELASENHADOBANCO pela senha real)
sudo -u postgres psql << EOF
CREATE DATABASE zabbix;
CREATE USER zabbix WITH ENCRYPTED PASSWORD 'TROQUEPELASENHADOBANCO';
GRANT ALL PRIVILEGES ON DATABASE zabbix TO zabbix;
\c zabbix
GRANT USAGE  ON SCHEMA public TO zabbix;
GRANT CREATE ON SCHEMA public TO zabbix;
EOF

# Voltar para zbx-server-01
exit
```

---

## ETAPA 5 — Configurar Zabbix Server

### 5.1 — Backup da configuração original

```bash
cp /etc/zabbix/zabbix_server.conf /etc/zabbix/zabbix_server.conf.backup
```

### 5.2 — Configurar banco de dados

> ⚠️ No arquivo padrão, `DBHost` e `DBPassword` ficam **comentados** (`# DBHost=`).  
> Os comandos abaixo já tratam esse padrão corretamente.

```bash
sed -i "s/^# DBHost=.*/DBHost=10.31.38.64/" /etc/zabbix/zabbix_server.conf
sed -i "s/^DBName=.*/DBName=zabbix/" /etc/zabbix/zabbix_server.conf
sed -i "s/^DBUser=.*/DBUser=zabbix/" /etc/zabbix/zabbix_server.conf
sed -i "s/^# DBPassword=.*/DBPassword=${DB_PASS:-TROQUEPELASENHADOBANCO}/" /etc/zabbix/zabbix_server.conf

# Confirmar (todas devem aparecer sem #)
grep -n "^DBHost\|^DBName\|^DBUser\|^DBPassword" /etc/zabbix/zabbix_server.conf
```

### 5.3 — Configurar HA (NodeID = 1)

```bash
sed -i "s/^# NodeID=/NodeID=/" /etc/zabbix/zabbix_server.conf
sed -i "s/^NodeID=.*/NodeID=1/" /etc/zabbix/zabbix_server.conf
```

### 5.4 — Configurar performance

```bash
sed -i "s/^# CacheSize=.*/CacheSize=512M/" /etc/zabbix/zabbix_server.conf
sed -i "s/^# HistoryCacheSize=.*/HistoryCacheSize=256M/" /etc/zabbix/zabbix_server.conf
sed -i "s/^# ValueCacheSize=.*/ValueCacheSize=256M/" /etc/zabbix/zabbix_server.conf
sed -i "s/^# WorkerProcesses=.*/WorkerProcesses=8/" /etc/zabbix/zabbix_server.conf
```

### 5.5 — Configurar logging

```bash
sed -i "s/^LogFile=.*/LogFile=\/var\/log\/zabbix\/zabbix_server.log/" /etc/zabbix/zabbix_server.conf
```

---

## ETAPA 6 — Importar schema do banco

> ⚠️ **Somente no NODE 1** — o node2 usa o banco já populado aqui.  
> Use a linha única abaixo. O `PGPASSWORD` deve ficar antes do `zcat`.

```bash
PGPASSWORD="${DB_PASS:-TROQUEPELASENHADOBANCO}" zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | psql -h 10.31.38.64 -U zabbix -d zabbix
```

✅ **Verificação:**
```bash
PGPASSWORD="${DB_PASS:-TROQUEPELASENHADOBANCO}" psql -h 10.31.38.64 -U zabbix -d zabbix -c "\dt" | head -20
```

---

## ETAPA 7 — Iniciar serviços

```bash
systemctl enable zabbix-server zabbix-agent2
systemctl restart zabbix-server zabbix-agent2

# Aguardar e verificar logs
sleep 10
tail -30 /var/log/zabbix/zabbix_server.log
```

✅ **Esperado nos logs:** `started [ha manager]`, `started [availability manager]`, sem erros `Z3001`.

---

## ETAPA 8 — Configurar chave SSH para sincronização entre nodes

> ⚠️ O diretório `/home/zabbix/.ssh` não existe por padrão — crie antes do keygen.

```bash
# Criar diretório .ssh para o usuário zabbix
mkdir -p /home/zabbix/.ssh
chown zabbix:zabbix /home/zabbix/.ssh
chmod 700 /home/zabbix/.ssh

# Gerar par de chaves
sudo -u zabbix ssh-keygen -t rsa -b 4096 -f /home/zabbix/.ssh/id_rsa -N ""

# Visualizar chave pública (será copiada para node2 após ele ser instalado)
cat /home/zabbix/.ssh/id_rsa.pub
```

> 📌 **Guarde a chave pública acima** — ela será adicionada ao node2 no TUTORIAL_04c.

---

## ETAPA 9 — Verificação final

```bash
# Status dos serviços
systemctl status zabbix-server zabbix-agent2 --no-pager

# Porta do Zabbix Server (10051)
ss -tlnp | grep 10051

# Conexão com banco
PGPASSWORD="${DB_PASS:-TROQUEPELASENHADOBANCO}" psql -h 10.31.38.64 -U zabbix -d zabbix -c "SELECT COUNT(*) FROM hosts;"

# Status HA (deve aparecer node1 como active)
PGPASSWORD="${DB_PASS:-TROQUEPELASENHADOBANCO}" psql -h 10.31.38.64 -U zabbix -d zabbix \
    -c "SELECT name, address, status, lastaccess FROM ha_node;"
```

---

## ✅ Resultado esperado

| Item | Esperado |
|---|---|
| `zabbix-server` | `active (running)` |
| `zabbix-agent2` | `active (running)` |
| Porta 10051 | ouvindo |
| DBHost | `10.31.38.60` nos logs, conexão em `10.31.38.64` |
| ha_node | node1 como `active` |

---

## 📌 Próximo passo

➡️ **TUTORIAL_04c** — Instalar Zabbix Server node2 (`zbx-server-02 / 10.31.38.61`)
