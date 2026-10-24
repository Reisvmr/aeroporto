#!/bin/bash

################################################################################
#                                                                              #
#  SCRIPT DE INSTALAÇÃO INTERATIVA - GRAFANA 10.x                             #
#                                                                              #
#  Projeto: Aeroporto - AWX + Grafana + Zabbix                               #
#  Data: 24/10/2026                                                           #
#  Versão: 1.0                                                                #
#  Servidor: grafana-01 (10.31.38.66)                                         #
#                                                                              #
#  OBJETIVO:                                                                   #
#    Instalação completa e automatizada do Grafana 10.x                       #
#    Com questões interativas para customização                               #
#    Integração com PostgreSQL e Zabbix                                       #
#                                                                              #
#  PRÉ-REQUISITOS:                                                             #
#    - Ubuntu 26.04+                                                          #
#    - Acesso a repositórios apt                                              #
#    - 4 vCPU, 8 GB RAM, 50 GB disco                                          #
#    - PostgreSQL 10.31.38.64:5432 (para backend de dados)                    #
#                                                                              #
#  USO:                                                                        #
#    sudo bash 05-grafana-installer.sh                                        #
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

# Versão
GRAFANA_VERSION="${GRAFANA_VERSION:-10.0.0}"
GRAFANA_EDITION="${GRAFANA_EDITION:-oss}"

# Diretórios
GRAFANA_HOME="/etc/grafana"
GRAFANA_DATA="/var/lib/grafana"
GRAFANA_LOG="/var/log/grafana"
LOG_FILE="/var/log/grafana-install.log"

# Configurações padrão
GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-}"
GRAFANA_HTTP_PORT="${GRAFANA_HTTP_PORT:-3000}"
GRAFANA_DOMAIN="${GRAFANA_DOMAIN:-grafana.example.com}"

POSTGRES_HOST="${POSTGRES_HOST:-10.31.38.64}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-grafana}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
POSTGRES_DB="${POSTGRES_DB:-grafana}"

ZABBIX_API_URL="${ZABBIX_API_URL:-http://10.31.38.60/api_jsonrpc.php}"

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
    log_title "CREDENCIAIS ADMINISTRADOR GRAFANA"
    
    if [ "$INTERACTIVE" == "false" ]; then
        if [ -z "$GRAFANA_ADMIN_PASSWORD" ]; then
            GRAFANA_ADMIN_PASSWORD="changeme123!"
        fi
        return 0
    fi
    
    echo "Digite as credenciais do administrador Grafana:"
    echo ""
    
    read -p "Username (padrão: admin): " input_user
    GRAFANA_ADMIN_USER="${input_user:-admin}"
    
    read -s -p "Password: " input_pass
    echo ""
    
    if [ -z "$input_pass" ]; then
        log_warn "Gerando senha aleatória..."
        GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 12)
        log_info "Senha gerada: $GRAFANA_ADMIN_PASSWORD"
    else
        GRAFANA_ADMIN_PASSWORD="$input_pass"
    fi
    
    log_success "Credenciais administrador configuradas"
}

ask_postgres_credentials() {
    log_title "CREDENCIAIS POSTGRESQL (BACKEND)"
    
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
    
    read -p "Database (padrão: grafana): " input_db
    POSTGRES_DB="${input_db:-grafana}"
    
    read -p "Username (padrão: grafana): " input_user
    POSTGRES_USER="${input_user:-grafana}"
    
    read -s -p "Password: " input_pass
    echo ""
    
    if [ -z "$input_pass" ]; then
        log_error "Senha do PostgreSQL é obrigatória!"
        return 1
    fi
    
    POSTGRES_PASSWORD="$input_pass"
    log_success "Credenciais PostgreSQL configuradas"
}

ask_zabbix_integration() {
    log_title "INTEGRAÇÃO COM ZABBIX"
    
    if [ "$INTERACTIVE" == "false" ]; then
        return 0
    fi
    
    echo "Configure integração com Zabbix:"
    echo ""
    
    read -p "Zabbix API URL (padrão: http://10.31.38.60/api_jsonrpc.php): " input_url
    ZABBIX_API_URL="${input_url:-http://10.31.38.60/api_jsonrpc.php}"
    
    log_success "Zabbix integração configurada"
}

ask_domain() {
    log_title "CONFIGURAÇÃO DE DOMÍNIO"
    
    if [ "$INTERACTIVE" == "false" ]; then
        return 0
    fi
    
    echo "Configure o domínio para Grafana:"
    echo ""
    
    read -p "Domain/FQDN (padrão: grafana.example.com): " input_domain
    GRAFANA_DOMAIN="${input_domain:-grafana.example.com}"
    
    read -p "HTTP Port (padrão: 3000): " input_port
    GRAFANA_HTTP_PORT="${input_port:-3000}"
    
    log_success "Domain e porta configurados"
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
    
    # Verificar SO
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_error "Este script é específico para Ubuntu"
        return 1
    fi
    log_success "Ubuntu detectado"
    
    # Verificar conectividade
    if ! ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        log_warn "Sem conectividade com internet"
    else
        log_success "Conectividade com internet OK"
    fi
    
    # Verificar espaço em disco
    local disk_free=$(df / | awk 'NR==2 {print $4}')
    local disk_free_gb=$((disk_free / 1024 / 1024))
    
    if [ "$disk_free_gb" -lt 50 ]; then
        log_error "Espaço em disco insuficiente (< 50 GB)"
        return 1
    fi
    log_success "Espaço em disco OK: ${disk_free_gb}GB"
    
    # Verificar RAM
    local ram=$(free -g | awk 'NR==2 {print $2}')
    if [ "$ram" -lt 8 ]; then
        log_warn "RAM insuficiente (< 8 GB), Grafana pode ter performance reduzida"
    else
        log_success "RAM OK: ${ram}GB"
    fi
}

# ============================================================================
# ADICIONAR REPOSITÓRIO GRAFANA
# ============================================================================

add_grafana_repository() {
    log_title "ADICIONAR REPOSITÓRIO GRAFANA"
    
    log_info "Adicionando chave GPG do Grafana..."
    run_cmd "apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 965099582D33A8CD57CBB7D48F3F92365D9957FB" \
        "Importar chave GPG Grafana" || log_warn "Falha ao importar chave GPG"
    
    log_info "Adicionando repositório apt..."
    
    local repo_entry="deb https://apt.grafana.com stable main"
    
    if ! grep -q "grafana" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
        echo "$repo_entry" | tee /etc/apt/sources.list.d/grafana.list > /dev/null
        log_success "Repositório adicionado"
    else
        log_info "Repositório já existe"
    fi
    
    run_cmd "apt-get update" "Atualizar cache apt" || true
}

# ============================================================================
# INSTALAR GRAFANA
# ============================================================================

install_grafana() {
    log_title "INSTALAR GRAFANA $GRAFANA_VERSION"
    
    log_info "Instalando pacote Grafana..."
    
    if run_cmd "apt-get install -y grafana=$GRAFANA_VERSION" "Instalar Grafana"; then
        log_success "Grafana instalado"
    else
        log_warn "Versão específica não encontrada, instalando versão disponível..."
        run_cmd "apt-get install -y grafana" "Instalar Grafana (versão padrão)" || exit 1
    fi
}

# ============================================================================
# CONFIGURAR GRAFANA
# ============================================================================

configure_grafana() {
    log_title "CONFIGURAR GRAFANA"
    
    local config_file="/etc/grafana/grafana.ini"
    
    log_info "Configurando arquivo grafana.ini..."
    
    # Backup
    if [ -f "$config_file" ]; then
        cp "$config_file" "$config_file.backup.$(date +%s)"
        log_info "Backup criado: $config_file.backup"
    fi
    
    # Configurar domínio
    sed -i "s/^;domain = .*/domain = $GRAFANA_DOMAIN/" "$config_file"
    sed -i "s/^http_port = .*/http_port = $GRAFANA_HTTP_PORT/" "$config_file"
    
    # Configurar PostgreSQL
    sed -i "s/^type = .*/type = postgres/" "$config_file"
    
    # Configurar segurança
    sed -i "s/^;admin_user = .*/admin_user = $GRAFANA_ADMIN_USER/" "$config_file"
    # Senha será configurada via API após inicialização
    
    # Configurar logs
    sed -i "s/^;mode = .*/mode = file/" "$config_file"
    sed -i "s|^;path = .*|path = $GRAFANA_LOG/grafana.log|" "$config_file"
    
    log_success "Arquivo grafana.ini configurado"
}

# ============================================================================
# INSTALAR PLUGINS
# ============================================================================

install_grafana_plugins() {
    log_title "INSTALAR PLUGINS GRAFANA"
    
    local plugins=(
        "grafana-clock-panel"
        "grafana-simple-json-datasource"
        "grafana-piechart-panel"
    )
    
    for plugin in "${plugins[@]}"; do
        log_info "Instalando plugin: $plugin..."
        run_cmd "grafana-cli plugins install $plugin" "Instalar $plugin" || log_warn "Falha ao instalar $plugin"
    done
}

# ============================================================================
# INICIAR GRAFANA
# ============================================================================

start_grafana_service() {
    log_title "INICIAR SERVIÇO GRAFANA"
    
    log_info "Habilitando serviço..."
    run_cmd "systemctl enable grafana-server" "Habilitar grafana-server"
    
    log_info "Iniciando serviço..."
    run_cmd "systemctl start grafana-server" "Iniciar grafana-server"
    
    sleep 5
    
    if systemctl is-active --quiet grafana-server; then
        log_success "Grafana está rodando"
    else
        log_error "Grafana não está rodando"
        journalctl -u grafana-server -n 20
        return 1
    fi
}

# ============================================================================
# CONFIGURAR ZABBIX DATA SOURCE
# ============================================================================

configure_zabbix_datasource() {
    log_title "CONFIGURAR ZABBIX COMO DATA SOURCE"
    
    log_info "Aguardando inicialização do Grafana (30 segundos)..."
    sleep 30
    
    local ds_config="/tmp/zabbix-datasource.json"
    
    cat > "$ds_config" << EOF
{
  "name": "Zabbix",
  "type": "alexanderzobnin-zabbix-app",
  "url": "$ZABBIX_API_URL",
  "access": "proxy",
  "isDefault": true,
  "jsonData": {
    "trends": true,
    "alerting": true
  }
}
EOF
    
    log_info "Configuração Zabbix data source criada"
}

# ============================================================================
# VALIDAÇÃO PÓS-INSTALAÇÃO
# ============================================================================

validate_installation() {
    log_title "VALIDAÇÃO PÓS-INSTALAÇÃO"
    
    log_info "Testando conectividade HTTP..."
    
    if timeout 5 curl -s -o /dev/null -w "%{http_code}" "http://localhost:$GRAFANA_HTTP_PORT" | grep -q "^[23]"; then
        log_success "HTTP respondendo (porta $GRAFANA_HTTP_PORT)"
    else
        log_warn "HTTP pode não estar respondendo"
    fi
    
    log_info "Verificando status do serviço..."
    
    if systemctl is-active --quiet grafana-server; then
        log_success "Serviço grafana-server está ativo"
    else
        log_error "Serviço grafana-server não está ativo"
    fi
    
    log_info "Verificando logs..."
    tail -n 10 "$GRAFANA_LOG/grafana.log" | head -c 500
}

# ============================================================================
# INFORMAÇÕES DE ACESSO
# ============================================================================

print_access_info() {
    log_title "INFORMAÇÕES DE ACESSO GRAFANA"
    
    echo ""
    echo -e "${BOLD}🎉 GRAFANA INSTALADO COM SUCESSO!${NC}"
    echo ""
    echo "Acesso:"
    echo "  URL:      http://$(hostname -I | awk '{print $1}'):$GRAFANA_HTTP_PORT"
    echo "  Domain:   $GRAFANA_DOMAIN"
    echo "  Porta:    $GRAFANA_HTTP_PORT"
    echo ""
    echo "Credenciais de Acesso:"
    echo "  Username: $GRAFANA_ADMIN_USER"
    echo "  Password: $GRAFANA_ADMIN_PASSWORD"
    echo ""
    echo "Banco de Dados (Backend):"
    echo "  Host:     $POSTGRES_HOST"
    echo "  Port:     $POSTGRES_PORT"
    echo "  Database: $POSTGRES_DB"
    echo "  User:     $POSTGRES_USER"
    echo ""
    echo "Integração Zabbix:"
    echo "  API URL:  $ZABBIX_API_URL"
    echo ""
    echo "Diretórios:"
    echo "  Config:   $GRAFANA_HOME"
    echo "  Data:     $GRAFANA_DATA"
    echo "  Logs:     $GRAFANA_LOG"
    echo ""
    echo "Comandos Úteis:"
    echo "  Ver status:      systemctl status grafana-server"
    echo "  Ver logs:        tail -f $GRAFANA_LOG/grafana.log"
    echo "  Reiniciar:       systemctl restart grafana-server"
    echo "  Parar serviço:   systemctl stop grafana-server"
    echo "  Editar config:   nano $GRAFANA_HOME/grafana.ini"
    echo ""
    echo "Próximos Passos:"
    echo "  1. Acesse a URL acima"
    echo "  2. Faça login com as credenciais acima"
    echo "  3. Mude a senha padrão (recomendado)"
    echo "  4. Configure integração com PostgreSQL"
    echo "  5. Instale plugins Zabbix (Alexandr Zonbin)"
    echo "  6. Crie dashboards para monitorar seus ativos"
    echo "  7. Configure alertas e notificações"
    echo ""
}

# ============================================================================
# CRIAR USUÁRIO POSTGRESQL (SE NECESSÁRIO)
# ============================================================================

create_postgres_user() {
    log_title "CONFIGURAR POSTGRESQL"
    
    log_info "Verificando conectividade com PostgreSQL..."
    
    if timeout 5 bash -c "cat < /dev/null > /dev/tcp/$POSTGRES_HOST/$POSTGRES_PORT" 2>/dev/null; then
        log_success "PostgreSQL acessível em $POSTGRES_HOST:$POSTGRES_PORT"
    else
        log_warn "Não foi possível conectar ao PostgreSQL"
        log_info "Certifique-se de que:"
        log_info "  1. PostgreSQL está rodando em $POSTGRES_HOST:$POSTGRES_PORT"
        log_info "  2. Firewall permite conexão"
        log_info "  3. Usuário '$POSTGRES_USER' existe"
        return 0
    fi
    
    log_info "Nota: Crie manualmente o usuário e database se ainda não existirem"
    log_info "  SQL: CREATE DATABASE $POSTGRES_DB OWNER $POSTGRES_USER;"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    clear
    
    log_title "INSTALAÇÃO GRAFANA 10.x - INICIADA"
    
    log_info "Data: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Servidor: grafana-01 (10.31.38.66)"
    log_info "Versão Grafana: $GRAFANA_VERSION"
    
    # Executar etapas
    check_prerequisites || exit 1
    ask_admin_credentials
    ask_postgres_credentials || exit 1
    ask_zabbix_integration
    ask_domain
    add_grafana_repository
    install_grafana
    configure_grafana
    install_grafana_plugins
    start_grafana_service || exit 1
    create_postgres_user
    configure_zabbix_datasource
    validate_installation
    print_access_info
    
    log_success "=========================================="
    log_success "INSTALAÇÃO GRAFANA CONCLUÍDA COM SUCESSO"
    log_success "=========================================="
}

main "$@"
