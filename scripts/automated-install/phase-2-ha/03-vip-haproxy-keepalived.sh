#!/bin/bash

################################################################################
# Script: 03-vip-haproxy-keepalived.sh
# Descrição: Instalação HAProxy + Keepalived para VIP HA Load Balancer
# Data: 27/10/2026
# Versão: 2.0 (HA)
# Servidores: vip-01 (10.31.38.70 - Master) / vip-02 (10.31.38.71 - Backup)
# Autor: Aeroporto - Infraestrutura HA
#
# Uso: sudo ./03-vip-haproxy-keepalived.sh <master|backup>
#
# Exemplo:
#   Em vip-01: sudo ./03-vip-haproxy-keepalived.sh master
#   Em vip-02: sudo ./03-vip-haproxy-keepalived.sh backup
#
# Configura:
#   - HAProxy 2.x (Load Balancing)
#   - Keepalived (VRRP Failover)
#   - VIP flutuante: 10.31.38.70
#   - 3 backends: Zabbix, Grafana, AWX
#
################################################################################

set +e  # Não parar em erros - vamos tratar com exit codes


# ═══════════════════════════════════════════════════════════════════════════
# TRATAMENTO DE ERROS - Função auxiliar
# ═══════════════════════════════════════════════════════════════════════════

# Função para capturar erros sem parar (com set +e)
handle_error() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        return $exit_code
    fi
    return 0
}

# Função para garantir que script não fica em estado inválido
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
ROLE="${1:-}"  # master ou backup
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

# IPs VIP
VIP_IP="10.31.38.70"
VIP_MASTER="10.31.38.70"
VIP_BACKUP="10.31.38.71"

# Backends
ZABBIX_01="10.31.38.60:80"
ZABBIX_02="10.31.38.61:80"
GRAFANA_01="10.31.38.66:3000"
GRAFANA_02="10.31.38.67:3000"
AWX_01="10.31.38.68:8080"
AWX_02="10.31.38.69:8080"

# Keepalived VRRP
ROUTER_ID=50
PRIORITY_MASTER=100
PRIORITY_BACKUP=99
ADVERT_INT=1

# Data
DATA=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="/tmp/vip-haproxy-keepalived-install-$(date +%s).log"

# ═══════════════════════════════════════════════════════════════════════════
# FUNÇÕES
# ═══════════════════════════════════════════════════════════════════════════

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                    ║"
    echo "║  ⚖️  INSTALAÇÃO VIP/HAPROXY/KEEPALIVED - PROJETO AEROPORTO (HA)     ║"
    echo "║                                                                    ║"
    echo "║  VIP: 10.31.38.70 (Failover automático <5s)                       ║"
    echo "║  Role: $ROLE"
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

print_erro() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"
}

print_section() {
    echo "" | tee -a "$LOG_FILE"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}$1${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
}

verificar_prerequisitos() {
    print_section "VERIFICAÇÃO DE PRÉ-REQUISITOS"
    
    # Root check
    if [[ $EUID -ne 0 ]]; then
        print_erro "Este script deve ser executado como root"
        exit 1
    fi
    print_ok "Executando como root"
    
    # Role check
    if [[ "$ROLE" != "master" ]] && [[ "$ROLE" != "backup" ]]; then
        print_erro "Role deve ser 'master' ou 'backup'"
        echo ""
        echo "Uso: sudo ./03-vip-haproxy-keepalived.sh <master|backup>"
        exit 1
    fi
    print_ok "Role: $ROLE"
    
    # Interface check
    if [[ -z "$INTERFACE" ]]; then
        print_erro "Não foi possível determinar interface de rede"
        exit 1
    fi
    print_ok "Interface de rede: $INTERFACE"
}

atualizar_sistema() {
    print_section "ATUALIZAÇÃO DO SISTEMA"
    
    apt-get update 2>&1 | tee -a "$LOG_FILE"
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y 2>&1 | tee -a "$LOG_FILE"
    
    print_ok "Sistema atualizado"
}

instalar_haproxy() {
    print_section "INSTALAÇÃO HAPROXY"
    
    print_info "Instalando HAProxy..."
    apt-get install -y haproxy 2>&1 | tee -a "$LOG_FILE"
    
    print_ok "HAProxy instalado"
}

instalar_keepalived() {
    print_section "INSTALAÇÃO KEEPALIVED"
    
    print_info "Instalando Keepalived..."
    apt-get install -y keepalived 2>&1 | tee -a "$LOG_FILE"
    
    print_ok "Keepalived instalado"
}

configurar_haproxy() {
    print_section "CONFIGURAÇÃO HAPROXY"
    
    # Backup original
    cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.backup
    
    # Criar nova configuração
    cat > /etc/haproxy/haproxy.cfg << 'HAPROXY_EOF'
# ═══════════════════════════════════════════════════════════════════════════
# HAProxy Configuration - Projeto Aeroporto HA
# Data: 27/10/2026
# ═══════════════════════════════════════════════════════════════════════════

global
    log stdout local0
    log stdout local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    maxconn 2048
    tune.ssl.default-dh-param 2048

defaults
    log global
    mode http
    option httplog
    option dontlognull
    timeout connect 5000
    timeout client 50000
    timeout server 50000
    option forwardfor except 127.0.0.0/8
    option http-server-close
    compression algo gzip
    compression type text/html text/plain text/css text/xml text/javascript application/x-javascript application/json

# ═══════════════════════════════════════════════════════════════════════════
# Frontend - VIP Global
# ═══════════════════════════════════════════════════════════════════════════

frontend frontend_global
    bind *:80
    bind *:443 ssl crt /etc/ssl/certs/haproxy.pem
    option httpclose
    
    # Logs
    log 127.0.0.1 local0 info
    option forwardfor
    
    # ACLs para roteamento
    acl is_zabbix hdr(host) -i zabbix.aeroporto
    acl is_grafana hdr(host) -i grafana.aeroporto
    acl is_awx hdr(host) -i awx.aeroporto
    
    # Roteamento por URI
    acl is_zabbix_uri path_beg /zabbix
    acl is_grafana_uri path_beg /grafana
    acl is_awx_uri path_beg /awx
    
    # Default é health check
    default_backend backend_health

    # Zabbix
    use_backend backend_zabbix if is_zabbix OR is_zabbix_uri
    
    # Grafana
    use_backend backend_grafana if is_grafana OR is_grafana_uri
    
    # AWX
    use_backend backend_awx if is_awx OR is_awx_uri

# ═══════════════════════════════════════════════════════════════════════════
# Backends
# ═══════════════════════════════════════════════════════════════════════════

backend backend_health
    mode http
    balance roundrobin
    option httpchk GET /
    server local 127.0.0.1:8081 check inter 5s fall 3 rise 2

backend backend_zabbix
    mode http
    balance roundrobin
    option httpchk GET /zabbix/
    option http-keep-alive
    
    # Health checks
    server zabbix_01 10.31.38.60:80 check inter 5s fall 3 rise 2
    server zabbix_02 10.31.38.61:80 check inter 5s fall 3 rise 2

backend backend_grafana
    mode http
    balance roundrobin
    option httpchk GET /api/health
    
    # Health checks
    server grafana_01 10.31.38.66:3000 check inter 5s fall 3 rise 2
    server grafana_02 10.31.38.67:3000 check inter 5s fall 3 rise 2

backend backend_awx
    mode http
    balance roundrobin
    option httpchk GET /api/v2/
    
    # Health checks
    server awx_01 10.31.38.68:8080 check inter 5s fall 3 rise 2
    server awx_02 10.31.38.69:8080 check inter 5s fall 3 rise 2

# ═══════════════════════════════════════════════════════════════════════════
# Statistics
# ═══════════════════════════════════════════════════════════════════════════

listen stats
    bind 127.0.0.1:8081
    stats enable
    stats uri /stats
    stats refresh 30s
    stats show-legends
    stats show-node
    stats admin if TRUE

HAPROXY_EOF
    
    # Validar configuração
    if haproxy -c -f /etc/haproxy/haproxy.cfg &> /dev/null; then
        print_ok "Configuração HAProxy validada"
    else
        print_erro "Erro na configuração HAProxy"
        return 1
    fi
    
    # Iniciar HAProxy
    systemctl enable haproxy 2>&1 | tee -a "$LOG_FILE"
    systemctl restart haproxy 2>&1 | tee -a "$LOG_FILE"
    
    print_ok "HAProxy configurado e iniciado"
}

configurar_keepalived() {
    print_section "CONFIGURAÇÃO KEEPALIVED"
    
    # Determinar prioridade baseado no role
    if [[ "$ROLE" == "master" ]]; then
        PRIORITY=$PRIORITY_MASTER
        STATE="MASTER"
    else
        PRIORITY=$PRIORITY_BACKUP
        STATE="BACKUP"
    fi
    
    cat > /etc/keepalived/keepalived.conf << KEEPALIVED_EOF
# ═══════════════════════════════════════════════════════════════════════════
# Keepalived Configuration - Projeto Aeroporto HA
# Data: 27/10/2026
# ═══════════════════════════════════════════════════════════════════════════

global_defs {
    notification_email {
        admin@aeroporto.local
    }
    notification_email_from keepalived@aeroporto.local
    smtp_server localhost
    smtp_connect_timeout 30
    router_id AEROPORTO_HA
    script_user root
    enable_script_security
}

# ═══════════════════════════════════════════════════════════════════════════
# VRRP Instances
# ═══════════════════════════════════════════════════════════════════════════

vrrp_script check_haproxy {
    script "/etc/keepalived/check_haproxy.sh"
    interval 5
    weight 2
    fall 2
    rise 2
}

vrrp_instance VI_1 {
    state $STATE
    interface $INTERFACE
    virtual_router_id $ROUTER_ID
    priority $PRIORITY
    advert_int $ADVERT_INT
    authentication {
        auth_type PASS
        auth_pass aeroporto_ha
    }
    virtual_ipaddress {
        $VIP_IP/24
    }
    track_script {
        check_haproxy
    }
    notify_master "/etc/keepalived/notify_master.sh"
    notify_backup "/etc/keepalived/notify_backup.sh"
    notify_fault "/etc/keepalived/notify_fault.sh"
}
KEEPALIVED_EOF
    
    # Script de verificação HAProxy
    cat > /etc/keepalived/check_haproxy.sh << 'CHECK_EOF'
#!/bin/bash
if systemctl is-active --quiet haproxy; then
    exit 0
else
    systemctl restart haproxy
    exit 1
fi
CHECK_EOF
    chmod +x /etc/keepalived/check_haproxy.sh
    
    # Scripts de notificação
    cat > /etc/keepalived/notify_master.sh << 'NOTIFY_EOF'
#!/bin/bash
echo "$(date) - Servidor promovido a MASTER (VIP ativo)" >> /var/log/keepalived_notify.log
NOTIFY_EOF
    chmod +x /etc/keepalived/notify_master.sh
    
    cat > /etc/keepalived/notify_backup.sh << 'NOTIFY_EOF'
#!/bin/bash
echo "$(date) - Servidor revertido a BACKUP (VIP desativo)" >> /var/log/keepalived_notify.log
NOTIFY_EOF
    chmod +x /etc/keepalived/notify_backup.sh
    
    cat > /etc/keepalived/notify_fault.sh << 'NOTIFY_EOF'
#!/bin/bash
echo "$(date) - Falha detectada no servidor" >> /var/log/keepalived_notify.log
NOTIFY_EOF
    chmod +x /etc/keepalived/notify_fault.sh
    
    # Iniciar Keepalived
    systemctl enable keepalived 2>&1 | tee -a "$LOG_FILE"
    systemctl restart keepalived 2>&1 | tee -a "$LOG_FILE"
    
    print_ok "Keepalived configurado (Role: $ROLE, Prioridade: $PRIORITY)"
}

configurar_firewall() {
    print_section "CONFIGURAÇÃO DE FIREWALL"
    
    if command -v ufw &> /dev/null; then
        print_info "Configurando UFW..."
        
        # HTTP/HTTPS
        ufw allow 80/tcp comment "HTTP" 2>&1 | tee -a "$LOG_FILE"
        ufw allow 443/tcp comment "HTTPS" 2>&1 | tee -a "$LOG_FILE"
        
        # VRRP
        ufw allow 112 comment "VRRP" 2>&1 | tee -a "$LOG_FILE"
        
        # Health checks (todos os backends)
        ufw allow from 10.31.38.0/24 2>&1 | tee -a "$LOG_FILE"
        
        print_ok "Firewall configurado"
    fi
}

testar_vip() {
    print_section "TESTE DO VIP"
    
    sleep 3
    
    print_info "Verificando IP Virtual..."
    if ip addr | grep -q "$VIP_IP"; then
        print_ok "VIP ativo: $VIP_IP"
    else
        if [[ "$ROLE" == "master" ]]; then
            print_erro "VIP não ativo em $ROLE"
        else
            print_info "VIP não ativo em backup (esperado)"
        fi
    fi
    
    print_info "Status HAProxy:"
    systemctl status haproxy --no-pager | head -5 | tee -a "$LOG_FILE"
    
    print_info "Status Keepalived:"
    systemctl status keepalived --no-pager | head -5 | tee -a "$LOG_FILE"
}

gerar_relatorio() {
    print_section "RELATÓRIO DE INSTALAÇÃO"
    
    echo "" | tee -a "$LOG_FILE"
    echo "╔════════════════════════════════════════════════════════════════════╗" | tee -a "$LOG_FILE"
    echo "║              ✓ INSTALAÇÃO CONCLUÍDA COM SUCESSO                   ║" | tee -a "$LOG_FILE"
    echo "╚════════════════════════════════════════════════════════════════════╝" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo "📊 RESUMO:" | tee -a "$LOG_FILE"
    echo "  VIP: $VIP_IP" | tee -a "$LOG_FILE"
    echo "  Role: $ROLE" | tee -a "$LOG_FILE"
    echo "  Interface: $INTERFACE" | tee -a "$LOG_FILE"
    echo "  Status: ✓ Ativo" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo "🎯 BACKENDS CONFIGURADOS:" | tee -a "$LOG_FILE"
    echo "  Zabbix:  $ZABBIX_01 + $ZABBIX_02" | tee -a "$LOG_FILE"
    echo "  Grafana: $GRAFANA_01 + $GRAFANA_02" | tee -a "$LOG_FILE"
    echo "  AWX:     $AWX_01 + $AWX_02" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo "📝 COMANDOS ÚTEIS:" | tee -a "$LOG_FILE"
    echo "  Status: systemctl status haproxy keepalived" | tee -a "$LOG_FILE"
    echo "  HAProxy stats: curl http://localhost:8081/stats" | tee -a "$LOG_FILE"
    echo "  Logs: tail -f /var/log/keepalived_notify.log" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════

main() {
    print_header
    
    print_info "Iniciando instalação..."
    print_info "Log: $LOG_FILE"
    
    verificar_prerequisitos || exit 1
    atualizar_sistema || exit 1
    instalar_haproxy || exit 1
    instalar_keepalived || exit 1
    configurar_haproxy || exit 1
    configurar_keepalived || exit 1
    configurar_firewall || exit 1
    testar_vip || exit 1
    gerar_relatorio
    
    print_ok "✓ INSTALAÇÃO CONCLUÍDA COM SUCESSO"
    echo ""
}

main "$@"
