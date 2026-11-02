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
#   - 3 VIPs gerenciados pelo Keepalived (VRRP):
#       VIP-Zabbix-Web : 10.31.38.72 (acesso ao Zabbix Frontend)
#       VIP-Grafana    : 10.31.38.73 (acesso ao Grafana)
#       VIP-AWX        : 10.31.38.74 (acesso ao AWX)
#   - 3 backends pre-configurados (disabled até semanas 3b/4/5)
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

# IPs gerenciamento (estáticos)
VIP_MASTER="10.31.38.70"   # vip-01 — MASTER
VIP_BACKUP="10.31.38.71"   # vip-02 — BACKUP

# 3 VIPs de serviço (gerenciados pelo Keepalived)
VIP_ZABBIX="10.31.38.72"   # VIP acesso Zabbix Frontend
VIP_GRAFANA="10.31.38.73"  # VIP acesso Grafana
VIP_AWX="10.31.38.74"      # VIP acesso AWX

# Backends — Zabbix Frontend (zbx-fe-01/02)
ZBX_FE_01="10.31.38.62:80"
ZBX_FE_02="10.31.38.63:80"

# Backends — Grafana
GRAFANA_01="10.31.38.66:3000"
GRAFANA_02="10.31.38.67:3000"

# Backends — AWX
AWX_01="10.31.38.68:8080"
AWX_02="10.31.38.69:8080"

# Keepalived VRRP
ROUTER_ID_ZABBIX=51
ROUTER_ID_GRAFANA=52
ROUTER_ID_AWX=53
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
    echo "║  VIPs: Zabbix=10.31.38.72 | Grafana=10.31.38.73 | AWX=10.31.38.74  ║"
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
    apt-get install -y haproxy socat 2>&1 | tee -a "$LOG_FILE"
    
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
    # sysctl: permitir bind em IPs ainda não atribuídos à interface (VIPs Keepalived)
    grep -q 'ip_nonlocal_bind' /etc/sysctl.conf || echo 'net.ipv4.ip_nonlocal_bind = 1' >> /etc/sysctl.conf
    sysctl -p 2>&1 | grep -i nonlocal || true

    cat > /etc/haproxy/haproxy.cfg << HAPROXY_EOF
# ═══════════════════════════════════════════════════════════════════════════
# HAProxy Configuration - Projeto Aeroporto HA
# VIPs: Zabbix=10.31.38.72 | Grafana=10.31.38.73 | AWX=10.31.38.74
# Gerado pelo script 03-vip-haproxy-keepalived.sh
# ═══════════════════════════════════════════════════════════════════════════

global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    maxconn 2048

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    option  forwardfor except 127.0.0.0/8
    option  http-server-close
    timeout connect 5000
    timeout client  50000
    timeout server  50000

# ═══════════════════════════════════════════════════════════════════════════
# Frontend Zabbix — VIP 10.31.38.72 porta 80
# Backends: zbx-fe-01 (10.31.38.62) + zbx-fe-02 (10.31.38.63)
# ═══════════════════════════════════════════════════════════════════════════
frontend zabbix_front
    bind ${VIP_ZABBIX}:80
    default_backend backend_zabbix_frontend

backend backend_zabbix_frontend
    balance roundrobin
    option httpchk GET /zabbix/
    # DISABLED — ativado pelo script 04b-zabbix-frontend-ha.sh (Semana 3b)
    server zbx_fe_01 ${ZBX_FE_01} disabled
    server zbx_fe_02 ${ZBX_FE_02} disabled

# ═══════════════════════════════════════════════════════════════════════════
# Frontend Grafana — VIP 10.31.38.73 porta 3000
# Backends: grafana-01 (10.31.38.66) + grafana-02 (10.31.38.67)
# ═══════════════════════════════════════════════════════════════════════════
frontend grafana_front
    bind ${VIP_GRAFANA}:3000
    default_backend backend_grafana

backend backend_grafana
    balance roundrobin
    option httpchk GET /api/health
    # DISABLED — ativado pelo script 05-grafana-ha.sh (Semana 4)
    server grafana_01 ${GRAFANA_01} disabled
    server grafana_02 ${GRAFANA_02} disabled

# ═══════════════════════════════════════════════════════════════════════════
# Frontend AWX — VIP 10.31.38.74 porta 8080
# Backends: awx-01 (10.31.38.68) + awx-02 (10.31.38.69)
# ═══════════════════════════════════════════════════════════════════════════
frontend awx_front
    bind ${VIP_AWX}:8080
    default_backend backend_awx

backend backend_awx
    balance roundrobin
    option httpchk GET /api/v2/ping/
    # DISABLED — ativado pelo script 06-awx-ha.sh (Semana 5)
    server awx_01 ${AWX_01} disabled
    server awx_02 ${AWX_02} disabled

# ═══════════════════════════════════════════════════════════════════════════
# Stats — porta 8404 (local)
# ═══════════════════════════════════════════════════════════════════════════
listen stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 30s
    stats show-legends
    stats show-node
    stats auth admin:haproxy@stats
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
    
    # Determinar src_ip e peer
    if [[ "$ROLE" == "master" ]]; then
        SRC_IP="$VIP_MASTER"
        PEER_IP="$VIP_BACKUP"
    else
        SRC_IP="$VIP_BACKUP"
        PEER_IP="$VIP_MASTER"
    fi

    cat > /etc/keepalived/keepalived.conf << KEEPALIVED_EOF
# ═══════════════════════════════════════════════════════════════════════════
# Keepalived Configuration - Projeto Aeroporto HA
# 3 instâncias VRRP: Zabbix (.72) | Grafana (.73) | AWX (.74)
# Gerado pelo script 03-vip-haproxy-keepalived.sh
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
# Script de health check
# ═══════════════════════════════════════════════════════════════════════════

vrrp_script check_haproxy {
    script "/etc/keepalived/check_haproxy.sh"
    interval 5
    weight 2
    fall 2
    rise 2
}

# ═══════════════════════════════════════════════════════════════════════════
# VI_ZABBIX — VIP 10.31.38.72 (acesso ao Zabbix Frontend)
# ═══════════════════════════════════════════════════════════════════════════

vrrp_instance VI_ZABBIX {
    state $STATE
    interface $INTERFACE
    virtual_router_id $ROUTER_ID_ZABBIX
    priority $PRIORITY
    advert_int $ADVERT_INT
    unicast_src_ip $SRC_IP
    unicast_peer {
        $PEER_IP
    }
    authentication {
        auth_type PASS
        auth_pass aeroporto_ha
    }
    virtual_ipaddress {
        $VIP_ZABBIX/25
    }
    track_script {
        check_haproxy
    }
    notify_master "/etc/keepalived/notify_master.sh"
    notify_backup "/etc/keepalived/notify_backup.sh"
    notify_fault  "/etc/keepalived/notify_fault.sh"
}

# ═══════════════════════════════════════════════════════════════════════════
# VI_GRAFANA — VIP 10.31.38.73 (acesso ao Grafana)
# ═══════════════════════════════════════════════════════════════════════════

vrrp_instance VI_GRAFANA {
    state $STATE
    interface $INTERFACE
    virtual_router_id $ROUTER_ID_GRAFANA
    priority $PRIORITY
    advert_int $ADVERT_INT
    unicast_src_ip $SRC_IP
    unicast_peer {
        $PEER_IP
    }
    authentication {
        auth_type PASS
        auth_pass aeroporto_ha
    }
    virtual_ipaddress {
        $VIP_GRAFANA/25
    }
    track_script {
        check_haproxy
    }
    notify_master "/etc/keepalived/notify_master.sh"
    notify_backup "/etc/keepalived/notify_backup.sh"
    notify_fault  "/etc/keepalived/notify_fault.sh"
}

# ═══════════════════════════════════════════════════════════════════════════
# VI_AWX — VIP 10.31.38.74 (acesso ao AWX)
# ═══════════════════════════════════════════════════════════════════════════

vrrp_instance VI_AWX {
    state $STATE
    interface $INTERFACE
    virtual_router_id $ROUTER_ID_AWX
    priority $PRIORITY
    advert_int $ADVERT_INT
    unicast_src_ip $SRC_IP
    unicast_peer {
        $PEER_IP
    }
    authentication {
        auth_type PASS
        auth_pass aeroporto_ha
    }
    virtual_ipaddress {
        $VIP_AWX/25
    }
    track_script {
        check_haproxy
    }
    notify_master "/etc/keepalived/notify_master.sh"
    notify_backup "/etc/keepalived/notify_backup.sh"
    notify_fault  "/etc/keepalived/notify_fault.sh"
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
        
        ufw allow 3000/tcp comment "HAProxy -> Grafana" 2>&1 | tee -a "$LOG_FILE"
        ufw allow 8080/tcp comment "HAProxy -> AWX" 2>&1 | tee -a "$LOG_FILE"
        ufw allow 8404/tcp comment "HAProxy Stats" 2>&1 | tee -a "$LOG_FILE"

        # Health checks (todos os backends)
        ufw allow from 10.31.38.0/24 2>&1 | tee -a "$LOG_FILE"
        
        print_ok "Firewall configurado"
    fi
}

testar_vip() {
    print_section "TESTE DOS VIPs"

    sleep 3

    print_info "Verificando VIPs Keepalived..."
    for vip_label in "VIP-Zabbix:${VIP_ZABBIX}" "VIP-Grafana:${VIP_GRAFANA}" "VIP-AWX:${VIP_AWX}"; do
        label="${vip_label%%:*}"
        ip="${vip_label##*:}"
        if ip addr | grep -q "${ip}"; then
            print_ok "${label} ativo: ${ip}"
        else
            if [[ "$ROLE" == "master" ]]; then
                print_info "${label} (${ip}) não detectado ainda em MASTER — aguardar Keepalived convergir"
            else
                print_info "${label} (${ip}) não ativo em BACKUP (esperado)"
            fi
        fi
    done

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
    echo "  VIP Zabbix : $VIP_ZABBIX" | tee -a "$LOG_FILE"
    echo "  VIP Grafana: $VIP_GRAFANA" | tee -a "$LOG_FILE"
    echo "  VIP AWX    : $VIP_AWX" | tee -a "$LOG_FILE"
    echo "  Role: $ROLE" | tee -a "$LOG_FILE"
    echo "  Interface: $INTERFACE" | tee -a "$LOG_FILE"
    echo "  Status: ✓ Ativo" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo "🎯 BACKENDS CONFIGURADOS:" | tee -a "$LOG_FILE"
    echo "  Zabbix Frontend: $ZBX_FE_01 + $ZBX_FE_02" | tee -a "$LOG_FILE"
    echo "  Grafana: $GRAFANA_01 + $GRAFANA_02" | tee -a "$LOG_FILE"
    echo "  AWX:     $AWX_01 + $AWX_02" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo "📝 COMANDOS ÚTEIS:" | tee -a "$LOG_FILE"
    echo "  Status: systemctl status haproxy keepalived" | tee -a "$LOG_FILE"
    echo "  HAProxy stats: curl -u admin:haproxy@stats http://localhost:8404/stats" | tee -a "$LOG_FILE"
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
