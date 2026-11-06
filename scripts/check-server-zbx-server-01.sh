#!/bin/bash

################################################################################
#                                                                              #
#  SCRIPT DE VALIDAÇÃO - SERVIDOR ZABBIX SERVER 01                           #
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
REPORT_FILE="/tmp/check-zbx-server-01-$(date +%Y%m%d_%H%M%S).txt"

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
        
        if [[ "$os_name" == *"Ubuntu"* ]] && [[ $(echo "$os_version >= 20.04" | bc) -eq 1 ]]; then
            print_pass "Ubuntu >= 20.04 detectado"
        elif [[ "$os_name" == *"Debian"* ]] && [[ $(echo "$os_version >= 11" | bc) -eq 1 ]]; then
            print_pass "Debian >= 11 detectado"
        elif [[ "$os_name" == *"CentOS"* ]] || [[ "$os_name" == *"Red Hat"* ]]; then
            print_pass "CentOS/RHEL detectado"
        else
            print_fail "SO não suportado ou versão muito antiga"
        fi
    fi
}

check_cpu_ram() {
    print_header "3. CPU E MEMÓRIA RAM"
    
    # CPU
    local cpu_count=$(nproc)
    print_spec "8 vCPU (mínimo) - 16 vCPU (recomendado)"
    print_current "" "$cpu_count vCPU"
    
    if [ "$cpu_count" -ge 16 ]; then
        print_pass "CPU com $cpu_count vCPU (>= 16, recomendado)"
    elif [ "$cpu_count" -ge 8 ]; then
        print_warn "CPU com $cpu_count vCPU (mínimo, performance pode sofrer)"
        print_options "Aumentar para 16 vCPU para melhor performance" "Prosseguir com setup"
    else
        print_fail "CPU com apenas $cpu_count vCPU (< 8)"
        print_options "Solicitar upgrade para mínimo 8 vCPU"
    fi
    
    # RAM
    local ram_gb=$(free -g | awk '/^Mem:/ {print $2}')
    print_spec "16 GB RAM (mínimo) - 32 GB RAM (recomendado)"
    print_current "" "$ram_gb GB"
    
    if [ "$ram_gb" -ge 32 ]; then
        print_pass "RAM com $ram_gb GB (>= 32, recomendado)"
    elif [ "$ram_gb" -ge 16 ]; then
        print_pass "RAM com $ram_gb GB (mínimo)"
    elif [ "$ram_gb" -ge 8 ]; then
        print_warn "RAM com apenas $ram_gb GB (< 16) - Pode ter problemas com 676 ativos"
        print_options "Aumentar para 16 GB mínimo" "Reduzir número de ativos"
    else
        print_fail "RAM com apenas $ram_gb GB (< 8)"
        print_options "Solicitar upgrade para mínimo 16 GB"
    fi
}

check_firewall() {
    print_header "4. FIREWALL"
    
    print_spec "Porta 10051 (Zabbix) aberta para entrada e saída"
    print_spec "Porta 5432 (PostgreSQL) aberta para saída (para 10.31.38.64)"
    
    if command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL
        local fw_status=$(sudo firewall-cmd --state 2>/dev/null || echo "inactive")
        print_current "" "FirewallD: $fw_status"
        
        if [[ "$fw_status" == "running" ]]; then
            local port_10051=$(sudo firewall-cmd --list-ports 2>/dev/null | grep -c "10051/tcp" || echo 0)
            local port_5432=$(sudo firewall-cmd --list-ports 2>/dev/null | grep -c "5432/tcp" || echo 0)
            
            if [ "$port_10051" -gt 0 ]; then
                print_pass "Porta 10051/tcp liberada"
            else
                print_fail "Porta 10051/tcp NÃO está liberada"
                print_options "Executar: sudo firewall-cmd --permanent --add-port=10051/tcp"
            fi
            
            if [ "$port_5432" -gt 0 ]; then
                print_pass "Porta 5432/tcp liberada (PostgreSQL)"
            else
                print_warn "Porta 5432/tcp pode não estar liberada (para saída)"
                print_options "Executar: sudo firewall-cmd --permanent --add-port=5432/tcp"
            fi
        else
            print_warn "FirewallD não está ativo"
        fi
    elif command -v ufw &> /dev/null; then
        print_current "" "UFW"
        local port_10051=$(sudo ufw status | grep -c "10051" || echo 0)
        
        if [ "$port_10051" -gt 0 ]; then
            print_pass "Porta 10051 liberada em UFW"
        else
            print_fail "Porta 10051 NÃO está liberada"
            print_options "Executar: sudo ufw allow 10051/tcp"
        fi
    fi
}

check_ntp() {
    print_header "5. NTP (SINCRONISMO DE HORA)"
    
    print_spec "NTP/Chrony sincronizado (< 1 segundo de desvio)"
    
    if command -v chronyc &> /dev/null; then
        print_current "" "Chrony detectado"
        
        if sudo systemctl is-active --quiet chrony; then
            print_pass "Chrony está rodando"
        else
            print_fail "Chrony não está ativo"
            print_options "Executar: sudo systemctl start chrony"
        fi
    elif command -v ntpstat &> /dev/null; then
        print_current "" "NTP detectado"
        
        if sudo systemctl is-active --quiet ntp; then
            print_pass "NTP está rodando"
        else
            print_fail "NTP não está ativo"
            print_options "Executar: sudo systemctl start ntp"
        fi
    else
        print_warn "Nenhum NTP detectado"
    fi
    
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    print_info "Hora do sistema: $current_time"
}

check_storage() {
    print_header "6. STORAGE - DISCO PARA ZABBIX"
    
    print_spec "SSD/NVMe de 120GB-200GB para /var/lib/zabbix"
    
    local zabbix_storage=""
    if [ -d "/var/lib/zabbix" ]; then
        zabbix_storage="/var/lib/zabbix"
    elif [ -d "/opt/zabbix" ]; then
        zabbix_storage="/opt/zabbix"
    fi
    
    if [ -n "$zabbix_storage" ]; then
        local storage_size=$(df -h "$zabbix_storage" | awk 'NR==2 {print $2}')
        local storage_available=$(df -h "$zabbix_storage" | awk 'NR==2 {print $4}')
        
        print_current "" "$zabbix_storage: $storage_size (Disponível: $storage_available)"
        
        local storage_size_num=$(echo "$storage_size" | sed 's/G//')
        if [ "$storage_size_num" -ge 120 ]; then
            print_pass "Storage >= 120GB"
        elif [ "$storage_size_num" -ge 80 ]; then
            print_warn "Storage entre 80-120GB (mínimo aceitável)"
        else
            print_fail "Storage < 80GB"
            print_options "Expandir storage" "Usar disco adicional para Zabbix"
        fi
    else
        print_info "Zabbix ainda não instalado - storage será verificado pós-instalação"
    fi
    
    # Disco raiz
    local root_available=$(df / | awk 'NR==2 {print $4}')
    local root_available_gb=$(echo "scale=2; $root_available / 1024 / 1024" | bc)
    print_current "" "/ disponível: ${root_available_gb}GB"
    
    if (( $(echo "$root_available_gb >= 50" | bc -l) )); then
        print_pass "Espaço em / >= 50GB"
    else
        print_warn "Espaço em / < 50GB"
    fi
}

check_zabbix() {
    print_header "7. ZABBIX SERVER"
    
    print_spec "Zabbix Server 7.0 LTS instalado"
    
    if command -v zabbix_server &> /dev/null; then
        local zabbix_version=$(zabbix_server -V 2>/dev/null | head -1)
        print_current "" "$zabbix_version"
        
        if [[ "$zabbix_version" == *"7."* ]]; then
            print_pass "Zabbix Server 7.0 LTS detectado"
        else
            print_warn "Zabbix versão diferente da esperada (v7)"
            print_options "Atualizar para Zabbix 7.0 LTS" "Prosseguir com versão atual"
        fi
        
        if sudo systemctl is-active --quiet zabbix-server; then
            print_pass "Zabbix Server está rodando"
        else
            print_warn "Zabbix Server não está rodando"
            print_options "Iniciar: sudo systemctl start zabbix-server"
        fi
    else
        print_fail "Zabbix Server NÃO está instalado"
        print_options "Segue: SETUP_ZABBIX_SERVER_01.md Passo 3"
    fi
}

check_zabbix_agent() {
    print_header "8. ZABBIX AGENT"
    
    print_spec "Zabbix Agent 2.0 instalado para auto-monitoramento"
    
    if command -v zabbix_agent2 &> /dev/null; then
        local agent_version=$(zabbix_agent2 -V 2>/dev/null | head -1)
        print_current "" "$agent_version"
        
        if sudo systemctl is-active --quiet zabbix-agent2; then
            print_pass "Zabbix Agent 2 está rodando"
        else
            print_warn "Zabbix Agent 2 não está rodando"
            print_options "Iniciar: sudo systemctl start zabbix-agent2"
        fi
    elif command -v zabbix_agentd &> /dev/null; then
        print_warn "Zabbix Agent 1 (legacy) detectado ao invés de Agent 2"
        print_options "Atualizar para Zabbix Agent 2.0" "Prosseguir com Agent 1"
    else
        print_fail "Zabbix Agent NÃO está instalado"
        print_options "Segue: SETUP_ZABBIX_SERVER_01.md Passo 2"
    fi
}

check_postgresql_connectivity() {
    print_header "9. CONECTIVIDADE COM POSTGRESQL (10.31.38.64)"
    
    print_spec "Conexão TCP aberta para 10.31.38.64:5432"
    
    if timeout 5 nc -z 10.31.38.64 5432 &> /dev/null; then
        print_pass "Conectividade TCP com 10.31.38.64:5432 OK"
    else
        print_fail "Não consegue conectar em 10.31.38.64:5432"
        print_options \
            "Verificar firewall local (porta 5432 liberada)" \
            "Verificar firewall remoto (10.31.38.64 permite entrada)" \
            "Testar: telnet 10.31.38.64 5432"
    fi
    
    # Testar com psql se instalado
    if command -v psql &> /dev/null; then
        print_info "Testando conexão psql com credenciais padrão..."
        
        if timeout 5 psql -h 10.31.38.64 -U zabbix -d zabbix -c "SELECT 1;" &> /dev/null; then
            print_pass "Autenticação PostgreSQL (usuário zabbix) OK"
        else
            print_warn "Não consegue autenticar como usuário 'zabbix'"
            print_options \
                "Verificar senha do usuário zabbix" \
                "Verificar pg_hba.conf em 10.31.38.64"
        fi
    fi
}

check_zabbix_config() {
    print_header "10. CONFIGURAÇÃO ZABBIX SERVER"
    
    print_spec "Arquivo /etc/zabbix/zabbix_server.conf configurado"
    
    if [ -f "/etc/zabbix/zabbix_server.conf" ]; then
        print_pass "Arquivo zabbix_server.conf existe"
        
        # Verificar parâmetros críticos
        if grep -q "^DBHost=10.31.38.64" /etc/zabbix/zabbix_server.conf; then
            print_pass "DBHost = 10.31.38.64"
        else
            print_warn "DBHost não configurado para 10.31.38.64"
            print_options "Editar: /etc/zabbix/zabbix_server.conf" "Adicionar: DBHost=10.31.38.64"
        fi
        
        if grep -q "^DBName=zabbix" /etc/zabbix/zabbix_server.conf; then
            print_pass "DBName = zabbix"
        else
            print_warn "DBName não configurado"
        fi
        
        if grep -q "^DBUser=zabbix" /etc/zabbix/zabbix_server.conf; then
            print_pass "DBUser = zabbix"
        else
            print_warn "DBUser não configurado"
        fi
    else
        print_fail "Arquivo zabbix_server.conf NÃO existe"
        print_options "Segue: SETUP_ZABBIX_SERVER_01.md"
    fi
}

check_connectivity_network() {
    print_header "11. CONECTIVIDADE DE REDE"
    
    print_spec "Servidor acessível via SSH, DNS funcionando"
    
    local current_ip=$(hostname -I | awk '{print $1}')
    print_current "" "IP: $current_ip"
    
    if [ -n "$current_ip" ]; then
        print_pass "IP configurado: $current_ip"
    else
        print_fail "Não conseguiu detectar IP"
    fi
    
    # DNS
    if nslookup 8.8.8.8 &> /dev/null; then
        print_pass "DNS funcionando"
    else
        print_warn "DNS pode não estar funcionando"
    fi
}

check_selinux() {
    print_header "12. SELINUX (CentOS/RHEL)"
    
    if command -v getenforce &> /dev/null; then
        local selinux_status=$(getenforce)
        print_current "" "$selinux_status"
        
        if [[ "$selinux_status" == "Disabled" ]] || [[ "$selinux_status" == "Permissive" ]]; then
            print_pass "SELinux em modo adequado"
        else
            print_warn "SELinux em modo Enforcing (pode bloquear Zabbix)"
            print_options "Desabilitar: setenforce 0"
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
    
    if [ "$FAIL" -eq 0 ]; then
        echo -e "\n${GREEN}${BOLD}✅ SERVIDOR PRONTO PARA SETUP!${NC}\n"
        return 0
    else
        echo -e "\n${RED}${BOLD}❌ RESOLVER FALHAS ANTES DE PROSSEGUIR${NC}\n"
        return 1
    fi
}

print_report_location() {
    echo -e "${BOLD}Relatório completo salvo em:${NC}"
    echo -e "  ${BLUE}$REPORT_FILE${NC}\n"
}

################################################################################
# MAIN
################################################################################

main() {
    clear
    
    echo -e "${BOLD}${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║  SCRIPT DE VALIDAÇÃO - ZABBIX SERVER 01                        ║"
    echo "║  Projeto: Aeroporto - Zabbix 7.0 LTS + PostgreSQL 16           ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
    
    # Inicializar relatório
    {
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║  RELATÓRIO DE VALIDAÇÃO - ZABBIX SERVER 01                     ║"
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
    check_zabbix
    check_zabbix_agent
    check_postgresql_connectivity
    check_zabbix_config
    check_connectivity_network
    check_selinux
    
    # Resumo
    generate_summary
    print_report_location
    
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}\n"
}

# Executar
main "$@"
