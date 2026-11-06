#!/bin/bash

################################################################################
#                                                                              #
#  SCRIPT DE VALIDAÇÃO - SERVIDOR POSTGRESQL PRIMARY (VERSÃO MELHORADA 1.1)   #
#                                                                              #
#  Projeto: Aeroporto - Zabbix 7.0 LTS + PostgreSQL 16                        #
#  Data: 23/10/2024                                                           #
#  Versão: 1.1 - Melhorada (continua mesmo com erros)                         #
#                                                                              #
################################################################################

# IMPORTANTE: NÃO usar set -e (permitir que o script continue mesmo com erros)

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

REPORT_FILE="/tmp/check-pg-01-$(date +%Y%m%d_%H%M%S).txt"

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
    print_spec "pg-primary-01 ou pg-01"
    print_current "" "$current_hostname"
    
    if [[ "$current_hostname" == "pg-primary-01" ]] || [[ "$current_hostname" == "pg-01" ]]; then
        print_pass "Hostname configurado corretamente"
    else
        print_fail "Hostname não configurado conforme especificação"
        print_options \
            "Executar: sudo hostnamectl set-hostname pg-primary-01" \
            "Executar: sudo hostnamectl set-hostname pg-01"
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
    print_spec "20 vCPU"
    print_current "" "$cpu_count vCPU"
    
    if [[ "$cpu_count" != "DESCONHECIDO" ]]; then
        if [ "$cpu_count" -ge 20 ]; then
            print_pass "CPU com $cpu_count vCPU (>= 20)"
        elif [ "$cpu_count" -ge 16 ]; then
            print_warn "CPU com $cpu_count vCPU (< 20)"
        else
            print_fail "CPU com apenas $cpu_count vCPU (< 16)"
        fi
    else
        print_warn "Não foi possível detectar número de CPUs"
    fi
    
    local ram_gb=$(free -g 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "DESCONHECIDO")
    print_spec "96 GB RAM"
    print_current "" "$ram_gb GB"
    
    if [[ "$ram_gb" != "DESCONHECIDO" ]]; then
        if [ "$ram_gb" -ge 96 ]; then
            print_pass "RAM com $ram_gb GB (>= 96)"
        elif [ "$ram_gb" -ge 64 ]; then
            print_warn "RAM com $ram_gb GB (< 96)"
        else
            print_fail "RAM com apenas $ram_gb GB (< 64)"
        fi
    else
        print_warn "Não foi possível detectar RAM"
    fi
}

check_firewall() {
    print_header "4. FIREWALL"
    
    print_spec "Porta 5432 (PostgreSQL) aberta para entrada"
    
    if command -v firewall-cmd &> /dev/null; then
        local fw_status=$(sudo firewall-cmd --state 2>/dev/null || echo "ERRO")
        
        if [[ "$fw_status" == "running" ]]; then
            print_info "FirewallD está ativo"
            local port_check=$(sudo firewall-cmd --list-ports 2>/dev/null | grep -c "5432/tcp" || echo 0)
            if [ "$port_check" -gt 0 ]; then
                print_pass "Porta 5432/tcp liberada"
            else
                print_fail "Porta 5432/tcp NÃO está liberada"
            fi
        else
            print_warn "FirewallD não está ativo ou erro de acesso"
        fi
    elif command -v ufw &> /dev/null; then
        print_info "UFW detectado"
        if sudo ufw status 2>/dev/null | grep -q "active"; then
            local port_check=$(sudo ufw status 2>/dev/null | grep -c "5432" || echo 0)
            if [ "$port_check" -gt 0 ]; then
                print_pass "Porta 5432 liberada em UFW"
            else
                print_fail "Porta 5432 NÃO está liberada"
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
    
    print_spec "NTP/Chrony sincronizado (< 1 segundo desvio)"
    
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
        print_warn "Nenhum NTP (chrony/ntp) detectado"
    fi
    
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    print_info "Hora do sistema: $current_time"
}

check_storage() {
    print_header "6. STORAGE - DISCO NVMe PARA POSTGRESQL"
    
    print_spec "Disco NVMe 800GB-1TB montado em /pgdata"
    
    local nvme_count=$(lsblk -n -l 2>/dev/null | grep -c "nvme" || echo 0)
    
    if [ "$nvme_count" -gt 0 ]; then
        print_info "Disco(s) NVMe detectado(s)"
        lsblk -n -l 2>/dev/null | grep "nvme" | while read line; do
            print_info "  $line"
        done
        
        if [ -d "/pgdata" ]; then
            local pgdata_size=$(df -h /pgdata 2>/dev/null | awk 'NR==2 {print $2}')
            local pgdata_available=$(df -h /pgdata 2>/dev/null | awk 'NR==2 {print $4}')
            local pgdata_device=$(df /pgdata 2>/dev/null | awk 'NR==2 {print $1}')
            
            print_info "/pgdata montado em $pgdata_device"
            print_info "  Tamanho: $pgdata_size, Disponível: $pgdata_available"
            
            if [[ "$pgdata_device" == *"nvme"* ]]; then
                print_pass "/pgdata está em disco NVMe"
            else
                print_fail "/pgdata está em disco não-NVMe"
            fi
        else
            print_fail "/pgdata NÃO existe"
        fi
    else
        print_warn "Nenhum disco NVMe detectado"
        
        if [ -d "/pgdata" ]; then
            local pgdata_device=$(df /pgdata 2>/dev/null | awk 'NR==2 {print $1}')
            print_warn "/pgdata em $pgdata_device (não-NVMe)"
        else
            print_fail "/pgdata não existe e sem disco NVMe"
            print_options \
                "Ver: docs/execucao/VALIDACAO_DISCO_PG01.md" \
                "Opção 1: Procurar disco NVMe (5-10 min)" \
                "Opção 2: Solicitar ao datacenter (4-48h)" \
                "Opção 3: Criar LVM /pgdata (10-15 min)"
        fi
    fi
    
    print_info "Todos os discos:"
    lsblk -n -l -d 2>/dev/null | while read line; do
        echo "    $line"
    done
}

check_postgresql() {
    print_header "7. POSTGRESQL"
    
    print_spec "PostgreSQL 16 instalado e rodando"
    
    if command -v postgres &> /dev/null; then
        local pg_version=$(postgres --version 2>/dev/null || echo "DESCONHECIDO")
        print_info "$pg_version"
        
        if [[ "$pg_version" == *"16"* ]]; then
            print_pass "PostgreSQL 16 detectado"
        else
            print_warn "PostgreSQL versão diferente de 16"
        fi
        
        if sudo systemctl is-active --quiet postgresql 2>/dev/null || sudo systemctl is-active --quiet postgresql-16 2>/dev/null; then
            print_pass "PostgreSQL está rodando"
        else
            print_warn "PostgreSQL não está rodando"
        fi
    else
        print_fail "PostgreSQL NÃO está instalado"
        print_options "Segue: SETUP_POSTGRESQL_PRIMARY.md Passo 4"
    fi
}

check_database() {
    print_header "8. DATABASE ZABBIX"
    
    print_spec "Database 'zabbix' existente com usuário 'zabbix'"
    
    if command -v psql &> /dev/null; then
        local zabbix_db=$(sudo -u postgres psql -l 2>/dev/null | grep -c "zabbix" || echo 0)
        
        if [ "$zabbix_db" -gt 0 ]; then
            print_pass "Database 'zabbix' encontrada"
        else
            print_fail "Database 'zabbix' NÃO encontrada"
            print_options "Segue: SETUP_POSTGRESQL_PRIMARY.md Passo 6"
        fi
    else
        print_fail "psql não encontrado - PostgreSQL não instalado"
    fi
}

check_disk_space() {
    print_header "9. ESPAÇO EM DISCO"
    
    print_spec "/pgdata com >= 800GB disponível"
    
    if [ -d "/pgdata" ]; then
        local pgdata_available=$(df /pgdata 2>/dev/null | awk 'NR==2 {print $4}')
        local pgdata_available_gb=$(echo "scale=2; $pgdata_available / 1024 / 1024" | bc 2>/dev/null || echo "DESCONHECIDO")
        local pgdata_used=$(df /pgdata 2>/dev/null | awk 'NR==2 {print $3}')
        local pgdata_used_gb=$(echo "scale=2; $pgdata_used / 1024 / 1024" | bc 2>/dev/null || echo "DESCONHECIDO")
        
        print_info "Disponível: ${pgdata_available_gb}GB, Usado: ${pgdata_used_gb}GB"
        
        if [[ "$pgdata_available_gb" != "DESCONHECIDO" ]]; then
            if (( $(echo "$pgdata_available_gb >= 800" | bc -l 2>/dev/null) )); then
                print_pass "Espaço disponível >= 800GB"
            else
                print_warn "Espaço disponível < 800GB"
            fi
        fi
    else
        print_warn "/pgdata não existe"
    fi
}

check_connectivity() {
    print_header "10. CONECTIVIDADE DE REDE"
    
    print_spec "Servidor acessível, DNS e HTTPS OK"
    
    local current_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    print_info "IP: $current_ip"
    
    if [ -n "$current_ip" ]; then
        print_pass "IP detectado"
    else
        print_warn "Não foi possível detectar IP"
    fi
    
    if nslookup 8.8.8.8 &>/dev/null; then
        print_pass "DNS funcionando"
    else
        print_warn "DNS pode não estar funcionando"
    fi
    
    if command -v curl &> /dev/null; then
        if timeout 3 curl -I https://github.com 2>/dev/null | grep -q "HTTP"; then
            print_pass "Conectividade HTTPS OK"
        else
            print_warn "Conectividade HTTPS limitada"
        fi
    fi
}

check_selinux() {
    print_header "11. SELINUX (CentOS/RHEL)"
    
    if command -v getenforce &> /dev/null; then
        local selinux_status=$(getenforce 2>/dev/null)
        print_info "SELinux: $selinux_status"
        
        if [[ "$selinux_status" == "Disabled" ]] || [[ "$selinux_status" == "Permissive" ]]; then
            print_pass "SELinux em modo adequado"
        else
            print_warn "SELinux em modo Enforcing (pode bloquear PostgreSQL)"
        fi
    else
        print_info "SELinux não está instalado"
    fi
}

check_kernel_params() {
    print_header "12. PARÂMETROS DO KERNEL"
    
    print_spec "kernel.shmmax >= 16GB para shared_buffers"
    
    if command -v sysctl &> /dev/null; then
        local shmmax=$(sysctl -n kernel.shmmax 2>/dev/null || echo "DESCONHECIDO")
        print_info "kernel.shmmax: $shmmax"
        
        if [[ "$shmmax" != "DESCONHECIDO" ]] && [ "$shmmax" -ge 17179869184 ]; then
            print_pass "kernel.shmmax adequado (>= 16GB)"
        else
            print_warn "kernel.shmmax pode precisar ajuste"
        fi
    else
        print_info "sysctl não encontrado"
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
    elif [ "$FAIL" -le 2 ]; then
        echo -e "\n${YELLOW}${BOLD}⚠️  RESOLVER ALGUMAS FALHAS${NC}\n"
        echo "⚠️  RESOLVER ALGUMAS FALHAS" >> "$REPORT_FILE"
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
    echo "║  SCRIPT DE VALIDAÇÃO - POSTGRESQL PRIMARY (10.31.38.64)        ║"
    echo "║  Projeto: Aeroporto - Zabbix 7.0 LTS + PostgreSQL 16           ║"
    echo "║  Versão: 1.1 - Melhorada (continua mesmo com erros)            ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
    
    {
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║  RELATÓRIO - POSTGRESQL PRIMARY (10.31.38.64)"
        echo "║  Data: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "║  Hostname: $(hostname)"
        echo "║  Versão: 1.1 - Melhorada"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""
    } > "$REPORT_FILE"
    
    # Executar TODAS as checagens (não para em erro)
    check_hostname
    check_os
    check_cpu_ram
    check_firewall
    check_ntp
    check_storage
    check_postgresql
    check_database
    check_disk_space
    check_connectivity
    check_selinux
    check_kernel_params
    
    generate_summary
    print_report_location
    
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}\n"
}

main "$@"
