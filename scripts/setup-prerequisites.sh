#!/bin/bash

################################################################################
# Projeto Aeroporto - Setup Automático de Pré-Requisitos
# 
# Objetivo:
#   Validar todos os pré-requisitos necessários para os scripts de validação
#   Instalar dependências faltantes automaticamente
#   Fornecer relatório detalhado do status
#
# Uso:
#   bash scripts/setup-prerequisites.sh              # Interativo
#   bash scripts/setup-prerequisites.sh --auto       # Automático (assume sim)
#   bash scripts/setup-prerequisites.sh --check-only # Apenas verifica
#   bash scripts/setup-prerequisites.sh --skip-install # Valida, não instala
#
# Suporta:
#   Linux (Ubuntu, Debian, CentOS, RHEL, Alpine, etc)
#   macOS
#   Windows (WSL2)
#
################################################################################

set -o pipefail

# Configurações
MODE="interactive"  # interactive, auto, check-only, skip-install
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="setup-prerequisites-$(date +%s).log"

# Contadores
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
INSTALLED_COUNT=0

# Cores
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    RESET='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    RESET=''
fi

# Detectar SO
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS_TYPE="$ID"
            OS_VERSION="$VERSION_ID"
        elif command -v lsb_release &>/dev/null; then
            OS_TYPE=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
            OS_VERSION=$(lsb_release -sr)
        else
            OS_TYPE="linux"
            OS_VERSION="unknown"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS_TYPE="macos"
        OS_VERSION=$(sw_vers -productVersion)
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS_TYPE="windows"
        OS_VERSION="wsl"
    else
        OS_TYPE="unknown"
        OS_VERSION="unknown"
    fi
}

# Funções de logging
log_header() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${BLUE}  $1${RESET}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${RESET}"
    echo ""
}

log_info() {
    echo -e "${CYAN}ℹ${RESET}  $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}✓${RESET}  $1" | tee -a "$LOG_FILE"
    ((PASSED_CHECKS++))
}

log_failed() {
    echo -e "${RED}✗${RESET}  $1" | tee -a "$LOG_FILE"
    ((FAILED_CHECKS++))
}

log_warning() {
    echo -e "${YELLOW}⚠${RESET}  $1" | tee -a "$LOG_FILE"
}

log_action() {
    echo -e "${BLUE}→${RESET}  $1" | tee -a "$LOG_FILE"
}

# Parse de argumentos
parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --auto)
                MODE="auto"
                ;;
            --check-only)
                MODE="check-only"
                ;;
            --skip-install)
                MODE="skip-install"
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
    cat << 'EOF'
Uso: bash scripts/setup-prerequisites.sh [opções]

Opções:
  --auto            Instala automaticamente sem pedir confirmação
  --check-only      Apenas verifica, não instala nada
  --skip-install    Valida pré-requisitos mas não instala
  --help            Exibe esta mensagem

Exemplos:
  bash scripts/setup-prerequisites.sh              # Interativo
  bash scripts/setup-prerequisites.sh --auto       # Automático
  bash scripts/setup-prerequisites.sh --check-only # Apenas check
EOF
}

# Verificar se comando existe
command_exists() {
    command -v "$1" &>/dev/null
}

# Verificar versão
check_version() {
    local cmd=$1
    local min_version=$2
    
    case "$cmd" in
        bash)
            local version=$(bash --version | head -1 | grep -oP '\d+\.\d+' | head -1)
            ;;
        python3)
            local version=$(python3 --version 2>&1 | grep -oP '\d+\.\d+')
            ;;
        *)
            return 0  # Não verifica versão por padrão
            ;;
    esac
    
    # Comparação simples (não é perfeita mas funciona para 90% dos casos)
    if [ -n "$version" ] && [ -n "$min_version" ]; then
        if [ "$(printf '%s\n' "$min_version" "$version" | sort -V | head -n1)" = "$min_version" ]; then
            return 0
        else
            return 1
        fi
    fi
    
    return 0
}

# Instalar pacote (Linux)
install_package_linux() {
    local package=$1
    local pkg_manager=""
    
    # Detectar package manager
    if command_exists apt-get; then
        pkg_manager="apt-get"
    elif command_exists dnf; then
        pkg_manager="dnf"
    elif command_exists yum; then
        pkg_manager="yum"
    elif command_exists apk; then
        pkg_manager="apk"
    elif command_exists pacman; then
        pkg_manager="pacman"
    else
        return 1
    fi
    
    case "$pkg_manager" in
        apt-get)
            sudo apt-get update >/dev/null 2>&1
            sudo apt-get install -y "$package" >/dev/null 2>&1
            ;;
        dnf)
            sudo dnf install -y "$package" >/dev/null 2>&1
            ;;
        yum)
            sudo yum install -y "$package" >/dev/null 2>&1
            ;;
        apk)
            sudo apk add "$package" >/dev/null 2>&1
            ;;
        pacman)
            sudo pacman -S --noconfirm "$package" >/dev/null 2>&1
            ;;
    esac
    
    return $?
}

# Instalar pacote (macOS)
install_package_macos() {
    local package=$1
    
    if ! command_exists brew; then
        log_warning "Homebrew não instalado"
        return 1
    fi
    
    brew install "$package" >/dev/null 2>&1
    return $?
}

# Função genérica de instalação
install_package() {
    local package=$1
    local cmd_name=${2:-$1}
    
    log_action "Instalando $cmd_name..."
    
    case "$OS_TYPE" in
        ubuntu|debian|linuxmint|elementary|pop)
            install_package_linux "$package"
            ;;
        fedora|centos|rhel|opensuse)
            install_package_linux "$package"
            ;;
        alpine)
            install_package_linux "$package"
            ;;
        macos|darwin)
            install_package_macos "$package"
            ;;
        *)
            log_failed "Sistema operacional não suportado: $OS_TYPE"
            return 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        log_success "$cmd_name instalado com sucesso"
        ((INSTALLED_COUNT++))
        return 0
    else
        log_failed "Falha ao instalar $cmd_name"
        return 1
    fi
}

# Perguntar ao usuário
ask_user() {
    local prompt=$1
    local response
    
    if [ "$MODE" = "auto" ]; then
        return 0  # Assume sim em modo automático
    fi
    
    read -p "$(echo -e "${YELLOW}?${RESET}  $prompt (s/n): ")" -n 1 -r response
    echo
    [[ "$response" =~ ^[Ss]$ ]]
}

################################################################################
# Verificações
################################################################################

check_bash() {
    ((TOTAL_CHECKS++))
    
    if command_exists bash; then
        local version=$(bash --version | head -1)
        log_success "Bash: $version"
        return 0
    else
        log_failed "Bash não encontrado"
        return 1
    fi
}

check_python3() {
    ((TOTAL_CHECKS++))
    
    if command_exists python3; then
        local version=$(python3 --version 2>&1)
        log_success "Python3: $version"
        return 0
    else
        log_failed "Python3 não encontrado"
        
        if [ "$MODE" != "check-only" ] && [ "$MODE" != "skip-install" ]; then
            if ask_user "Deseja instalar Python3?"; then
                install_package "python3" "Python3"
                return 0
            fi
        fi
        return 1
    fi
}

check_curl() {
    ((TOTAL_CHECKS++))
    
    if command_exists curl; then
        local version=$(curl --version | head -1)
        log_success "curl: $version"
        return 0
    else
        log_failed "curl não encontrado"
        
        if [ "$MODE" != "check-only" ] && [ "$MODE" != "skip-install" ]; then
            if ask_user "Deseja instalar curl?"; then
                install_package "curl" "curl"
                return 0
            fi
        fi
        return 1
    fi
}

check_netcat() {
    ((TOTAL_CHECKS++))
    
    if command_exists nc; then
        local version=$(nc -h 2>&1 | head -1)
        log_success "netcat (nc): Instalado"
        return 0
    else
        log_failed "netcat (nc) não encontrado"
        
        if [ "$MODE" != "check-only" ] && [ "$MODE" != "skip-install" ]; then
            if ask_user "Deseja instalar netcat?"; then
                case "$OS_TYPE" in
                    ubuntu|debian|linuxmint)
                        install_package "netcat-openbsd" "netcat"
                        ;;
                    fedora|centos|rhel)
                        install_package "nmap-ncat" "netcat"
                        ;;
                    alpine)
                        install_package "netcat-openbsd" "netcat"
                        ;;
                    macos|darwin)
                        install_package "netcat" "netcat"
                        ;;
                    *)
                        log_warning "Não sei como instalar netcat em $OS_TYPE"
                        return 1
                        ;;
                esac
                return 0
            fi
        fi
        return 1
    fi
}

check_nslookup() {
    ((TOTAL_CHECKS++))
    
    if command_exists nslookup; then
        log_success "nslookup: Instalado"
        return 0
    elif command_exists dig; then
        log_warning "dig encontrado (alternativa a nslookup)"
        return 0
    elif command_exists getent; then
        log_warning "getent encontrado (alternativa a nslookup)"
        return 0
    else
        log_failed "nslookup/dig/getent não encontrado"
        
        if [ "$MODE" != "check-only" ] && [ "$MODE" != "skip-install" ]; then
            if ask_user "Deseja instalar dnsutils (inclui nslookup)?"; then
                case "$OS_TYPE" in
                    ubuntu|debian|linuxmint)
                        install_package "dnsutils" "dnsutils"
                        ;;
                    fedora|centos|rhel)
                        install_package "bind-utils" "bind-utils"
                        ;;
                    alpine)
                        install_package "bind-tools" "bind-tools"
                        ;;
                    macos|darwin)
                        install_package "bind" "bind"
                        ;;
                    *)
                        log_warning "Não sei como instalar DNS tools em $OS_TYPE"
                        return 1
                        ;;
                esac
                return 0
            fi
        fi
        return 1
    fi
}

check_dns() {
    ((TOTAL_CHECKS++))
    
    log_info "Testando DNS (nslookup google.com)..."
    
    if nslookup google.com 8.8.8.8 &>/dev/null; then
        log_success "DNS: Funcionando"
        return 0
    else
        log_failed "DNS: Não funcionando (verifique conectividade)"
        return 1
    fi
}

check_internet() {
    ((TOTAL_CHECKS++))
    
    log_info "Testando Internet (curl https://github.com)..."
    
    if curl -s --connect-timeout 3 https://github.com &>/dev/null; then
        log_success "Internet: HTTPS funcionando"
        return 0
    else
        log_failed "Internet: HTTPS não funcionando"
        return 1
    fi
}

check_scripts_exist() {
    ((TOTAL_CHECKS++))
    
    if [ -f "scripts/validate-access.sh" ] && [ -f "scripts/validate-access.py" ]; then
        log_success "Scripts: Encontrados (validate-access.sh, validate-access.py)"
        return 0
    else
        log_failed "Scripts: Não encontrados (execute a partir do diretório do projeto)"
        return 1
    fi
}

check_scripts_executable() {
    ((TOTAL_CHECKS++))
    
    if [ -x "scripts/validate-access.sh" ] && [ -x "scripts/validate-access.py" ]; then
        log_success "Permissões: Scripts executáveis"
        return 0
    else
        log_warning "Permissões: Scripts não executáveis"
        
        if [ "$MODE" != "check-only" ]; then
            if ask_user "Deseja tornar os scripts executáveis?"; then
                chmod +x scripts/validate-access.sh scripts/validate-access.py
                log_success "Permissões: Scripts agora são executáveis"
                return 0
            fi
        fi
        return 1
    fi
}

################################################################################
# Relatório
################################################################################

print_header_report() {
    log_header "Setup de Pré-Requisitos - Projeto Aeroporto"
    log_info "Data/Hora: $TIMESTAMP"
    log_info "Sistema: $OS_TYPE $OS_VERSION"
    log_info "Modo: $MODE"
    echo ""
}

print_summary() {
    echo ""
    log_header "Resumo da Verificação"
    
    echo -e "Total verificado:    ${CYAN}${TOTAL_CHECKS}${RESET}"
    echo -e "Passou:              ${GREEN}${PASSED_CHECKS}${RESET}"
    echo -e "Falhou:              ${RED}${FAILED_CHECKS}${RESET}"
    echo -e "Instalados:          ${CYAN}${INSTALLED_COUNT}${RESET}"
    echo ""
    
    if [ "$FAILED_CHECKS" -eq 0 ]; then
        echo -e "${GREEN}✓ Todos os pré-requisitos estão OK!${RESET}"
        echo ""
        echo "Pode executar os scripts de validação:"
        echo -e "  ${CYAN}bash scripts/validate-access.sh${RESET}"
        echo -e "  ${CYAN}python3 scripts/validate-access.py${RESET}"
        return 0
    else
        echo -e "${RED}✗ ${FAILED_CHECKS} pré-requisito(s) com problema${RESET}"
        echo ""
        echo "Ações necessárias:"
        echo -e "  1. Instale as dependências faltantes"
        echo -e "  2. Verifique conectividade (DNS, Internet)"
        echo -e "  3. Execute novamente: ${CYAN}bash scripts/setup-prerequisites.sh${RESET}"
        return 1
    fi
}

save_log() {
    log_info ""
    log_info "Relatório salvo em: $LOG_FILE"
    log_info "Para ver o relatório: cat $LOG_FILE"
}

################################################################################
# Main
################################################################################

main() {
    parse_arguments "$@"
    detect_os
    
    print_header_report
    
    # Executar todas as verificações
    echo -e "${BLUE}→ Verificando Pré-Requisitos${RESET}"
    echo ""
    
    check_bash
    check_python3
    check_curl
    check_netcat
    check_nslookup
    
    echo ""
    echo -e "${BLUE}→ Verificando Conectividade${RESET}"
    echo ""
    
    check_dns
    check_internet
    
    echo ""
    echo -e "${BLUE}→ Verificando Projeto${RESET}"
    echo ""
    
    check_scripts_exist
    check_scripts_executable
    
    # Relatório final
    print_summary
    SUMMARY_EXIT=$?
    
    save_log
    
    exit $SUMMARY_EXIT
}

# Executar main
main "$@"
