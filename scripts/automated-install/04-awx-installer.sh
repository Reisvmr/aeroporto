#!/bin/bash

################################################################################
#                                                                              #
#  SCRIPT DE INSTALAÇÃO INTERATIVA - AWX 22.x                                 #
#                                                                              #
#  Projeto: Aeroporto - AWX + Grafana + Zabbix                               #
#  Data: 24/10/2026                                                           #
#  Versão: 1.0                                                                #
#  Servidor: awx-01 (10.31.38.68)                                             #
#                                                                              #
#  OBJETIVO:                                                                   #
#    Instalação completa e automatizada do AWX 22.x                           #
#    Com questões interativas para customização                               #
#    Usa Docker Compose para containerização                                  #
#                                                                              #
#  PRÉ-REQUISITOS:                                                             #
#    - Docker 20.10+                                                          #
#    - Docker Compose 1.28+                                                   #
#    - Python 3.9+                                                            #
#    - Git                                                                    #
#    - 4 vCPU, 16 GB RAM, 150 GB disco                                        #
#                                                                              #
#  USO:                                                                        #
#    sudo bash 04-awx-installer.sh                                            #
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

# Diretórios
AWX_BASE_PATH="${AWX_BASE_PATH:-/opt/awx}"
AWX_PROJECTS_PATH="${AWX_BASE_PATH}/projects"
LOG_FILE="/var/log/awx-install.log"
CONFIG_DIR="/opt/awx-config"

# Variáveis padrão
AWX_VERSION="${AWX_VERSION:-22.7.0}"
AWX_HOSTNAME="${AWX_HOSTNAME:-awx.example.com}"
AWX_ADMIN_USER="${AWX_ADMIN_USER:-admin}"
AWX_ADMIN_PASSWORD="${AWX_ADMIN_PASSWORD:-}"
AWX_SECRET_KEY="${AWX_SECRET_KEY:-}"

POSTGRES_HOST="${POSTGRES_HOST:-10.31.38.64}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-awx}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
POSTGRES_DB="${POSTGRES_DB:-awx}"

DEBUG="${DEBUG:-false}"
DRY_RUN="${DRY_RUN:-false}"
INTERACTIVE="${INTERACTIVE:-true}"

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
    
    if [ "$DRY_RUN" == "true" ]; then
        log_info "[DRY RUN] $desc: $cmd"
        return 0
    fi
    
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        log_success "$desc"
        return 0
    else
        log_error "FALHOU: $desc"
        return 1
    fi
}

# ============================================================================
# PERGUNTAS INTERATIVAS
# ============================================================================

ask_admin_credentials() {
    log_title "CREDENCIAIS ADMINISTRADOR AWX"
    
    if [ "$INTERACTIVE" == "false" ]; then
        if [ -z "$AWX_ADMIN_PASSWORD" ]; then
            AWX_ADMIN_PASSWORD="changeme123!"
        fi
        return 0
    fi
    
    echo "Digite as credenciais do administrador AWX:"
    echo "(deixe em branco para usar padrão)"
    echo ""
    
    read -p "Username (padrão: admin): " input_user
    AWX_ADMIN_USER="${input_user:-admin}"
    
    read -s -p "Password: " input_pass
    echo ""
    
    if [ -z "$input_pass" ]; then
        log_warn "Gerando senha aleatória..."
        AWX_ADMIN_PASSWORD=$(openssl rand -base64 12)
        log_info "Senha gerada: $AWX_ADMIN_PASSWORD"
    else
        AWX_ADMIN_PASSWORD="$input_pass"
    fi
    
    # Gerar secret key
    AWX_SECRET_KEY=$(openssl rand -base64 32)
    log_success "Secret key gerado com sucesso"
}

ask_postgres_credentials() {
    log_title "CREDENCIAIS POSTGRESQL"
    
    if [ "$INTERACTIVE" == "false" ]; then
        if [ -z "$POSTGRES_PASSWORD" ]; then
            POSTGRES_PASSWORD="changeme123!"
        fi
        return 0
    fi
    
    echo "Configure acesso ao PostgreSQL:"
    echo ""
    
    read -p "Host (padrão: 10.31.38.64): " input_host
    POSTGRES_HOST="${input_host:-10.31.38.64}"
    
    read -p "Port (padrão: 5432): " input_port
    POSTGRES_PORT="${input_port:-5432}"
    
    read -p "Database (padrão: awx): " input_db
    POSTGRES_DB="${input_db:-awx}"
    
    read -p "Username (padrão: awx): " input_user
    POSTGRES_USER="${input_user:-awx}"
    
    read -s -p "Password: " input_pass
    echo ""
    
    if [ -z "$input_pass" ]; then
        log_error "Senha do PostgreSQL é obrigatória!"
        return 1
    fi
    
    POSTGRES_PASSWORD="$input_pass"
    log_success "Credenciais PostgreSQL configuradas"
}

ask_hostname() {
    log_title "CONFIGURAÇÃO DE HOSTNAME"
    
    if [ "$INTERACTIVE" == "false" ]; then
        return 0
    fi
    
    echo "Configure o hostname/FQDN para AWX:"
    echo "(será usado para HTTPS e acesso web)"
    echo ""
    
    read -p "Hostname (padrão: awx.example.com): " input_hostname
    AWX_HOSTNAME="${input_hostname:-awx.example.com}"
    
    log_success "Hostname configurado: $AWX_HOSTNAME"
}

# ============================================================================
# VALIDAÇÃO PRÉ-REQUISITOS
# ============================================================================

check_prerequisites() {
    log_title "VALIDAÇÃO PRÉ-REQUISITOS"
    
    # Verificar root
    if [ "$EUID" -ne 0 ]; then
        log_error "Este script deve ser executado como root"
        exit 1
    fi
    log_success "Executando como root"
    
    # Verificar Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker não está instalado"
        log_info "Instale com: apt-get install docker.io"
        return 1
    fi
    log_success "Docker instalado: $(docker --version)"
    
    # Verificar Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose não está instalado"
        log_info "Instale com: apt-get install docker-compose"
        return 1
    fi
    log_success "Docker Compose instalado: $(docker-compose --version)"
    
    # Verificar Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 não está instalado"
        return 1
    fi
    log_success "Python 3 instalado: $(python3 --version)"
    
    # Verificar Git
    if ! command -v git &> /dev/null; then
        log_error "Git não está instalado"
        return 1
    fi
    log_success "Git instalado: $(git --version)"
    
    # Verificar espaço em disco
    local disk_free=$(df /opt 2>/dev/null | awk 'NR==2 {print $4}' || df / | awk 'NR==2 {print $4}')
    local disk_free_gb=$((disk_free / 1024 / 1024))
    
    if [ "$disk_free_gb" -lt 150 ]; then
        log_error "Espaço em disco insuficiente (< 150 GB)"
        return 1
    fi
    log_success "Espaço em disco OK: ${disk_free_gb}GB"
    
    # Verificar Docker daemon
    if ! docker ps > /dev/null 2>&1; then
        log_error "Docker não está rodando"
        log_info "Inicie com: systemctl start docker"
        return 1
    fi
    log_success "Docker daemon está rodando"
}

# ============================================================================
# PREPARAÇÃO DO AMBIENTE
# ============================================================================

prepare_directories() {
    log_title "PREPARAÇÃO DE DIRETÓRIOS"
    
    mkdir -p "$AWX_BASE_PATH" "$AWX_PROJECTS_PATH" "$CONFIG_DIR"
    mkdir -p /var/log/awx
    
    log_success "Diretórios criados: $AWX_BASE_PATH"
}

# ============================================================================
# DOWNLOAD E SETUP AWX
# ============================================================================

download_awx() {
    log_title "DOWNLOAD AWX $AWX_VERSION"
    
    cd /tmp
    
    if [ -d "awx-$AWX_VERSION" ]; then
        log_warn "Diretório já existe, removendo..."
        rm -rf "awx-$AWX_VERSION"
    fi
    
    local awx_url="https://github.com/ansible/awx/archive/refs/tags/$AWX_VERSION.tar.gz"
    
    log_info "Baixando AWX de: $awx_url"
    
    if ! run_cmd "curl -fsSL -o awx-$AWX_VERSION.tar.gz $awx_url" "Download AWX"; then
        return 1
    fi
    
    run_cmd "tar -xzf awx-$AWX_VERSION.tar.gz" "Extrair AWX"
    
    log_success "AWX $AWX_VERSION baixado e extraído"
}

# ============================================================================
# CRIAR ARQUIVO DE CONFIGURAÇÃO DOCKER-COMPOSE
# ============================================================================

create_docker_compose_file() {
    log_title "CRIAÇÃO ARQUIVO DOCKER-COMPOSE"
    
    local compose_file="$AWX_BASE_PATH/docker-compose.yml"
    
    cat > "$compose_file" << 'EOF'
version: '3'
services:
  postgres:
    image: postgres:13
    container_name: awx-postgres
    environment:
      POSTGRES_DB: awx
      POSTGRES_USER: awx
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - awx_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U awx"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7
    container_name: awx-redis
    networks:
      - awx_network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  awx-web:
    image: quay.io/ansible/awx:${AWX_VERSION}
    container_name: awx-web
    ports:
      - "80:8052"
      - "443:8053"
    environment:
      SECRET_KEY: ${AWX_SECRET_KEY}
      DEBUG: "False"
      ALLOWED_HOSTS: "*"
      DATABASE_NAME: awx
      DATABASE_USER: awx
      DATABASE_PASSWORD: ${POSTGRES_PASSWORD}
      DATABASE_HOST: postgres
      DATABASE_PORT: 5432
      REDIS_HOST: redis
      REDIS_PORT: 6379
      ADMIN_USER: ${AWX_ADMIN_USER}
      ADMIN_PASSWORD: ${AWX_ADMIN_PASSWORD}
    volumes:
      - ${AWX_PROJECTS_PATH}:/data/projects
      - /var/log/awx:/var/log/awx
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - awx_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8052/"]
      interval: 30s
      timeout: 10s
      retries: 5

  awx-task:
    image: quay.io/ansible/awx:${AWX_VERSION}
    container_name: awx-task
    entrypoint: /bin/sh
    command: -c "awx-manage migrate && /usr/bin/launch_awx_task.sh"
    environment:
      SECRET_KEY: ${AWX_SECRET_KEY}
      DEBUG: "False"
      DATABASE_NAME: awx
      DATABASE_USER: awx
      DATABASE_PASSWORD: ${POSTGRES_PASSWORD}
      DATABASE_HOST: postgres
      DATABASE_PORT: 5432
      REDIS_HOST: redis
      REDIS_PORT: 6379
      ADMIN_USER: ${AWX_ADMIN_USER}
      ADMIN_PASSWORD: ${AWX_ADMIN_PASSWORD}
    volumes:
      - ${AWX_PROJECTS_PATH}:/data/projects
      - /var/log/awx:/var/log/awx
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - awx_network

volumes:
  postgres_data:
    driver: local

networks:
  awx_network:
    driver: bridge
EOF
    
    log_success "Arquivo docker-compose.yml criado"
}

# ============================================================================
# INICIAR SERVIÇOS
# ============================================================================

start_awx_services() {
    log_title "INICIANDO SERVIÇOS AWX"
    
    cd "$AWX_BASE_PATH"
    
    # Exportar variáveis
    export POSTGRES_PASSWORD
    export AWX_SECRET_KEY
    export AWX_ADMIN_USER
    export AWX_ADMIN_PASSWORD
    export AWX_VERSION
    export AWX_PROJECTS_PATH
    
    log_info "Iniciando docker-compose up -d..."
    
    if ! run_cmd "docker-compose up -d" "Iniciar contêineres"; then
        log_error "Falha ao iniciar contêineres"
        return 1
    fi
    
    # Aguardar inicialização
    log_info "Aguardando inicialização dos serviços (pode levar 2-3 minutos)..."
    sleep 30
    
    # Verificar status
    if docker-compose ps | grep -q "awx-web"; then
        log_success "Contêineres iniciados com sucesso"
        return 0
    else
        log_error "Contêineres não iniciaram corretamente"
        docker-compose logs
        return 1
    fi
}

# ============================================================================
# VALIDAÇÃO PÓS-INSTALAÇÃO
# ============================================================================

validate_installation() {
    log_title "VALIDAÇÃO PÓS-INSTALAÇÃO"
    
    # Aguardar mais um pouco
    sleep 10
    
    # Teste HTTP
    log_info "Testando conexão HTTP..."
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:80 | grep -q "^[23]"; then
        log_success "HTTP respondendo (porta 80)"
    else
        log_warn "HTTP pode não estar respondendo"
    fi
    
    # Teste com credenciais
    log_info "Testando acesso com credenciais..."
    if curl -s -u "${AWX_ADMIN_USER}:${AWX_ADMIN_PASSWORD}" \
        "http://localhost/api/v2/me/" | grep -q "username"; then
        log_success "Autenticação funcionando"
    else
        log_warn "Autenticação pode ter problemas"
    fi
    
    # Verificar banco de dados
    log_info "Verificando status do PostgreSQL..."
    if docker-compose exec -T postgres psql -U awx -d awx -c "SELECT 1" > /dev/null 2>&1; then
        log_success "PostgreSQL conectando corretamente"
    else
        log_warn "PostgreSQL pode ter problemas"
    fi
}

# ============================================================================
# INFORMAÇÕES DE ACESSO
# ============================================================================

print_access_info() {
    log_title "INFORMAÇÕES DE ACESSO AWX"
    
    echo ""
    echo -e "${BOLD}🎉 AWX INSTALADO COM SUCESSO!${NC}"
    echo ""
    echo "Acesso:"
    echo "  URL:      http://$(hostname -I | awk '{print $1}'):80"
    echo "  HTTPS:    https://$(hostname -I | awk '{print $1}'):443"
    echo "  Hostname: $AWX_HOSTNAME"
    echo ""
    echo "Credenciais de Acesso:"
    echo "  Username: $AWX_ADMIN_USER"
    echo "  Password: $AWX_ADMIN_PASSWORD"
    echo ""
    echo "Banco de Dados:"
    echo "  Host:     $POSTGRES_HOST"
    echo "  Port:     $POSTGRES_PORT"
    echo "  Database: $POSTGRES_DB"
    echo "  User:     $POSTGRES_USER"
    echo ""
    echo "Diretórios:"
    echo "  Base:     $AWX_BASE_PATH"
    echo "  Projects: $AWX_PROJECTS_PATH"
    echo "  Logs:     $LOG_FILE"
    echo ""
    echo "Comandos Úteis:"
    echo "  Ver logs:        docker-compose -f $AWX_BASE_PATH/docker-compose.yml logs -f"
    echo "  Parar serviços:  docker-compose -f $AWX_BASE_PATH/docker-compose.yml down"
    echo "  Iniciar:         docker-compose -f $AWX_BASE_PATH/docker-compose.yml up -d"
    echo ""
    echo "Próximos Passos:"
    echo "  1. Acesse a URL acima"
    echo "  2. Faça login com as credenciais acima"
    echo "  3. Configure suas organizações e usuários"
    echo "  4. Configure as credenciais do Zabbix"
    echo "  5. Crie playbooks e agendamentos"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    clear
    
    log_title "INSTALAÇÃO AWX 22.x - INICIADA"
    
    log_info "Data: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Servidor: awx-01 (10.31.38.68)"
    log_info "Versão AWX: $AWX_VERSION"
    
    # Executar etapas
    check_prerequisites || exit 1
    prepare_directories
    ask_admin_credentials
    ask_postgres_credentials || exit 1
    ask_hostname
    download_awx
    create_docker_compose_file
    start_awx_services || exit 1
    validate_installation
    print_access_info
    
    log_success "=========================================="
    log_success "INSTALAÇÃO AWX CONCLUÍDA COM SUCESSO"
    log_success "=========================================="
}

main "$@"
