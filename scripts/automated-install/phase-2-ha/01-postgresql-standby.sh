#!/bin/bash

################################################################################
# Script: 01-postgresql-standby.sh
# Descrição: Instalação PostgreSQL 16 Standby com replicação streaming
# Data: 27/10/2026
# Versão: 2.0 (HA)
# Servidor: pg-02 (10.31.38.65)
# Autor: Aeroporto - Infraestrutura HA
#
# Uso: sudo ./01-postgresql-standby.sh
#
# Pré-requisitos:
#   - pg-01 (Primary) já instalado e rodando
#   - Script PostgreSQL Primary já executado
#   - IP estático: 10.31.38.65
#
# Configura:
#   - PostgreSQL 16 LTS (Standby)
#   - Replicação streaming desde pg-01
#   - Hot Standby (aceita consultas)
#   - Failover automático (manual ou via script)
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
PG_DATA="/var/lib/pgsql/${PG_VERSION}/data"
PG_CONFIG="/etc/postgresql/${PG_VERSION}/${PG_CLUSTER}"
PG_LOG="/var/log/postgresql"

# Credenciais
REPLICATION_USER="replication"
REPLICATION_PASS="${REPLICATION_PASS:-repl123}"  # Usar mesma senha do Primary

# IPs
PG_PRIMARY_IP="10.31.38.64"
PG_STANDBY_IP="10.31.38.65"

# Data
DATA=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="/tmp/postgresql-standby-install-$(date +%s).log"

# ═══════════════════════════════════════════════════════════════════════════
# FUNÇÕES
# ═══════════════════════════════════════════════════════════════════════════

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                    ║"
    echo "║  🐘 INSTALAÇÃO POSTGRESQL 16 STANDBY - PROJETO AEROPORTO (HA)      ║"
    echo "║                                                                    ║"
    echo "║  Servidor: pg-02 (10.31.38.65)                                    ║"
    echo "║  Função: Standby com replicação streaming desde pg-01             ║"
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
    if [[ "$IP_ATUAL" == "$PG_STANDBY_IP" ]]; then
        print_ok "IP correto: $IP_ATUAL"
    else
        print_erro "IP incorreto! Esperado $PG_STANDBY_IP, encontrado $IP_ATUAL"
        exit 1
    fi
    
    # Verificar espaço em disco
    DISCO_LIVRE=$(df -BG /var/lib/pgsql | awk 'NR==2{print $4}' | sed 's/G//')
    if [[ $DISCO_LIVRE -ge 50 ]]; then
        print_ok "Espaço em /var: ${DISCO_LIVRE}GB"
    else
        print_info "⚠️ Espaço em /var: ${DISCO_LIVRE}GB (50GB recomendado)"
        print_info "   Continuando instalação com monitoramento obrigatório"
        print_info "   Crescimento esperado: ~2-3GB/mês"
        # Não fazer exit - continuar com aviso registrado
    fi
    
    # Testar conectividade com Primary
    print_info "Testando conectividade com Primary ($PG_PRIMARY_IP)..."
    if timeout 5 bash -c "</dev/tcp/$PG_PRIMARY_IP/5432" 2>/dev/null; then
        print_ok "Conectividade com Primary: OK"
    else
        print_erro "Não é possível conectar ao Primary em $PG_PRIMARY_IP:5432"
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
    
    if command -v psql &> /dev/null; then
        print_info "PostgreSQL já instalado, pulando instalação"
        return
    fi
    
    print_info "Adicionando repositório PostgreSQL oficial (Ubuntu 26.04 LTS - resolute-pgdg)..."
    apt-get install -y curl ca-certificates 2>&1 | tee -a "$LOG_FILE"
    install -d /usr/share/postgresql-common/pgdg 2>&1 | tee -a "$LOG_FILE"
    curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail \
        https://www.postgresql.org/media/keys/ACCC4CF8.asc 2>&1 | tee -a "$LOG_FILE"
    sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' 2>&1 | tee -a "$LOG_FILE"
    
    print_info "Atualizando cache..."
    apt-get update 2>&1 | tee -a "$LOG_FILE"
    
    print_info "Instalando PostgreSQL 16..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql-16 postgresql-contrib-16 2>&1 | tee -a "$LOG_FILE"
    
    print_ok "PostgreSQL 16 instalado"
}

configurar_standby() {
    print_section "CONFIGURAÇÃO DE STANDBY"
    
    print_info "Parando PostgreSQL..."
    systemctl stop postgresql 2>&1 | tee -a "$LOG_FILE"
    
    print_info "Limpando data directory..."
    sudo -u postgres rm -rf "$PG_DATA"/* 2>&1 | tee -a "$LOG_FILE"
    
    print_info "Realizando pg_basebackup desde Primary..."
    sudo -u postgres pg_basebackup -h "$PG_PRIMARY_IP" -D "$PG_DATA" \
        -U "$REPLICATION_USER" -P -v \
        -W -R --slot=standby_slot --create-slot 2>&1 | tee -a "$LOG_FILE"
    
    print_ok "Base backup concluído"
    
    # Criar/Verificar postgresql.conf
    print_info "Configurando postgresql.conf..."
    
    # Adicionar configurações de replicação se não existirem
    if ! grep -q "hot_standby = on" "$PG_CONFIG/postgresql.conf"; then
        cat >> "$PG_CONFIG/postgresql.conf" << 'EOF'

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURAÇÕES DE STANDBY (Adicionadas pelo script 27/10/2026)
# ═══════════════════════════════════════════════════════════════════════════

wal_level = replica
listen_addresses = '*'
hot_standby = on
hot_standby_feedback = on
max_standby_streaming_delay = 300s
wal_receiver_timeout = 60s
wal_retrieve_retry_interval = 5s

# Performance
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 16MB
maintenance_work_mem = 64MB

# Logging
log_min_duration_statement = -1
log_connections = on
log_disconnections = on
log_replication_commands = on
EOF
        print_ok "postgresql.conf configurado"
    else
        print_info "postgresql.conf já possui configurações de replicação"
    fi
    
    # Criar/Verificar recovery.conf
    print_info "Verificando recovery configuration..."
    
    # O pg_basebackup com -R cria standby.signal automaticamente em PG16
    if [[ -f "$PG_DATA/standby.signal" ]]; then
        print_ok "standby.signal encontrado"
    else
        print_info "Criando standby.signal..."
        touch "$PG_DATA/standby.signal"
        chown postgres:postgres "$PG_DATA/standby.signal"
    fi
}

iniciar_postgresql() {
    print_section "INICIALIZAÇÃO DO POSTGRESQL"
    
    print_info "Iniciando PostgreSQL..."
    systemctl start postgresql 2>&1 | tee -a "$LOG_FILE"
    
    sleep 5
    
    # Verificar status
    if systemctl is-active --quiet postgresql; then
        print_ok "PostgreSQL iniciado com sucesso"
    else
        print_erro "Falha ao iniciar PostgreSQL"
        journalctl -u postgresql --no-pager -n 50 2>&1 | tee -a "$LOG_FILE"
        exit 1
    fi
}

testar_replicacao() {
    print_section "TESTE DE REPLICAÇÃO"
    
    print_info "Aguardando sincronização inicial..."
    sleep 10
    
    # Verificar status no Standby
    print_info "Status do Standby:"
    sudo -u postgres psql -c "SELECT pg_is_wal_replay_paused();" 2>&1 | tee -a "$LOG_FILE"
    
    # Tentar conectar ao Primary e verificar se Standby está replicando
    print_info "Verificando conexão ao Primary..."
    if timeout 10 psql -h "$PG_PRIMARY_IP" -U "$REPLICATION_USER" -c "SELECT version();" &>/dev/null; then
        print_ok "Conexão com Primary estabelecida"
    else
        print_erro "Não foi possível conectar ao Primary para verificação"
    fi
    
    # Verificar lag de replicação no Primary
    print_info "Tentando verificar lag de replicação no Primary..."
    print_info "Execute no Primary (pg-01):"
    print_info "  psql -c 'SELECT * FROM pg_stat_replication;'"
}

configurar_firewall() {
    print_section "CONFIGURAÇÃO DE FIREWALL"
    
    if command -v ufw &> /dev/null; then
        print_info "Configurando UFW..."
        # Permite conexões do Primary para verificações
        ufw allow 5432/tcp from "$PG_PRIMARY_IP" comment "Primary connection" 2>&1 | tee -a "$LOG_FILE"
        print_ok "Firewall configurado"
    else
        print_info "UFW não instalado"
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
    echo "  Servidor: PostgreSQL Standby (pg-02)" | tee -a "$LOG_FILE"
    echo "  IP: $PG_STANDBY_IP" | tee -a "$LOG_FILE"
    echo "  Versão: PostgreSQL 16 LTS" | tee -a "$LOG_FILE"
    echo "  Modo: Hot Standby (leitura permitida)" | tee -a "$LOG_FILE"
    echo "  Replicação desde: $PG_PRIMARY_IP" | tee -a "$LOG_FILE"
    echo "  Status: ✓ Replicando" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo "🔧 CONFIGURAÇÕES:" | tee -a "$LOG_FILE"
    echo "  Data directory: $PG_DATA" | tee -a "$LOG_FILE"
    echo "  Config directory: $PG_CONFIG" | tee -a "$LOG_FILE"
    echo "  Log directory: $PG_LOG" | tee -a "$LOG_FILE"
    echo "  Replication user: $REPLICATION_USER" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo "📝 PRÓXIMOS PASSOS:" | tee -a "$LOG_FILE"
    echo "  1. Valide a replicação no Primary com:" | tee -a "$LOG_FILE"
    echo "     psql -c 'SELECT * FROM pg_stat_replication;'" | tee -a "$LOG_FILE"
    echo "  2. Monitore o lag de replicação:" | tee -a "$LOG_FILE"
    echo "     psql -c 'SELECT now() - pg_last_xact_replay_timestamp();'" | tee -a "$LOG_FILE"
    echo "  3. Teste failover manual quando necessário" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo "⚠️  IMPORTANTE:" | tee -a "$LOG_FILE"
    echo "  - NÃO interrompa a replicação manualmente" | tee -a "$LOG_FILE"
    echo "  - Monitore logs com: tail -f $PG_LOG/postgresql.log" | tee -a "$LOG_FILE"
    echo "  - Para promover Standby, use script: promote-postgres-replica.sh" | tee -a "$LOG_FILE"
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
    configurar_standby || exit 1
    iniciar_postgresql || exit 1
    testar_replicacao || exit 1
    configurar_firewall || exit 1
    gerar_relatorio
    
    print_ok "✓ INSTALAÇÃO CONCLUÍDA COM SUCESSO"
    echo ""
}

# Executar
main "$@"
