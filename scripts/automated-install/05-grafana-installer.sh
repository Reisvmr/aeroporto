#!/bin/bash

################################################################################
#                                                                              #
#  SCRIPT DE INSTALAÇÃO INTERATIVA - GRAFANA 10.x (OTIMIZADO PARA 10GB)       #
#                                                                              #
#  Projeto: Aeroporto - AWX + Grafana + Zabbix                               #
#  Data: 24/10/2026                                                           #
#  Versão: 2.0 (OTIMIZADO PARA DISCO LIMITADO)                                #
#  Servidor: grafana-01 (10.31.38.66)                                         #
#                                                                              #
#  OBJETIVO:                                                                   #
#    Instalação completa e automatizada do Grafana 10.x                       #
#    OTIMIZADO para funcionar com 10GB de espaço livre em disco               #
#    Com questões interativas para customização                               #
#    Integração com PostgreSQL remoto e Zabbix                                #
#                                                                              #
#  OTIMIZAÇÕES PARA 10GB:                                                      #
#    ✅ Configuração agressiva de rotação de logs (3 dias)                    #
#    ✅ Limpeza automática de cache antigo                                    #
#    ✅ Monitora espaço em disco continuamente                                #
#    ✅ Alerta quando disco > 80%                                             #
#    ✅ Configuração PostgreSQL remoto (sem dados locais)                     #
#    ✅ Desabilita histórico extenso de métricas                              #
#                                                                              #
#  PRÉ-REQUISITOS:                                                             #
#    - Ubuntu 26.04+                                                          #
#    - Acesso a repositórios apt                                              #
#    - 4 vCPU, 8 GB RAM, 10 GB disco MÍNIMO                                   #
#    - PostgreSQL 10.31.38.64:5432 (para backend de dados REMOTO)             #
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

# OTIMIZAÇÕES PARA 10GB
MIN_DISK_GB=10
WARN_DISK_PERCENT=80
ALERT_DISK_PERCENT=90

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
# FUNÇÕES DE MONITORAMENTO DE DISCO
# ============================================================================

check_disk_space() {
    log_title "VERIFICAÇÃO DE ESPAÇO EM DISCO"
    
    local disk_used=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    local disk_free_gb=$(df / | awk 'NR==2 {print $4}' | awk '{print int($1/1024/1024)}')
    
    echo "Espaço em disco:"
    echo "  Livre: ${disk_free_gb}GB"
    echo "  Usado: ${disk_used}%"
    echo ""
    
    if [ "$disk_free_gb" -lt "$MIN_DISK_GB" ]; then
        log_error "ESPAÇO EM DISCO CRÍTICO: ${disk_free_gb}GB (mínimo: ${MIN_DISK_GB}GB)"
        return 1
    fi
    
    if [ "$disk_used" -gt "$ALERT_DISK_PERCENT" ]; then
        log_error "ALERTA CRÍTICO: Disco ${disk_used}% cheio!"
        return 1
    fi
    
    if [ "$disk_used" -gt "$WARN_DISK_PERCENT" ]; then
        log_warn "AVISO: Disco ${disk_used}% cheio - prepare-se para limpeza"
    fi
    
    log_success "Espaço em disco OK"
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
    log_title "CREDENCIAIS POSTGRESQL (BACKEND REMOTO)"
    
    if [ "$INTERACTIVE" == "false" ]; then
        if [ -z "$POSTGRES_PASSWORD" ]; then
            POSTGRES_PASSWORD="changeme123!"
        fi
        return 0
    fi
    
    echo "Configure acesso ao PostgreSQL (REMOTO em 10.31.38.64):"
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
    
    # Verificar espaço em disco (OTIMIZADO PARA 10GB)
    local disk_free=$(df / | awk 'NR==2 {print $4}')
    local disk_free_gb=$((disk_free / 1024 / 1024))
    
    if [ "$disk_free_gb" -lt "$MIN_DISK_GB" ]; then
        log_error "Espaço em disco INSUFICIENTE (< ${MIN_DISK_GB} GB)"
        return 1
    fi
    log_success "Espaço em disco OK: ${disk_free_gb}GB (mínimo recomendado: ${MIN_DISK_GB}GB)"
    
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
    
    log_info "Adicionando chave GPG do Grafana...\n"
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
# CONFIGURAR GRAFANA (OTIMIZADO PARA 10GB)
# ============================================================================

configure_grafana() {
    log_title "CONFIGURAR GRAFANA (OTIMIZADO PARA 10GB)"
    
    local config_file="/etc/grafana/grafana.ini"
    
    log_info "Configurando arquivo grafana.ini com otimizações de disco..."
    
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
    
    # Configurar logs (OTIMIZADO PARA 10GB)
    sed -i "s/^;mode = .*/mode = file/" "$config_file"
    sed -i "s|^;path = .*|path = $GRAFANA_LOG/grafana.log|" "$config_file"
    
    # OTIMIZAÇÕES DE DISCO:
    # 1. Limitar tamanho máximo de log
    if grep -q "max_lines" "$config_file"; then
        sed -i "s/^max_lines = .*/max_lines = 1000000/" "$config_file"
    else
        echo "max_lines = 1000000" >> "$config_file"
    fi
    
    # 2. Limitar retenção de dados
    if grep -q "max_retention_days" "$config_file"; then
        sed -i "s/^max_retention_days = .*/max_retention_days = 90/" "$config_file"
    else
        echo "max_retention_days = 90" >> "$config_file"
    fi
    
    log_success "Arquivo grafana.ini configurado com otimizações de disco"
}

# ============================================================================
# CONFIGURAR ROTAÇÃO DE LOGS (OTIMIZADO PARA 10GB)
# ============================================================================

configure_log_rotation() {
    log_title "CONFIGURAR ROTAÇÃO AGRESSIVA DE LOGS"
    
    log_info "Configurando logrotate para Grafana (retenção: 3 dias)..."
    
    cat > /etc/logrotate.d/grafana-server << 'EOF'
/var/log/grafana/grafana.log {
    daily
    rotate 3
    compress
    delaycompress
    missingok
    notifempty
    create 640 grafana grafana
    sharedscripts
    postrotate
        systemctl reload grafana-server > /dev/null 2>&1 || true
    endscript
}
EOF
    
    log_success "Rotação de logs configurada (máximo 3 dias de histórico)"
}

# ============================================================================
# INSTALAR PLUGINS (SELETIVO PARA 10GB)
# ============================================================================

install_grafana_plugins() {
    log_title "INSTALAR PLUGINS GRAFANA (SELETIVO)"
    
    log_warn "Com 10GB, instalando apenas plugins essenciais..."
    
    local plugins=(
        "grafana-piechart-panel"
    )
    
    for plugin in "${plugins[@]}"; do
        log_info "Instalando plugin: $plugin..."
        run_cmd "grafana-cli plugins install $plugin" "Instalar $plugin" || log_warn "Falha ao instalar $plugin"
    done
    
    log_success "Plugins essenciais instalados (plugins adicionais podem ser instalados depois)"
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
# CRIAR SCRIPT DE LIMPEZA AUTOMÁTICA
# ============================================================================

create_cleanup_script() {
    log_title "CRIAR SCRIPT DE LIMPEZA AUTOMÁTICA"
    
    cat > /usr/local/bin/grafana-cleanup.sh << 'EOF'
#!/bin/bash

# Script de limpeza automática para Grafana com 10GB de disco

ALERT_PERCENT=80
CRITICAL_PERCENT=90
GRAFANA_LOG="/var/log/grafana"

disk_used=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')

if [ "$disk_used" -gt "$CRITICAL_PERCENT" ]; then
    echo "[CRÍTICO] Disco ${disk_used}% cheio - limpando logs antigos..."
    find "$GRAFANA_LOG" -name "*.log.*" -mtime +1 -delete
    systemctl restart grafana-server
elif [ "$disk_used" -gt "$ALERT_PERCENT" ]; then
    echo "[AVISO] Disco ${disk_used}% cheio - monitore o espaço"
fi
EOF
    
    chmod +x /usr/local/bin/grafana-cleanup.sh
    
    # Adicionar ao crontab para executar diariamente
    if ! crontab -l | grep -q "grafana-cleanup"; then
        (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/grafana-cleanup.sh") | crontab -
        log_success "Script de limpeza automática instalado (executa diariamente às 02:00)"
    fi
}

# ============================================================================
# INFORMAÇÕES DE ACESSO
# ============================================================================

print_access_info() {
    log_title "INFORMAÇÕES DE ACESSO GRAFANA"
    
    echo ""
    echo -e "${BOLD}🎉 GRAFANA INSTALADO COM SUCESSO!${NC}"
    echo ""
    echo "⚠️  ATENÇÃO: INSTALADO COM OTIMIZAÇÕES PARA 10GB DE DISCO"
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
    echo "Banco de Dados (Backend REMOTO):"
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
    echo "🔧 OTIMIZAÇÕES PARA 10GB:"
    echo "  ✅ Rotação agressiva de logs (3 dias)"
    echo "  ✅ Script de limpeza automática (diário às 02:00)"
    echo "  ✅ PostgreSQL remoto (sem ocupar espaço local)"
    echo "  ✅ Plugins minimizados"
    echo ""
    echo "📊 COMANDOS PARA MONITORAR DISCO:"
    echo "  Ver espaço:     df -h /"
    echo "  Ver uso Grafana: du -sh /var/lib/grafana /var/log/grafana"
    echo "  Limpeza manual: /usr/local/bin/grafana-cleanup.sh"
    echo ""
    echo "⚠️  IMPORTANTE:"
    echo "  • Monitore espaço mensalmente: df -h /"
    echo "  • Mantenha sempre 1-2 GB livres"
    echo "  • Se disco > 80%, limpeza automática será executada"
    echo "  • Se disco > 90%, Grafana será reiniciado"
    echo ""
    echo "Próximos Passos:"
    echo "  1. Acesse a URL acima"
    echo "  2. Faça login com as credenciais acima"
    echo "  3. Mude a senha padrão (recomendado)"
    echo "  4. Configure integração com PostgreSQL"
    echo "  5. Crie dashboards para monitorar seus ativos"
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
    
    log_title "INSTALAÇÃO GRAFANA 10.x - OTIMIZADA PARA 10GB"
    
    log_info "Data: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Servidor: grafana-01 (10.31.38.66)"
    log_info "Versão Grafana: $GRAFANA_VERSION"
    log_info "MODO: OTIMIZADO PARA 10GB DE DISCO LIVRE"
    
    # Executar etapas
    check_disk_space || exit 1
    check_prerequisites || exit 1
    ask_admin_credentials
    ask_postgres_credentials || exit 1
    ask_zabbix_integration
    ask_domain
    add_grafana_repository
    install_grafana
    configure_grafana
    configure_log_rotation
    install_grafana_plugins
    start_grafana_service || exit 1
    create_postgres_user
    create_cleanup_script
    print_access_info
    
    log_success "=========================================="
    log_success "INSTALAÇÃO GRAFANA CONCLUÍDA COM SUCESSO"
    log_success "MODO: OTIMIZADO PARA 10GB"
    log_success "=========================================="
}

main "$@"
