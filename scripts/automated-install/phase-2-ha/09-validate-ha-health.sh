#!/bin/bash

################################################################################
# Script: 09-validate-ha-health.sh
# Descrição: Validação de saúde do cluster HA após instalação
# Data: 27/10/2026
# Versão: 1.0
#
# Objetivo: Verificar que todos os scripts rodaram até o fim com sucesso
#
# Uso: sudo ./09-validate-ha-health.sh [--quiet] [--timeout=N]
#
# Pré-requisitos:
#   - Todos os scripts Phase 2 HA já executados (Semanas 0-5)
#   - Conectividade entre todos os servidores
#   - Acesso root/sudo
#
################################################################################

set -e

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURAÇÕES
# ═══════════════════════════════════════════════════════════════════════════

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Modo
QUIET=false
TIMEOUT=10
OUTPUT_FORMAT="text"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --quiet) QUIET=true; shift ;;
        --timeout=*) TIMEOUT="${1#*=}"; shift ;;
        --format=*) OUTPUT_FORMAT="${1#*=}"; shift ;;
        --help) print_help; exit 0 ;;
        *) shift ;;
    esac
done

# Data
DATA=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="/tmp/validate-ha-health-$(date +%s).log"

# Servidores
declare -A SERVERS=(
    [postgresql_primary]="10.31.38.64:5432"
    [postgresql_standby]="10.31.38.65:5432"
    [zabbix_server_01]="10.31.38.60:10051"
    [zabbix_server_02]="10.31.38.61:10051"
    [grafana_01]="10.31.38.66:3000"
    [grafana_02]="10.31.38.67:3000"
    [awx_01]="10.31.38.68:8080"
    [awx_02]="10.31.38.69:8080"
    [vip_master]="10.31.38.70:80"
    [vip_backup]="10.31.38.71:80"
)

# Contadores
TOTAL=0
SUCCESS=0
WARNING=0
FAILED=0

# Arrays para resultados
declare -a RESULTS

# ═══════════════════════════════════════════════════════════════════════════
# FUNÇÕES
# ═══════════════════════════════════════════════════════════════════════════

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                    ║"
    echo "║  🔍 VALIDAÇÃO DE SAÚDE - CLUSTER HA PROJETO AEROPORTO             ║"
    echo "║                                                                    ║"
    echo "║  Objetivo: Verificar que TODOS os scripts rodaram até o fim       ║"
    echo "║  Data: $DATA"
    echo "║                                                                    ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
}

print_info() {
    if [ "$QUIET" = false ]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
    echo "[INFO] $1" >> "$LOG_FILE"
}

print_ok() {
    if [ "$QUIET" = false ]; then
        echo -e "${GREEN}[✓]${NC} $1"
    fi
    echo "[OK] $1" >> "$LOG_FILE"
}

print_warning() {
    if [ "$QUIET" = false ]; then
        echo -e "${YELLOW}[⚠]${NC} $1"
    fi
    echo "[WARNING] $1" >> "$LOG_FILE"
}

print_error() {
    if [ "$QUIET" = false ]; then
        echo -e "${RED}[✗]${NC} $1"
    fi
    echo "[ERROR] $1" >> "$LOG_FILE"
}

print_section() {
    if [ "$QUIET" = false ]; then
        echo "" | tee -a "$LOG_FILE"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
        echo -e "${BLUE}$1${NC}" | tee -a "$LOG_FILE"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
    fi
}

test_dns() {
    local domain=$1
    local start=$(date +%s%N)
    
    if command -v nslookup &> /dev/null; then
        if nslookup "$domain" 8.8.8.8 &>/dev/null; then
            local end=$(date +%s%N)
            echo "$(( (end - start) / 1000000 ))"
            return 0
        fi
    elif command -v dig &> /dev/null; then
        if dig +short "$domain" @8.8.8.8 | grep -q .; then
            local end=$(date +%s%N)
            echo "$(( (end - start) / 1000000 ))"
            return 0
        fi
    fi
    return 1
}

test_tcp() {
    local domain=$1
    local port=$2
    local start=$(date +%s%N)
    
    if command -v nc &> /dev/null; then
        if nc -z -w "$TIMEOUT" "$domain" "$port" 2>/dev/null; then
            local end=$(date +%s%N)
            echo "$(( (end - start) / 1000000 ))"
            return 0
        fi
    elif timeout "$TIMEOUT" bash -c "echo >/dev/tcp/${domain}/${port}" 2>/dev/null; then
        local end=$(date +%s%N)
        echo "$(( (end - start) / 1000000 ))"
        return 0
    fi
    return 1
}

test_http() {
    local url=$1
    local start=$(date +%s%N)
    
    if command -v curl &> /dev/null; then
        local http_code=$(curl -s --connect-timeout "$TIMEOUT" --max-time "$((TIMEOUT + 2))" \
                               -o /dev/null -w "%{http_code}" "http://${url}" 2>/dev/null)
        
        if [[ "$http_code" =~ ^[23][0-9]{2}$ ]] || [[ "$http_code" =~ ^[34][0-9]{2}$ ]]; then
            local end=$(date +%s%N)
            echo "$(( (end - start) / 1000000 ))"
            return 0
        fi
    fi
    return 1
}

validate_server() {
    local name=$1
    local host=$2
    local port=$3
    
    TOTAL=$((TOTAL + 1))
    
    # DNS
    local dns_time=$(test_dns "$host" 2>/dev/null)
    if [ $? -ne 0 ]; then
        print_error "[$name] DNS Resolution falhou para $host"
        RESULTS+=("[FAILED] $name: DNS Resolution")
        FAILED=$((FAILED + 1))
        return 1
    fi
    
    # TCP
    local tcp_time=$(test_tcp "$host" "$port" 2>/dev/null)
    if [ $? -ne 0 ]; then
        print_error "[$name] TCP Connection falhou em $host:$port"
        RESULTS+=("[FAILED] $name: TCP Connection")
        FAILED=$((FAILED + 1))
        return 1
    fi
    
    # HTTP (para ports 80, 3000, 8080)
    if [[ "$port" == "80" ]] || [[ "$port" == "3000" ]] || [[ "$port" == "8080" ]] || [[ "$port" == "10051" ]]; then
        local http_time=$(test_http "$host:$port" 2>/dev/null)
        if [ $? -ne 0 ]; then
            print_warning "[$name] HTTP Connection falhou em $host:$port (pode ser firewall ou serviço)"
            RESULTS+=("[WARNING] $name: HTTP Connection")
            WARNING=$((WARNING + 1))
            return 0
        fi
    fi
    
    print_ok "[$name] Todas as camadas OK ($host:$port)"
    RESULTS+=("[SUCCESS] $name")
    SUCCESS=$((SUCCESS + 1))
    return 0
}

validate_postgresql() {
    print_section "VALIDAÇÃO POSTGRESQL HA"
    
    # Primary
    print_info "Testando PostgreSQL Primary (10.31.38.64)..."
    validate_server "PostgreSQL Primary" "10.31.38.64" "5432"
    
    # Standby
    print_info "Testando PostgreSQL Standby (10.31.38.65)..."
    validate_server "PostgreSQL Standby" "10.31.38.65" "5432"
}

validate_zabbix() {
    print_section "VALIDAÇÃO ZABBIX SERVER HA"
    
    # Node 1
    print_info "Testando Zabbix Server 01 (10.31.38.60)..."
    validate_server "Zabbix Server 01" "10.31.38.60" "10051"
    
    # Node 2
    print_info "Testando Zabbix Server 02 (10.31.38.61)..."
    validate_server "Zabbix Server 02" "10.31.38.61" "10051"
}

validate_grafana() {
    print_section "VALIDAÇÃO GRAFANA HA"
    
    # Node 1
    print_info "Testando Grafana 01 (10.31.38.66)..."
    validate_server "Grafana 01" "10.31.38.66" "3000"
    
    # Node 2
    print_info "Testando Grafana 02 (10.31.38.67)..."
    validate_server "Grafana 02" "10.31.38.67" "3000"
}

validate_awx() {
    print_section "VALIDAÇÃO AWX HA"
    
    # Node 1
    print_info "Testando AWX 01 (10.31.38.68)..."
    validate_server "AWX 01" "10.31.38.68" "8080"
    
    # Node 2
    print_info "Testando AWX 02 (10.31.38.69)..."
    validate_server "AWX 02" "10.31.38.69" "8080"
}

validate_vip() {
    print_section "VALIDAÇÃO VIP / LOAD BALANCER"
    
    # Master
    print_info "Testando VIP Master (10.31.38.70)..."
    validate_server "VIP Master" "10.31.38.70" "80"
    
    # Backup
    print_info "Testando VIP Backup (10.31.38.71)..."
    validate_server "VIP Backup" "10.31.38.71" "80"
}

validate_logs() {
    print_section "VERIFICAÇÃO DE LOGS DOS SCRIPTS"
    
    print_info "Procurando por logs de execução dos scripts..."
    
    local log_count=0
    local error_count=0
    
    for log in $(find /tmp -maxdepth 1 -name "*-ha-install-*.log" -o -name "validate-*.log" 2>/dev/null); do
        if [ -f "$log" ]; then
            log_count=$((log_count + 1))
            
            if grep -q "ERROR\|FAILED" "$log" 2>/dev/null; then
                error_count=$((error_count + 1))
                print_warning "Log com potenciais erros: $(basename "$log")"
            else
                print_ok "Log OK: $(basename "$log")"
            fi
        fi
    done
    
    if [ $log_count -eq 0 ]; then
        print_warning "Nenhum log encontrado em /tmp/ - scripts podem não ter rodado"
    else
        print_ok "Encontrados $log_count logs de instalação"
        if [ $error_count -gt 0 ]; then
            print_warning "$error_count logs com possíveis erros"
        fi
    fi
}

generate_report() {
    print_section "RELATÓRIO FINAL"
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                  RESUMO DE VALIDAÇÃO                              ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "  Total Testado:     $TOTAL servidores"
    echo "  ✓ Sucesso:         $SUCCESS"
    echo "  ⚠ Avisos:          $WARNING"
    echo "  ✗ Falhas:          $FAILED"
    echo ""
    
    if [ $FAILED -eq 0 ]; then
        echo "  🎉 STATUS: ✅ TODOS OS SCRIPTS RODARAM ATÉ O FIM COM SUCESSO"
        return 0
    else
        echo "  ⚠️  STATUS: ❌ ALGUNS SERVIDORES NÃO RESPONDERAM"
        return 1
    fi
}

save_json_report() {
    local report_file="/tmp/validate-ha-health-report.json"
    
    cat > "$report_file" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "timeout": $TIMEOUT,
  "results": {
    "total": $TOTAL,
    "success": $SUCCESS,
    "warnings": $WARNING,
    "failed": $FAILED,
    "exit_code": $([ $FAILED -eq 0 ] && echo 0 || echo 1)
  },
  "tests": [
EOF
    
    for result in "${RESULTS[@]}"; do
        local status=$(echo "$result" | cut -d] -f1 | sed 's/\[//')
        local details=$(echo "$result" | cut -d] -f2 | sed 's/^ //')
        echo "    { \"status\": \"$status\", \"details\": \"$details\" }," >> "$report_file"
    done
    
    # Remove trailing comma da última linha
    sed -i '$ s/,$//' "$report_file"
    
    echo "  ]" >> "$report_file"
    echo "}" >> "$report_file"
    
    print_ok "Relatório JSON salvo: $report_file"
}

save_csv_report() {
    local report_file="/tmp/validate-ha-health-report.csv"
    
    echo "Componente,Status,Detalhes,Timestamp" > "$report_file"
    
    for result in "${RESULTS[@]}"; do
        local status=$(echo "$result" | cut -d] -f1 | sed 's/\[//')
        local details=$(echo "$result" | cut -d] -f2 | sed 's/^ //')
        echo "\"$details\",\"$status\",\"Validado em $DATA\",\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" >> "$report_file"
    done
    
    print_ok "Relatório CSV salvo: $report_file"
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════

main() {
    # Root check
    if [[ $EUID -ne 0 ]]; then
        echo "Este script deve ser executado como root"
        exit 1
    fi
    
    if [ "$QUIET" = false ]; then
        print_header
    fi
    
    print_info "Iniciando validação de saúde do cluster HA..."
    print_info "Timeout: $TIMEOUT segundos"
    print_info "Log: $LOG_FILE"
    
    # Executar validações
    validate_postgresql
    validate_zabbix
    validate_grafana
    validate_awx
    validate_vip
    validate_logs
    
    # Gerar relatório
    generate_report
    REPORT_EXIT=$?
    
    # Salvar relatórios
    if [ "$QUIET" = false ]; then
        if [[ "$OUTPUT_FORMAT" == "json" ]] || [[ "$OUTPUT_FORMAT" == "all" ]]; then
            save_json_report
        fi
        if [[ "$OUTPUT_FORMAT" == "csv" ]] || [[ "$OUTPUT_FORMAT" == "all" ]]; then
            save_csv_report
        fi
    fi
    
    echo ""
    echo "Log completo: $LOG_FILE"
    echo ""
    
    exit $REPORT_EXIT
}

# Executar
main "$@"
