# 🌐 TUTORIAL — Zabbix Frontend HA (Apache + PHP)

> **Script:** `04b-zabbix-frontend-ha.sh`
> **Objetivo:** Instalar o Zabbix Frontend (interface web) nos servidores zbx-fe-01 e zbx-fe-02
> **Servidores:** zbx-fe-01 (`10.31.38.62`) e zbx-fe-02 (`10.31.38.63`)
> **VIP cliente:** `10.31.38.72` — HAProxy roteia entre zbx-fe-01 e zbx-fe-02
> **Semana:** 3b (após instalação do Zabbix Server — script 04)

---

## 🗺️ Visão geral

| Componente | Servidor | IP |
|------------|----------|----|
| Zabbix Server | zbx-server-01 / zbx-server-02 | 10.31.38.60 / 10.31.38.61 |
| **Zabbix Frontend** | **zbx-fe-01 / zbx-fe-02** | **10.31.38.62 / 10.31.38.63** |
| Banco de dados | pg-01 / pg-02 | 10.31.38.64 / 10.31.38.65 |
| VIP de acesso | HAProxy em vip-01/vip-02 | **10.31.38.72** |

> ⚠️ O **Zabbix Server** (daemon de monitoramento) roda em zbx-server-01/02.
> O **Zabbix Frontend** (interface web Apache/PHP) roda em zbx-fe-01/02 — **servidores separados**.

---

## 📋 Pré-requisitos

- ✅ Script `04-zabbix-server-ha.sh` concluído (zbx-server-01/02)
- ✅ PostgreSQL HA rodando (pg-01 `10.31.38.64` + pg-02 `10.31.38.65`)
- ✅ HAProxy + Keepalived configurados (script 03, VIP `10.31.38.72`)
- IPs estáticos: zbx-fe-01 `10.31.38.62` · zbx-fe-02 `10.31.38.63`
- Acesso root/sudo em zbx-fe-01 e zbx-fe-02

---

## ETAPA 1 — Verificar pré-requisitos

> 🖥️ **Execute em: zbx-fe-01 E zbx-fe-02** (verificação independente em cada servidor)

```bash
# Confirmar IP do servidor
hostname -I | awk '{print $1}'
# Esperado: 10.31.38.62 (zbx-fe-01) | 10.31.38.63 (zbx-fe-02)

# Verificar acesso ao banco
timeout 5 bash -c '</dev/tcp/10.31.38.64/5432' && echo "✓ pg-01:5432" || echo "✗ pg-01:5432"

# Verificar acesso ao Zabbix Server
timeout 5 bash -c '</dev/tcp/10.31.38.60/10051' && echo "✓ zbx-server-01:10051" || echo "✗ zbx-server-01:10051"

# Verificar acesso SSH aos vips (necessário para ativar backend HAProxy)
timeout 5 bash -c '</dev/tcp/10.31.38.70/22' && echo "✓ vip-01:22" || echo "✗ vip-01:22"
timeout 5 bash -c '</dev/tcp/10.31.38.71/22' && echo "✓ vip-02:22" || echo "✗ vip-02:22"
```

---

## ETAPA 2 — Instalar Apache2 + PHP + Zabbix Frontend

> 🖥️ **Execute em: zbx-fe-01 E zbx-fe-02** (mesmos pacotes nos dois servidores)

```bash
# Adicionar repositório Zabbix 7.0
wget -qO /tmp/zabbix-release.deb \
  https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
dpkg -i /tmp/zabbix-release.deb
apt-get update

# Instalar
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apache2 php php-xml php-bcmath php-mbstring php-gd \
    php-ldap php-pgsql php-curl libapache2-mod-php \
    zabbix-frontend-php zabbix-apache-conf
```

---

## ETAPA 3 — Configurar zabbix.conf.php

> 🖥️ **Execute em: zbx-fe-01 E zbx-fe-02** (mesma configuração nos dois)

```bash
cat > /etc/zabbix/zabbix.conf.php << 'PHP_EOF'
<?php
global $DB;

$DB['TYPE']      = 'POSTGRESQL';
$DB['SERVER']    = '10.31.38.64';     # pg-01 Primary
$DB['PORT']      = '5432';
$DB['DATABASE']  = 'zabbix';
$DB['USER']      = 'zabbix';
$DB['PASSWORD']  = 'zabbix123';       # trocar conforme instalação
$DB['SCHEMA']    = '';

$ZBX_SERVER      = '10.31.38.60';     # zbx-server-01
$ZBX_SERVER_PORT = '10051';
$ZBX_SERVER_NAME = 'Aeroporto HA';
PHP_EOF

chmod 640 /etc/zabbix/zabbix.conf.php
chown www-data:www-data /etc/zabbix/zabbix.conf.php
```

---

## ETAPA 4 — Configurar Apache e PHP

> 🖥️ **Execute em: zbx-fe-01 E zbx-fe-02**

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

# Reiniciar Apache
systemctl enable apache2
systemctl restart apache2
```

✅ **Verificação:**
```bash
systemctl status apache2 --no-pager
curl -s -o /dev/null -w "%{http_code}" http://localhost/zabbix/
# Esperado: 200 ou 302
```

---

## ETAPA 5 — Configurar firewall

> 🖥️ **Execute em: zbx-fe-01 E zbx-fe-02**

```bash
ufw allow 80/tcp comment "Zabbix Frontend"
ufw allow ssh
ufw --force enable
ufw status verbose
```

---

## ETAPA 6 — Iniciar serviços

> 🖥️ **Execute em: zbx-fe-01 E zbx-fe-02**

```bash
systemctl enable apache2
systemctl restart apache2
systemctl status apache2 --no-pager

# Testar acesso local
curl -s -o /dev/null -w "HTTP: %{http_code}\n" http://localhost/zabbix/
```

---

## ⚡ ETAPA FINAL — Ativação do Backend no HAProxy

> Esta etapa é executada **automaticamente** pelo script `04b-zabbix-frontend-ha.sh` ao final da instalação.
> Se o SSH para vip-01/vip-02 não estiver disponível, execute manualmente.

### Execução automática (pelo script)

O script conecta via SSH em **vip-01** (`10.31.38.70`) e **vip-02** (`10.31.38.71`) e:
1. Ativa os backends via **HAProxy Runtime API** (efeito imediato, sem interrupção)
2. Atualiza `/etc/haproxy/haproxy.cfg` (persistência após reload)
3. Executa `systemctl reload haproxy`

### Execução manual (se SSH falhar)

Execute em **vip-01 E em vip-02**:

```bash
# 1. Ativar via Runtime API (imediato)
echo 'enable server backend_zabbix_frontend/zbx_fe_01' | socat /run/haproxy/admin.sock stdio
echo 'enable server backend_zabbix_frontend/zbx_fe_02' | socat /run/haproxy/admin.sock stdio

# 2. Persistência no config
sed -i 's/zbx_fe_01 10.31.38.62:80 disabled/zbx_fe_01 10.31.38.62:80 check inter 5s fall 3 rise 2/' /etc/haproxy/haproxy.cfg
sed -i 's/zbx_fe_02 10.31.38.63:80 disabled/zbx_fe_02 10.31.38.63:80 check inter 5s fall 3 rise 2/' /etc/haproxy/haproxy.cfg

# 3. Validar e recarregar
haproxy -c -f /etc/haproxy/haproxy.cfg && systemctl reload haproxy
```

### Validação pós-ativação

> 🖥️ **Execute em: vip-01 OU vip-02**

```bash
# Status dos backends Zabbix Frontend
echo 'show servers state backend_zabbix_frontend' | socat /run/haproxy/admin.sock stdio

# Stats HAProxy
curl -s -u admin:haproxy@stats 'http://10.31.38.70:8404/stats' | grep -i zbx_fe
```

> 🖥️ **Execute em: qualquer máquina com acesso à rede**

```bash
# Acesso via VIP-Zabbix-Web
curl -sk http://10.31.38.72/zabbix/ -o /dev/null -w "HTTP: %{http_code}\n"
# Esperado: 200 ou 302
```

> ✅ Backends devem aparecer como **UP** nas stats: `http://10.31.38.70:8404/stats`

---

## 📝 Próximos passos

1. Acesse: `http://10.31.38.72/zabbix` e troque a senha do admin (padrão: `Admin / zabbix`)
2. Configure o data source do Grafana para apontar para `http://10.31.38.72/zabbix/api_jsonrpc.php`
3. Prossiga com `05-grafana-ha.sh` (Semana 4)

---

## 🔍 Monitoramento

> 🖥️ **Execute em: zbx-fe-01 OU zbx-fe-02**

```bash
# Logs Apache
tail -f /var/log/apache2/error.log
tail -f /var/log/apache2/access.log

# Status
systemctl status apache2 --no-pager

# Verificar PHP está funcionando
php -v
php -m | grep -E 'pgsql|gd|mbstring|xml'
```
