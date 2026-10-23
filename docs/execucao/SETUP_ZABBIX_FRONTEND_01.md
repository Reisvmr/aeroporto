# 🔧 PROCEDIMENTO DE SETUP - ZABBIX FRONTEND

**Data:** 23/10/2024  
**Versão:** 1.0  
**Status:** Pronto para execução  
**Ambiente:** Linux (CentOS/RHEL 8+, Ubuntu 20.04+, Debian 11+)

---

## 📋 PRÉ-REQUISITOS

### Informações de Conectividade
- **Servidor Zabbix Frontend:** `zbx-fe-01` (IP: A DEFINIR)
- **Zabbix Server:** `zbx-server-01` (IP: A DEFINIR, porta 10051)
- **PostgreSQL (Remoto):** `10.31.38.64:5432`
- **Usuário BD Zabbix:** `zabbix`
- **Password BD Zabbix:** `(será fornecido)`
- **Database:** `zabbix`
- **URL de Acesso:** `https://<IP-ou-FQDN>/zabbix`

### Hardware Esperado
- **CPU:** 2 vCPU
- **RAM:** 8 GB
- **Disco:** 40 GB SSD
- **Rede:** Conectividade com 10.31.38.64 (PostgreSQL) e Zabbix Server

### SO Esperado
- CentOS 8+ / RHEL 8+
- OU Ubuntu 20.04+ / Debian 11+
- Servidor zerado (fresh install)

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
  openssl openssl-devel \
  zlib zlib-devel

# Ubuntu/Debian
sudo apt-get install -y \
  wget curl git vim nano htop net-tools \
  ntp ntpdate chrony \
  build-essential \
  libssl-dev \
  zlib1g zlib1g-dev
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
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-port=10051/tcp  # Comunicação com Server
sudo firewall-cmd --reload

# Ubuntu/Debian
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 10051/tcp
sudo ufw enable
```

### 1.5 Configurar Hostname
```bash
sudo hostnamectl set-hostname zbx-fe-01
hostname
```

---

## ✅ PASSO 2: PREPARAR REPOSITÓRIOS

### 2.1 Adicionar Repositório Zabbix Oficial
```bash
# CentOS/RHEL 8
sudo yum install -y https://repo.zabbix.com/zabbix/7.0/rhel/8/x86_64/zabbix-release-7.0-1.el8.noarch.rpm

# Ubuntu 20.04
curl https://repo.zabbix.com/zabbix-official-repo.key | sudo apt-key add -
echo "deb https://repo.zabbix.com/zabbix/7.0/ubuntu focal main" | sudo tee /etc/apt/sources.list.d/zabbix.list
sudo apt-get update

# Debian 11
curl https://repo.zabbix.com/zabbix-official-repo.key | sudo apt-key add -
echo "deb https://repo.zabbix.com/zabbix/7.0/debian bullseye main" | sudo tee /etc/apt/sources.list.d/zabbix.list
sudo apt-get update
```

### 2.2 Habilitar Repositórios EPEL (CentOS/RHEL)
```bash
sudo yum install -y epel-release
```

---

## ✅ PASSO 3: INSTALAR NGINX + PHP-FPM

### 3.1 Instalar Nginx
```bash
# CentOS/RHEL
sudo yum install -y nginx

# Ubuntu/Debian
sudo apt-get install -y nginx
```

### 3.2 Instalar PHP + Extensões Zabbix
```bash
# CentOS/RHEL (usando repositório Remi)
sudo yum install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm
sudo yum install -y @php:7.4  # ou 8.0, 8.1, etc
sudo yum install -y php-fpm php-gd php-mbstring php-mysql php-pgsql php-xml php-json php-ldap php-bcmath

# Ubuntu/Debian
sudo apt-get install -y php-fpm php-gd php-mbstring php-mysql php-pgsql php-xml php-json php-ldap php-bcmath
```

### 3.3 Validar Versão PHP
```bash
php -v
# Esperado: PHP 7.4+ ou 8.0+

php-fpm -v
# Esperado: PHP 7.4+ ou 8.0+
```

---

## ✅ PASSO 4: INSTALAR ZABBIX FRONTEND

### 4.1 Instalar Frontend Zabbix
```bash
# CentOS/RHEL
sudo yum install -y zabbix-web-pgsql zabbix-web-japanese

# Ubuntu/Debian
sudo apt-get install -y zabbix-frontend-php zabbix-frontend-php-pgsql zabbix-frontend-php-japanese
```

### 4.2 Verificar Instalação
```bash
# Localizar arquivos
ls -la /usr/share/zabbix/

# Verificar diretório web
ls -la /usr/share/zabbix/ui/ 2>/dev/null || ls -la /usr/share/zabbix/web/
```

---

## ✅ PASSO 5: CONFIGURAR NGINX

### 5.1 Criar Arquivo de Configuração do Zabbix
```bash
sudo nano /etc/nginx/conf.d/zabbix.conf
```

### 5.2 Conteúdo da Configuração
```nginx
server {
    listen 80;
    listen [::]:80;
    server_name _;

    # Redirecionar HTTP para HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name _;

    # Certificados SSL ⭐ A CONFIGURAR
    ssl_certificate /etc/nginx/ssl/zabbix.crt;
    ssl_certificate_key /etc/nginx/ssl/zabbix.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    client_max_body_size 16M;
    index index.html index.htm index.php;

    # Root do Zabbix
    root /usr/share/zabbix/ui;  # ou /usr/share/zabbix/web, depende da distribuição

    # Logging
    access_log /var/log/nginx/zabbix_access.log;
    error_log /var/log/nginx/zabbix_error.log;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    # Processar arquivos PHP
    location ~ \.php$ {
        fastcgi_pass unix:/run/php-fpm.sock;  # ou 127.0.0.1:9000
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        
        # Headers para Zabbix
        fastcgi_param PHP_VALUE "post_max_size=16M
max_execution_time=300
max_input_time=300
date.timezone=America/Sao_Paulo";
    }

    # Bloquear acesso a arquivos sensíveis
    location ~ /\.ht {
        deny all;
    }

    location ~ /conf/ {
        deny all;
    }
}
```

### 5.3 Validar Configuração Nginx
```bash
sudo nginx -t
# Esperado: "syntax is ok" e "test is successful"
```

### 5.4 Iniciar Nginx
```bash
sudo systemctl enable nginx
sudo systemctl start nginx
sudo systemctl status nginx
```

---

## ✅ PASSO 6: CRIAR CERTIFICADO SSL (Auto-assinado para teste)

### 6.1 Criar Diretório SSL
```bash
sudo mkdir -p /etc/nginx/ssl
sudo cd /etc/nginx/ssl
```

### 6.2 Gerar Certificado Auto-assinado
```bash
# Este é um certificado de TESTE (válido por 365 dias)
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/zabbix.key \
  -out /etc/nginx/ssl/zabbix.crt \
  -subj "/C=BR/ST=SP/L=Sao Paulo/O=Empresa/CN=zabbix.local"

# Ajustar permissões
sudo chmod 600 /etc/nginx/ssl/zabbix.key
sudo chmod 644 /etc/nginx/ssl/zabbix.crt
```

**Nota:** Em produção, usar certificado de CA confiável (Let's Encrypt, etc)

---

## ✅ PASSO 7: CONFIGURAR PHP-FPM

### 7.1 Verificar Socket PHP-FPM
```bash
# CentOS/RHEL
ls -la /run/php-fpm.sock

# Ubuntu/Debian
ls -la /run/php/php*-fpm.sock
```

### 7.2 Ajustar se necessário
```bash
sudo nano /etc/php-fpm.d/zabbix.conf
# ou
sudo nano /etc/php/*/fpm/pool.d/zabbix.conf
```

Verificar:
```bash
listen = /run/php-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660
```

### 7.3 Iniciar PHP-FPM
```bash
sudo systemctl enable php-fpm
sudo systemctl start php-fpm
sudo systemctl status php-fpm
```

---

## ✅ PASSO 8: CONFIGURAR FRONTEND ZABBIX

### 8.1 Criar Diretório de Configuração
```bash
sudo mkdir -p /etc/zabbix/web
sudo chown www-data:www-data /etc/zabbix/web
sudo chmod 755 /etc/zabbix/web
```

### 8.2 Criar Arquivo de Configuração do Frontend
```bash
sudo nano /etc/zabbix/web/zabbix.conf.php
```

### 8.3 Conteúdo da Configuração
```php
<?php
// Zabbix Frontend Configuration File

// Banco de Dados
$DB['TYPE']     = 'POSTGRESQL';
$DB['SERVER']   = '10.31.38.64';
$DB['PORT']     = 5432;
$DB['DATABASE'] = 'zabbix';
$DB['USER']     = 'zabbix';
$DB['PASSWORD'] = '<SENHA_POSTGRES>';  // ⭐ ALTERAR
$DB['SCHEMA']   = 'public';

// Zabbix Server (para frontend comunicar)
$ZBX_SERVER      = '10.31.38.64';  // ⭐ ALTERAR para IP do zbx-server-01
$ZBX_SERVER_PORT = '10051';
$ZBX_SERVER_NAME = 'Zabbix Server';

// Timezone
date_default_timezone_set('America/Sao_Paulo');

// Session
$SESSION['HANDLER'] = 'DB';

// Segurança
$ZABBIX_COOKIE_HTTPONLY = true;
$ZABBIX_COOKIE_SAMESITE = 'Lax';

// Autenticação LDAP (opcional, deixar comentado se não usar)
// $ZBX_AUTH = 'LDAP';
// $LDAP_HOSTS = ['ldap.example.com'];

?>
```

### 8.4 Ajustar Permissões
```bash
sudo chown www-data:www-data /etc/zabbix/web/zabbix.conf.php
sudo chmod 600 /etc/zabbix/web/zabbix.conf.php
```

---

## ✅ PASSO 9: TESTES DE VALIDAÇÃO

### 9.1 Acessar Frontend via Navegador
```bash
# Abrir navegador
https://<IP-ou-FQDN>/zabbix

# Login padrão:
# Usuario: Admin
# Senha:   zabbix
```

**Esperado:** Página de login do Zabbix

### 9.2 Testar Conexão com Banco
```bash
# Do servidor Frontend
psql -h 10.31.38.64 -U zabbix -d zabbix -c "SELECT COUNT(*) FROM hosts;"
```

**Esperado:** Número de hosts (0 se novo)

### 9.3 Testar Conexão com Zabbix Server
```bash
# Do servidor Frontend
telnet <IP-zbx-server-01> 10051
```

**Esperado:** Conexão estabelecida

### 9.4 Verificar Logs
```bash
# Nginx
sudo tail -f /var/log/nginx/zabbix_access.log
sudo tail -f /var/log/nginx/zabbix_error.log

# PHP-FPM
sudo journalctl -u php-fpm -f
```

---

## ✅ PASSO 10: CONFIGURAR FRONTEND AUTOMÁTICO (Setup Wizard)

### 10.1 Acessar Setup Wizard
```
https://<IP-ou-FQDN>/zabbix/setup.php
```

### 10.2 Preencher Informações
1. **Welcome** → Next
2. **Pré-requisitos** → Verificar (PHP extensions)
3. **Database Connection**
   - Database type: PostgreSQL
   - Host: 10.31.38.64
   - Port: 5432
   - Database name: zabbix
   - User: zabbix
   - Password: <senha>
4. **Zabbix Server Details**
   - Host: <IP-zbx-server-01>
   - Port: 10051
5. **Summary** → Finish

**Esperado:** Configuração realizada com sucesso

---

## ⚠️ TROUBLESHOOTING

### Erro: "Cannot connect to database"
```bash
# Verificar conectividade
psql -h 10.31.38.64 -U zabbix -d zabbix

# Verificar firewall
sudo firewall-cmd --list-all
```

### Erro: "Cannot connect to Zabbix Server"
```bash
# Verificar conectividade
telnet <IP-zbx-server-01> 10051

# Verificar firewall no servidor Zabbix
sudo firewall-cmd --list-all
```

### Erro: "PHP extensions missing"
```bash
# Reinstalar extensões
sudo yum install -y php-mbstring php-gd php-xml php-json

# Reiniciar PHP-FPM
sudo systemctl restart php-fpm
```

### Certificado SSL auto-assinado
```bash
# Aceitar no navegador (desenvolvimento)
# Substituir em produção por certificado válido
```

---

## ✅ CHECKLIST FINAL

- [ ] Sistema operacional atualizado
- [ ] NTP sincronizado
- [ ] Firewall configurado (portas 80, 443, 10051)
- [ ] Nginx instalado e rodando
- [ ] PHP-FPM instalado e rodando
- [ ] Zabbix Frontend instalado
- [ ] Certificado SSL criado
- [ ] Configuração Nginx validada
- [ ] Conectividade com PostgreSQL (10.31.38.64) testada
- [ ] Conectividade com Zabbix Server testada
- [ ] Frontend acessível via HTTPS
- [ ] Setup Wizard executado com sucesso
- [ ] Login frontend funcionando

---

## 📞 PRÓXIMA ETAPA

Após completar este procedimento com sucesso:
1. Configurar PostgreSQL no servidor 10.31.38.64 (próximo documento)
2. Testar coleta do primeiro host
3. Configurar Keepalived para VIP (failover)

---

**Status:** ✅ Pronto para execução  
**Data:** 23/10/2024  
**Versão:** 1.0
