#!/bin/bash

################################################################################
#                                                                              #
#  SCRIPT DE INSTALAÇÃO AUTOMATIZADA - POSTGRESQL 16 PRIMARY                  #
#                                                                              #
#  Projeto: Aeroporto - Zabbix 7.0 LTS + PostgreSQL 16                        #
#  Data: 24/10/2026                                                           #
#  Versão: 1.0                                                                #
#  Servidor: pg-01 (10.31.38.64)                                              #
#                                                                              #
#  OBJETIVO:                                                                   #
#    Instalação completa e automatizada de PostgreSQL 16                      #
#    Preparado para Zabbix, com backup e monitoring                           #
#                                                                              #
#  PRÉ-REQUISITOS:                                                             #
#    - SO: Ubuntu 20.04+ / CentOS 8+ / Debian 11+                             #
#    - Acesso root ou sudo                                                    #
#    - NVMe montado em /var/lib/postgresql ou /pgdata                         #
#    - NTP sincronizado                                                       #
#    - 50+ GB livres                                                          #
#                                                                              #
#  USO:                                                                        #
#    sudo bash 01-postgresql.sh                                               #
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
PG_VERSION="${PG_VERSION:-16}"
PG_HOST="${PG_HOST:-10.31.38.64}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-zabbix}"
PG_DB="${PG_DB:-zabbix}"
PG_DATA_PATH="${PG_DATA_PATH:-/var/lib/postgresql}"
PG_BACKUP_PATH="${PG_BACKUP_PATH:-/backups/postgresql}"
LOG_FILE="${LOG_FILE:-/var/log/postgresql-install.log}"
TIMEZONE="${TIMEZONE:-UTC}"

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

# Função para confirmar ação
confirm() {
    if [ "$INTERACTIVE" == "false" ]; then
        return 0
    fi
    
    local prompt="$1"
    local response
    read -p "$prompt (s/n): " -r response
    [[ "$response" =~ ^[Ss]$ ]]
}

# Função para executar comando com log
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
            LOG_INFO "Debian/Ubuntu detectado"
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
    if [ "$disk_free" -lt 51200000 ]; then
        log_error "Espaço em disco insuficiente (< 50 GB livres)"
        exit 1
    fi
    log_success "Espaço em disco OK: $(( disk_free / 1024 / 1024 )) GB"
    
    # Verificar NTP
    if ! systemctl is-active --quiet chrony && ! systemctl is-active --quiet ntpd; then
        log_warn "NTP não está sincronizado. Configure antes de continuar."
        if ! confirm "Continuar mesmo assim?"; then
            exit 1
        fi
    fi
    
    # Verificar storage path
    if ! mountpoint -q "$PG_DATA_PATH" 2>/dev/null; then
        log_warn "Caminho $PG_DATA_PATH não é um ponto de montagem"
        if ! confirm "Continuar mesmo assim?"; then
            exit 1
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
            run_cmd "apt-get install -y build-essential libreadline-dev zlib1g-dev libssl-dev" \
                "Instalar dependências PostgreSQL"
            run_cmd "apt-get install -y curl wget git vim htop net-tools chrony" \
                "Instalar ferramentas adicionais"
            ;;
        centos|rhel)
            run_cmd "$PKG_UPDATE" "Atualizar repositórios"
            run_cmd "yum groupinstall -y 'Development Tools'" \
                "Instalar grupo Development Tools"
            run_cmd "yum install -y readline-devel zlib-devel openssl-devel" \
                "Instalar dependências PostgreSQL"
            run_cmd "yum install -y curl wget git vim htop net-tools chrony" \
                "Instalar ferramentas adicionais"
            ;;
    esac
    
    log_success "Pacotes básicos instalados"
}

# ============================================================================
# ADICIONAR REPOSITÓRIO POSTGRESQL OFICIAL
# ============================================================================

setup_postgresql_repo() {
    log_info "Configurando repositório PostgreSQL oficial..."
    
    case "$OS_ID" in
        ubuntu|debian)
            run_cmd "apt-get install -y postgresql-common" \
                "Instalar postgresql-common"
            run_cmd "/usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y" \
                "Configurar repositório PGDG"
            ;;
        centos|rhel)
            local repo_url="https://download.postgresql.org/pub/repos/yum/reporpms/EL-${OS_VERSION_ID}-x86_64/pgdg-redhat-repo-latest.noarch.rpm"
            run_cmd "yum install -y $repo_url" \
                "Instalar repositório PostgreSQL"
            ;;
    esac
    
    log_success "Repositório PostgreSQL configurado"
}

# ============================================================================
# INSTALAR POSTGRESQL
# ============================================================================

install_postgresql() {
    log_info "Instalando PostgreSQL $PG_VERSION..."
    
    case "$OS_ID" in
        ubuntu|debian)
            run_cmd "apt-get update" "Atualizar repositórios"
            run_cmd "apt-get install -y postgresql-$PG_VERSION postgresql-contrib-$PG_VERSION" \
                "Instalar PostgreSQL $PG_VERSION"
            run_cmd "apt-get install -y postgresql-$PG_VERSION-pg-stat-kcache" \
                "Instalar pg-stat-kcache"
            ;;
        centos|rhel)
            run_cmd "yum install -y postgresql${PG_VERSION}-server postgresql${PG_VERSION}-contrib" \
                "Instalar PostgreSQL $PG_VERSION"
            ;;
    esac
    
    log_success "PostgreSQL $PG_VERSION instalado"
}

# ============================================================================
# CRIAR USUÁRIO ZABBIX
# ============================================================================

create_zabbix_user() {
    log_info "Criando usuário PostgreSQL '$PG_USER'..."
    
    # Aguardar serviço iniciar
    sleep 3
    
    local create_user_sql="
        CREATE USER $PG_USER WITH PASSWORD 'PLACEHOLDER_PASSWORD';
        GRANT CONNECT ON DATABASE $PG_DB TO $PG_USER;
        GRANT USAGE ON SCHEMA public TO $PG_USER;
    "
    
    if ! run_cmd "echo '$create_user_sql' | sudo -u postgres psql" \
        "Criar usuário $PG_USER"; then
        log_warn "Usuário pode já existir"
    fi
    
    log_success "Usuário $PG_USER criado/verificado"
}

# ============================================================================
# CRIAR DATABASE ZABBIX
# ============================================================================

create_zabbix_database() {
    log_info "Criando database '$PG_DB'..."
    
    if ! run_cmd "sudo -u postgres createdb --owner=$PG_USER $PG_DB" \
        "Criar database $PG_DB"; then
        log_warn "Database pode já existir"
    fi
    
    # Criar extensões necessárias
    run_cmd "sudo -u postgres psql -d $PG_DB -c 'CREATE EXTENSION IF NOT EXISTS pg_stat_statements;'" \
        "Criar extensão pg_stat_statements"
    
    run_cmd "sudo -u postgres psql -d $PG_DB -c 'CREATE EXTENSION IF NOT EXISTS uuid-ossp;'" \
        "Criar extensão uuid-ossp"
    
    log_success "Database $PG_DB criado"
}

# ============================================================================
# CONFIGURAR POSTGRESQL.CONF
# ============================================================================

configure_postgresql() {
    log_info "Configurando postgresql.conf..."
    
    local pg_conf_file="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
    
    if [ ! -f "$pg_conf_file" ]; then
        log_error "Arquivo postgresql.conf não encontrado"
        return 1
    fi
    
    # Fazer backup
    run_cmd "cp $pg_conf_file ${pg_conf_file}.backup" \
        "Backup postgresql.conf"
    
    # Configurações recomendadas para Zabbix + 676 ativos
    local config_additions="
# Configurações para Zabbix
listen_addresses = '*'
port = $PG_PORT
max_connections = 200
shared_buffers = 24GB
effective_cache_size = 72GB
maintenance_work_mem = 6GB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
work_mem = 122880kB
min_wal_size = 2GB
max_wal_size = 8GB
shared_preload_libraries = 'pg_stat_statements'
log_statement = 'mod'
log_duration = off
timezone = '$TIMEZONE'
"
    
    echo "$config_additions" >> "$pg_conf_file"
    
    log_success "postgresql.conf configurado"
}

# ============================================================================
# CONFIGURAR PG_HBA.CONF
# ============================================================================

configure_pg_hba() {
    log_info "Configurando pg_hba.conf..."
    
    local pg_hba_file="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
    
    if [ ! -f "$pg_hba_file" ]; then
        log_error "Arquivo pg_hba.conf não encontrado"
        return 1
    fi
    
    # Fazer backup
    run_cmd "cp $pg_hba_file ${pg_hba_file}.backup" \
        "Backup pg_hba.conf"
    
    # Adicionar linhas de ACL (antes da última linha)
    local acl_lines="
# Zabbix Server
host    $PG_DB      $PG_USER    10.31.38.60/32  md5
# Zabbix Frontend
host    $PG_DB      $PG_USER    10.31.38.62/32  md5
# PostgreSQL local
local   $PG_DB      $PG_USER                    md5
"
    
    # Adicionar antes da linha "local   all     all     peer"
    if grep -q "^local.*all.*all.*peer" "$pg_hba_file"; then
        sed -i "/^local.*all.*all.*peer/i\\$acl_lines" "$pg_hba_file"
    else
        echo "$acl_lines" >> "$pg_hba_file"
    fi
    
    log_success "pg_hba.conf configurado"
}

# ============================================================================
# INICIAR SERVIÇO POSTGRESQL
# ============================================================================

start_postgresql_service() {
    log_info "Iniciando serviço PostgreSQL..."
    
    run_cmd "systemctl restart postgresql" \
        "Reiniciar PostgreSQL"
    
    run_cmd "systemctl enable postgresql" \
        "Habilitar PostgreSQL auto-start"
    
    # Aguardar inicialização
    sleep 5
    
    # Verificar se serviço está rodando
    if systemctl is-active --quiet postgresql; then
        log_success "PostgreSQL iniciado com sucesso"
        return 0
    else
        log_error "PostgreSQL falhou ao iniciar"
        systemctl status postgresql >> "$LOG_FILE"
        return 1
    fi
}

# ============================================================================
# CONFIGURAR BACKUP COM PGBACKREST
# ============================================================================

setup_backup() {
    log_info "Configurando backup com pgBackRest..."
    
    # Instalar pgBackRest
    case "$OS_ID" in
        ubuntu|debian)
            run_cmd "apt-get install -y pgbackrest" \
                "Instalar pgBackRest"
            ;;
        centos|rhel)
            run_cmd "yum install -y pgbackrest" \
                "Instalar pgBackRest"
            ;;
    esac
    
    # Criar diretório de backup
    run_cmd "mkdir -p $PG_BACKUP_PATH" \
        "Criar diretório de backup"
    
    run_cmd "chown postgres:postgres $PG_BACKUP_PATH" \
        "Configurar permissões do diretório"
    
    run_cmd "chmod 700 $PG_BACKUP_PATH" \
        "Restringir acesso ao diretório"
    
    # Criar configuração pgBackRest
    local pgbackrest_conf="/etc/pgbackrest.conf"
    cat > "$pgbackrest_conf" << 'EOF'
[global]
repo1-path=/backups/postgresql
repo1-retention-full=7

[PostgreSQL]
pg1-path=/var/lib/postgresql/16/main
EOF
    
    run_cmd "chmod 640 $pgbackrest_conf" \
        "Configurar permissões pgbackrest.conf"
    
    # Criar backup inicial
    log_info "Criando backup inicial (pode levar alguns minutos)..."
    if run_cmd "sudo -u postgres pgbackrest stanza-create --stanza=PostgreSQL" \
        "Criar stanza pgBackRest"; then
        run_cmd "sudo -u postgres pgbackrest backup --stanza=PostgreSQL" \
            "Criar backup inicial"
    fi
    
    log_success "pgBackRest configurado"
}

# ============================================================================
# CONFIGURAR FIREWALL
# ============================================================================

configure_firewall() {
    log_info "Configurando firewall..."
    
    case "$OS_ID" in
        ubuntu|debian)
            if command -v ufw &> /dev/null; then
                run_cmd "ufw allow 5432/tcp" \
                    "Permitir porta 5432 (UFW)"
            fi
            ;;
        centos|rhel)
            if systemctl is-active --quiet firewalld; then
                run_cmd "firewall-cmd --permanent --add-port=5432/tcp" \
                    "Permitir porta 5432 (firewalld)"
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
    
    # Verificar se PostgreSQL está rodando
    if ! systemctl is-active --quiet postgresql; then
        log_error "PostgreSQL não está rodando"
        ((errors++))
    else
        log_success "PostgreSQL está rodando"
    fi
    
    # Verificar conexão local
    if ! sudo -u postgres psql -c "SELECT 1" > /dev/null 2>&1; then
        log_error "Falha ao conectar no PostgreSQL local"
        ((errors++))
    else
        log_success "Conexão PostgreSQL local OK"
    fi
    
    # Verificar database zabbix
    if ! sudo -u postgres psql -lqt | cut -d\| -f 1 | grep -qw "$PG_DB"; then
        log_error "Database $PG_DB não existe"
        ((errors++))
    else
        log_success "Database $PG_DB existe"
    fi
    
    # Verificar usuário zabbix
    if ! sudo -u postgres psql -t -c "SELECT usename FROM pg_user WHERE usename = '$PG_USER'" | grep -q "$PG_USER"; then
        log_error "Usuário $PG_USER não existe"
        ((errors++))
    else
        log_success "Usuário $PG_USER existe"
    fi
    
    # Verificar porta
    if ! netstat -tlnap 2>/dev/null | grep -q ":5432"; then
        log_error "PostgreSQL não está escutando na porta 5432"
        ((errors++))
    else
        log_success "PostgreSQL escutando na porta 5432"
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
    log_info "INSTALAÇÃO POSTGRESQL 16 - INICIADO"
    log_info "=========================================="
    log_info "SO: $OS_NAME"
    log_info "PostgreSQL Versão: $PG_VERSION"
    log_info "Data: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Log: $LOG_FILE"
    
    # Executar etapas
    check_prerequisites || exit 1
    install_base_packages || exit 1
    setup_postgresql_repo || exit 1
    install_postgresql || exit 1
    start_postgresql_service || exit 1
    configure_postgresql || exit 1
    configure_pg_hba || exit 1
    create_zabbix_database || exit 1
    create_zabbix_user || exit 1
    setup_backup || exit 1
    configure_firewall || exit 1
    
    # Reiniciar para aplicar configurações
    log_info "Reiniciando PostgreSQL para aplicar configurações..."
    systemctl restart postgresql
    sleep 5
    
    # Validar
    if validate_installation; then
        log_success "=========================================="
        log_success "INSTALAÇÃO POSTGRESQL CONCLUÍDA COM SUCESSO"
        log_success "=========================================="
        log_info "Próximo passo: Instalar Zabbix Server"
        log_info "Para definir senha do usuário zabbix:"
        log_info "  sudo -u postgres psql"
        log_info "  ALTER USER $PG_USER WITH PASSWORD 'sua_senha';"
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
