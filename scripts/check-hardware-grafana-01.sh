#!/bin/bash

################################################################################
#                                                                              #
#  SCRIPT DE VALIDAÇÃO DE HARDWARE - GRAFANA                                  #
#                                                                              #
#  Projeto: Aeroporto - AWX + Grafana + Zabbix                               #
#  Data: 24/10/2026                                                           #
#  Versão: 1.0                                                                #
#  Servidor: grafana-01 (10.31.38.66)                                         #
#                                                                              #
#  OBJETIVO:                                                                   #
#    Validar hardware e conectividade de Grafana antes da instalação          #
#    Checklist de 11 testes automatizados                                      #
#                                                                              #
#  HARDWARE ESPERADO:                                                          #
#    - CPU: 4 vCPU (mínimo)                                                   #
#    - RAM: 8 GB (mínimo)                                                     #
#    - Disco: 50 GB livres                                                    #
#    - SO: Ubuntu 26.04                                                       #
#    - IP: 10.31.38.66 (fixo)                                                 #
#    - Porta: 80 (HTTP), 443 (HTTPS), 22 (SSH), 3000 (Grafana)               #
#                                                                              #
#  USO:                                                                        #
#    sudo bash check-hardware-grafana-01.sh                                   #
#    ou                                                                        #
#    bash check-hardware-grafana-01.sh (pode avisar sobre permissões)        #
#                                                                              #
#  AUTHOR: Vinicius Reis (reisvmr@gmail.com)                                  #
#  LICENSE: MIT                                                               #
#                                                                              #
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURAÇÕES
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Variáveis de checagem
ERRORS=0
WARNINGS=0
PASSES=0

# Hardware esperado
MIN_CPU=4
MIN_RAM_GB=8
MIN_DISK_GB=50
EXPECTED_SO="Ubuntu"
EXPECTED_IP="10.31.38.66"
EXPECTED_HOSTNAME="grafana-01"

# Domínios críticos para Grafana
CRITICAL_DOMAINS=(
    "grafana.com"
    "apt.grafana.com"
    "rpm.grafana.com"
    "github.com"
    "raw.githubusercontent.com"
    "pypi.org"
)

# ============================================================================
# FUNÇÕES DE LOG
# ============================================================================

log_pass() {
    echo -e "${GREEN}[✓ PASS]${NC} $*"
    ((PASSES++))
}

log_fail() {
    echo -e "${RED}[✗ FAIL]${NC} $*"
    ((ERRORS++))
}

log_warn() {
    echo -e "${YELLOW}[⚠ WARN]${NC} $*"
    ((WARNINGS++))
}

log_info() {
    echo -e "${BLUE}[ℹ INFO]${NC} $*"
}

log_title() {
    echo ""
    echo -e "${BOLD}${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${BOLD}${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
}

# ============================================================================
# 1. INFORMAÇÕES DO SERVIDOR
# ============================================================================

check_hostname() {
    log_title "1. HOSTNAME E INFORMAÇÕES DO SERVIDOR"
    
    local current_hostname=$(hostname)
    local expected="$EXPECTED_HOSTNAME"
    
    echo "  Esperado: $expected ou similar"
    echo "  Atual:    $current_hostname"
    
    if [[ "$current_hostname" == *"$expected"* ]] || [[ "$expected" == *"$current_hostname"* ]]; then
        log_pass "Hostname configurado apropriadamente"
    else
        log_warn "Hostname pode não estar correto (esperado algo com '$expected')"
    fi
}

# ============================================================================
# 2. SISTEMA OPERACIONAL
# ============================================================================

check_operating_system() {
    log_title "2. SISTEMA OPERACIONAL"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        local so_name="$NAME"
        local so_version="$VERSION_ID"
        
        echo "  Esperado: Ubuntu 26.04+"
        echo "  Atual:    $so_name $so_version"
        
        if [[ "$so_name" == *"Ubuntu"* ]]; then
            log_pass "Sistema operacional suportado detectado"
        else
            log_fail "SO não é Ubuntu (detectado: $so_name)"
        fi
    else
        log_fail "Não foi possível detectar o SO"
    fi
}

# ============================================================================
# 3. HARDWARE - CPU
# ============================================================================

check_cpu() {
    log_title "3. HARDWARE - CPU"
    
    local cpu_count=$(nproc)
    local cpu_model=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
    
    echo "  Esperado: Mínimo $MIN_CPU vCPU (recomendado 8+)"
    echo "  Atual:    vCPU: $cpu_count | Modelo: $cpu_model"
    
    if [ "$cpu_count" -ge "$MIN_CPU" ]; then
        log_pass "CPU OK: $cpu_count vCPU"
    else
        log_fail "CPU insuficiente: $cpu_count vCPU (mínimo: $MIN_CPU)"
    fi
    
    if [ "$cpu_count" -lt 8 ]; then
        log_warn "CPU recomendação: 8+ vCPU para melhor performance (atual: $cpu_count)"
    fi
}

# ============================================================================
# 4. HARDWARE - MEMÓRIA RAM
# ============================================================================

check_ram() {
    log_title "4. HARDWARE - MEMÓRIA RAM"
    
    local ram_gb=$(free -g | awk 'NR==2 {print $2}')
    
    echo "  Esperado: Mínimo $MIN_RAM_GB GB (recomendado 16+ GB)"
    echo "  Atual:    $ram_gb GB"
    
    if [ "$ram_gb" -ge "$MIN_RAM_GB" ]; then
        log_pass "RAM OK: $ram_gb GB"
    else
        log_fail "RAM insuficiente: ${ram_gb}GB (mínimo: ${MIN_RAM_GB}GB)"
    fi
    
    if [ "$ram_gb" -lt 16 ]; then
        log_warn "RAM recomendação: 16+ GB para muitos dashboards (atual: $ram_gb GB)"
    fi
}

# ============================================================================
# 5. HARDWARE - DISCO
# ============================================================================

check_disk() {
    log_title "5. HARDWARE - DISCO"
    
    local disk_info=$(df / | awk 'NR==2 {print $2, $3, $4}')
    local disk_total=$(echo "$disk_info" | awk '{print $1}')
    local disk_used=$(echo "$disk_info" | awk '{print $2}')
    local disk_free=$(echo "$disk_info" | awk '{print $3}')
    
    local disk_free_gb=$((disk_free / 1024 / 1024))
    local disk_total_gb=$((disk_total / 1024 / 1024))
    local disk_used_gb=$((disk_used / 1024 / 1024))
    
    echo "  Esperado: Mínimo $MIN_DISK_GB GB livres"
    echo "  Atual:    Disco raiz: ${disk_total_gb}G ${disk_used_gb}G ${disk_free_gb}G"
    
    if [ "$disk_free_gb" -ge "$MIN_DISK_GB" ]; then
        log_pass "Espaço em disco OK: ${disk_free_gb}GB livres"
    else
        log_fail "Espaço em disco insuficiente (< $MIN_DISK_GB GB)"
    fi
}

# ============================================================================
# 6. HARDWARE - INTERFACE DE REDE
# ============================================================================

check_network_interface() {
    log_title "6. HARDWARE - INTERFACE DE REDE"
    
    local interfaces=$(ip -4 addr | grep -oP '(?<=inet\s)\d+(\.\d+){3}(?=/[0-9]+)' | wc -l)
    local ip_addr=$(hostname -I | awk '{print $1}')
    
    echo "  Esperado: Mínimo 1 interface de rede configurada"
    echo "  Atual:    Interfaces ativas: $interfaces"
    
    if [ "$interfaces" -gt 0 ]; then
        log_pass "Interface de rede detectada"
        log_info "  IP: $ip_addr"
        
        if [[ "$ip_addr" == "$EXPECTED_IP" ]]; then
            log_pass "IP configurado corretamente: $EXPECTED_IP"
        else
            log_warn "IP esperado: $EXPECTED_IP | Atual: $ip_addr"
        fi
    else
        log_fail "Nenhuma interface de rede configurada"
    fi
}

# ============================================================================
# 7. CONECTIVIDADE - DNS
# ============================================================================

check_dns() {
    log_title "7. CONECTIVIDADE - RESOLUÇÃO DNS"
    
    local test_domain="grafana.com"
    local dns_result=$(nslookup "$test_domain" 2>&1 | grep "Address:" | head -1)
    local nameservers=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}')
    
    echo "  Esperado: Resolução de nomes funcionando"
    echo "  Teste:    $test_domain → $dns_result"
    
    if [ -z "$dns_result" ]; then
        log_fail "DNS não funcionando"
    else
        log_pass "Resolução DNS funcionando"
        log_info "  Nameservers configurados: $nameservers"
    fi
}

# ============================================================================
# 8. CONECTIVIDADE - TESTE DE PORTAS TCP
# ============================================================================

check_tcp_ports() {
    log_title "8. CONECTIVIDADE - TESTE DE PORTAS TCP"
    
    log_info "Testando conectividade TCP para ${#CRITICAL_DOMAINS[@]} domínios críticos..."
    
    local open=0
    local closed=0
    
    for domain in "${CRITICAL_DOMAINS[@]}"; do
        if timeout 5 bash -c "cat < /dev/null > /dev/tcp/$domain/443" 2>/dev/null; then
            ((open++))
            log_pass "TCP 443 ABERTO: $domain"
        else
            ((closed++))
            log_warn "TCP 443 FECHADO/TIMEOUT: $domain"
        fi
    done
    
    log_info "Resumo TCP: $open/${#CRITICAL_DOMAINS[@]} portas ABERTAS, $closed/${#CRITICAL_DOMAINS[@]} FECHADAS"
    
    if [ "$closed" -gt 2 ]; then
        log_fail "Muitos domínios com TCP fechado - verificar firewall/conectividade"
    fi
}

# ============================================================================
# 9. CONECTIVIDADE - TESTE HTTPS
# ============================================================================

check_https() {
    log_title "9. CONECTIVIDADE - TESTE HTTPS"
    
    log_info "Testando HTTPS com curl para domínios críticos..."
    
    local https_ok=0
    local https_fail=0
    
    for domain in "${CRITICAL_DOMAINS[@]:0:3}"; do
        if curl -s -o /dev/null -w "%{http_code}" "https://$domain" 2>/dev/null | grep -q "^[23]"; then
            ((https_ok++))
            log_pass "HTTPS OK: $domain"
        else
            ((https_fail++))
            log_warn "HTTPS FALHOU: $domain"
        fi
    done
    
    if [ "$https_ok" -gt 0 ]; then
        log_pass "HTTPS funcionando para domínios testados"
    else
        log_fail "HTTPS não funcionando - verificar conectividade"
    fi
}

# ============================================================================
# 10. NTP - SINCRONIZAÇÃO DE TEMPO
# ============================================================================

check_ntp() {
    log_title "10. NTP - SINCRONIZAÇÃO DE TEMPO"
    
    local ntp_status=$(timedatectl status 2>/dev/null | grep "synchronized" || echo "desconhecido")
    
    echo "  Status: $ntp_status"
    
    if systemctl is-active --quiet chrony || systemctl is-active --quiet ntpd; then
        log_pass "NTP sincronizado"
    else
        log_warn "NTP pode não estar sincronizado (importante para gráficos)"
    fi
}

# ============================================================================
# 11. CONECTIVIDADE - SERVIDOR ZABBIX
# ============================================================================

check_zabbix_connectivity() {
    log_title "11. CONECTIVIDADE - SERVIDOR ZABBIX"
    
    log_info "Testando conectividade com Zabbix Server (10.31.38.60:10051)..."
    
    if timeout 2 bash -c "cat < /dev/null > /dev/tcp/10.31.38.60/10051" 2>/dev/null; then
        log_pass "Conectividade Zabbix Server OK"
    else
        log_warn "Não conseguiu conectar ao Zabbix Server (pode estar offline)"
    fi
}

# ============================================================================
# RESUMO FINAL
# ============================================================================

print_summary() {
    log_title "RESUMO DA VALIDAÇÃO"
    
    local total=$((PASSES + ERRORS + WARNINGS))
    
    echo ""
    echo "Total de testes: $total"
    echo -e "${GREEN}Passed: $PASSES${NC}"
    echo -e "${RED}Failed: $ERRORS${NC}"
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
    echo ""
    
    if [ $ERRORS -eq 0 ]; then
        echo -e "${GREEN}${BOLD}✓ VALIDAÇÃO PASSOU - PRONTO PARA INSTALAR GRAFANA${NC}"
        return 0
    else
        echo -e "${RED}${BOLD}✗ VALIDAÇÃO FALHOU - REVISE OS ERROS ACIMA${NC}"
        return 1
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    clear
    
    echo ""
    echo -e "${BOLD}${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}VALIDAÇÃO DE HARDWARE - GRAFANA v1.0${NC}"
    echo -e "${BOLD}Servidor: grafana-01 (10.31.38.66)${NC}"
    echo -e "${BOLD}Data: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${BOLD}${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    check_hostname
    check_operating_system
    check_cpu
    check_ram
    check_disk
    check_network_interface
    check_dns
    check_tcp_ports
    check_https
    check_ntp
    check_zabbix_connectivity
    
    print_summary
}

main "$@"
