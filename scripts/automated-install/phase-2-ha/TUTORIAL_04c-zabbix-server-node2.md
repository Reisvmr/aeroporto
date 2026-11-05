# 📊 TUTORIAL 04c — Zabbix Server 7.0 + Frontend · NODE 2 (zbx-server-02)

> **Servidor:** zbx-server-02 — IP `10.31.38.61`  
> **Objetivo:** Instalar Zabbix Server 7.0 LTS **e** Zabbix Frontend (Apache + PHP) no segundo nó do cluster HA  
> **Pré-requisito:** TUTORIAL_04 (zbx-server-01) **totalmente concluído**

---

## 📋 Pré-requisitos

- PostgreSQL HA (pg-01 `10.31.38.64`) rodando com banco `zabbix` já criado
- zbx-server-01 (`10.31.38.60`) instalado, ativo e com HA funcionando
- IP estático `10.31.38.61` já configurado neste servidor

---

## 🔧 Variável — defina antes de executar

```bash
export DB_PASS="TROQUEPELASENHADOBANCO"   # Mesma senha usada no node1
```

---

## ETAPA 1 — Verificar pré-requisitos

```bash
# Confirmar IP do node
hostname -I | awk '{print $1}'
# Esperado: 10.31.38.61

# Testar conectividade com PostgreSQL Primary
timeout 5 bash -c '</dev/tcp/10.31.38.64/5432' && echo "✓ pg-01 acessível" || echo "✗ pg-01 INACESSÍVEL"

# Testar conectividade com node1 (deve estar instalado)
timeout 5 bash -c '</dev/tcp/10.31.38.60/10051' && echo "✓ zbx-server-01:10051 acessível" || echo "✗ zbx-server-01 INACESSÍVEL"
timeout 5 bash -c '</dev/tcp/10.31.38.60/80' && echo "✓ zbx-server-01:80 acessível" || echo "✗ zbx-server-01:80 INACESSÍVEL"

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

## ETAPA 3 — Instalar Zabbix Server + Frontend + Agent2

> ℹ️ Mesmo procedimento do node1.  
> ℹ️ **Ubuntu 26.04 (resolute):** corrigir sources.list de `noble` para `resolute` após instalação.

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

# Instalar Zabbix Server + Agent2 + sql-scripts + Frontend
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    zabbix-server-pgsql \
    zabbix-agent2 \
    zabbix-sql-scripts \
    apache2 php php-xml php-bcmath php-mbstring php-gd \
    php-ldap php-pgsql php-curl libapache2-mod-php \
    zabbix-frontend-php zabbix-apache-conf
```

✅ **Verificação:** `zabbix_server --version && php -v && apache2 -v`

---

## ETAPA 4 — Configurar Zabbix Server

### 4.1 — Backup da configuração original

```bash
cp /etc/zabbix/zabbix_server.conf /etc/zabbix/zabbix_server.conf.backup
```

### 4.2 — Configurar banco de dados

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

### 4.3 — Configurar HA (NodeID = 2)

> ⚠️ Node2 usa `NodeID=2` — diferente do node1 que usa `NodeID=1`.

```bash
sed -i "s/^# NodeID=/NodeID=/" /etc/zabbix/zabbix_server.conf
sed -i "s/^NodeID=.*/NodeID=2/" /etc/zabbix/zabbix_server.conf
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

## ETAPA 5 — Iniciar Zabbix Server

> ⚠️ **NÃO importar schema aqui** — o banco já foi populado pelo node1.

```bash
systemctl enable zabbix-server zabbix-agent2
systemctl restart zabbix-server zabbix-agent2

# Aguardar e verificar logs
sleep 10
tail -30 /var/log/zabbix/zabbix_server.log
```

✅ **Esperado nos logs:** `started [ha manager]` e node2 como `standby` sem erros `Z3001`.

---

## ETAPA 6 — Configurar Zabbix Frontend

### 6.1 — Criar zabbix.conf.php

```bash
cat > /etc/zabbix/zabbix.conf.php << PHP_EOF
<?php
global \$DB;

\$DB['TYPE']      = 'POSTGRESQL';
\$DB['SERVER']    = '10.31.38.64';     // pg-01 Primary
\$DB['PORT']      = '5432';
\$DB['DATABASE']  = 'zabbix';
\$DB['USER']      = 'zabbix';
\$DB['PASSWORD']  = '${DB_PASS:-TROQUEPELASENHADOBANCO}';
\$DB['SCHEMA']    = '';

\$ZBX_SERVER      = '10.31.38.61';     // zbx-server-02 (local)
\$ZBX_SERVER_PORT = '10051';
\$ZBX_SERVER_NAME = 'Aeroporto HA';
PHP_EOF

chmod 640 /etc/zabbix/zabbix.conf.php
chown www-data:www-data /etc/zabbix/zabbix.conf.php

# Confirmar
cat /etc/zabbix/zabbix.conf.php
```

### 6.2 — Configurar Apache e PHP

```bash
# Habilitar módulos e configuração Zabbix
a2enmod rewrite
a2enconf zabbix

# Timezone PHP (todas as versões instaladas)
for f in /etc/php/*/apache2/php.ini; do
    sed -i "s|;date.timezone =|date.timezone = America/Sao_Paulo|" "$f"
    sed -i "s|^memory_limit = .*|memory_limit = 256M|" "$f"
    sed -i "s|^max_execution_time = .*|max_execution_time = 300|" "$f"
done

# Verificar
for f in /etc/php/*/apache2/php.ini; do
    echo "$f:"
    grep -E "date.timezone|memory_limit|max_execution_time" "$f"
done
```

---

## ETAPA 7 — Iniciar Apache

```bash
systemctl enable apache2
systemctl restart apache2

# Aguardar e verificar
sleep 5
systemctl status apache2 --no-pager

# Verificar acesso local ao Frontend
curl -s -o /dev/null -w "HTTP: %{http_code}\n" http://localhost/zabbix/
# Esperado: 200 ou 302
```

---

## ETAPA 8 — Troca de chaves SSH entre os nodes

> ⚠️ O diretório `/home/zabbix/.ssh` não existe por padrão — crie antes do keygen.

### 8.1 — Gerar chave no node2

```bash
mkdir -p /home/zabbix/.ssh
chown zabbix:zabbix /home/zabbix/.ssh
chmod 700 /home/zabbix/.ssh

sudo -u zabbix ssh-keygen -t rsa -b 4096 -f /home/zabbix/.ssh/id_rsa -N ""
```

### 8.2 — Copiar chave do node2 → node1

```bash
# Especificar a chave com -i para evitar erro "No identities found"
sudo -u zabbix ssh-copy-id -i /home/zabbix/.ssh/id_rsa.pub zabbix@10.31.38.60
```

### 8.3 — No node1: copiar chave do node1 → node2

```bash
# Execute este comando NO zbx-server-01 (10.31.38.60)
sudo -u zabbix ssh-copy-id -i /home/zabbix/.ssh/id_rsa.pub zabbix@10.31.38.61
```

### 8.4 — Testar SSH entre nodes

```bash
# No node2: testar acesso ao node1
sudo -u zabbix ssh zabbix@10.31.38.60 hostname

# No node1: testar acesso ao node2
# sudo -u zabbix ssh zabbix@10.31.38.61 hostname
```

---

## ETAPA 9 — Verificação final do cluster HA

```bash
# Status dos serviços no node2
systemctl status zabbix-server zabbix-agent2 apache2 --no-pager

# Portas ouvindo (10051 = Server, 80 = Frontend)
ss -tlnp | grep -E '10051|:80'

# Status HA (node1=active, node2=standby)
PGPASSWORD="${DB_PASS:-TROQUEPELASENHADOBANCO}" psql -h 10.31.38.64 -U zabbix -d zabbix \
    -c "SELECT name, address, status, lastaccess FROM ha_node;"

# Acesso ao Frontend local
curl -Ls http://localhost/zabbix/ -o /dev/null -w "HTTP: %{http_code}\n"
```

✅ **Resultado esperado:**

```
     name      |   address     | status  |     lastaccess
---------------+---------------+---------+--------------------
 zbx-server-01 | 10.31.38.60   | active  | 2026-...
 zbx-server-02 | 10.31.38.61   | standby | 2026-...
```

---

## ✅ Checklist do cluster Zabbix HA

| Item | node1 | node2 |
|---|---|---|
| `zabbix-server` | ✅ active (running) | ✅ active (running) |
| `zabbix-agent2` | ✅ active (running) | ✅ active (running) |
| `apache2` | ✅ active (running) | ✅ active (running) |
| Porta 10051 | ✅ ouvindo | ✅ ouvindo |
| Porta 80 | ✅ ouvindo | ✅ ouvindo |
| NodeID | ✅ 1 | ✅ 2 |
| HA status | ✅ active | ✅ standby |
| SSH entre nodes | ✅ | ✅ |

---

## 📌 Próximo passo

➡️ **TUTORIAL_04d** — Ativar backends Zabbix Server no HAProxy (vip-01 / vip-02)
