# 📊 TUTORIAL — Zabbix Server 7.0 HA
> **Script:** `04-zabbix-server-ha.sh`  
> **Objetivo:** Instalar Zabbix Server 7.0 LTS em cluster HA (dois nós)  
> **Servidores:** zbx-server-01 (`10.31.38.60`) e zbx-server-02 (`10.31.38.61`)  
> **Uso:** `sudo ./04-zabbix-server-ha.sh <node1|node2>`

---

## 📋 Pré-requisitos

- PostgreSQL HA (pg-01/pg-02) já instalado e rodando  
- VIP (`10.31.38.70`) já configurado via HAProxy+Keepalived  
- IPs estáticos: `10.31.38.60` (node1) / `10.31.38.61` (node2)  

---

## 🔧 Variáveis — defina antes de executar

```bash
export DB_PASS="SUA_SENHA_ZABBIX_DB"        # Senha do banco zabbix
export ZABBIX_API_PASS="SUA_SENHA_API"      # Senha da API Zabbix (padrão: zabbix)
```

---

## ETAPA 1 — Verificar pré-requisitos

```bash
# Verificar IP (node1 = 10.31.38.60, node2 = 10.31.38.61)
hostname -I | awk '{print $1}'

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

```bash
# Adicionar chave do repositório
wget -q https://repo.zabbix.com/zabbix-official-repo.key -O /tmp/zabbix-key
apt-key add /tmp/zabbix-key

# Adicionar repositório Zabbix 7.0
echo "deb https://repo.zabbix.com/zabbix/7.0/ubuntu $(lsb_release -cs) main" > /etc/apt/sources.list.d/zabbix.list

apt-get update

# Instalar Zabbix Server + Frontend + Agent2
DEBIAN_FRONTEND=noninteractive apt-get install -y     zabbix-server-pgsql     zabbix-frontend-php-pgsql     zabbix-agent2     zabbix-sql-scripts
```

✅ **Verificação:** `zabbix_server --version`

---

## ETAPA 4 — Configurar Zabbix Server

### 4.1 — Backup da configuração original

```bash
cp /etc/zabbix/zabbix_server.conf /etc/zabbix/zabbix_server.conf.backup
```

### 4.2 — Configurar banco de dados

```bash
# Definir conexão com PostgreSQL Primary
sed -i "s/^DBHost=.*/DBHost=10.31.38.64/" /etc/zabbix/zabbix_server.conf
sed -i "s/^DBName=.*/DBName=zabbix/" /etc/zabbix/zabbix_server.conf
sed -i "s/^DBUser=.*/DBUser=zabbix/" /etc/zabbix/zabbix_server.conf
sed -i "s/^DBPassword=.*/DBPassword=${DB_PASS:-zabbix123}/" /etc/zabbix/zabbix_server.conf
```

### 4.3 — Configurar HA (node1 ou node2)

```bash
# Para NODE 1 (zbx-server-01):
sed -i "s/^# NodeID=/NodeID=/" /etc/zabbix/zabbix_server.conf
sed -i "s/^NodeID=.*/NodeID=1/" /etc/zabbix/zabbix_server.conf

# Para NODE 2 (zbx-server-02):
# sed -i "s/^NodeID=.*/NodeID=2/" /etc/zabbix/zabbix_server.conf
```

### 4.4 — Configurar performance

```bash
sed -i "s/^# CacheSize=.*/CacheSize=512M/" /etc/zabbix/zabbix_server.conf
sed -i "s/^# HistoryCacheSize=.*/HistoryCacheSize=256M/" /etc/zabbix/zabbix_server.conf
sed -i "s/^# ValueCacheSize=.*/ValueCacheSize=256M/" /etc/zabbix/zabbix_server.conf
sed -i "s/^# WorkerProcesses=.*/WorkerProcesses=8/" /etc/zabbix/zabbix_server.conf
```

### 4.5 — Configurar logging

```bash
sed -i "s/^LogFile=.*/LogFile=\/var\/log\/zabbix\/zabbix_server.log/" /etc/zabbix/zabbix_server.conf
```

---

## ETAPA 5 — Criar usuário no PostgreSQL para Zabbix

> ⚠️ **Execute no pg-01 como postgres ANTES de importar o schema** — o schema precisa do usuário para conectar.

```bash
# Execute no pg-01 como postgres
sudo -u postgres psql << EOF
CREATE USER zabbix WITH ENCRYPTED PASSWORD '${DB_PASS:-zabbix123}';
GRANT ALL PRIVILEGES ON DATABASE zabbix TO zabbix;
EOF
```

---

## ETAPA 6 — Importar schema do banco (somente no NODE 1)

```bash
# Criar usuário e conceder permissões no PostgreSQL
PGPASSWORD="${DB_PASS:-zabbix123}" psql -h 10.31.38.64 -U zabbix -d zabbix << 'EOF'
-- Verificar se schema já existe
SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';
EOF

# Importar schema (somente node1, na primeira instalação)
zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz |     PGPASSWORD="${DB_PASS:-zabbix123}" psql -h 10.31.38.64 -U zabbix -d zabbix
```

> ⚠️ **Node 2:** pule a importação do schema — o banco já foi populado pelo node1

✅ **Verificação:**
```bash
PGPASSWORD="${DB_PASS:-zabbix123}" psql -h 10.31.38.64 -U zabbix -d zabbix -c "\dt" | head -20
```

---

## ETAPA 7 — Iniciar Zabbix Server

```bash
systemctl enable zabbix-server zabbix-agent2
systemctl restart zabbix-server zabbix-agent2

# Verificar status
systemctl status zabbix-server
```

✅ **Verificação:**
```bash
# Aguardar 10 segundos e verificar logs
sleep 10
tail -50 /var/log/zabbix/zabbix_server.log
```

---

## ETAPA 8 — Configurar sincronização entre nodes (SSH)

```bash
# Criar par de chaves para o usuário zabbix
sudo -u zabbix ssh-keygen -t rsa -b 4096 -f /home/zabbix/.ssh/id_rsa -N ""

# Copiar chave pública para o outro node
# NODE 1: copiar para NODE 2
sudo -u zabbix ssh-copy-id zabbix@10.31.38.61

# NODE 2: copiar para NODE 1
# sudo -u zabbix ssh-copy-id zabbix@10.31.38.60
```

---

## ETAPA 9 — Verificação final

```bash
# Status dos serviços
systemctl status zabbix-server
systemctl status zabbix-agent2

# Teste de conectividade com banco
PGPASSWORD="${DB_PASS:-zabbix123}" psql -h 10.31.38.64 -U zabbix -d zabbix -c "SELECT COUNT(*) FROM hosts;"

# Verificar porta do Zabbix Server
ss -tlnp | grep 10051
```

---

## 📝 Próximos passos

1. Acesse o frontend via: `http://10.31.38.72/zabbix`  
2. Instale node2 (repita os passos no zbx-server-02)  
3. Configure templates e hosts no Zabbix  

---

## 🔍 Monitoramento

```bash
# Logs em tempo real
tail -f /var/log/zabbix/zabbix_server.log

# Status HA dos nodes Zabbix (via banco)
PGPASSWORD="${DB_PASS:-zabbix123}" psql -h 10.31.38.64 -U zabbix -d zabbix \
    -c "SELECT name, address, status, lastaccess FROM ha_node;"

---

## ⚡ ETAPA FINAL — Ativação do Backend no HAProxy

> Esta etapa é executada **automaticamente** pelo script `04-zabbix-server-ha.sh` ao final da instalação.
> Se o SSH para vip-01/vip-02 não estiver disponível, execute manualmente.

### Execução automática (pelo script)

O script conecta via SSH em **vip-01** (`10.31.38.70`) e **vip-02** (`10.31.38.71`) e:
1. Ativa os backends via **HAProxy Runtime API** (efeito imediato, sem interrupção)
2. Atualiza `/etc/haproxy/haproxy.cfg` (persistência após restart)
3. Executa `systemctl reload haproxy`

### Execução manual (se SSH falhar)

Execute em **vip-01 E em vip-02**:

```bash
# 1. Ativar via Runtime API (imediato, sem reload)
echo 'enable server backend_zabbix/zabbix_01' | socat /run/haproxy/admin.sock stdio
echo 'enable server backend_zabbix/zabbix_02' | socat /run/haproxy/admin.sock stdio

# 2. Atualizar config (persistência)
sed -i 's/zabbix_01 10.31.38.60:80 disabled/zabbix_01 10.31.38.60:80 check inter 5s fall 3 rise 2/' /etc/haproxy/haproxy.cfg
sed -i 's/zabbix_02 10.31.38.61:80 disabled/zabbix_02 10.31.38.61:80 check inter 5s fall 3 rise 2/' /etc/haproxy/haproxy.cfg

# 3. Validar config e recarregar
haproxy -c -f /etc/haproxy/haproxy.cfg && systemctl reload haproxy
```

### Validação pós-ativação (executar nos VIPs)

```bash
# Status dos backends Zabbix
echo 'show servers state backend_zabbix' | socat /run/haproxy/admin.sock stdio

# Stats web (confirmar backends UP)
curl -s 'http://10.31.38.70:8404/stats' | grep -i zabbix

# Acesso via VIP flutuante
curl -sk http://10.31.38.72/zabbix/ -o /dev/null -w "HTTP: %{http_code}\n"
```

> ✅ Backends devem aparecer como **UP** nas stats: `http://10.31.38.70:8404/stats`

```
