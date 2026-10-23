#!/bin/bash

################################################################################
#                                                                              #
#  SCRIPT DE VALIDAÇÃO - ZABBIX SERVER 01 (VERSÃO MELHORADA 1.1)             #
#                                                                              #
#  Projeto: Aeroporto - Zabbix 7.0 LTS + PostgreSQL 16                        #
#  Data: 23/10/2024                                                           #
#  Versão: 1.1 - Melhorada (continua mesmo com erros)                         #
#                                                                              #
################################################################################

# NÃO usar set -e (continua mesmo com erros)

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0
INFO=0

REPORT_FILE="/tmp/check-zbx-server-01-$(date +%Y%m%d_%H%M%S).txt"

################################################################################
# FUNÇÕES
################################################################################

print_header() {
    echo -e "\n${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}\n"
    echo "" >> "$REPORT_FILE"
    echo "════════════════════════════════════════════════════════════════" >> "$REPORT_FILE"
    echo "  $1" >> "$REPORT_FILE"
    echo "════════════════════════════════════════════════════════════════" >> "$REPORT_FILE"
}

print_pass() {
    echo -e "${GREEN}✅ PASS${NC}  : $1"
    echo "✅ PASS: $1" >> "$REPORT_FILE"
    ((PASS++))
}

print_fail() {
    echo -e "${RED}❌ FAIL${NC}  : $1"
    echo "❌ FAIL: $1" >> "$REPORT_FILE"
    ((FAIL++))
}

print_warn() {
    echo -e "${YELLOW}⚠️  WARN${NC}  : $1"
    echo "⚠️  WARN: $1" >> "$REPORT_FILE"
    ((WARN++))
}

print_info() {
    echo -e "${BLUE}ℹ️  INFO${NC}  : $1"
    echo "ℹ️  INFO: $1" >> "$REPORT_FILE"
    ((INFO++))
}

print_spec() {
    echo -e "  ${BOLD}Esperado:${NC} $1"
    echo "  Esperado: $1" >> "$REPORT_FILE"
}

print_current() {
    echo -e "  ${BOLD}Atual:${NC}    $2"
    echo "  Atual: $2" >> "$REPORT_FILE"
}

print_options() {
    echo -e "  ${BOLD}Opções:${NC}"
    echo "  Opções:" >> "$REPORT_FILE"
    local i=1
    while [ $i -le $# ]; do
        echo -e "    $i) ${!i}"
        echo "    $i) ${!i}" >> "$REPORT_FILE"
        ((i++))
    done
}

################################################################################
# CHECAGENS
################################################################################

check_hostname() {
    print_header "1. HOSTNAME"
    
    local current_hostname=$(hostname 2>/dev/null || echo "DESCONHECIDO")
    print_spec "zbx-server-01 ou zabbix-server"
    print_current "" "$current_hostname"
    
    if [[ "$current_hostname" == "zbx-server-01" ]] || [[ "$current_hostname" == "zabbix-server" ]]; then
        print_pass "Hostname configurado corretamente"
    else
        print_fail "Hostname não configurado conforme especificação"
        print_options \
            "Executar: sudo hostnamectl set-hostname zbx-server-01" \
            "Executar: sudo hostnamectl set-hostname zabbix-server"
    fi
}

check_os() {
    print_header "2. SISTEMA OPERACIONAL"
    
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        local os_name="$NAME"
        local os_version="$VERSION_ID"
        
        print_spec "Ubuntu 20.04+, Debian 11+, CentOS 8+, RHEL 8+"
        print_current "" "$os_name $os_version"
        
        if [[ "$os_name" == *"Ubuntu"* ]]; then
            print_pass "Ubuntu detectado: $os_version"
        elif [[ "$os_name" == *"Debian"* ]]; then
            print_pass "Debian detectado: $os_version"
        elif [[ "$os_name" == *"CentOS"* ]] || [[ "$os_name" == *"Red Hat"* ]]; then
            print_pass "CentOS/RHEL detectado"
        else
            print_fail "SO não suportado"
        fi
    else
        print_fail "Não foi possível detectar SO"
    fi
}

check_cpu_ram() {
    print_header "3. CPU E MEMÓRIA RAM"
    
    local cpu_count=$(nproc 2>/dev/null || echo "DESCONHECIDO")
    print_spec "16 vCPU (mínimo 8)"
    print_current "" "$cpu_count vCPU"
    
    if [[ "$cpu_count" != "DESCONHECIDO" ]]; then
        if [ "$cpu_count" -ge 16 ]; then
            print_pass "CPU com $cpu_count vCPU (>= 16, recomendado)"
        elif [ "$cpu_count" -ge 8 ]; then
            print_pass "CPU com $cpu_count vCPU (mínimo)"
        else
            print_fail "CPU com apenas $cpu_count vCPU (< 8)"
        fi
    else
        print_warn "Não foi possível detectar CPUs"
    fi
    
    local ram_gb=$(free -g 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "DESCONHECIDO")
    print_spec "32 GB (recomendado), mínimo 16 GB"
    print_current "" "$ram_gb GB"
    
    if [[ "$ram_gb" != "DESCONHECIDO" ]]; then
        if [ "$ram_gb" -ge 32 ]; then
            print_pass "RAM com $ram_gb GB (>= 32, recomendado)"
        elif [ "$ram_gb" -ge 16 ]; then
            print_pass "RAM com $ram_gb GB (mínimo)"
        else
            print_fail "RAM com apenas $ram_gb GB (< 16)"
        fi
    else
        print_warn "Não foi possível detectar RAM"
    fi
}

check_firewall() {
    print_header "4. FIREWALL"
    
    print_spec "Porta 10051 (Zabbix) aberta para entrada/saída"
    
    if command -v firewall-cmd &> /dev/null; then
        local fw_status=$(sudo firewall-cmd --state 2>/dev/null || echo "ERRO")
        
        if [[ "$fw_status" == "running" ]]; then
            print_info "FirewallD está ativo"
            local port_check=$(sudo firewall-cmd --list-ports 2>/dev/null | grep -c "10051/tcp" || echo 0)
            if [ "$port_check" -gt 0 ]; then
                print_pass "Porta 10051/tcp liberada"
            else
                print_fail "Porta 10051/tcp NÃO está liberada"
            fi
        else
            print_warn "FirewallD não está ativo"
        fi
    elif command -v ufw &> /dev/null; then
        print_info "UFW detectado"
        if sudo ufw status 2>/dev/null | grep -q "active"; then
            local port_check=$(sudo ufw status 2>/dev/null | grep -c "10051" || echo 0)
            if [ "$port_check" -gt 0 ]; then
                print_pass "Porta 10051 liberada em UFW"
            else
                print_fail "Porta 10051 NÃO está liberada"
            fi
        else
            print_warn "UFW não está ativo"
        fi
    else
        print_warn "Nenhum firewall detectado"
    fi
}

check_ntp() {
    print_header "5. NTP (SINCRONISMO DE HORA)"
    
    print_spec "NTP/Chrony sincronizado"
    
    local ntp_found=0
    
    if command -v chronyc &> /dev/null; then
        print_info "Chrony detectado"
        ntp_found=1
        
        if sudo systemctl is-active --quiet chrony 2>/dev/null; then
            print_pass "Chrony está rodando"
        else
            print_warn "Chrony não está ativo"
        fi
    fi
    
    if command -v ntpstat &> /dev/null; then
        print_info "NTP detectado"
        ntp_found=1
        
        if sudo systemctl is-active --quiet ntp 2>/dev/null; then
            print_pass "NTP está rodando"
        else
            print_warn "NTP não está ativo"
        fi
    fi
    
    if [ "$ntp_found" -eq 0 ]; then
        print_warn "Nenhum NTP detectado"
    fi
    
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    print_info "Hora do sistema: $current_time"
}

check_storage() {
    print_header "6. STORAGE - DISCO PARA ZABBIX"
    
    print_spec "SSD de 120GB-200GB para /var/lib/zabbix"
    
    if [ -d "/var/lib/zabbix" ]; then
        local storage_size=$(df -h /var/lib/zabbix 2>/dev/null | awk 'NR==2 {print $2}')
        local storage_available=$(df -h /var/lib/zabbix 2>/dev/null | awk 'NR==2 {print $4}')
        
        print_info "/var/lib/zabbix: $storage_size (Disponível: $storage_available)"
        
        local storage_size_num=$(echo "$storage_size" | sed 's/G//')
        if [ "$storage_size_num" -ge 120 ]; then
            print_pass "Storage >= 120GB"
        else
            print_warn "Storage < 120GB"
        fi
    else
        print_info "Zabbix ainda não instalado"
    fi
    
    local root_available=$(df / 2>/dev/null | awk 'NR==2 {print $4}')
    local root_available_gb=$(echo "scale=2; $root_available / 1024 / 1024" | bc 2>/dev/null || echo "DESCONHECIDO")
    
    print_info "/ disponível: ${root_available_gb}GB"
}

check_zabbix() {
    print_header "7. ZABBIX SERVER"
    
    print_spec "Zabbix Server 7.0 LTS instalado"
    
    if command -v zabbix_server &> /dev/null; then
        local zabbix_version=$(zabbix_server -V 2>/dev/null | head -1)
        print_info "$zabbix_version"
        
        if [[ "$zabbix_version" == *"7."* ]]; then
            print_pass "Zabbix Server 7.0 detectado"
        else
            print_warn "Zabbix versão diferente de 7"
        fi
        
        if sudo systemctl is-active --quiet zabbix-server 2>/dev/null; then
            print_pass "Zabbix Server está rodando"
        else
            print_warn "Zabbix Server não está rodando"
        fi
    else
        print_fail "Zabbix Server NÃO está instalado"
        print_options "Segue: SETUP_ZABBIX_SERVER_01.md Passo 3"
    fi
}

check_zabbix_agent() {
    print_header "8. ZABBIX AGENT"
    
    print_spec "Zabbix Agent 2.0 para auto-monitoramento"
    
    if command -v zabbix_agent2 &> /dev/null; then
        local agent_version=$(zabbix_agent2 -V 2>/dev/null | head -1)
        print_info "$agent_version"
        
        if sudo systemctl is-active --quiet zabbix-agent2 2>/dev/null; then
            print_pass "Zabbix Agent 2 está rodando"
        else
            print_warn "Zabbix Agent 2 não está rodando"
        fi
    elif command -v zabbix_agentd &> /dev/null; then
        print_warn "Zabbix Agent 1 (legacy) detectado"
        print_options "Atualizar para Zabbix Agent 2.0"
    else
        print_fail "Zabbix Agent NÃO está instalado"
        print_options "Segue: SETUP_ZABBIX_SERVER_01.md Passo 2"
    fi
}

check_postgresql_connectivity() {
    print_header "9. CONECTIVIDADE COM POSTGRESQL (10.31.38.64)"
    
    print_spec "Conexão TCP aberta para 10.31.38.64:5432"
    
    if command -v nc &> /dev/null; then
        if timeout 3 nc -z 10.31.38.64 5432 2>/dev/null; then
            print_pass "Conectividade TCP com 10.31.38.64:5432 OK"
        else
            print_fail "Não consegue conectar em 10.31.38.64:5432"
            print_options \
                "Verificar firewall (porta 5432 saída)" \
                "Testar: ping 10.31.38.64"
        fi
    else
        print_warn "nc (netcat) não instalado"
    fi
}

check_zabbix_config() {
    print_header "10. CONFIGURAÇÃO ZABBIX SERVER"
    
    print_spec "Arquivo /etc/zabbix/zabbix_server.conf configurado"
    
    if [ -f "/etc/zabbix/zabbix_server.conf" ]; then
        print_pass "Arquivo zabbix_server.conf existe"
        
        if grep -q "^DBHost=10.31.38.64" /etc/zabbix/zabbix_server.conf 2>/dev/null; then
            print_pass "DBHost = 10.31.38.64"
        else
            print_warn "DBHost não configurado para 10.31.38.64"
        fi
        
        if grep -q "^DBName=zabbix" /etc/zabbix/zabbix_server.conf 2>/dev/null; then
            print_pass "DBName = zabbix"
        else
            print_warn "DBName não configurado"
        fi
    else
        print_fail "Arquivo zabbix_server.conf NÃO existe"
        print_options "Segue: SETUP_ZABBIX_SERVER_01.md"
    fi
}

check_connectivity_network() {
    print_header "11. CONECTIVIDADE DE REDE"
    
    print_spec "Servidor acessível, DNS funcionando"
    
    local current_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    print_info "IP: $current_ip"
    
    if [ -n "$current_ip" ]; then
        print_pass "IP configurado"
    else
        print_fail "Não conseguiu detectar IP"
    fi
    
    if nslookup 8.8.8.8 &>/dev/null; then
        print_pass "DNS funcionando"
    else
        print_warn "DNS pode não estar funcionando"
    fi
}

check_selinux() {
    print_header "12. SELINUX (CentOS/RHEL)"
    
    if command -v getenforce &> /dev/null; then
        local selinux_status=$(getenforce 2>/dev/null)
        print_info "SELinux: $selinux_status"
        
        if [[ "$selinux_status" == "Disabled" ]] || [[ "$selinux_status" == "Permissive" ]]; then
            print_pass "SELinux em modo adequado"
        else
            print_warn "SELinux em modo Enforcing"
        fi
    else
        print_info "SELinux não está instalado"
    fi
}

generate_summary() {
    print_header "RESUMO DA CHECAGEM"
    
    local total=$((PASS + FAIL + WARN + INFO))
    
    echo -e "Total de verificações: ${BOLD}$total${NC}"
    echo -e "  ${GREEN}Passou (✅):${NC} $PASS"
    echo -e "  ${RED}Falhou (❌):${NC} $FAIL"
    echo -e "  ${YELLOW}Aviso (⚠️):${NC}  $WARN"
    echo -e "  ${BLUE}Informação (ℹ️):${NC}  $INFO"
    echo ""
    
    echo "Total: $total | Passou: $PASS | Falhou: $FAIL | Aviso: $WARN | Info: $INFO" >> "$REPORT_FILE"
    
    if [ "$FAIL" -eq 0 ]; then
        echo -e "\n${GREEN}${BOLD}✅ SERVIDOR PRONTO PARA SETUP!${NC}\n"
        echo "✅ SERVIDOR PRONTO PARA SETUP!" >> "$REPORT_FILE"
    else
        echo -e "\n${RED}${BOLD}❌ RESOLVER FALHAS ANTES DE PROSSEGUIR${NC}\n"
        echo "❌ RESOLVER FALHAS ANTES DE PROSSEGUIR" >> "$REPORT_FILE"
    fi
}

print_report_location() {
    echo -e "${BOLD}Relatório completo:${NC} ${BLUE}$REPORT_FILE${NC}\n"
}

################################################################################
# MAIN
################################################################################

main() {
    clear
    
    echo -e "${BOLD}${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  SCRIPT DE VALIDAÇÃO - ZABBIX SERVER 01                        ║"
    echo "║  Projeto: Aeroporto - Zabbix 7.0 LTS + PostgreSQL 16           ║"
    echo "║  Versão: 1.1 - Melhorada (continua mesmo com erros)            ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
    
    {
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║  RELATÓRIO - ZABBIX SERVER 01"
        echo "║  Data: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "║  Hostname: $(hostname)"
        echo "║  Versão: 1.1 - Melhorada"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""
    } > "$REPORT_FILE"
    
    # Executar TODAS as checagens
    check_hostname
    check_os
    check_cpu_ram
    check_firewall
    check_ntp
    check_storage
    check_zabbix
    check_zabbix_agent
    check_postgresql_connectivity
    check_zabbix_config
    check_connectivity_network
    check_selinux
    
    generate_summary
    print_report_location
    
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}\n"
}

main "$@"
