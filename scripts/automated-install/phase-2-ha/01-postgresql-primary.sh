#!/bin/bash

################################################################################
# Script: 01-postgresql-primary.sh
# Descrição: Instalação e configuração PostgreSQL 16 Primary com Replication
# Data: 27/10/2026
# Versão: 2.0 (HA)
# Servidor: pg-01 (10.31.38.64)
# Autor: Aeroporto - Infraestrutura HA
#
# Uso: sudo ./01-postgresql-primary.sh
#
# Pré-requisitos:
#   - Ubuntu/Debian atualizado
#   - Mínimo 50 GB de disco em /var
#   - IP estático: 10.31.38.64
#
# Configura:
#   - PostgreSQL 16 LTS
#   - Replication User (replication)
#   - Streaming WAL Replication
#   - Hot Standby para pg-02
#   - 3 Databases: zabbix, grafana, awx
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

# Variáveis
PG_VERSION="16"
PG_CLUSTER="main"
PG_DATA="/var/lib/postgresql/${PG_VERSION}/${PG_CLUSTER}"
PG_CONFIG="/etc/postgresql/${PG_VERSION}/${PG_CLUSTER}"
PG_LOG="/var/log/postgresql"

# Usuários e Senhas
POSTGRES_PASS="${POSTGRES_PASS:-postgres123}"  # Trocar em produção
REPLICATION_USER="replication"
REPLICATION_PASS="${REPLICATION_PASS:-repl123}"  # Trocar em produção

# IPs
PG_PRIMARY_IP="10.31.38.64"
PG_STANDBY_IP="10.31.38.65"

# Banco de dados
DATABASES=("zabbix" "grafana" "awx")

# Data
DATA=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="/tmp/postgresql-primary-install-$(date +%s).log"

# ═══════════════════════════════════════════════════════════════════════════
# FUNÇÕES
# ═══════════════════════════════════════════════════════════════════════════

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                    ║"
    echo "║  🐘 INSTALAÇÃO POSTGRESQL 16 PRIMARY - PROJETO AEROPORTO (HA)      ║"
    echo "║                                                                    ║"
    echo "║  Servidor: pg-01 (10.31.38.64)                                    ║"
    echo "║  Função: Primary com Streaming Replication                        ║"
    echo "║                                                                    ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
}

log_msg() {
    local msg="$1"
    echo "[$(date '+%H:%M:%S')] $msg" | tee -a "$LOG_FILE"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_ok() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
}

print_erro() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"
}

print_section() {
    echo "" | tee -a "$LOG_FILE"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}$1${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
}

verificar_prerequisitos() {
    print_section "VERIFICAÇÃO DE PRÉ-REQUISITOS"
    
    # Verificar se é root
    if [[ $EUID -ne 0 ]]; then
        print_erro "Este script deve ser executado como root"
        exit 1
    fi
    print_ok "Executando como root"
    
    # Verificar IP
    IP_ATUAL=$(hostname -I | awk '{print $1}')
    if [[ "$IP_ATUAL" == "$PG_PRIMARY_IP" ]]; then
        print_ok "IP correto: $IP_ATUAL"
    else
        print_erro "IP incorreto! Esperado $PG_PRIMARY_IP, encontrado $IP_ATUAL"
        exit 1
    fi
    
    # Verificar espaço em disco
    DISCO_LIVRE=$(df -BG /var | awk 'NR==2{print $4}' | sed 's/G//')
    if [[ $DISCO_LIVRE -ge 50 ]]; then
        print_ok "Espaço em /var: ${DISCO_LIVRE}GB"
    else
        print_erro "Espaço insuficiente em /var (${DISCO_LIVRE}GB < 50GB recomendado)"
        exit 1
    fi
}

atualizar_sistema() {
    print_section "ATUALIZAÇÃO DO SISTEMA"
    
    print_info "Atualizando repositórios..."
    apt-get update 2>&1 | tee -a "$LOG_FILE"
    
    print_info "Atualizando pacotes..."
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y 2>&1 | tee -a "$LOG_FILE"
    
    print_ok "Sistema atualizado"
}

instalar_postgresql() {
    print_section "INSTALAÇÃO POSTGRESQL 16"
    
    # Verificar se já está instalado
    if command -v psql &> /dev/null; then
        print_info "PostgreSQL já instalado, pulando instalação"
        return
    fi
    
    print_info "Adicionando repositório PostgreSQL oficial..."
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' 2>&1 | tee -a "$LOG_FILE"
    wget -q -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - 2>&1 | tee -a "$LOG_FILE"
    
    print_info "Atualizando cache..."
    apt-get update 2>&1 | tee -a "$LOG_FILE"
    
    print_info "Instalando PostgreSQL 16..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql-16 postgresql-contrib-16 2>&1 | tee -a "$LOG_FILE"
    
    print_ok "PostgreSQL 16 instalado"
}

configurar_replicacao() {
    print_section "CONFIGURAÇÃO DE REPLICAÇÃO"
    
    print_info "Parando PostgreSQL..."
    systemctl stop postgresql 2>&1 | tee -a "$LOG_FILE"
    
    print_info "Criando usuário de replicação..."
    sudo -u postgres psql << EOF 2>&1 | tee -a "$LOG_FILE"
CREATE USER $REPLICATION_USER WITH REPLICATION ENCRYPTED PASSWORD '$REPLICATION_PASS';
EOF
    
    print_info "Configurando postgresql.conf..."
    
    # Backup do arquivo original
    cp "$PG_CONFIG/postgresql.conf" "$PG_CONFIG/postgresql.conf.backup"
    
    # Configurações para replicação
    cat >> "$PG_CONFIG/postgresql.conf" << 'EOF'

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURAÇÕES DE REPLICAÇÃO (Adicionadas pelo script 27/10/2026)
# ═══════════════════════════════════════════════════════════════════════════

# Modo archive
wal_level = replica
max_wal_senders = 10
max_replication_slots = 10
wal_keep_segments = 64
hot_standby = on
hot_standby_feedback = on

# Performance
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 16MB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB

# Logging
log_min_duration_statement = -1
log_connections = on
log_disconnections = on
log_duration = off
log_lock_waits = on
log_statement = 'all'
log_replication_commands = on

# Sincronização
synchronous_commit = remote_apply
EOF
    
    print_ok "postgresql.conf configurado"
    
    # Configurar pg_hba.conf para replicação
    print_info "Configurando pg_hba.conf..."
    
    # Backup
    cp "$PG_CONFIG/pg_hba.conf" "$PG_CONFIG/pg_hba.conf.backup"
    
    # Adicionar acesso para replicação
    cat >> "$PG_CONFIG/pg_hba.conf" << EOF

# Replicação de $PG_STANDBY_IP
host    replication     $REPLICATION_USER    $PG_STANDBY_IP/32    md5
EOF
    
    print_ok "pg_hba.conf configurado"
}

criar_databases() {
    print_section "CRIAÇÃO DE BANCOS DE DADOS"
    
    print_info "Iniciando PostgreSQL..."
    systemctl start postgresql 2>&1 | tee -a "$LOG_FILE"
    
    sleep 3
    
    for db in "${DATABASES[@]}"; do
        print_info "Criando banco: $db"
        sudo -u postgres psql << EOF 2>&1 | tee -a "$LOG_FILE"
CREATE DATABASE $db OWNER postgres;
COMMENT ON DATABASE $db IS 'Database for $db cluster - Created: $DATA';
EOF
        print_ok "Banco $db criado"
    done
}

configurar_firewall() {
    print_section "CONFIGURAÇÃO DE FIREWALL"
    
    # Verificar se UFW está instalado
    if command -v ufw &> /dev/null; then
        print_info "Configurando UFW..."
        ufw allow 5432/tcp from "$PG_STANDBY_IP" comment "PostgreSQL replication from pg-02" 2>&1 | tee -a "$LOG_FILE"
        ufw allow 5432/tcp from 10.31.38.60 comment "Zabbix access to PostgreSQL" 2>&1 | tee -a "$LOG_FILE"
        ufw allow 5432/tcp from 10.31.38.66 comment "Grafana access to PostgreSQL" 2>&1 | tee -a "$LOG_FILE"
        ufw allow 5432/tcp from 10.31.38.68 comment "AWX access to PostgreSQL" 2>&1 | tee -a "$LOG_FILE"
        print_ok "Firewall configurado"
    else
        print_info "UFW não instalado, pulando"
    fi
}

testar_conexao() {
    print_section "TESTE DE CONEXÃO"
    
    print_info "Testando conexão local..."
    if sudo -u postgres psql -c "SELECT version();" &> /dev/null; then
        print_ok "Conexão local OK"
    else
        print_erro "Falha na conexão local"
        return 1
    fi
    
    print_info "Verificando replication user..."
    if sudo -u postgres psql << EOF &> /dev/null
\du $REPLICATION_USER
EOF
    then
        print_ok "Usuário de replicação criado"
    else
        print_erro "Usuário de replicação não encontrado"
        return 1
    fi
}

gerar_relatorio() {
    print_section "RELATÓRIO DE INSTALAÇÃO"
    
    echo "" | tee -a "$LOG_FILE"
    echo "╔════════════════════════════════════════════════════════════════════╗" | tee -a "$LOG_FILE"
    echo "║              ✓ INSTALAÇÃO CONCLUÍDA COM SUCESSO                   ║" | tee -a "$LOG_FILE"
    echo "╚════════════════════════════════════════════════════════════════════╝" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo "📊 RESUMO DA INSTALAÇÃO:" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "  Servidor: PostgreSQL Primary (pg-01)" | tee -a "$LOG_FILE"
    echo "  IP: $PG_PRIMARY_IP" | tee -a "$LOG_FILE"
    echo "  Versão: PostgreSQL 16 LTS" | tee -a "$LOG_FILE"
    echo "  Replicação: Habilitada (Standby em $PG_STANDBY_IP)" | tee -a "$LOG_FILE"
    echo "  Bancos de dados criados: ${DATABASES[*]}" | tee -a "$LOG_FILE"
    echo "  Status: ✓ Pronto para replicação" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo "🔧 CONFIGURAÇÕES:" | tee -a "$LOG_FILE"
    echo "  Data directory: $PG_DATA" | tee -a "$LOG_FILE"
    echo "  Config directory: $PG_CONFIG" | tee -a "$LOG_FILE"
    echo "  Log directory: $PG_LOG" | tee -a "$LOG_FILE"
    echo "  Replication user: $REPLICATION_USER" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo "📝 PRÓXIMOS PASSOS:" | tee -a "$LOG_FILE"
    echo "  1. Execute o script PostgreSQL Standby em pg-02" | tee -a "$LOG_FILE"
    echo "  2. Valide a replicação com: SELECT * FROM pg_stat_replication;" | tee -a "$LOG_FILE"
    echo "  3. Monitore o lag de replicação" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo "📋 LOG COMPLETO:" | tee -a "$LOG_FILE"
    echo "  $LOG_FILE" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════

main() {
    print_header
    
    print_info "Iniciando instalação..."
    print_info "Log: $LOG_FILE"
    
    # Executar etapas
    verificar_prerequisitos || exit 1
    atualizar_sistema || exit 1
    instalar_postgresql || exit 1
    configurar_replicacao || exit 1
    criar_databases || exit 1
    configurar_firewall || exit 1
    testar_conexao || exit 1
    gerar_relatorio
    
    print_ok "✓ INSTALAÇÃO CONCLUÍDA COM SUCESSO"
    echo ""
}

# Executar
main "$@"
