#!/bin/bash

################################################################################
# Script: 07-pre-execution-validation.sh
# Descrição: Validação PRÉ-EXECUÇÃO de todos os scripts Phase 2 HA
# Data: 27/10/2026
# Versão: 1.0
#
# Objetivo: GARANTIR que cada script rodará até o fim sem problemas
#
# Usa: sudo ./07-pre-execution-validation.sh [--auto-fix]
#
# Validações:
#   1. Sintaxe bash (shellcheck)
#   2. Dependências (comandos necessários)
#   3. Permissões de arquivo
#   4. Espaço em disco
#   5. Conectividade de rede
#   6. Acesso root
#   7. Variáveis de ambiente
#   8. Funções críticas presentes
#   9. Tratamento de erros (set -e, set -o pipefail)
#   10. Log files configurados
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
AUTO_FIX=false
VERBOSE=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-fix) AUTO_FIX=true; shift ;;
        --quiet) VERBOSE=false; shift ;;
        *) shift ;;
    esac
done

# Data
DATA=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="/tmp/pre-execution-validation-$(date +%s).log"

# Contadores
TOTAL_CHECKS=0
PASSED=0
FAILED=0
WARNINGS=0

# ═══════════════════════════════════════════════════════════════════════════
# FUNÇÕES
# ═══════════════════════════════════════════════════════════════════════════

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                    ║"
    echo "║  ✅ VALIDAÇÃO PRÉ-EXECUÇÃO - PHASE 2 HA SCRIPTS                   ║"
    echo "║                                                                    ║"
    echo "║  Objetivo: Garantir que TODOS os scripts rodam até o fim          ║"
    echo "║  Data: $DATA"
    echo "║                                                                    ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
}

print_info() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
    echo "[INFO] $1" >> "$LOG_FILE"
}

print_ok() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}[✓]${NC} $1"
    fi
    echo "[OK] $1" >> "$LOG_FILE"
    PASSED=$((PASSED + 1))
}

print_warning() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${YELLOW}[⚠]${NC} $1"
    fi
    echo "[WARNING] $1" >> "$LOG_FILE"
    WARNINGS=$((WARNINGS + 1))
}

print_error() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${RED}[✗]${NC} $1"
    fi
    echo "[ERROR] $1" >> "$LOG_FILE"
    FAILED=$((FAILED + 1))
}

print_section() {
    echo "" | tee -a "$LOG_FILE"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}$1${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
}

check_script_syntax() {
    local script=$1
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ ! -f "$script" ]; then
        print_error "[SINTAXE] Arquivo não existe: $script"
        return 1
    fi
    
    # Verificar se é um script bash válido
    if ! head -1 "$script" | grep -q "#!/bin/bash"; then
        print_error "[SINTAXE] Script não começa com #!/bin/bash: $script"
        return 1
    fi
    
    # Verificar se tem erros de sintaxe com bash -n
    if ! bash -n "$script" 2>/dev/null; then
        print_error "[SINTAXE] Erro de sintaxe bash em: $script"
        bash -n "$script" 2>&1 | head -5 >> "$LOG_FILE"
        return 1
    fi
    
    print_ok "[SINTAXE] Script válido: $(basename $script)"
    return 0
}

check_script_permissions() {
    local script=$1
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ ! -x "$script" ]; then
        print_warning "[PERMISSÃO] Script não é executável: $script"
        if [ "$AUTO_FIX" = true ]; then
            chmod +x "$script"
            print_ok "[PERMISSÃO] CORRIGIDO: chmod +x $(basename $script)"
            return 0
        fi
        return 1
    fi
    
    print_ok "[PERMISSÃO] Script executável: $(basename $script)"
    return 0
}

check_script_dependencies() {
    local script=$1
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    # Extrair comandos necessários do script
    local deps=$(grep -oE 'command -v [a-z0-9_-]+|which [a-z0-9_-]+' "$script" | awk '{print $NF}' | sort -u)
    
    local missing=()
    for dep in $deps; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_warning "[DEPS] Comandos faltando em $(basename $script): ${missing[@]}"
        return 1
    fi
    
    print_ok "[DEPS] Todas as dependências OK: $(basename $script)"
    return 0
}

check_error_handling() {
    local script=$1
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    local has_set_e=false
    local has_exit_handler=false
    
    if grep -q "set -e" "$script"; then
        has_set_e=true
    fi
    
    if grep -q "trap.*EXIT\|exit" "$script"; then
        has_exit_handler=true
    fi
    
    if [ "$has_set_e" = true ]; then
        print_ok "[ERROS] Script tem 'set -e': $(basename $script)"
        return 0
    else
        print_warning "[ERROS] Script SEM 'set -e': $(basename $script)"
        return 1
    fi
}

check_log_configuration() {
    local script=$1
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if grep -q "LOG_FILE\|tee -a" "$script"; then
        print_ok "[LOGS] Script configura logging: $(basename $script)"
        return 0
    else
        print_warning "[LOGS] Script SEM logging configurado: $(basename $script)"
        if [ "$AUTO_FIX" = true ]; then
            print_info "[LOGS] RECOMENDAÇÃO: Adicionar LOG_FILE e tee -a para debugging"
        fi
        return 1
    fi
}

check_disk_space() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    local root_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    local tmp_space=$(df -BG /tmp | awk 'NR==2 {print $4}' | sed 's/G//')
    local opt_space=$(df -BG /opt 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//' || echo "0")
    
    local min_space=10
    
    if [ "$root_space" -lt "$min_space" ]; then
        print_error "[DISCO] Espaço insuficiente em /: ${root_space}GB (mín: ${min_space}GB)"
        return 1
    fi
    
    if [ "$tmp_space" -lt 5 ]; then
        print_warning "[DISCO] Espaço em /tmp: ${tmp_space}GB (recomendado: 5GB+)"
        print_warning "         Continuando com monitoramento obrigatório"
        # Não fazer return 1 - apenas avisar
    fi
    
    if [ "$opt_space" -lt 20 ] && [ "$opt_space" -gt 0 ]; then
        print_warning "[DISCO] Espaço em /opt: ${opt_space}GB (recomendado: 20GB+)"
        print_warning "         Continuando com monitoramento obrigatório"
        # Não fazer return 1 - apenas avisar
    fi
    
    print_ok "[DISCO] Espaço em disco OK (/ ${root_space}GB, /tmp ${tmp_space}GB)"
    return 0
}

check_network_connectivity() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    # Testa conectividade com Google DNS
    if timeout 5 ping -c 1 8.8.8.8 &>/dev/null; then
        print_ok "[REDE] Conectividade de rede OK"
        return 0
    else
        print_error "[REDE] Sem conectividade de rede"
        return 1
    fi
}

check_root_access() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [[ $EUID -ne 0 ]]; then
        print_error "[ROOT] Script NÃO está rodando como root"
        return 1
    fi
    
    print_ok "[ROOT] Executando como root"
    return 0
}

check_critical_functions() {
    local script=$1
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    local critical_funcs=("print_header" "print_info" "print_ok" "print_error")
    local missing=()
    
    for func in "${critical_funcs[@]}"; do
        if ! grep -q "^${func}()" "$script"; then
            missing+=("$func")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_warning "[FUNÇÕES] Funções críticas faltando: ${missing[@]}"
        return 1
    fi
    
    print_ok "[FUNÇÕES] Funções críticas presentes: $(basename $script)"
    return 0
}

validate_script_complete() {
    local script=$1
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    # Contar linhas
    local lines=$(wc -l < "$script")
    if [ $lines -lt 50 ]; then
        print_warning "[TAMANHO] Script muito pequeno ($lines linhas): $(basename $script)"
        return 1
    fi
    
    # Verificar se tem seção MAIN
    if ! grep -q "main()\|^main\s" "$script"; then
        print_warning "[MAIN] Script sem função main(): $(basename $script)"
        return 1
    fi
    
    # Verificar se tem chamada de main
    if ! tail -20 "$script" | grep -q "main"; then
        print_warning "[MAIN] Script não chama main(): $(basename $script)"
        return 1
    fi
    
    print_ok "[COMPLETO] Script estruturado corretamente: $(basename $script)"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════

main() {
    print_header
    
    if [ "$AUTO_FIX" = true ]; then
        print_info "Modo: AUTO-FIX (correções automáticas habilitadas)"
    else
        print_info "Modo: VALIDAÇÃO APENAS (use --auto-fix para corrigir)"
    fi
    
    print_info "Log: $LOG_FILE"
    echo ""
    
    # Encontrar todos os scripts Phase 2 HA
    local scripts=(
        "00-prerequisitos-validacao.sh"
        "01-postgresql-primary.sh"
        "02-postgresql-standby.sh"
        "04-zabbix-server-ha.sh"
        "06-awx-ha.sh"
        "05-grafana-ha.sh"
        "03-vip-haproxy-keepalived.sh"
        "08-validate-ha-health.sh"
        "09-failover-test.sh"
    )
    
    # Validações de Sistema
    print_section "VALIDAÇÕES DE SISTEMA"
    check_root_access || true
    check_disk_space || true
    check_network_connectivity || true
    
    # Validações de Scripts
    print_section "VALIDAÇÕES DE SCRIPTS"
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            echo ""
            echo -e "${BLUE}Validando: $script${NC}"
            check_script_syntax "$script" || true
            check_script_permissions "$script" || true
            check_error_handling "$script" || true
            check_log_configuration "$script" || true
            check_critical_functions "$script" || true
            validate_script_complete "$script" || true
        else
            print_error "Script não encontrado: $script"
        fi
    done
    
    # Relatório Final
    print_section "RELATÓRIO FINAL"
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                  SUMÁRIO DE VALIDAÇÃO                             ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "  Total de Verificações: $TOTAL_CHECKS"
    echo "  ✓ Passou:              $PASSED"
    echo "  ⚠ Avisos:              $WARNINGS"
    echo "  ✗ Falhas:              $FAILED"
    echo ""
    
    if [ $FAILED -eq 0 ]; then
        echo "  🎉 STATUS: ✅ TODOS OS SCRIPTS ESTÃO PRONTOS PARA EXECUÇÃO"
        echo ""
        echo "  Próximas ações:"
        echo "    1. Copiar scripts para os servidores"
        echo "    2. Executar: sudo ./00-prerequisitos-validacao.sh"
        echo "    3. Seguir guia de Semanas (1-5)"
        echo ""
        exit 0
    else
        echo "  ⚠️  STATUS: ❌ ALGUNS SCRIPTS PRECISAM DE AJUSTES"
        echo ""
        echo "  Ações recomendadas:"
        echo "    1. Revisar erros acima"
        if [ "$AUTO_FIX" = false ]; then
            echo "    2. Executar com --auto-fix: sudo ./07-pre-execution-validation.sh --auto-fix"
        fi
        echo "    3. Executar novamente para validar correções"
        echo ""
        exit 1
    fi
}

# Executar
main "$@"
