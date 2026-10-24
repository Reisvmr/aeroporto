#!/bin/bash

################################################################################
#                                                                              #
#  SCRIPT DE INSTALAÇÃO AUTOMATIZADA - ZABBIX FRONTEND 7.0 LTS                #
#                                                                              #
#  Projeto: Aeroporto - Zabbix 7.0 LTS + PostgreSQL 16                        #
#  Data: 24/10/2026                                                           #
#  Versão: 1.0                                                                #
#  Servidor: zbx-fe-01 (10.31.38.62)                                          #
#                                                                              #
#  OBJETIVO:                                                                   #
#    Instalação completa e automatizada do Zabbix Frontend 7.0 LTS            #
#    Nginx + PHP-FPM + Interface web                                          #
#    Conectado a PostgreSQL remoto + Zabbix Server remoto                     #
#                                                                              #
#  PRÉ-REQUISITOS:                                                             #
#    - SO: Ubuntu 20.04+ / CentOS 8+ / Debian 11+                             #
#    - Acesso root ou sudo                                                    #
#    - CPU: 4 vCPU (mínimo) - UPGRADEAR DE 2 VCPU                             #
#    - RAM: 8+ GB (mínimo)                                                    #
#    - Disco: 50+ GB livres                                                   #
#    - PostgreSQL 16 rodando em pg-01 (10.31.38.64:5432)                      #
#    - Zabbix Server rodando em zbx-server-01 (10.31.38.60:10051)             #
#    - NTP sincronizado                                                       #
#    - Conectividade TCP 5432 (PostgreSQL) e TCP 10051 (Zabbix Server)        #
#                                                                              #
#  DEPENDÊNCIAS:                                                               #
#    - PostgreSQL 16 (pg-01: 10.31.38.64:5432)                                #
#    - Zabbix Server (zbx-server-01: 10.31.38.60:10051)                       #
#    - Database 'zabbix' já inicializado                                      #
#                                                                              #
#  USO:                                                                        #
#    sudo bash 03-zabbix-frontend.sh                                          #
#                                                                              #
#  AUTHOR: Vinicius Reis (reisvmr@gmail.com)                                  #
#  LICENSE: MIT                                                               #
#                                                                              #
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURAÇÕES
# ============================================================================

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Variáveis de configuração (podem ser sobrescritas)
ZABBIX_VERSION="${ZABBIX_VERSION:-7.0}"
ZABBIX_RELEASE="${ZABBIX_RELEASE:-7.0.0}"
ZABBIX_HOST="${ZABBIX_HOST:-zbx-fe-01}"
ZABBIX_IP="${ZABBIX_IP:-10.31.38.62}"
ZABBIX_SERVER="${ZABBIX_SERVER:-10.31.38.60}"
ZABBIX_SERVER_PORT="${ZABBIX_SERVER_PORT:-10051}"

PG_HOST="${PG_HOST:-10.31.38.64}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-zabbix}"
PG_DB="${PG_DB:-zabbix}"
PG_PASSWORD="${PG_PASSWORD:-}"

LOG_FILE="${LOG_FILE:-/var/log/zabbix-frontend-install.log}"
ZABBIX_USER="${ZABBIX_USER:-zabbix}"
ZABBIX_GROUP="${ZABBIX_GROUP:-zabbix}"
TIMEZONE="${TIMEZONE:-America/Sao_Paulo}"
WEB_USER="${WEB_USER:-www-data}"
WEB_GROUP="${WEB_GROUP:-www-data}"

# Flags
SKIP_VALIDATION="${SKIP_VALIDATION:-false}"
DRY_RUN="${DRY_RUN:-false}"
INTERACTIVE="${INTERACTIVE:-true}"

# ============================================================================
# FUNÇÕES COMPARTILHADAS
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[⚠]${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*" | tee -a "$LOG_FILE"
}

log_debug() {
    if [ "${DEBUG:-false}" == "true" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $*" | tee -a "$LOG_FILE"
    fi
}

confirm() {
    if [ "$INTERACTIVE" == "false" ]; then
        return 0
    fi
    
    local prompt="$1"
    local response
    read -p "$prompt (s/n): " -r response
    [[ "$response" =~ ^[Ss]$ ]]
}

run_cmd() {
    local cmd="$1"
    local desc="${2:-Executando comando}"
    
    log_debug "Executando: $cmd"
    
    if [ "$DRY_RUN" == "true" ]; then
        log_info "[DRY RUN] $desc: $cmd"
        return 0
    fi
    
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        log_success "$desc"
        return 0
    else
        log_error "FALHOU: $desc"
        return 1
    fi
}

# ============================================================================
# PRÉ-REQUISITOS
# ============================================================================

check_prerequisites() {
    log_info "Verificando pré-requisitos..."
    
    # Verificar se é root
    if [ "$EUID" -ne 0 ]; then
        log_error "Este script deve ser executado como root"
        exit 1
    fi
    
    # Detectar SO
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_ID="$ID"
    else
        log_error "Não foi possível detectar o SO"
        exit 1
    fi
    
    log_info "SO Detectado: $OS_NAME ($OS_ID)"
    
    # Validar SO suportado
    case "$OS_ID" in
        ubuntu|debian)
            log_info "Debian/Ubuntu detectado"
            PKG_MANAGER="apt-get"
            PKG_UPDATE="apt-get update"
            ;;
        centos|rhel)
            log_info "CentOS/RHEL detectado"
            PKG_MANAGER="yum"
            PKG_UPDATE="yum makecache"
            ;;
        *)
            log_error "SO não suportado: $OS_ID"
            exit 1
            ;;
    esac
    
    # Verificar CPU (avisar se < 4 vCPU)
    local cpu_count=$(nproc)
    if [ "$cpu_count" -lt 4 ]; then
        log_warn "CPU insuficiente: $cpu_count vCPU (recomendado: 4+)"
        if ! confirm "Continuar mesmo assim?"; then
            exit 1
        fi
    else
        log_success "CPU OK: $cpu_count vCPU"
    fi
    
    # Verificar RAM (avisar se < 8 GB)
    local ram_gb=$(free -g | awk 'NR==2 {print $2}')
    if [ "$ram_gb" -lt 8 ]; then
        log_warn "RAM baixa: ${ram_gb}GB (recomendado: 8+GB)"
        if ! confirm "Continuar mesmo assim?"; then
            exit 1
        fi
    else
        log_success "RAM OK: ${ram_gb}GB"
    fi
    
    # Verificar espaço em disco
    local disk_free=$(df / | awk 'NR==2 {print $4}')
    if [ "$disk_free" -lt 51200000 ]; then
        log_error "Espaço em disco insuficiente (< 50 GB livres)"
        exit 1
    fi
    log_success "Espaço em disco OK: $(( disk_free / 1024 / 1024 )) GB"
    
    # Verificar NTP
    if ! systemctl is-active --quiet chrony && ! systemctl is-active --quiet ntpd; then
        log_warn "NTP não está sincronizado. Frontend pode não sincronizar com Server."
        if ! confirm "Continuar mesmo assim?"; then
            exit 1
        fi
    else
        log_success "NTP sincronizado"
    fi
    
    log_success "Pré-requisitos verificados"
}

# ============================================================================
# INSTALAÇÃO DE PACOTES BÁSICOS
# ============================================================================

install_base_packages() {
    log_info "Instalando pacotes básicos..."
    
    case "$OS_ID" in
        ubuntu|debian)
            run_cmd "$PKG_UPDATE" "Atualizar repositórios"
            run_cmd "apt-get install -y curl wget git vim htop net-tools telnet jq" \
                "Instalar ferramentas básicas"
            ;;
        centos|rhel)
            run_cmd "$PKG_UPDATE" "Atualizar repositórios"
            run_cmd "yum install -y curl wget git vim htop net-tools telnet jq" \
                "Instalar ferramentas básicas"
            ;;
    esac
    
    log_success "Pacotes básicos instalados"
}

# ============================================================================
# INSTALAR NGINX
# ============================================================================

install_nginx() {
    log_info "Instalando Nginx..."
    
    case "$OS_ID" in
        ubuntu|debian)
            run_cmd "apt-get install -y nginx" \
                "Instalar Nginx"
            ;;
        centos|rhel)
            run_cmd "yum install -y nginx" \
                "Instalar Nginx"
            ;;
    esac
    
    # Habilitar auto-start
    run_cmd "systemctl enable nginx" \
        "Habilitar Nginx auto-start"
    
    log_success "Nginx instalado"
}

# ============================================================================
# INSTALAR PHP-FPM
# ============================================================================

install_php_fpm() {
    log_info "Instalando PHP-FPM..."
    
    case "$OS_ID" in
        ubuntu|debian)
            run_cmd "apt-get install -y php-fpm php-pgsql php-mbstring php-gd php-bcmath php-xml php-ldap" \
                "Instalar PHP-FPM e módulos"
            run_cmd "systemctl enable php-fpm" \
                "Habilitar PHP-FPM auto-start"
            ;;
        centos|rhel)
            run_cmd "yum install -y php-fpm php-pgsql php-mbstring php-gd php-bcmath php-xml php-ldap" \
                "Instalar PHP-FPM e módulos"
            run_cmd "systemctl enable php-fpm" \
                "Habilitar PHP-FPM auto-start"
            ;;
    esac
    
    log_success "PHP-FPM instalado"
}

# ============================================================================
# CONFIGURAR PHP-FPM
# ============================================================================

configure_php_fpm() {
    log_info "Configurando PHP-FPM..."
    
    # Detectar versão PHP
    local php_version=$(php -r 'echo PHP_VERSION;' | cut -d. -f1,2)
    local php_pool="/etc/php/${php_version}/fpm/pool.d/www.conf"
    
    if [ ! -f "$php_pool" ]; then
        log_warn "Arquivo de pool PHP-FPM não encontrado: $php_pool"
        return 0
    fi
    
    # Fazer backup
    run_cmd "cp $php_pool ${php_pool}.backup" \
        "Backup www.conf"
    
    # Configurar para melhor performance
    sed -i 's/^pm\.max_children.*/pm.max_children = 50/' "$php_pool"
    sed -i 's/^pm\.start_servers.*/pm.start_servers = 10/' "$php_pool"
    sed -i 's/^pm\.min_spare_servers.*/pm.min_spare_servers = 5/' "$php_pool"
    sed -i 's/^pm\.max_spare_servers.*/pm.max_spare_servers = 35/' "$php_pool"
    
    log_success "PHP-FPM configurado"
}

# ============================================================================
# CONFIGURAR NGINX VHOST
# ============================================================================

configure_nginx_vhost() {
    log_info "Configurando Nginx vhost..."
    
    # Desabilitar site default
    if [ -f /etc/nginx/sites-enabled/default ]; then
        rm -f /etc/nginx/sites-enabled/default
    fi
    
    # Criar vhost para Zabbix
    local vhost_file="/etc/nginx/sites-available/zabbix"
    cat > "$vhost_file" << 'EOF'
# Zabbix Frontend Nginx Configuration

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    server_name zbx-fe-01 zbx.example.com localhost;
    
    root /usr/share/zabbix;
    index index.php index.html;
    
    # Logs
    access_log /var/log/nginx/zabbix-access.log combined;
    error_log /var/log/nginx/zabbix-error.log warn;
    
    # Segurança
    client_max_body_size 16M;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript 
               application/json application/javascript application/xml+rss;
    
    # Timeouts
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    
    # Localizações
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PHP_VALUE "post_max_size=16M
upload_max_filesize=16M
max_execution_time=300
max_input_time=300";
    }
    
    # Negar acesso a arquivos sensíveis
    location ~ /\. {
        deny all;
    }
    
    location ~ ~$ {
        deny all;
    }
}
EOF
    
    run_cmd "ln -sf $vhost_file /etc/nginx/sites-enabled/zabbix" \
        "Habilitar vhost Zabbix"
    
    # Testar configuração
    if nginx -t > /dev/null 2>&1; then
        run_cmd "systemctl restart nginx" \
            "Reiniciar Nginx"
    else
        log_error "Configuração Nginx inválida"
        return 1
    fi
    
    log_success "Nginx vhost configurado"
}

# ============================================================================
# ADICIONAR REPOSITÓRIO ZABBIX
# ============================================================================

setup_zabbix_repo() {
    log_info "Configurando repositório Zabbix..."
    
    case "$OS_ID" in
        ubuntu|debian)
            run_cmd "wget -q -O /tmp/zabbix-release.deb https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/ubuntu/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_RELEASE}-1+ubuntu$(lsb_release -rs)_all.deb" \
                "Download Zabbix repository deb"
            run_cmd "dpkg -i /tmp/zabbix-release.deb" \
                "Instalar Zabbix repository"
            run_cmd "apt-get update" \
                "Atualizar repositórios"
            ;;
        centos|rhel)
            run_cmd "rpm -Uvh https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/rhel/$(rpm -q --queryformat '%{VERSION}' centos-release)/x86_64/zabbix-release-${ZABBIX_RELEASE}-1.el$(rpm -q --queryformat '%{VERSION}' centos-release).noarch.rpm" \
                "Instalar Zabbix repository"
            run_cmd "yum makecache" \
                "Atualizar repositórios"
            ;;
    esac
    
    log_success "Repositório Zabbix configurado"
}

# ============================================================================
# INSTALAR ZABBIX FRONTEND
# ============================================================================

install_zabbix_frontend() {
    log_info "Instalando Zabbix Frontend..."
    
    case "$OS_ID" in
        ubuntu|debian)
            run_cmd "apt-get install -y zabbix-frontend-php zabbix-sql-scripts" \
                "Instalar Zabbix Frontend"
            ;;
        centos|rhel)
            run_cmd "yum install -y zabbix-web-pgsql zabbix-sql-scripts" \
                "Instalar Zabbix Frontend"
            ;;
    esac
    
    log_success "Zabbix Frontend instalado"
}

# ============================================================================
# CONFIGURAR ZABBIX WEB
# ============================================================================

configure_zabbix_web() {
    log_info "Configurando Zabbix Web..."
    
    local web_config="/etc/zabbix/web/zabbix.conf.php"
    
    # Criar configuração
    cat > "$web_config" << EOF
<?php
// Zabbix configuration file
// Auto-generated by installation script

\$ZBX_SERVER = '$ZABBIX_SERVER';
\$ZBX_SERVER_PORT = $ZABBIX_SERVER_PORT;
\$ZBX_SERVER_NAME = 'Zabbix - Aeroporto';

\$DB['TYPE']     = 'POSTGRESQL';
\$DB['SERVER']   = '$PG_HOST';
\$DB['PORT']     = $PG_PORT;
\$DB['DATABASE'] = '$PG_DB';
\$DB['USER']     = '$PG_USER';
\$DB['PASSWORD'] = '$PG_PASSWORD';
\$DB['SCHEMA']   = 'public';

// Timezone
\$ZBX_TIMEZONE   = '$TIMEZONE';

// Session
\$SESSION_KEY_SECRET = '$(openssl rand -hex 16)';

// Image export
\$IMAGE_FORMAT_DEFAULT = IMAGE_FORMAT_PNG;
EOF
    
    run_cmd "chown $WEB_USER:$WEB_GROUP $web_config" \
        "Configurar permissões zabbix.conf.php"
    
    run_cmd "chmod 640 $web_config" \
        "Restringir acesso zabbix.conf.php"
    
    log_success "Zabbix Web configurado"
}

# ============================================================================
# INSTALAR POSTGRESQL CLIENT
# ============================================================================

install_postgres_client() {
    log_info "Instalando PostgreSQL client..."
    
    case "$OS_ID" in
        ubuntu|debian)
            run_cmd "apt-get install -y postgresql-client libpq5 libpq-dev" \
                "Instalar PostgreSQL client"
            ;;
        centos|rhel)
            run_cmd "yum install -y postgresql" \
                "Instalar PostgreSQL client"
            ;;
    esac
    
    log_success "PostgreSQL client instalado"
}

# ============================================================================
# CONFIGURAR FIREWALL
# ============================================================================

configure_firewall() {
    log_info "Configurando firewall..."
    
    case "$OS_ID" in
        ubuntu|debian)
            if command -v ufw &> /dev/null; then
                run_cmd "ufw allow 80/tcp" \
                    "Permitir porta 80 (UFW)"
                run_cmd "ufw allow 443/tcp" \
                    "Permitir porta 443 (UFW)"
            fi
            ;;
        centos|rhel)
            if systemctl is-active --quiet firewalld; then
                run_cmd "firewall-cmd --permanent --add-port=80/tcp" \
                    "Permitir porta 80 (firewalld)"
                run_cmd "firewall-cmd --permanent --add-port=443/tcp" \
                    "Permitir porta 443 (firewalld)"
                run_cmd "firewall-cmd --reload" \
                    "Recarregar firewall"
            fi
            ;;
    esac
    
    log_success "Firewall configurado"
}

# ============================================================================
# VALIDAÇÃO PÓS-INSTALAÇÃO
# ============================================================================

validate_installation() {
    log_info "Validando instalação..."
    
    local errors=0
    
    # Verificar se Nginx está rodando
    if ! systemctl is-active --quiet nginx; then
        log_error "Nginx não está rodando"
        ((errors++))
    else
        log_success "Nginx está rodando"
    fi
    
    # Verificar se PHP-FPM está rodando
    if ! systemctl is-active --quiet php-fpm; then
        log_error "PHP-FPM não está rodando"
        ((errors++))
    else
        log_success "PHP-FPM está rodando"
    fi
    
    # Verificar porta HTTP
    if ! netstat -tlnap 2>/dev/null | grep -q ":80"; then
        log_error "Nginx não está escutando na porta 80"
        ((errors++))
    else
        log_success "Nginx escutando na porta 80"
    fi
    
    # Verificar frontend directory
    if [ -d /usr/share/zabbix ]; then
        log_success "Diretório Zabbix Frontend existe"
    else
        log_error "Diretório Zabbix Frontend não existe"
        ((errors++))
    fi
    
    # Verificar conectividade PostgreSQL
    if ! psql -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" -c "SELECT 1" > /dev/null 2>&1; then
        log_error "Falha ao conectar no PostgreSQL"
        ((errors++))
    else
        log_success "Conectividade PostgreSQL OK"
    fi
    
    if [ $errors -eq 0 ]; then
        log_success "Todas as validações passaram!"
        return 0
    else
        log_error "Total de erros: $errors"
        return 1
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    log_info "=========================================="
    log_info "INSTALAÇÃO ZABBIX FRONTEND 7.0 - INICIADO"
    log_info "=========================================="
    log_info "SO: $OS_NAME"
    log_info "Zabbix Versão: $ZABBIX_VERSION"
    log_info "Zabbix Server: $ZABBIX_SERVER:$ZABBIX_SERVER_PORT"
    log_info "PostgreSQL: $PG_HOST:$PG_PORT"
    log_info "Data: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Log: $LOG_FILE"
    
    # Executar etapas
    check_prerequisites || exit 1
    install_base_packages || exit 1
    install_postgres_client || exit 1
    install_nginx || exit 1
    install_php_fpm || exit 1
    configure_php_fpm || exit 1
    configure_nginx_vhost || exit 1
    setup_zabbix_repo || exit 1
    install_zabbix_frontend || exit 1
    configure_zabbix_web || exit 1
    configure_firewall || exit 1
    
    # Validar
    if validate_installation; then
        log_success "=========================================="
        log_success "INSTALAÇÃO ZABBIX FRONTEND CONCLUÍDA COM SUCESSO"
        log_success "=========================================="
        log_info "Acesse o frontend em: http://$ZABBIX_IP"
        log_info "Credenciais padrão: Admin / zabbix"
        log_info "Arquivo de configuração: /etc/zabbix/web/zabbix.conf.php"
        log_info "Logs Nginx: /var/log/nginx/zabbix-*.log"
        return 0
    else
        log_error "=========================================="
        log_error "VALIDAÇÃO FALHOU"
        log_error "=========================================="
        log_error "Revise o log: $LOG_FILE"
        return 1
    fi
}

# Executar main
main "$@"
