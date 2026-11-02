#!/bin/bash

################################################################################
# Script: 04b-zabbix-frontend-ha.sh
# Descrição: Instalação Zabbix Frontend 7.0 LTS (Apache + PHP) em HA
# Data: 27/10/2026
# Versão: 1.0 (HA)
# Servidores: zbx-fe-01 (10.31.38.62) / zbx-fe-02 (10.31.38.63)
# Autor: Aeroporto - Infraestrutura HA
#
# Uso: sudo ./04b-zabbix-frontend-ha.sh <node1|node2>
#
# Exemplo:
#   Em zbx-fe-01: sudo ./04b-zabbix-frontend-ha.sh node1
#   Em zbx-fe-02: sudo ./04b-zabbix-frontend-ha.sh node2
#
# Pré-requisitos:
#   - PostgreSQL HA (pg-01/pg-02) já instalado e rodando
#   - Zabbix Server HA (zbx-server-01/02) já instalado e rodando (script 04)
#   - VIP-Zabbix-Web 10.31.38.72 já configurado (HAProxy+Keepalived em vip-01/vip-02)
#   - IPs estáticos: 10.31.38.62 (node1) / 10.31.38.63 (node2)
#
# Configura:
#   - Apache2 + PHP 8.x
#   - Zabbix Frontend 7.0 LTS
#   - Conexão ao banco PostgreSQL via pg-01 (10.31.38.64)
#   - Ativa backend_zabbix_frontend no HAProxy ao final (via SSH em vip-01/vip-02)
#
################################################################################

set +e  # Não parar em erros - vamos tratar com exit codes


# ═══════════════════════════════════════════════════════════════════════════
# TRATAMENTO DE ERROS - Função auxiliar
# ═══════════════════════════════════════════════════════════════════════════

handle_error() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        return $exit_code
    fi
    return 0
}

trap 'handle_error' ERR

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURAÇÕES
# ═══════════════════════════════════════════════════════════════════════════

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parâmetros
NODE_TYPE="${1:-}"  # node1 ou node2
ZABBIX_VERSION="7.0"

# Database (Zabbix usa o mesmo DB do Zabbix Server)
PG_HOST="10.31.38.64"   # pg-01 Primary
PG_STANDBY="10.31.38.65"
PG_PORT="5432"
DB_NAME="zabbix"
DB_USER="zabbix"
DB_PASS="${DB_PASS:-zabbix123}"

# IPs zbx-fe
ZBXFE_NODE1="10.31.38.62"
ZBXFE_NODE2="10.31.38.63"
ZABBIX_VIP="10.31.38.72"   # VIP-Zabbix-Web (acesso cliente)

# Zabbix Server (backend)
ZABBIX_SERVER_HOST="10.31.38.60"  # zbx-server-01

# HAProxy VIPs (vip-01/vip-02)
HAPROXY_VIP1="10.31.38.70"
HAPROXY_VIP2="10.31.38.71"

# Data
DATA=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="/tmp/zabbix-frontend-ha-install-$(date +%s).log"

# ═══════════════════════════════════════════════════════════════════════════
# FUNÇÕES
# ═══════════════════════════════════════════════════════════════════════════

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                    ║"
    echo "║  🌐 INSTALAÇÃO ZABBIX FRONTEND 7.0 HA - PROJETO AEROPORTO (HA)    ║"
    echo "║                                                                    ║"
    echo "║  Node Type: $NODE_TYPE"
    echo "║  Servidores: zbx-fe-01 (10.31.38.62) + zbx-fe-02 (10.31.38.63)   ║"
    echo "║  Database: PostgreSQL HA (10.31.38.64/65)                        ║"
    echo "║  VIP-Zabbix-Web: 10.31.38.72  (HAProxy em vip-01/vip-02)         ║"
    echo "║                                                                    ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_ok() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"
}

print_erro() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"
}

print_section() {
    echo "" | tee -a "$LOG_FILE"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}$1${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
}

# ═══════════════════════════════════════════════════════════════════════════
# VERIFICAR PRÉ-REQUISITOS
# ═══════════════════════════════════════════════════════════════════════════

verificar_prerequisitos() {
    print_section "VERIFICAÇÃO DE PRÉ-REQUISITOS"

    # Root check
    if [[ $EUID -ne 0 ]]; then
        print_erro "Este script deve ser executado como root"
        exit 1
    fi
    print_ok "Executando como root"

    # Node check
    if [[ "$NODE_TYPE" != "node1" ]] && [[ "$NODE_TYPE" != "node2" ]]; then
        print_erro "Node deve ser 'node1' ou 'node2'"
        echo ""
        echo "Uso: sudo ./04b-zabbix-frontend-ha.sh <node1|node2>"
        echo "  node1 → zbx-fe-01 (10.31.38.62)"
        echo "  node2 → zbx-fe-02 (10.31.38.63)"
        exit 1
    fi

    if [[ "$NODE_TYPE" == "node1" ]]; then
        CURRENT_IP="$ZBXFE_NODE1"
    else
        CURRENT_IP="$ZBXFE_NODE2"
    fi
    print_ok "Node: $NODE_TYPE ($CURRENT_IP)"

    # Verificar conectividade com o banco
    print_info "Verificando acesso ao PostgreSQL (pg-01: $PG_HOST)..."
    if timeout 5 bash -c "</dev/tcp/${PG_HOST}/${PG_PORT}" 2>/dev/null; then
        print_ok "pg-01 ($PG_HOST:$PG_PORT) acessível"
    else
        print_warning "pg-01 ($PG_HOST) inacessível — verificar antes de continuar"
    fi

    # Verificar Zabbix Server
    print_info "Verificando acesso ao Zabbix Server (zbx-server-01: $ZABBIX_SERVER_HOST)..."
    if timeout 5 bash -c "</dev/tcp/${ZABBIX_SERVER_HOST}/10051" 2>/dev/null; then
        print_ok "zbx-server-01 ($ZABBIX_SERVER_HOST:10051) acessível"
    else
        print_warning "zbx-server-01 inacessível — certifique-se que o script 04 foi executado"
    fi

    # Verificar vip-01 e vip-02
    for vip_ip in "$HAPROXY_VIP1" "$HAPROXY_VIP2"; do
        if timeout 5 bash -c "</dev/tcp/${vip_ip}/22" 2>/dev/null; then
            print_ok "vip ($vip_ip:22) acessível via SSH"
        else
            print_warning "vip ($vip_ip:22) não acessível — ativação HAProxy será manual"
        fi
    done
}

# ═══════════════════════════════════════════════════════════════════════════
# ATUALIZAR SISTEMA
# ═══════════════════════════════════════════════════════════════════════════

atualizar_sistema() {
    print_section "ATUALIZAÇÃO DO SISTEMA"

    apt-get update 2>&1 | tee -a "$LOG_FILE"
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y 2>&1 | tee -a "$LOG_FILE"

    print_ok "Sistema atualizado"
}

# ═══════════════════════════════════════════════════════════════════════════
# INSTALAR APACHE + PHP + ZABBIX FRONTEND
# ═══════════════════════════════════════════════════════════════════════════

instalar_frontend() {
    print_section "INSTALAÇÃO APACHE + PHP + ZABBIX FRONTEND"

    # Adicionar repositório Zabbix (mesma fonte do server)
    print_info "Adicionando repositório Zabbix ${ZABBIX_VERSION}..."
    if ! dpkg -l zabbix-release &>/dev/null; then
        wget -qO /tmp/zabbix-release.deb \
            "https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb"
        dpkg -i /tmp/zabbix-release.deb 2>&1 | tee -a "$LOG_FILE"
        apt-get update 2>&1 | tee -a "$LOG_FILE"
        print_ok "Repositório Zabbix ${ZABBIX_VERSION} adicionado"
    else
        print_ok "Repositório Zabbix já presente"
    fi

    print_info "Instalando Apache2, PHP e Zabbix Frontend..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        apache2 \
        php \
        php-xml \
        php-bcmath \
        php-mbstring \
        php-gd \
        php-ldap \
        php-pgsql \
        php-curl \
        libapache2-mod-php \
        zabbix-frontend-php \
        zabbix-apache-conf \
        2>&1 | tee -a "$LOG_FILE"

    print_ok "Apache2 + PHP + Zabbix Frontend instalados"
}

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURAR ZABBIX FRONTEND
# ═══════════════════════════════════════════════════════════════════════════

configurar_frontend() {
    print_section "CONFIGURAÇÃO DO ZABBIX FRONTEND"

    ZBXCONF="/etc/zabbix/zabbix.conf.php"

    print_info "Criando ${ZBXCONF}..."
    cat > "$ZBXCONF" << PHP_EOF
<?php
// Zabbix GUI configuration file.
global \$DB;

\$DB['TYPE']                     = 'POSTGRESQL';
\$DB['SERVER']                   = '${PG_HOST}';
\$DB['PORT']                     = '${PG_PORT}';
\$DB['DATABASE']                 = '${DB_NAME}';
\$DB['USER']                     = '${DB_USER}';
\$DB['PASSWORD']                 = '${DB_PASS}';
\$DB['SCHEMA']                   = '';
\$DB['ENCRYPTION']               = false;
\$DB['KEY_FILE']                 = '';
\$DB['CERT_FILE']                = '';
\$DB['CA_FILE']                  = '';
\$DB['VERIFY_HOST']              = false;
\$DB['CIPHER_LIST']              = '';
\$DB['VAULT_URL']                = '';
\$DB['VAULT_DB_PATH']            = '';
\$DB['VAULT_TOKEN']              = '';
\$DB['DOUBLE_IEEE754']           = true;

\$ZBX_SERVER                     = '${ZABBIX_SERVER_HOST}';
\$ZBX_SERVER_PORT                = '10051';
\$ZBX_SERVER_NAME                = 'Aeroporto HA';

\$IMAGE_FORMAT_DEFAULT           = IMAGE_FORMAT_PNG;

// Timeout
\$ZBX_HISTORY_LIMIT              = 10000;
PHP_EOF

    chmod 640 "$ZBXCONF"
    chown www-data:www-data "$ZBXCONF"
    print_ok "zabbix.conf.php configurado (banco: $PG_HOST, server: $ZABBIX_SERVER_HOST)"
}

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURAR APACHE
# ═══════════════════════════════════════════════════════════════════════════

configurar_apache() {
    print_section "CONFIGURAÇÃO APACHE"

    # Habilitar módulos necessários
    a2enmod rewrite 2>&1 | tee -a "$LOG_FILE"
    a2enconf zabbix 2>&1 | tee -a "$LOG_FILE"

    # PHP timezone
    PHP_INI=$(php --ini 2>/dev/null | grep "Loaded Configuration" | awk '{print $NF}')
    if [[ -f "$PHP_INI" ]]; then
        sed -i "s|;date.timezone =|date.timezone = America/Sao_Paulo|" "$PHP_INI"
        print_ok "PHP timezone configurado (America/Sao_Paulo)"
    fi

    # PHP memory limit para Zabbix
    for conf_file in /etc/php/*/apache2/php.ini; do
        [[ -f "$conf_file" ]] || continue
        sed -i "s|^memory_limit = .*|memory_limit = 256M|" "$conf_file"
        sed -i "s|^post_max_size = .*|post_max_size = 32M|" "$conf_file"
        sed -i "s|^upload_max_filesize = .*|upload_max_filesize = 32M|" "$conf_file"
        sed -i "s|^max_execution_time = .*|max_execution_time = 300|" "$conf_file"
        sed -i "s|;date.timezone =|date.timezone = America/Sao_Paulo|" "$conf_file"
    done

    # Reiniciar Apache
    systemctl enable apache2 2>&1 | tee -a "$LOG_FILE"
    systemctl restart apache2 2>&1 | tee -a "$LOG_FILE"

    print_ok "Apache configurado e reiniciado"
}

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURAR FIREWALL
# ═══════════════════════════════════════════════════════════════════════════

configurar_firewall() {
    print_section "CONFIGURAÇÃO DE FIREWALL"

    if command -v ufw &>/dev/null; then
        ufw allow 80/tcp comment "Zabbix Frontend (HTTP)" 2>&1 | tee -a "$LOG_FILE"
        ufw allow ssh 2>&1 | tee -a "$LOG_FILE"
        ufw --force enable 2>&1 | tee -a "$LOG_FILE"
        print_ok "Firewall: porta 80 liberada"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# ATIVAR BACKEND ZABBIX FRONTEND NO HAPROXY (vip-01 / vip-02)
# ═══════════════════════════════════════════════════════════════════════════
ativar_backend_haproxy() {
    local VIPS=("$HAPROXY_VIP1" "$HAPROXY_VIP2")
    local ativados=0

    print_info "Ativando backend Zabbix Frontend no HAProxy (vip-01 e vip-02)..."

    for vip_ip in "${VIPS[@]}"; do
        if timeout 5 bash -c "</dev/tcp/${vip_ip}/22" 2>/dev/null; then
            print_info "  -> SSH em ${vip_ip}..."
            if ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=10 root@"${vip_ip}" \
                'socat_ok=0; command -v socat &>/dev/null && [ -S /run/haproxy/admin.sock ] && socat_ok=1
                 [ "$socat_ok" -eq 1 ] && echo "enable server backend_zabbix_frontend/zbx_fe_01" | socat /run/haproxy/admin.sock stdio
                 [ "$socat_ok" -eq 1 ] && echo "enable server backend_zabbix_frontend/zbx_fe_02" | socat /run/haproxy/admin.sock stdio
                 sed -i "s|zbx_fe_01 10.31.38.62:80 disabled|zbx_fe_01 10.31.38.62:80 check inter 5s fall 3 rise 2|" /etc/haproxy/haproxy.cfg
                 sed -i "s|zbx_fe_02 10.31.38.63:80 disabled|zbx_fe_02 10.31.38.63:80 check inter 5s fall 3 rise 2|" /etc/haproxy/haproxy.cfg
                 haproxy -c -f /etc/haproxy/haproxy.cfg && systemctl reload haproxy'; then
                print_ok "  ✓ Backend Zabbix Frontend ativado em ${vip_ip}"
                ativados=$((ativados + 1))
            else
                print_warning "  ✗ Falha ao ativar em ${vip_ip}"
            fi
        else
            print_warning "  ✗ ${vip_ip}:22 inacessível — ative manualmente"
        fi
    done

    if [ "$ativados" -lt 2 ]; then
        echo ""
        print_warning "Execute manualmente em CADA vip (vip-01 E vip-02):"
        echo "  # Via runtime API (efeito imediato)"
        echo "  echo 'enable server backend_zabbix_frontend/zbx_fe_01' | socat /run/haproxy/admin.sock stdio"
        echo "  echo 'enable server backend_zabbix_frontend/zbx_fe_02' | socat /run/haproxy/admin.sock stdio"
        echo "  # Persistência"
        echo "  sed -i 's/zbx_fe_01 10.31.38.62:80 disabled/zbx_fe_01 10.31.38.62:80 check inter 5s fall 3 rise 2/' /etc/haproxy/haproxy.cfg"
        echo "  sed -i 's/zbx_fe_02 10.31.38.63:80 disabled/zbx_fe_02 10.31.38.63:80 check inter 5s fall 3 rise 2/' /etc/haproxy/haproxy.cfg"
        echo "  systemctl reload haproxy"
        echo "  # Stats: http://10.31.38.70:8404/stats"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# GERAR RELATÓRIO
# ═══════════════════════════════════════════════════════════════════════════

gerar_relatorio() {
    print_section "RELATÓRIO DE INSTALAÇÃO"

    echo "" | tee -a "$LOG_FILE"
    echo "╔════════════════════════════════════════════════════════════════════╗" | tee -a "$LOG_FILE"
    echo "║         ✓ ZABBIX FRONTEND INSTALADO COM SUCESSO                   ║" | tee -a "$LOG_FILE"
    echo "╚════════════════════════════════════════════════════════════════════╝" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    echo "📊 RESUMO:" | tee -a "$LOG_FILE"
    echo "  Node      : $NODE_TYPE ($CURRENT_IP)" | tee -a "$LOG_FILE"
    echo "  Frontend  : Apache2 + PHP + Zabbix ${ZABBIX_VERSION}" | tee -a "$LOG_FILE"
    echo "  Banco     : PostgreSQL $PG_HOST (zabbix)" | tee -a "$LOG_FILE"
    echo "  Server    : zbx-server-01 $ZABBIX_SERVER_HOST:10051" | tee -a "$LOG_FILE"
    echo "  VIP       : $ZABBIX_VIP (acesso cliente)" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    echo "🌐 ACESSO:" | tee -a "$LOG_FILE"
    echo "  Via VIP: http://${ZABBIX_VIP}/zabbix" | tee -a "$LOG_FILE"
    echo "  Direto : http://${CURRENT_IP}/zabbix  (para teste local)" | tee -a "$LOG_FILE"
    echo "  Login  : Admin / zabbix (trocar imediatamente)" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    echo "📝 COMANDOS ÚTEIS:" | tee -a "$LOG_FILE"
    echo "  Status Apache : systemctl status apache2" | tee -a "$LOG_FILE"
    echo "  Logs Apache   : tail -f /var/log/apache2/error.log" | tee -a "$LOG_FILE"
    echo "  Logs Zabbix   : tail -f /var/log/zabbix/zabbix_server.log" | tee -a "$LOG_FILE"
    echo "  HAProxy Stats : http://10.31.38.70:8404/stats" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════

main() {
    print_header

    print_info "Iniciando instalação do Zabbix Frontend..."
    print_info "Log: $LOG_FILE"

    verificar_prerequisitos || exit 1
    atualizar_sistema || exit 1
    instalar_frontend || exit 1
    configurar_frontend || exit 1
    configurar_apache || exit 1
    configurar_firewall || exit 1
    ativar_backend_haproxy
    gerar_relatorio

    print_ok "✓ ZABBIX FRONTEND INSTALADO COM SUCESSO"
    echo ""
}

main "$@"
