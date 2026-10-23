#!/bin/bash

################################################################################
# Projeto Aeroporto - Script de Validação de Acessos
# 
# Objetivo:
#   Validar conectividade aos domínios críticos do projeto Aeroporto
#   (Zabbix, Grafana, PostgreSQL, Ansible AWX, Docker, Kubernetes)
#
# Uso:
#   ./scripts/validate-access.sh                    # Verbose + relatório
#   ./scripts/validate-access.sh --quiet            # Apenas resumo
#   ./scripts/validate-access.sh --output=json      # Saída JSON
#   ./scripts/validate-access.sh --timeout=10       # Timeout customizado
#
# Pré-requisitos:
#   - curl ou wget
#   - nc (netcat) ou telnet
#   - jq (para saída JSON)
#
# Retorno:
#   0 = Todos os acessos validados
#   1 = Um ou mais acessos falharam
#
################################################################################

set -o pipefail

# Configurações padrão
TIMEOUT=${TIMEOUT:-5}
OUTPUT_FORMAT="text"
VERBOSE=true
REPORT_FILE="access-validation-report.txt"
JSON_FILE="access-validation-report.json"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Cores para output (desabilita se não for terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    RESET='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    RESET=''
fi

# Contadores
TOTAL=0
SUCCESS=0
FAILED=0
RESULTS=()

################################################################################
# Funções Auxiliares
################################################################################

print_header() {
    echo -e "${BLUE}================================ VALIDAÇÃO DE ACESSOS ================================${RESET}"
    echo -e "${BLUE}Projeto: Aeroporto${RESET}"
    echo -e "${BLUE}Data/Hora: $TIMESTAMP${RESET}"
    echo -e "${BLUE}Timeout: ${TIMEOUT}s${RESET}"
    echo -e "${BLUE}========================================================================================${RESET}"
    echo ""
}

log_info() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}ℹ${RESET}  $1"
    fi
}

log_success() {
    echo -e "${GREEN}✓${RESET}  $1"
}

log_failed() {
    echo -e "${RED}✗${RESET}  $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${RESET}  $1"
}

# Testa conectividade via curl (HEAD request)
test_https_curl() {
    local domain=$1
    local port=$2
    
    if command -v curl &> /dev/null; then
        if curl -s --connect-timeout "$TIMEOUT" --max-time "$((TIMEOUT + 2))" \
                 -o /dev/null -w "%{http_code}" "https://${domain}:${port}" 2>/dev/null | grep -q "200\|301\|302\|401\|403"; then
            return 0
        fi
    fi
    return 1
}

# Testa conectividade via telnet/nc (TCP handshake)
test_tcp_connection() {
    local domain=$1
    local port=$2
    
    if command -v nc &> /dev/null; then
        nc -z -w "$TIMEOUT" "$domain" "$port" 2>/dev/null && return 0
    elif command -v telnet &> /dev/null; then
        timeout "$TIMEOUT" telnet "$domain" "$port" </dev/null 2>/dev/null | grep -q "Connected" && return 0
    elif command -v timeout &> /dev/null; then
        timeout "$TIMEOUT" bash -c "echo >/dev/tcp/${domain}/${port}" 2>/dev/null && return 0
    fi
    
    return 1
}

# Testa DNS
test_dns() {
    local domain=$1
    
    if command -v nslookup &> /dev/null; then
        nslookup "$domain" 8.8.8.8 &>/dev/null && return 0
    elif command -v dig &> /dev/null; then
        dig +short "$domain" @8.8.8.8 | grep -q . && return 0
    elif command -v getent &> /dev/null; then
        getent hosts "$domain" &>/dev/null && return 0
    fi
    
    return 1
}

# Valida um acesso (domínio + porta)
validate_access() {
    local component=$1
    local domain=$2
    local port=$3
    local full_name="${component} (${domain}:${port})"
    
    ((TOTAL++))
    
    log_info "Testando: $full_name"
    
    # Teste 1: DNS
    if ! test_dns "$domain"; then
        log_failed "$full_name - DNS falhou"
        RESULTS+=("FAILED|$component|$domain|$port|DNS Resolution")
        ((FAILED++))
        return 1
    fi
    
    # Teste 2: TCP Connection
    if ! test_tcp_connection "$domain" "$port"; then
        log_failed "$full_name - Conexão TCP falhou"
        RESULTS+=("FAILED|$component|$domain|$port|TCP Connection")
        ((FAILED++))
        return 1
    fi
    
    # Teste 3: HTTPS (se curl disponível)
    if command -v curl &> /dev/null; then
        if ! test_https_curl "$domain" "$port"; then
            log_warning "$full_name - HTTPS respondeu com erro, mas TCP OK"
            RESULTS+=("WARNING|$component|$domain|$port|HTTPS Response")
            ((SUCCESS++))
            return 0
        fi
    fi
    
    log_success "$full_name"
    RESULTS+=("SUCCESS|$component|$domain|$port|OK")
    ((SUCCESS++))
    return 0
}

# Exibe relatório em texto
print_text_report() {
    echo ""
    echo -e "${BLUE}================================ RELATÓRIO DE RESULTADOS ================================${RESET}"
    echo ""
    echo -e "Total de acessos testados: ${TOTAL}"
    echo -e "Sucessos: ${GREEN}${SUCCESS}${RESET}"
    echo -e "Falhas: ${RED}${FAILED}${RESET}"
    
    if [ $FAILED -eq 0 ]; then
        echo -e "\n${GREEN}✓ Todos os acessos foram validados com sucesso!${RESET}"
    else
        echo -e "\n${RED}✗ ${FAILED} acesso(s) falharam. Verifique a conectividade e firewall.${RESET}"
    fi
    
    echo ""
    echo -e "${BLUE}========================================================================================${RESET}"
    
    # Detalhes de falhas (se houver)
    if [ $FAILED -gt 0 ]; then
        echo ""
        echo -e "${RED}Detalhes das Falhas:${RESET}"
        for result in "${RESULTS[@]}"; do
            IFS='|' read -r status component domain port reason <<< "$result"
            if [ "$status" != "SUCCESS" ]; then
                echo -e "  ${RED}✗${RESET} $component ($domain:$port) - $reason"
            fi
        done
    fi
}

# Exibe relatório em JSON
print_json_report() {
    local json_output="{"
    json_output+="\"timestamp\": \"$TIMESTAMP\","
    json_output+="\"total\": $TOTAL,"
    json_output+="\"success\": $SUCCESS,"
    json_output+="\"failed\": $FAILED,"
    json_output+="\"results\": ["
    
    local first=true
    for result in "${RESULTS[@]}"; do
        IFS='|' read -r status component domain port reason <<< "$result"
        
        if [ "$first" = true ]; then
            first=false
        else
            json_output+=","
        fi
        
        json_output+="{\"status\": \"$status\", \"component\": \"$component\", \"domain\": \"$domain\", \"port\": \"$port\", \"reason\": \"$reason\"}"
    done
    
    json_output+="]}"
    
    if command -v jq &> /dev/null; then
        echo "$json_output" | jq .
    else
        echo "$json_output"
    fi
}

# Salva relatório em arquivo
save_reports() {
    # Salvar relatório texto
    {
        echo "Relatório de Validação de Acessos - Projeto Aeroporto"
        echo "Data/Hora: $TIMESTAMP"
        echo "=================================================="
        echo ""
        echo "Resumo:"
        echo "  Total testado: $TOTAL"
        echo "  Sucessos: $SUCCESS"
        echo "  Falhas: $FAILED"
        echo ""
        echo "Detalhes:"
        for result in "${RESULTS[@]}"; do
            echo "  $result"
        done
    } > "$REPORT_FILE"
    
    log_info "Relatório texto salvo em: $REPORT_FILE"
    
    # Salvar relatório JSON
    if command -v jq &> /dev/null; then
        print_json_report > "$JSON_FILE"
        log_info "Relatório JSON salvo em: $JSON_FILE"
    fi
}

# Parse de argumentos
parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --quiet)
                VERBOSE=false
                ;;
            --timeout=*)
                TIMEOUT="${1#*=}"
                ;;
            --output=*)
                OUTPUT_FORMAT="${1#*=}"
                ;;
            --help)
                print_usage
                exit 0
                ;;
            *)
                log_warning "Argumento desconhecido: $1"
                ;;
        esac
        shift
    done
}

print_usage() {
    cat << EOF
Uso: ./scripts/validate-access.sh [opções]

Opções:
  --quiet              Desabilita output verboso (apenas resumo)
  --timeout=N          Define timeout em segundos (padrão: 5)
  --output=json        Saída em formato JSON (padrão: text)
  --help               Exibe esta mensagem

Exemplos:
  ./scripts/validate-access.sh
  ./scripts/validate-access.sh --quiet
  ./scripts/validate-access.sh --timeout=10 --output=json
EOF
}

################################################################################
# Lista de Acessos a Validar
################################################################################

validate_all() {
    # Zabbix
    validate_access "Zabbix Repository" "repo.zabbix.com" "443"
    validate_access "Zabbix Website" "www.zabbix.com" "443"
    
    # Grafana
    validate_access "Grafana RPM Repo" "rpm.grafana.com" "443"
    validate_access "Grafana APT Repo" "apt.grafana.com" "443"
    validate_access "Grafana Plugins" "grafana.com" "443"
    
    # PostgreSQL
    validate_access "PostgreSQL Downloads" "download.postgresql.org" "443"
    
    # Ansible AWX
    validate_access "GitHub" "github.com" "443"
    validate_access "GitHub API" "api.github.com" "443"
    validate_access "GitHub Raw Content" "raw.githubusercontent.com" "443"
    validate_access "GitHub Objects" "objects.githubusercontent.com" "443"
    validate_access "GitHub Release Assets" "release-assets.githubusercontent.com" "443"
    validate_access "Quay.io (Container Images)" "quay.io" "443"
    validate_access "Ansible Galaxy" "galaxy.ansible.com" "443"
    
    # Docker Hub
    validate_access "Docker Hub Auth" "auth.docker.io" "443"
    validate_access "Docker Hub Registry" "registry-1.docker.io" "443"
    
    # Kubernetes
    validate_access "Kubernetes Registry" "registry.k8s.io" "443"
}

################################################################################
# Main
################################################################################

main() {
    parse_arguments "$@"
    
    if [ "$VERBOSE" = true ]; then
        print_header
    fi
    
    validate_all
    
    if [ "$OUTPUT_FORMAT" = "json" ]; then
        print_json_report
    else
        print_text_report
    fi
    
    # Salvar relatórios se verbose
    if [ "$VERBOSE" = true ]; then
        save_reports
    fi
    
    # Retorno apropriado
    if [ $FAILED -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Executar main
main "$@"
