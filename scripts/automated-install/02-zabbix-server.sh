#!/bin/bash

################################################################################
#                                                                              #
#  SCRIPT DE INSTALAÇÃO AUTOMATIZADA - ZABBIX SERVER 7.0 LTS                  #
#                                                                              #
#  Projeto: Aeroporto - Zabbix 7.0 LTS + PostgreSQL 16                        #
#  Data: 24/10/2026                                                           #
#  Versão: 1.0                                                                #
#  Servidor: zbx-server-01 (10.31.38.60)                                      #
#                                                                              #
#  OBJETIVO:                                                                   #
#    Instalação completa e automatizada do Zabbix Server 7.0 LTS              #
#    Conectado a PostgreSQL remoto                                            #
#    Monitoramento de 676 ativos (câmeras, controle acesso, etc)             #
#                                                                              #
#  PRÉ-REQUISITOS:                                                             #
#    - SO: Ubuntu 20.04+ / CentOS 8+ / Debian 11+                             #
#    - Acesso root ou sudo                                                    #
#    - PostgreSQL 16 já instalado e funcionando em pg-01 (10.31.38.64)       #
#    - NTP sincronizado (crítico para Zabbix)                                 #
#    - Conectividade TCP 5432 para PostgreSQL                                 #
#    - 20+ GB livres                                                          #
#                                                                              #
#  DEPENDÊNCIAS:                                                               #
#    - PostgreSQL 16 (pg-01: 10.31.38.64:5432)                                #
#    - Database 'zabbix' criado                                               #
#    - Usuário PostgreSQL 'zabbix' criado                                     #
#                                                                              #
#  USO:                                                                        #
#    sudo bash 02-zabbix-server.sh                                            #
#                                                                              #
#  AUTHOR: Vinicius Reis (reisvmr@gmail.com)                                  #
#  LICENSE: MIT                                                               #
#                                                                              #
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURAÇÕES
# ============================================================================

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Variáveis de configuração (podem ser sobrescritas)
ZABBIX_VERSION="${ZABBIX_VERSION:-7.0}"
ZABBIX_RELEASE="${ZABBIX_RELEASE:-7.0.0}"
ZABBIX_HOST="${ZABBIX_HOST:-zbx-server-01}"
ZABBIX_IP="${ZABBIX_IP:-10.31.38.60}"
ZABBIX_PORT="${ZABBIX_PORT:-10051}"

PG_HOST="${PG_HOST:-10.31.38.64}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-zabbix}"
PG_DB="${PG_DB:-zabbix}"
PG_PASSWORD="${PG_PASSWORD:-}"

LOG_FILE="${LOG_FILE:-/var/log/zabbix-server-install.log}"
ZABBIX_USER="${ZABBIX_USER:-zabbix}"
ZABBIX_GROUP="${ZABBIX_GROUP:-zabbix}"
TIMEZONE="${TIMEZONE:-America/Sao_Paulo}"

# Flags
SKIP_VALIDATION="${SKIP_VALIDATION:-false}"
DRY_RUN="${DRY_RUN:-false}"
INTERACTIVE="${INTERACTIVE:-true}"

# ============================================================================
# FUNÇÕES COMPARTILHADAS
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

log_debug() {
    if [ "${DEBUG:-false}" == "true" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $*" | tee -a "$LOG_FILE"
    fi
}

confirm() {
    if [ "$INTERACTIVE" == "false" ]; then
        return 0
    fi
    
    local prompt="$1"
    local response
    read -p "$prompt (s/n): " -r response
    [[ "$response" =~ ^[Ss]$ ]]
}

run_cmd() {
    local cmd="$1"
    local desc="${2:-Executando comando}"
    
    log_debug "Executando: $cmd"
    
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
# PRÉ-REQUISITOS
# ============================================================================

check_prerequisites() {
    log_info "Verificando pré-requisitos..."
    
    # Verificar se é root
    if [ "$EUID" -ne 0 ]; then
        log_error "Este script deve ser executado como root"
        exit 1
    fi
    
    # Detectar SO
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_ID="$ID"
    else
        log_error "Não foi possível detectar o SO"
        exit 1
    fi
    
    log_info "SO Detectado: $OS_NAME ($OS_ID)"
    
    # Validar SO suportado
    case "$OS_ID" in
        ubuntu|debian)
            log_info "Debian/Ubuntu detectado"
            PKG_MANAGER="apt-get"
            PKG_UPDATE="apt-get update"
            ;;
        centos|rhel)
            log_info "CentOS/RHEL detectado"
            PKG_MANAGER="yum"
            PKG_UPDATE="yum makecache"
            ;;
        *)
            log_error "SO não suportado: $OS_ID"
            exit 1
            ;;
    esac
    
    # Verificar espaço em disco
    local disk_free=$(df / | awk 'NR==2 {print $4}')
    if [ "$disk_free" -lt 20480000 ]; then
        log_error "Espaço em disco insuficiente (< 20 GB livres)"
        exit 1
    fi
    log_success "Espaço em disco OK: $(( disk_free / 1024 / 1024 )) GB"
    
    # Verificar NTP (crítico para Zabbix)
    if ! systemctl is-active --quiet chrony && ! systemctl is-active --quiet ntpd; then
        log_warn "NTP não está sincronizado. Zabbix pode não funcionar corretamente."
        if ! confirm "Continuar mesmo assim?"; then
            exit 1
        fi
    else
        log_success "NTP sincronizado"
    fi
    
    # Verificar conectividade PostgreSQL
    log_info "Verificando conectividade com PostgreSQL..."
    if ! command -v psql &> /dev/null; then
        log_warn "PostgreSQL client não instalado (será instalado)"
    else
        if ! timeout 5 psql -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" -c "SELECT 1" > /dev/null 2>&1; then
            log_error "Não foi possível conectar ao PostgreSQL em $PG_HOST:$PG_PORT"
            if ! confirm "Continuar mesmo assim?"; then
                exit 1
            fi
        else
            log_success "Conectividade PostgreSQL OK"
        fi
    fi
    
    log_success "Pré-requisitos verificados"
}

# ============================================================================
# INSTALAÇÃO DE PACOTES BÁSICOS
# ============================================================================

install_base_packages() {
    log_info "Instalando pacotes básicos..."
    
    case "$OS_ID" in
        ubuntu|debian)
            run_cmd "$PKG_UPDATE" "Atualizar repositórios"
            run_cmd "apt-get install -y curl wget git vim htop net-tools telnet jq" \
                "Instalar ferramentas básicas"
            ;;
        centos|rhel)
            run_cmd "$PKG_UPDATE" "Atualizar repositórios"
            run_cmd "yum install -y curl wget git vim htop net-tools telnet jq" \
                "Instalar ferramentas básicas"
            ;;
    esac
    
    log_success "Pacotes básicos instalados"
}

# ============================================================================
# ADICIONAR REPOSITÓRIO ZABBIX
# ============================================================================

setup_zabbix_repo() {
    log_info "Configurando repositório Zabbix..."
    
    case "$OS_ID" in
        ubuntu|debian)
            run_cmd "wget -q -O /tmp/zabbix-release.deb https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/ubuntu/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_RELEASE}-1+ubuntu$(lsb_release -rs)_all.deb" \
                "Download Zabbix repository deb"
            run_cmd "dpkg -i /tmp/zabbix-release.deb" \
                "Instalar Zabbix repository"
            run_cmd "apt-get update" \
                "Atualizar repositórios"
            ;;
        centos|rhel)
            run_cmd "rpm -Uvh https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/rhel/$(rpm -q --queryformat '%{VERSION}' centos-release)/x86_64/zabbix-release-${ZABBIX_RELEASE}-1.el$(rpm -q --queryformat '%{VERSION}' centos-release).noarch.rpm" \
                "Instalar Zabbix repository"
            run_cmd "yum makecache" \
                "Atualizar repositórios"
            ;;
    esac
    
    log_success "Repositório Zabbix configurado"
}

# ============================================================================
# INSTALAR POSTGRESQL CLIENT
# ============================================================================

install_postgres_client() {
    log_info "Instalando PostgreSQL client..."
    
    case "$OS_ID" in
        ubuntu|debian)
            run_cmd "apt-get install -y postgresql-client libpq5 libpq-dev" \
                "Instalar PostgreSQL client"
            ;;
        centos|rhel)
            run_cmd "yum install -y postgresql" \
                "Instalar PostgreSQL client"
            ;;
    esac
    
    log_success "PostgreSQL client instalado"
}

# ============================================================================
# INSTALAR ZABBIX SERVER
# ============================================================================

install_zabbix_server() {
    log_info "Instalando Zabbix Server $ZABBIX_VERSION..."
    
    case "$OS_ID" in
        ubuntu|debian)
            run_cmd "apt-get install -y zabbix-server-pgsql zabbix-frontend-php php-pgsql zabbix-agent2 zabbix-agent2-plugin-*" \
                "Instalar Zabbix Server e Agent"
            ;;
        centos|rhel)
            run_cmd "yum install -y zabbix-server-pgsql zabbix-web-pgsql zabbix-agent2 zabbix-agent2-plugin-*" \
                "Instalar Zabbix Server e Agent"
            ;;
    esac
    
    log_success "Zabbix Server instalado"
}

# ============================================================================
# CRIAR USUÁRIO E GRUPO ZABBIX
# ============================================================================

create_zabbix_user() {
    log_info "Criando usuário/grupo Zabbix..."
    
    # Criar grupo
    if ! getent group "$ZABBIX_GROUP" > /dev/null; then
        run_cmd "groupadd --system $ZABBIX_GROUP" \
            "Criar grupo $ZABBIX_GROUP"
    else
        log_warn "Grupo $ZABBIX_GROUP já existe"
    fi
    
    # Criar usuário
    if ! getent passwd "$ZABBIX_USER" > /dev/null; then
        run_cmd "useradd --system --no-create-home --shell /bin/false --gid $ZABBIX_GROUP $ZABBIX_USER" \
            "Criar usuário $ZABBIX_USER"
    else
        log_warn "Usuário $ZABBIX_USER já existe"
    fi
    
    log_success "Usuário/grupo Zabbix criado"
}

# ============================================================================
# CRIAR DIRETÓRIOS ZABBIX
# ============================================================================

create_zabbix_directories() {
    log_info "Criando diretórios Zabbix..."
    
    local dirs=(
        "/var/lib/zabbix"
        "/var/lib/zabbix/alertscripts"
        "/var/lib/zabbix/externalscripts"
        "/var/log/zabbix"
        "/etc/zabbix"
        "/etc/zabbix/web"
        "/etc/zabbix/conf.d"
    )
    
    for dir in "${dirs[@]}"; do
        run_cmd "mkdir -p $dir" "Criar diretório $dir"
        run_cmd "chown $ZABBIX_USER:$ZABBIX_GROUP $dir" "Configurar permissões $dir"
    done
    
    log_success "Diretórios Zabbix criados"
}

# ============================================================================
# CONFIGURAR ZABBIX_SERVER.CONF
# ============================================================================

configure_zabbix_server() {
    log_info "Configurando zabbix_server.conf..."
    
    local config_file="/etc/zabbix/zabbix_server.conf"
    
    # Fazer backup
    if [ -f "$config_file" ]; then
        run_cmd "cp $config_file ${config_file}.backup" \
            "Backup zabbix_server.conf"
    fi
    
    # Criar configuração
    cat > "$config_file" << EOF
# Zabbix Server Configuration File
# Generated automatically by installation script

# Servidor
ListenPort=$ZABBIX_PORT
ListenIP=0.0.0.0

# Banco de Dados
DBHost=$PG_HOST
DBName=$PG_DB
DBUser=$PG_USER
DBPassword=$PG_PASSWORD
DBPort=$PG_PORT
DBSchema=public

# Caminhos
LogFile=/var/log/zabbix/zabbix_server.log
AlertScriptsPath=/var/lib/zabbix/alertscripts
ExternalScripts=/var/lib/zabbix/externalscripts
ForeignKeysCheckInterval=60
MaxHousekeeperDelete=5000

# Pollers e Processadores
StartPollers=4
StartPollersUnreachable=1
StartTrappers=5
StartPingers=1
StartDiscoverers=1
StartHTTPPollers=1
StartTimers=1
StartEscalators=1
StartPreprocessors=3
StartLLDProcessors=2
StartAgentPollers=1

# Cache
CacheSize=32M
HistoryCacheSize=16M
HistoryIndexCacheSize=4M
TrendCacheSize=4M
ValueCacheSize=8M

# Housekeeping (Limpeza de dados históricos)
HousekeepingFrequency=1
MaxHousekeeperDelete=5000
MaxHousekeeperBatchSize=500

# API
TLSCAFile=
TLSCertFile=
TLSKeyFile=

# Timezone
Timezone=$TIMEZONE

# Logs
LogType=file
LogFileSize=100
DebugLevel=3

# Protocolo
TLSConnect=unencrypted
TLSAccept=unencrypted

EOF
    
    run_cmd "chown $ZABBIX_USER:$ZABBIX_GROUP $config_file" \
        "Configurar permissões zabbix_server.conf"
    
    run_cmd "chmod 640 $config_file" \
        "Restringir acesso zabbix_server.conf"
    
    log_success "zabbix_server.conf configurado"
}

# ============================================================================
# INICIALIZAR DATABASE ZABBIX
# ============================================================================

initialize_zabbix_database() {
    log_info "Inicializando database Zabbix..."
    
    # Verificar se já foi inicializado
    if psql -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" -c "SELECT 1 FROM history LIMIT 1" > /dev/null 2>&1; then
        log_warn "Database Zabbix já parece estar inicializado"
        return 0
    fi
    
    # Encontrar arquivo de schema
    local schema_file="/usr/share/zabbix-server-pgsql/schema.sql.gz"
    if [ ! -f "$schema_file" ]; then
        log_error "Arquivo de schema não encontrado: $schema_file"
        return 1
    fi
    
    log_info "Importando schema Zabbix..."
    zcat "$schema_file" | psql -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" > /dev/null 2>&1 || {
        log_error "Falha ao importar schema"
        return 1
    }
    
    log_success "Database Zabbix inicializado"
}

# ============================================================================
# INICIAR SERVIÇO ZABBIX SERVER
# ============================================================================

start_zabbix_service() {
    log_info "Iniciando serviço Zabbix Server..."
    
    run_cmd "systemctl daemon-reload" \
        "Reload systemd"
    
    run_cmd "systemctl restart zabbix-server" \
        "Reiniciar Zabbix Server"
    
    run_cmd "systemctl enable zabbix-server" \
        "Habilitar Zabbix Server auto-start"
    
    # Aguardar inicialização
    sleep 5
    
    # Verificar se serviço está rodando
    if systemctl is-active --quiet zabbix-server; then
        log_success "Zabbix Server iniciado com sucesso"
        return 0
    else
        log_error "Zabbix Server falhou ao iniciar"
        systemctl status zabbix-server >> "$LOG_FILE" 2>&1 || true
        return 1
    fi
}

# ============================================================================
# INSTALAR E CONFIGURAR ZABBIX AGENT 2
# ============================================================================

configure_zabbix_agent2() {
    log_info "Configurando Zabbix Agent 2..."
    
    local agent_config="/etc/zabbix/zabbix_agent2.conf"
    
    # Fazer backup
    if [ -f "$agent_config" ]; then
        run_cmd "cp $agent_config ${agent_config}.backup" \
            "Backup zabbix_agent2.conf"
    fi
    
    # Configurar para monitorar o próprio servidor
    cat > "$agent_config" << EOF
# Zabbix Agent 2 Configuration
# Server local

Server=127.0.0.1
ServerActive=127.0.0.1:10051
Hostname=$ZABBIX_HOST
HostnameItem=system.hostname

# Timeout
Timeout=30

# LogFile
LogFile=/var/log/zabbix/zabbix_agent2.log
LogFileSize=100

# User
User=$ZABBIX_USER

# Plugins
Plugins.Timeout=30
Plugins.Uptime.Capacity=100
Plugins.Net.Capacity=200
Plugins.Proc.Capacity=200
Plugins.SystemRun.LogRemoteCommands=1

EOF
    
    run_cmd "chown $ZABBIX_USER:$ZABBIX_GROUP $agent_config" \
        "Configurar permissões zabbix_agent2.conf"
    
    run_cmd "systemctl daemon-reload" \
        "Reload systemd"
    
    run_cmd "systemctl restart zabbix-agent2" \
        "Reiniciar Zabbix Agent 2"
    
    run_cmd "systemctl enable zabbix-agent2" \
        "Habilitar Zabbix Agent 2 auto-start"
    
    log_success "Zabbix Agent 2 configurado"
}

# ============================================================================
# CONFIGURAR FIREWALL
# ============================================================================

configure_firewall() {
    log_info "Configurando firewall..."
    
    case "$OS_ID" in
        ubuntu|debian)
            if command -v ufw &> /dev/null; then
                run_cmd "ufw allow 10051/tcp" \
                    "Permitir porta 10051 (UFW)"
            fi
            ;;
        centos|rhel)
            if systemctl is-active --quiet firewalld; then
                run_cmd "firewall-cmd --permanent --add-port=10051/tcp" \
                    "Permitir porta 10051 (firewalld)"
                run_cmd "firewall-cmd --reload" \
                    "Recarregar firewall"
            fi
            ;;
    esac
    
    log_success "Firewall configurado"
}

# ============================================================================
# VALIDAÇÃO PÓS-INSTALAÇÃO
# ============================================================================

validate_installation() {
    log_info "Validando instalação..."
    
    local errors=0
    
    # Verificar se Zabbix Server está rodando
    if ! systemctl is-active --quiet zabbix-server; then
        log_error "Zabbix Server não está rodando"
        ((errors++))
    else
        log_success "Zabbix Server está rodando"
    fi
    
    # Verificar se Agent 2 está rodando
    if ! systemctl is-active --quiet zabbix-agent2; then
        log_error "Zabbix Agent 2 não está rodando"
        ((errors++))
    else
        log_success "Zabbix Agent 2 está rodando"
    fi
    
    # Verificar porta
    if ! netstat -tlnap 2>/dev/null | grep -q ":10051"; then
        log_error "Zabbix Server não está escutando na porta 10051"
        ((errors++))
    else
        log_success "Zabbix Server escutando na porta 10051"
    fi
    
    # Verificar conectividade PostgreSQL
    if ! psql -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" -c "SELECT 1" > /dev/null 2>&1; then
        log_error "Falha ao conectar no PostgreSQL"
        ((errors++))
    else
        log_success "Conectividade PostgreSQL OK"
    fi
    
    # Verificar arquivo de log
    if [ -f /var/log/zabbix/zabbix_server.log ]; then
        log_success "Arquivo de log criado"
    else
        log_error "Arquivo de log não foi criado"
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        log_success "Todas as validações passaram!"
        return 0
    else
        log_error "Total de erros: $errors"
        return 1
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    log_info "=========================================="
    log_info "INSTALAÇÃO ZABBIX SERVER 7.0 - INICIADO"
    log_info "=========================================="
    log_info "SO: $OS_NAME"
    log_info "Zabbix Versão: $ZABBIX_VERSION"
    log_info "PostgreSQL: $PG_HOST:$PG_PORT"
    log_info "Data: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Log: $LOG_FILE"
    
    # Executar etapas
    check_prerequisites || exit 1
    install_base_packages || exit 1
    install_postgres_client || exit 1
    setup_zabbix_repo || exit 1
    install_zabbix_server || exit 1
    create_zabbix_user || exit 1
    create_zabbix_directories || exit 1
    configure_zabbix_server || exit 1
    initialize_zabbix_database || exit 1
    start_zabbix_service || exit 1
    configure_zabbix_agent2 || exit 1
    configure_firewall || exit 1
    
    # Validar
    if validate_installation; then
        log_success "=========================================="
        log_success "INSTALAÇÃO ZABBIX SERVER CONCLUÍDA COM SUCESSO"
        log_success "=========================================="
        log_info "Próximo passo: Instalar Zabbix Frontend em zbx-fe-01"
        log_info "Arquivo de configuração: /etc/zabbix/zabbix_server.conf"
        log_info "Logs: /var/log/zabbix/zabbix_server.log"
        return 0
    else
        log_error "=========================================="
        log_error "VALIDAÇÃO FALHOU"
        log_error "=========================================="
        log_error "Revise o log: $LOG_FILE"
        return 1
    fi
}

# Executar main
main "$@"
