#!/bin/bash

################################################################################
#                                                                              #
#  SCRIPT DE VALIDAÇÃO - SERVIDOR POSTGRESQL PRIMARY (10.31.38.64)           #
#                                                                              #
#  Projeto: Aeroporto - Zabbix 7.0 LTS + PostgreSQL 16                        #
#  Função: Validar se o servidor está de acordo com a especificação           #
#  Data: 23/10/2024                                                           #
#  Versão: 1.0                                                                #
#                                                                              #
################################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Contadores
PASS=0
FAIL=0
WARN=0
INFO=0

# Arquivo de relatório
REPORT_FILE="/tmp/check-pg-01-$(date +%Y%m%d_%H%M%S).txt"

################################################################################
# FUNÇÕES
################################################################################

print_header() {
    echo -e "\n${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}\n"
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
    
    local current_hostname=$(hostname)
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
        
        if [[ "$os_name" == *"Ubuntu"* ]] && [[ $(echo "$os_version >= 20.04" | bc) -eq 1 ]]; then
            print_pass "Ubuntu >= 20.04 detectado"
        elif [[ "$os_name" == *"Debian"* ]] && [[ $(echo "$os_version >= 11" | bc) -eq 1 ]]; then
            print_pass "Debian >= 11 detectado"
        elif [[ "$os_name" == *"CentOS"* ]] || [[ "$os_name" == *"Red Hat"* ]]; then
            print_pass "CentOS/RHEL detectado"
        else
            print_fail "SO não suportado ou versão muito antiga"
            print_options "Solicitar atualização ao datacenter" "Usar versão suportada"
        fi
    else
        print_fail "Não foi possível detectar SO"
    fi
}

check_cpu_ram() {
    print_header "3. CPU E MEMÓRIA RAM"
    
    # CPU
    local cpu_count=$(nproc)
    print_spec "20 vCPU"
    print_current "" "$cpu_count vCPU"
    
    if [ "$cpu_count" -ge 20 ]; then
        print_pass "CPU com $cpu_count vCPU (>= 20)"
    elif [ "$cpu_count" -ge 16 ]; then
        print_warn "CPU com $cpu_count vCPU (< 20) - Performance pode ser degradada"
        print_options "Aumentar para 20+ vCPU" "Prosseguir com resource tuning"
    else
        print_fail "CPU com apenas $cpu_count vCPU (< 16)"
        print_options "Solicitar upgrade para 20+ vCPU" "Limitar dados a 30-60 dias"
    fi
    
    # RAM
    local ram_gb=$(free -g | awk '/^Mem:/ {print $2}')
    print_spec "96 GB RAM"
    print_current "" "$ram_gb GB"
    
    if [ "$ram_gb" -ge 96 ]; then
        print_pass "RAM com $ram_gb GB (>= 96)"
    elif [ "$ram_gb" -ge 64 ]; then
        print_warn "RAM com $ram_gb GB (< 96) - Reduzir shared_buffers/effective_cache"
        print_options "Aumentar para 96 GB" "Ajustar postgresql.conf para $ram_gb GB"
    else
        print_fail "RAM com apenas $ram_gb GB (< 64)"
        print_options "Solicitar upgrade para 96 GB" "Reduzir retenção de dados"
    fi
}

check_firewall() {
    print_header "4. FIREWALL"
    
    print_spec "Porta 5432 (PostgreSQL) aberta para zbx-server-01 e zbx-fe-01"
    
    if command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL
        local fw_status=$(sudo firewall-cmd --state 2>/dev/null || echo "inactive")
        print_current "" "FirewallD: $fw_status"
        
        if [[ "$fw_status" == "running" ]]; then
            local port_5432=$(sudo firewall-cmd --list-ports 2>/dev/null | grep -c "5432/tcp" || echo 0)
            if [ "$port_5432" -gt 0 ]; then
                print_pass "Porta 5432/tcp liberada em FirewallD"
            else
                print_fail "Porta 5432/tcp NÃO está liberada em FirewallD"
                print_options \
                    "Executar: sudo firewall-cmd --permanent --add-port=5432/tcp" \
                    "Executar: sudo firewall-cmd --reload"
            fi
        else
            print_warn "FirewallD não está ativo"
            print_options "Ativar: sudo systemctl start firewalld" "Prosseguir com setup"
        fi
    elif command -v ufw &> /dev/null; then
        # Ubuntu/Debian
        local ufw_status=$(sudo ufw status | grep -c "Status: active" || echo 0)
        print_current "" "UFW"
        
        if [ "$ufw_status" -gt 0 ]; then
            local port_5432=$(sudo ufw status | grep -c "5432" || echo 0)
            if [ "$port_5432" -gt 0 ]; then
                print_pass "Porta 5432 liberada em UFW"
            else
                print_fail "Porta 5432 NÃO está liberada em UFW"
                print_options \
                    "Executar: sudo ufw allow 5432/tcp" \
                    "Executar: sudo ufw enable"
            fi
        else
            print_warn "UFW não está ativo"
            print_options "Ativar: sudo ufw enable" "Prosseguir com setup"
        fi
    else
        print_warn "Nenhum firewall detectado (iptables? ufw? firewalld?)"
        print_options "Verificar manualmente: sudo iptables -L" "Prosseguir com setup"
    fi
}

check_ntp() {
    print_header "5. NTP (SINCRONISMO DE HORA)"
    
    print_spec "NTP/Chrony sincronizado (< 1 segundo de desvio)"
    
    if command -v chronyc &> /dev/null; then
        print_current "" "Chrony detectado"
        
        local chrony_tracking=$(sudo chronyc tracking 2>/dev/null | grep "System time" | head -1)
        print_current "" "$chrony_tracking"
        
        if sudo systemctl is-active --quiet chrony; then
            print_pass "Chrony está rodando"
        else
            print_fail "Chrony não está ativo"
            print_options "Executar: sudo systemctl start chrony" "Executar: sudo systemctl enable chrony"
        fi
    elif command -v ntpstat &> /dev/null; then
        print_current "" "NTP detectado"
        
        local ntp_status=$(ntpstat 2>/dev/null | head -1 || echo "NTP não configurado")
        print_current "" "$ntp_status"
        
        if sudo systemctl is-active --quiet ntp; then
            print_pass "NTP está rodando"
        else
            print_fail "NTP não está ativo"
            print_options "Executar: sudo systemctl start ntp" "Executar: sudo systemctl enable ntp"
        fi
    else
        print_warn "Nenhum NTP detectado (chrony ou ntp)"
        print_options \
            "Instalar Chrony: apt install chrony (Debian/Ubuntu)" \
            "Instalar NTP: yum install ntp (CentOS/RHEL)"
    fi
    
    # Verificar hora atual
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    print_info "Hora do sistema: $current_time"
}

check_storage() {
    print_header "6. STORAGE - DISCO NVMe PARA POSTGRESQL"
    
    print_spec "Disco NVMe 800GB-1TB montado em /pgdata"
    
    # Listar discos
    local nvme_count=$(lsblk -n -l | grep -c "nvme" || echo 0)
    
    if [ "$nvme_count" -gt 0 ]; then
        print_info "Disco(s) NVMe detectado(s):"
        lsblk -n -l | grep "nvme" | while read line; do
            print_info "  $line"
        done
        
        # Verificar /pgdata
        if [ -d "/pgdata" ]; then
            local pgdata_size=$(df -h /pgdata | awk 'NR==2 {print $2}')
            local pgdata_available=$(df -h /pgdata | awk 'NR==2 {print $4}')
            local pgdata_mountpoint=$(df /pgdata | awk 'NR==2 {print $6}')
            local pgdata_device=$(df /pgdata | awk 'NR==2 {print $1}')
            
            print_current "" "/pgdata montado em $pgdata_device"
            print_info "  Tamanho: $pgdata_size, Disponível: $pgdata_available"
            
            if [[ "$pgdata_device" == *"nvme"* ]]; then
                print_pass "/pgdata está em disco NVMe"
                
                # Verificar tamanho
                local pgdata_size_num=$(echo "$pgdata_size" | sed 's/G//')
                if [ "$pgdata_size_num" -ge 800 ]; then
                    print_pass "Tamanho de /pgdata >= 800GB"
                else
                    print_warn "Tamanho de /pgdata < 800GB (apenas $pgdata_size_num GB)"
                    print_options "Expandir LV/partição" "Aceitar tamanho menor"
                fi
            else
                print_fail "/pgdata está em disco não-NVMe ($pgdata_device)"
                print_options \
                    "Conectar disco NVMe ao servidor" \
                    "Remontar /pgdata para NVMe" \
                    "Usar LVM com aviso de performance degradada"
            fi
        else
            print_fail "/pgdata NÃO está montado"
            print_options \
                "Verificar VALIDACAO_DISCO_PG01.md no repositório" \
                "Opção 1: Procurar disco NVMe existente (5-10 min)" \
                "Opção 2: Solicitar disco NVMe ao datacenter (4-48h)" \
                "Opção 3: Usar espaço LVM existente (não ideal, 10-15 min)"
        fi
    else
        # Sem NVMe, verificar LVM
        print_warn "Nenhum disco NVMe detectado"
        
        if [ -d "/pgdata" ]; then
            local pgdata_device=$(df /pgdata | awk 'NR==2 {print $1}')
            print_current "" "/pgdata em $pgdata_device (não-NVMe)"
            
            if [[ "$pgdata_device" == *"ubuntu--vg"* ]]; then
                print_warn "/pgdata está em LVM (performance degradada)"
                print_options \
                    "Adicionar disco NVMe ao servidor" \
                    "Mover /pgdata para NVMe quando disponível" \
                    "Aceitar performance degradada e prosseguir"
            else
                print_fail "/pgdata em dispositivo desconhecido: $pgdata_device"
            fi
        else
            print_fail "/pgdata NÃO existe e NEM há disco NVMe"
            print_options \
                "Executar script: docs/execucao/VALIDACAO_DISCO_PG01.md" \
                "Opção 1: Procurar disco NVMe (5-10 min)" \
                "Opção 2: Solicitar ao datacenter (4-48h)" \
                "Opção 3: Criar LVM /pgdata (10-15 min)"
        fi
    fi
    
    # Listar todos os discos
    print_info "Todos os discos do servidor:"
    lsblk -n -l -d | while read line; do
        echo "    $line" | tee -a "$REPORT_FILE"
    done
}

check_postgresql() {
    print_header "7. POSTGRESQL"
    
    print_spec "PostgreSQL 16 instalado e rodando"
    
    if command -v postgres &> /dev/null; then
        local pg_version=$(postgres --version)
        print_current "" "$pg_version"
        
        if [[ "$pg_version" == *"16"* ]]; then
            print_pass "PostgreSQL 16 detectado"
        elif [[ "$pg_version" == *"15"* ]] || [[ "$pg_version" == *"14"* ]]; then
            print_warn "PostgreSQL versão compatível mas não é v16: $pg_version"
            print_options "Atualizar para PostgreSQL 16" "Prosseguir com versão atual"
        else
            print_fail "PostgreSQL versão não suportada: $pg_version"
        fi
        
        # Verificar se está rodando
        if sudo systemctl is-active --quiet postgresql || sudo systemctl is-active --quiet postgresql-16; then
            print_pass "PostgreSQL está rodando"
        else
            print_warn "PostgreSQL não está rodando"
            print_options \
                "Iniciar: sudo systemctl start postgresql-16" \
                "Habilitar: sudo systemctl enable postgresql-16"
        fi
    else
        print_fail "PostgreSQL NÃO está instalado"
        print_options \
            "Segue: SETUP_POSTGRESQL_PRIMARY.md Passo 4" \
            "Instalação automática via package manager"
    fi
}

check_database() {
    print_header "8. DATABASE ZABBIX"
    
    print_spec "Database 'zabbix' existente com usuário 'zabbix'"
    
    if command -v psql &> /dev/null; then
        # Verificar database
        local zabbix_db=$(sudo -u postgres psql -l 2>/dev/null | grep -c "zabbix" || echo 0)
        
        if [ "$zabbix_db" -gt 0 ]; then
            print_pass "Database 'zabbix' encontrada"
            
            # Verificar usuário
            local zabbix_user=$(sudo -u postgres psql -c "SELECT 1 FROM pg_roles WHERE rolname='zabbix';" 2>/dev/null | grep -c "1" || echo 0)
            
            if [ "$zabbix_user" -gt 0 ]; then
                print_pass "Usuário 'zabbix' encontrado"
            else
                print_fail "Usuário 'zabbix' NÃO encontrado"
                print_options "Criar: sudo -u postgres psql -c \"CREATE ROLE zabbix WITH LOGIN PASSWORD 'senha';\""
            fi
        else
            print_fail "Database 'zabbix' NÃO encontrada"
            print_options "Segue: SETUP_POSTGRESQL_PRIMARY.md Passo 6" "Criar database e schema Zabbix"
        fi
    else
        print_fail "psql não encontrado - PostgreSQL não instalado"
        print_options "Instalar PostgreSQL primeiro" "Segue: SETUP_POSTGRESQL_PRIMARY.md Passo 4"
    fi
}

check_disk_space() {
    print_header "9. ESPAÇO EM DISCO"
    
    print_spec "/pgdata com >= 800GB disponível (para retenção 180 dias ~316GB)"
    
    if [ -d "/pgdata" ]; then
        local pgdata_available=$(df /pgdata | awk 'NR==2 {print $4}')
        local pgdata_available_gb=$(echo "scale=2; $pgdata_available / 1024 / 1024" | bc)
        local pgdata_used=$(df /pgdata | awk 'NR==2 {print $3}')
        local pgdata_used_gb=$(echo "scale=2; $pgdata_used / 1024 / 1024" | bc)
        
        print_current "" "Disponível: ${pgdata_available_gb}GB, Usado: ${pgdata_used_gb}GB"
        
        if (( $(echo "$pgdata_available_gb >= 800" | bc -l) )); then
            print_pass "Espaço disponível >= 800GB"
        elif (( $(echo "$pgdata_available_gb >= 500" | bc -l) )); then
            print_warn "Espaço disponível entre 500-800GB"
            print_options "Expandir disco" "Reduzir retenção para 60-90 dias"
        else
            print_fail "Espaço disponível < 500GB"
            print_options "Expandir disco urgentemente" "Limpar dados antigos"
        fi
    else
        print_warn "/pgdata não existe - não foi possível validar"
        print_options "Criar /pgdata conforme VALIDACAO_DISCO_PG01.md"
    fi
    
    # Espaço em /
    local root_available=$(df / | awk 'NR==2 {print $4}')
    local root_available_gb=$(echo "scale=2; $root_available / 1024 / 1024" | bc)
    print_current "" "/ disponível: ${root_available_gb}GB"
    
    if (( $(echo "$root_available_gb >= 50" | bc -l) )); then
        print_pass "Espaço em / >= 50GB"
    else
        print_warn "Espaço em / < 50GB"
        print_options "Limpar arquivos antigos" "Expandir partição"
    fi
}

check_connectivity() {
    print_header "10. CONECTIVIDADE DE REDE"
    
    print_spec "Servidor acessível em 10.31.38.64:5432, resolvê IP corretamente"
    
    # IP do servidor
    local current_ip=$(hostname -I | awk '{print $1}')
    print_current "" "IP: $current_ip"
    
    if [[ "$current_ip" == "10.31.38.64" ]] || [[ "$current_ip" == *"10.31"* ]]; then
        print_pass "IP configurado corretamente"
    else
        print_warn "IP inesperado: $current_ip (esperado: 10.31.38.64)"
        print_options "Verificar configuração de rede" "Ajustar /etc/network/interfaces ou netplan"
    fi
    
    # DNS
    if nslookup 8.8.8.8 &> /dev/null; then
        print_pass "DNS funcionando"
    else
        print_warn "DNS pode não estar funcionando corretamente"
        print_options "Verificar /etc/resolv.conf" "Configurar nameserver"
    fi
    
    # Conectividade externa
    if timeout 5 curl -I https://github.com &> /dev/null; then
        print_pass "Conectividade HTTPS (internet) OK"
    else
        print_warn "Conectividade HTTPS pode estar limitada"
        print_options "Verificar firewall/proxy" "Testar: curl -v https://github.com"
    fi
}

check_selinux() {
    print_header "11. SELINUX (CentOS/RHEL)"
    
    print_spec "SELinux desabilitado ou em modo permissive"
    
    if command -v getenforce &> /dev/null; then
        local selinux_status=$(getenforce)
        print_current "" "$selinux_status"
        
        if [[ "$selinux_status" == "Disabled" ]] || [[ "$selinux_status" == "Permissive" ]]; then
            print_pass "SELinux em modo adequado"
        else
            print_warn "SELinux em modo Enforcing (pode bloquear PostgreSQL)"
            print_options \
                "Desabilitar: setenforce 0 (temporário)" \
                "Desabilitar permanente: editar /etc/selinux/config" \
                "Reboot necessário após mudança"
        fi
    else
        print_info "SELinux não está instalado (típico em Ubuntu/Debian)"
    fi
}

check_kernel_params() {
    print_header "12. PARÂMETROS DO KERNEL"
    
    print_spec "Parâmetros otimizados para PostgreSQL"
    
    # Verificar alguns parâmetros importantes
    local shared_buffers_max=$(sysctl -n kernel.shmmax 2>/dev/null || echo "N/A")
    print_current "" "kernel.shmmax: $shared_buffers_max"
    
    if [ "$shared_buffers_max" != "N/A" ] && [ "$shared_buffers_max" -ge 17179869184 ]; then
        print_pass "kernel.shmmax adequado (>= 16GB)"
    else
        print_info "kernel.shmmax pode precisar ajuste"
        print_options "Ajustar em /etc/sysctl.conf" "Recarregar: sysctl -p"
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
    
    echo "Total de verificações: $total" >> "$REPORT_FILE"
    echo "  Passou: $PASS" >> "$REPORT_FILE"
    echo "  Falhou: $FAIL" >> "$REPORT_FILE"
    echo "  Aviso: $WARN" >> "$REPORT_FILE"
    echo "  Informação: $INFO" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    if [ "$FAIL" -eq 0 ]; then
        echo -e "\n${GREEN}${BOLD}✅ SERVIDOR PRONTO PARA SETUP!${NC}\n"
        echo "✅ SERVIDOR PRONTO PARA SETUP!" >> "$REPORT_FILE"
        return 0
    elif [ "$FAIL" -le 3 ]; then
        echo -e "\n${YELLOW}${BOLD}⚠️  SERVIDOR QUASE PRONTO - RESOLVER FALHAS CRÍTICAS${NC}\n"
        echo "⚠️  SERVIDOR QUASE PRONTO - RESOLVER FALHAS CRÍTICAS" >> "$REPORT_FILE"
        return 1
    else
        echo -e "\n${RED}${BOLD}❌ SERVIDOR NÃO ESTÁ PRONTO - MÚLTIPLAS FALHAS${NC}\n"
        echo "❌ SERVIDOR NÃO ESTÁ PRONTO - MÚLTIPLAS FALHAS" >> "$REPORT_FILE"
        return 2
    fi
}

print_report_location() {
    echo -e "\n${BOLD}Relatório completo salvo em:${NC}"
    echo -e "  ${BLUE}$REPORT_FILE${NC}\n"
    echo "Relatório completo salvo em: $REPORT_FILE" >> "$REPORT_FILE"
}

################################################################################
# MAIN
################################################################################

main() {
    clear
    
    echo -e "${BOLD}${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║  SCRIPT DE VALIDAÇÃO - SERVIDOR POSTGRESQL PRIMARY             ║"
    echo "║  IP: 10.31.38.64                                              ║"
    echo "║  Projeto: Aeroporto - Zabbix 7.0 LTS + PostgreSQL 16           ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
    
    # Inicializar relatório
    {
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║  RELATÓRIO DE VALIDAÇÃO - SERVIDOR POSTGRESQL PRIMARY          ║"
        echo "║  IP: 10.31.38.64                                              ║"
        echo "║  Data: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "║  Hostname: $(hostname)"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""
    } > "$REPORT_FILE"
    
    # Executar checagens
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
    
    # Resumo
    generate_summary
    print_report_location
    
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}\n"
}

# Executar
main "$@"
