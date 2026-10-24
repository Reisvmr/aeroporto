#!/bin/bash

################################################################################
#                                                                              #
#  FUNÇÕES COMPARTILHADAS - INSTALAÇÃO ZABBIX FASE 1                          #
#                                                                              #
#  Arquivo de biblioteca com funções comuns reutilizáveis                     #
#  Fonte: scripts/automated-install/common/functions.sh                       #
#                                                                              #
################################################################################

# ============================================================================
# FUNÇÕES DE LOG
# ============================================================================

# Cores ANSI para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Log com informação
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${LOG_FILE:-/dev/null}"
}

# Log com sucesso
log_success() {
    echo -e "${GREEN}[✓]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${LOG_FILE:-/dev/null}"
}

# Log com aviso
log_warn() {
    echo -e "${YELLOW}[⚠]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${LOG_FILE:-/dev/null}"
}

# Log com erro
log_error() {
    echo -e "${RED}[✗]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${LOG_FILE:-/dev/null}"
}

# Log para debug
log_debug() {
    if [ "${DEBUG:-false}" == "true" ]; then
        echo -e "${MAGENTA}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${LOG_FILE:-/dev/null}"
    fi
}

# ============================================================================
# FUNÇÕES DE VALIDAÇÃO
# ============================================================================

# Verificar se é root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Este script deve ser executado como root"
        exit 1
    fi
    log_success "Verificação de root OK"
}

# Detectar SO
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_ID="$ID"
        OS_VERSION="$VERSION_ID"
        return 0
    else
        log_error "Não foi possível detectar o SO"
        return 1
    fi
}

# Validar SO suportado
validate_os() {
    case "$OS_ID" in
        ubuntu|debian)
            PKG_MANAGER="apt-get"
            PKG_UPDATE="apt-get update"
            log_info "Debian/Ubuntu detectado"
            return 0
            ;;
        centos|rhel)
            PKG_MANAGER="yum"
            PKG_UPDATE="yum makecache"
            log_info "CentOS/RHEL detectado"
            return 0
            ;;
        *)
            log_error "SO não suportado: $OS_ID"
            return 1
            ;;
    esac
}

# Verificar espaço em disco
check_disk_space() {
    local path="${1:-.}"
    local min_size_kb="${2:-20480000}"  # 20GB padrão
    
    local available=$(df "$path" | awk 'NR==2 {print $4}')
    
    if [ "$available" -lt "$min_size_kb" ]; then
        log_error "Espaço insuficiente em $path (< $(( min_size_kb / 1024 / 1024 )) GB)"
        return 1
    fi
    
    log_success "Espaço em disco OK: $(( available / 1024 / 1024 )) GB"
    return 0
}

# Verificar NTP
check_ntp() {
    if systemctl is-active --quiet chrony || systemctl is-active --quiet ntpd; then
        log_success "NTP sincronizado"
        return 0
    else
        log_warn "NTP não está sincronizado"
        return 1
    fi
}

# Verificar conectividade TCP
check_tcp_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-5}"
    
    if timeout "$timeout" bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
        log_success "Conectividade TCP $host:$port OK"
        return 0
    else
        log_warn "Falha ao conectar em $host:$port"
        return 1
    fi
}

# ============================================================================
# FUNÇÕES DE EXECUÇÃO
# ============================================================================

# Executar comando com log
run_cmd() {
    local cmd="$1"
    local desc="${2:-Executando comando}"
    local log_output="${3:-true}"
    
    log_debug "Executando: $cmd"
    
    if [ "$DRY_RUN" == "true" ]; then
        log_info "[DRY RUN] $desc: $cmd"
        return 0
    fi
    
    local output
    local exit_code
    
    if [ "$log_output" == "true" ]; then
        output=$(eval "$cmd" 2>&1) || exit_code=$?
        if [ "${exit_code:-0}" -eq 0 ]; then
            log_success "$desc"
            return 0
        else
            log_error "FALHOU: $desc"
            log_debug "Output: $output"
            return 1
        fi
    else
        eval "$cmd" > /dev/null 2>&1 && {
            log_success "$desc"
            return 0
        } || {
            log_error "FALHOU: $desc"
            return 1
        }
    fi
}

# Solicitar confirmação
confirm() {
    if [ "$INTERACTIVE" == "false" ]; then
        return 0
    fi
    
    local prompt="$1"
    local response
    
    read -p "$prompt (s/n): " -r response
    [[ "$response" =~ ^[Ss]$ ]]
}

# ============================================================================
# FUNÇÕES DE CONFIGURAÇÃO
# ============================================================================

# Fazer backup de arquivo
backup_file() {
    local file="$1"
    local backup_suffix="${2:-.backup}"
    
    if [ ! -f "$file" ]; then
        log_warn "Arquivo não encontrado para backup: $file"
        return 1
    fi
    
    if [ -f "${file}${backup_suffix}" ]; then
        log_warn "Backup já existe: ${file}${backup_suffix}"
        return 0
    fi
    
    cp "$file" "${file}${backup_suffix}" && {
        log_success "Backup criado: ${file}${backup_suffix}"
        return 0
    } || {
        log_error "Falha ao criar backup: $file"
        return 1
    }
}

# Restaurar de backup
restore_file() {
    local file="$1"
    local backup_suffix="${2:-.backup}"
    
    if [ ! -f "${file}${backup_suffix}" ]; then
        log_error "Backup não encontrado: ${file}${backup_suffix}"
        return 1
    fi
    
    cp "${file}${backup_suffix}" "$file" && {
        log_success "Arquivo restaurado de backup"
        return 0
    } || {
        log_error "Falha ao restaurar arquivo"
        return 1
    }
}

# Configurar permissões
set_permissions() {
    local path="$1"
    local owner="$2"
    local perms="$3"
    
    if [ ! -e "$path" ]; then
        log_error "Caminho não existe: $path"
        return 1
    fi
    
    chown "$owner" "$path" && {
        log_success "Owner configurado: $owner para $path"
    } || {
        log_error "Falha ao configurar owner: $path"
        return 1
    }
    
    if [ -n "$perms" ]; then
        chmod "$perms" "$path" && {
            log_success "Permissões configuradas: $perms para $path"
        } || {
            log_error "Falha ao configurar permissões: $path"
            return 1
        }
    fi
    
    return 0
}

# ============================================================================
# FUNÇÕES DE BANCO DE DADOS
# ============================================================================

# Testar conectividade PostgreSQL
test_postgres_connection() {
    local host="$1"
    local port="$2"
    local user="$3"
    local db="$4"
    local password="${5:-}"
    
    local cmd="psql -h $host -p $port -U $user -d $db -c 'SELECT 1'"
    
    if [ -n "$password" ]; then
        cmd="PGPASSWORD=$password $cmd"
    fi
    
    if eval "$cmd" > /dev/null 2>&1; then
        log_success "Conectividade PostgreSQL OK ($host:$port)"
        return 0
    else
        log_error "Falha ao conectar PostgreSQL ($host:$port)"
        return 1
    fi
}

# Executar SQL
execute_sql() {
    local sql="$1"
    local host="$2"
    local user="$3"
    local db="$4"
    local password="${5:-}"
    
    local cmd="echo '$sql' | psql -h $host -U $user -d $db"
    
    if [ -n "$password" ]; then
        cmd="PGPASSWORD=$password $cmd"
    fi
    
    eval "$cmd" > /dev/null 2>&1
}

# ============================================================================
# FUNÇÕES DE SERVIÇO
# ============================================================================

# Iniciar e habilitar serviço
enable_service() {
    local service="$1"
    
    systemctl daemon-reload
    systemctl restart "$service" && {
        log_success "Serviço $service reiniciado"
    } || {
        log_error "Falha ao reiniciar $service"
        return 1
    }
    
    systemctl enable "$service" && {
        log_success "Serviço $service habilitado para auto-start"
    } || {
        log_error "Falha ao habilitar $service"
        return 1
    }
    
    sleep 2
    
    if systemctl is-active --quiet "$service"; then
        log_success "Serviço $service está rodando"
        return 0
    else
        log_error "Serviço $service não está rodando"
        return 1
    fi
}

# Verificar se serviço está rodando
is_service_running() {
    local service="$1"
    systemctl is-active --quiet "$service"
}

# ============================================================================
# FUNÇÕES DE TEMPO
# ============================================================================

# Aguardar com mensagem
wait_with_message() {
    local seconds="$1"
    local message="${2:-Aguardando}"
    
    for ((i = seconds; i > 0; i--)); do
        echo -ne "\r$message... $i segundos restantes"
        sleep 1
    done
    echo -ne "\r$message... concluído\n"
}

# Medir tempo de execução
time_command() {
    local desc="$1"
    shift
    
    local start=$(date +%s%N)
    "$@"
    local exit_code=$?
    local end=$(date +%s%N)
    
    local duration=$((($end - $start) / 1000000))
    log_info "$desc levou ${duration}ms"
    
    return $exit_code
}

# ============================================================================
# FUNÇÕES DE LIMPEZA
# ============================================================================

# Remover arquivo com confirmação
safe_remove() {
    local file="$1"
    
    if [ ! -e "$file" ]; then
        log_warn "Arquivo não existe: $file"
        return 0
    fi
    
    if confirm "Remover $file?"; then
        rm -f "$file" && {
            log_success "Arquivo removido: $file"
        } || {
            log_error "Falha ao remover: $file"
            return 1
        }
    fi
    
    return 0
}

# Limpar logs antigos
cleanup_old_logs() {
    local log_dir="$1"
    local days="${2:-30}"
    
    if [ ! -d "$log_dir" ]; then
        log_warn "Diretório de logs não existe: $log_dir"
        return 0
    fi
    
    find "$log_dir" -type f -name "*.log" -mtime +"$days" -delete && {
        log_success "Logs antigos (>$days dias) removidos de $log_dir"
    } || {
        log_error "Falha ao limpar logs antigos"
        return 1
    }
}

# ============================================================================
# FUNÇÕES DE VALIDAÇÃO FINAL
# ============================================================================

# Resumo de execução
print_summary() {
    local total="${1:-0}"
    local succeeded="${2:-0}"
    local failed="${3:-0}"
    
    echo ""
    echo "=================================================="
    log_info "RESUMO DA EXECUÇÃO"
    echo "=================================================="
    log_info "Total de tarefas: $total"
    log_info "Bem-sucedidas: ${GREEN}$succeeded${NC}"
    log_info "Falhadas: ${RED}$failed${NC}"
    
    if [ "$failed" -eq 0 ]; then
        log_success "TODAS AS TAREFAS CONCLUÍDAS COM SUCESSO"
        return 0
    else
        log_error "ALGUMAS TAREFAS FALHARAM"
        return 1
    fi
}

# ============================================================================
# EXPORT DE FUNÇÕES
# ============================================================================

# Disponibilizar funções para scripts que fonte este arquivo
export -f log_info log_success log_warn log_error log_debug
export -f check_root detect_os validate_os check_disk_space check_ntp
export -f check_tcp_port run_cmd confirm
export -f backup_file restore_file set_permissions
export -f test_postgres_connection execute_sql
export -f enable_service is_service_running
export -f wait_with_message time_command
export -f safe_remove cleanup_old_logs
export -f print_summary
