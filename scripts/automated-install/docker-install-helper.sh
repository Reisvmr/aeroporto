#!/bin/bash

################################################################################
#                                                                              #
#  SCRIPT HELPER - INSTALAÇÃO DOCKER + DOCKER COMPOSE                        #
#                                                                              #
#  Projeto: Aeroporto - AWX + Grafana + Zabbix                               #
#  Data: 24/10/2026                                                           #
#  Versão: 1.0                                                                #
#  Servidor: awx-01 (10.31.38.68)                                             #
#                                                                              #
#  OBJETIVO:                                                                   #
#    Instalar Docker Engine + Docker Compose via repositório oficial          #
#    Para preparar awx-01 para instalação de AWX 22.x                         #
#                                                                              #
#  PROBLEMA RESOLVIDO:                                                         #
#    Error: "Unable to locate package docker"                                 #
#    Causa: Repositório padrão Ubuntu não tem pacote 'docker'                #
#    Solução: Usar repositório oficial Docker (docker-ce)                    #
#                                                                              #
#  PRÉ-REQUISITOS:                                                             #
#    - Ubuntu 26.04+                                                          #
#    - Acesso root (sudo)                                                     #
#    - Conectividade com internet                                             #
#                                                                              #
#  USO:                                                                        #
#    sudo bash docker-install-helper.sh                                       #
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

LOG_FILE="/var/log/docker-install-helper.log"

# ============================================================================
# FUNÇÕES DE LOG
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[⚠]${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*" | tee -a "$LOG_FILE"
}

log_title() {
    echo ""
    echo -e "${BOLD}${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${BOLD}${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
}

run_cmd() {
    local cmd="$1"
    local desc="${2:-Executando}"
    
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        log_success "$desc"
        return 0
    else
        log_error "FALHOU: $desc"
        return 1
    fi
}

# ============================================================================
# VALIDAÇÕES PRÉ-REQUISITOS
# ============================================================================

check_prerequisites() {
    log_title "VALIDAÇÃO PRÉ-REQUISITOS"
    
    # Verificar root
    if [ "$EUID" -ne 0 ]; then
        log_error "Este script deve ser executado como root"
        exit 1
    fi
    log_success "Executando como root"
    
    # Verificar SO
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_error "Este script é específico para Ubuntu"
        return 1
    fi
    log_success "Ubuntu detectado"
    
    # Verificar conectividade
    if ! ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        log_warn "Sem conectividade com internet"
        return 1
    else
        log_success "Conectividade com internet OK"
    fi
}

# ============================================================================
# PREPARAR REPOSITÓRIO DOCKER
# ============================================================================

setup_docker_repository() {
    log_title "PREPARAR REPOSITÓRIO DOCKER OFICIAL"
    
    log_info "Atualizando cache apt..."
    run_cmd "apt-get update" "Atualizar cache apt" || true
    
    log_info "Instalando dependências..."
    run_cmd "apt-get install -y ca-certificates curl gnupg lsb-release" \
        "Instalar dependências (ca-certificates, curl, gnupg, lsb-release)" || return 1
    
    log_info "Adicionando chave GPG Docker..."
    run_cmd "mkdir -p /etc/apt/keyrings" "Criar diretório keyrings"
    
    if run_cmd "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg" \
        "Baixar e instalar chave GPG Docker"; then
        log_success "Chave GPG Docker instalada"
    else
        log_error "Falha ao baixar chave GPG"
        return 1
    fi
    
    log_info "Adicionando repositório Docker..."
    
    local arch=$(dpkg --print-architecture)
    local distro=$(lsb_release -cs)
    
    echo "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $distro stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    log_success "Repositório Docker adicionado"
    
    log_info "Atualizando cache apt novamente..."
    run_cmd "apt-get update" "Atualizar cache apt com novo repositório" || true
}

# ============================================================================
# INSTALAR DOCKER
# ============================================================================

install_docker() {
    log_title "INSTALAR DOCKER ENGINE"
    
    log_info "Instalando Docker, Docker CLI, Containerd, Buildx e Compose Plugin..."
    
    if run_cmd "apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin" \
        "Instalar Docker packages"; then
        log_success "Docker instalado com sucesso"
    else
        log_error "Falha ao instalar Docker"
        return 1
    fi
}

# ============================================================================
# VERIFICAR INSTALAÇÃO
# ============================================================================

verify_docker_installation() {
    log_title "VERIFICAR INSTALAÇÃO DOCKER"
    
    log_info "Verificando Docker..."
    
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version)
        log_success "Docker instalado: $docker_version"
    else
        log_error "Docker não encontrado"
        return 1
    fi
    
    log_info "Verificando Docker Compose..."
    
    if docker compose version > /dev/null 2>&1; then
        local compose_version=$(docker compose version)
        log_success "Docker Compose plugin instalado"
    else
        log_warn "Docker Compose plugin não encontrado, tentando versão standalone..."
        
        if ! install_compose_standalone; then
            log_warn "Docker Compose standalone não disponível"
        fi
    fi
}

# ============================================================================
# INSTALAR DOCKER COMPOSE STANDALONE (SE NECESSÁRIO)
# ============================================================================

install_compose_standalone() {
    log_info "Baixando Docker Compose standalone..."
    
    local compose_url="https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)"
    
    if curl -fsSL "$compose_url" -o /usr/local/bin/docker-compose 2>/dev/null; then
        run_cmd "chmod +x /usr/local/bin/docker-compose" "Tornando docker-compose executável"
        
        if docker-compose --version > /dev/null 2>&1; then
            log_success "Docker Compose standalone instalado"
            return 0
        fi
    fi
    
    return 1
}

# ============================================================================
# HABILITAR E INICIAR DOCKER
# ============================================================================

enable_docker_service() {
    log_title "HABILITAR SERVIÇO DOCKER"
    
    log_info "Habilitando Docker para iniciar com sistema..."
    run_cmd "systemctl enable docker" "Habilitar docker.service"
    
    log_info "Iniciando Docker..."
    run_cmd "systemctl start docker" "Iniciar docker.service"
    
    sleep 2
    
    log_info "Verificando status..."
    if systemctl is-active --quiet docker; then
        log_success "Docker está rodando"
    else
        log_error "Docker não está rodando"
        journalctl -u docker -n 20 | tee -a "$LOG_FILE"
        return 1
    fi
}

# ============================================================================
# TESTAR DOCKER
# ============================================================================

test_docker() {
    log_title "TESTAR DOCKER"
    
    log_info "Executando teste simples (hello-world)..."
    
    if docker run --rm hello-world > /dev/null 2>&1; then
        log_success "Docker funcionando corretamente"
    else
        log_warn "Teste hello-world falhou, mas Docker pode estar funcionando"
    fi
    
    log_info "Verificando acesso a imagens..."
    if docker images | grep -q hello-world; then
        log_success "Docker consegue baixar e executar imagens"
    fi
}

# ============================================================================
# INFORMAÇÕES DE ACESSO
# ============================================================================

print_summary() {
    log_title "RESUMO - DOCKER INSTALADO COM SUCESSO"
    
    echo ""
    echo "✅ Docker pronto para AWX 22.x"
    echo ""
    echo "Versões instaladas:"
    docker --version
    echo ""
    
    if docker compose version > /dev/null 2>&1; then
        echo "Docker Compose (plugin):"
        docker compose version
    elif command -v docker-compose &> /dev/null; then
        echo "Docker Compose (standalone):"
        docker-compose --version
    fi
    
    echo ""
    echo "Próximos passos:"
    echo "  1. Voltar à instalação AWX:"
    echo "     \$ sudo bash 04-awx-installer.sh"
    echo ""
    echo "  2. O script detectará Docker e continuará"
    echo ""
    echo "Log completo em: $LOG_FILE"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    clear
    
    log_title "INSTALAÇÃO DOCKER + DOCKER COMPOSE"
    log_info "Data: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Servidor: awx-01 (10.31.38.68)"
    
    # Executar etapas
    check_prerequisites || exit 1
    setup_docker_repository || exit 1
    install_docker || exit 1
    verify_docker_installation || exit 1
    enable_docker_service || exit 1
    test_docker
    print_summary
    
    log_success "=========================================="
    log_success "DOCKER INSTALADO COM SUCESSO"
    log_success "=========================================="
}

main "$@"
