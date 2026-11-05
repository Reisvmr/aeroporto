# 🌐 TUTORIAL 04b — Zabbix Frontend · NODE 1 (zbx-fe-01)

> **Servidor:** zbx-fe-01 — IP `10.31.38.62`  
> **Objetivo:** Instalar o Zabbix Frontend (Apache + PHP) no primeiro nó web  
> **Pré-requisito:** TUTORIAL_04d (backends Zabbix Server no HAProxy) concluído

---

## 📋 Pré-requisitos

- zbx-server-01 (`10.31.38.60`) e zbx-server-02 (`10.31.38.61`) rodando
- PostgreSQL HA (pg-01 `10.31.38.64`) operacional
- HAProxy + Keepalived configurados (VIP `10.31.38.72`)
- IP estático `10.31.38.62` já configurado neste servidor

---

## 🔧 Variável — defina antes de executar

```bash
export DB_PASS="TROQUEPELASENHADOBANCO"   # Mesma senha do banco zabbix
```

---

## ETAPA 1 — Verificar pré-requisitos

```bash
# Confirmar IP do node
hostname -I | awk '{print $1}'
# Esperado: 10.31.38.62

# Testar conectividade com PostgreSQL
timeout 5 bash -c '</dev/tcp/10.31.38.64/5432' && echo "✓ pg-01 acessível" || echo "✗ pg-01 INACESSÍVEL"

# Testar conectividade com Zabbix Server
timeout 5 bash -c '</dev/tcp/10.31.38.60/10051' && echo "✓ zbx-server-01 acessível" || echo "✗ zbx-server-01 INACESSÍVEL"

# Testar SSH nos VIPs (necessário para ativar backends HAProxy)
timeout 5 bash -c '</dev/tcp/10.31.38.70/22' && echo "✓ vip-01:22 acessível" || echo "✗ vip-01:22 INACESSÍVEL"
timeout 5 bash -c '</dev/tcp/10.31.38.71/22' && echo "✓ vip-02:22 acessível" || echo "✗ vip-02:22 INACESSÍVEL"

# Verificar espaço em /var (mínimo 5GB)
df -BG /var | awk 'NR==2{print $4}'
```

---

## ETAPA 2 — Instalar Apache2 + PHP + Zabbix Frontend

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

# Instalar Apache + PHP + Zabbix Frontend
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apache2 php php-xml php-bcmath php-mbstring php-gd \
    php-ldap php-pgsql php-curl libapache2-mod-php \
    zabbix-frontend-php zabbix-apache-conf
```

✅ **Verificação:** `php -v && apache2 -v`

---

## ETAPA 3 — Configurar zabbix.conf.php

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

\$ZBX_SERVER      = '10.31.38.60';     // zbx-server-01
\$ZBX_SERVER_PORT = '10051';
\$ZBX_SERVER_NAME = 'Aeroporto HA';
PHP_EOF

chmod 640 /etc/zabbix/zabbix.conf.php
chown www-data:www-data /etc/zabbix/zabbix.conf.php

# Confirmar
cat /etc/zabbix/zabbix.conf.php
```

---

## ETAPA 4 — Configurar Apache e PHP

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

## ETAPA 5 — Configurar firewall

```bash
ufw allow 80/tcp comment "Zabbix Frontend"
ufw allow ssh
ufw --force enable
ufw status verbose
```

---

## ETAPA 6 — Iniciar serviços

```bash
systemctl enable apache2
systemctl restart apache2

# Aguardar e verificar
sleep 5
systemctl status apache2 --no-pager

# Testar acesso local
curl -s -o /dev/null -w "HTTP: %{http_code}\n" http://localhost/zabbix/
# Esperado: 200 ou 302
```

---

## ETAPA 7 — Verificação final

```bash
# Status do Apache
systemctl status apache2 --no-pager

# Porta 80 ouvindo
ss -tlnp | grep ':80'

# Módulos PHP necessários
php -m | grep -E 'pgsql|gd|mbstring|xml|bcmath|ldap|curl'

# Acesso à interface web local
curl -Ls http://localhost/zabbix/ -o /dev/null -w "HTTP: %{http_code}\n"
```

✅ **Resultado esperado:**

| Item | Esperado |
|---|---|
| `apache2` | `active (running)` |
| Porta 80 | ouvindo |
| HTTP `/zabbix/` | 200 ou 302 |
| Módulos PHP | pgsql, gd, mbstring, xml |

---

## 📌 Próximo passo

➡️ **TUTORIAL_04e** — Instalar Zabbix Frontend node2 (`zbx-fe-02 / 10.31.38.63`)
