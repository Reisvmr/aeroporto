#!/bin/bash

################################################################################
#  VALIDAÇÃO PÓS-INSTALAÇÃO - POSTGRESQL 16                                   #
#  Verifica funcionamento completo do PostgreSQL Primary                       #
################################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configurações
PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-zabbix}"
PG_DB="${PG_DB:-zabbix}"
ERRORS=0
WARNINGS=0

log_pass() { echo -e "${GREEN}[✓]${NC} $*"; }
log_fail() { echo -e "${RED}[✗]${NC} $*"; ((ERRORS++)); }
log_warn() { echo -e "${YELLOW}[⚠]${NC} $*"; ((WARNINGS++)); }
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }

main() {
    log_info "Validação PostgreSQL 16 - Iniciada"
    echo "=================================================="
    
    # 1. Verificar serviço
    if systemctl is-active --quiet postgresql; then
        log_pass "PostgreSQL serviço ativo"
    else
        log_fail "PostgreSQL serviço inativo"
    fi
    
    # 2. Verificar porta
    if netstat -tlnap 2>/dev/null | grep -q ":5432" || ss -tlnap 2>/dev/null | grep -q ":5432"; then
        log_pass "PostgreSQL escutando na porta 5432"
    else
        log_fail "PostgreSQL não escuta na porta 5432"
    fi
    
    # 3. Conectar localmente
    if sudo -u postgres psql -c "SELECT 1" > /dev/null 2>&1; then
        log_pass "Conexão local PostgreSQL OK"
    else
        log_fail "Falha ao conectar localmente"
    fi
    
    # 4. Verificar database zabbix
    if sudo -u postgres psql -lqt | cut -d\| -f 1 | grep -qw "$PG_DB"; then
        log_pass "Database '$PG_DB' existe"
    else
        log_fail "Database '$PG_DB' não existe"
    fi
    
    # 5. Verificar usuário zabbix
    if sudo -u postgres psql -t -c "SELECT usename FROM pg_user WHERE usename = '$PG_USER'" | grep -q "$PG_USER"; then
        log_pass "Usuário '$PG_USER' existe"
    else
        log_fail "Usuário '$PG_USER' não existe"
    fi
    
    # 6. Verificar extensões
    if sudo -u postgres psql -d "$PG_DB" -c "\dx" | grep -q "pg_stat_statements"; then
        log_pass "Extensão pg_stat_statements instalada"
    else
        log_warn "Extensão pg_stat_statements não instalada"
    fi
    
    # 7. Verificar espaço em disco
    local disk_free=$(df /var/lib/postgresql | awk 'NR==2 {print $4}')
    if [ "$disk_free" -gt 5242880 ]; then
        log_pass "Espaço em disco OK: $((disk_free / 1048576)) GB"
    else
        log_warn "Espaço em disco baixo: $((disk_free / 1048576)) GB"
    fi
    
    # 8. Verificar backup
    if [ -d /backups/postgresql ] && ls /backups/postgresql/*.backup > /dev/null 2>&1; then
        log_pass "Backups encontrados"
    else
        log_warn "Nenhum backup encontrado"
    fi
    
    # 9. Verificar arquivo de log
    if [ -f /var/log/postgresql/postgresql.log ] || [ -f /var/log/postgresql/*.log ]; then
        log_pass "Arquivo de log PostgreSQL existe"
    else
        log_warn "Arquivo de log PostgreSQL não encontrado"
    fi
    
    # 10. Verificar configuração
    if grep -q "^listen_addresses = '\*'" /etc/postgresql/*/main/postgresql.conf; then
        log_pass "Listen addresses configurado para '*'"
    else
        log_warn "Listen addresses pode não estar correto"
    fi
    
    echo "=================================================="
    log_info "Validação concluída"
    log_info "Erros: $ERRORS | Avisos: $WARNINGS"
    
    [ $ERRORS -eq 0 ] && log_pass "VALIDAÇÃO PASSOU" || log_fail "VALIDAÇÃO FALHOU"
    exit $ERRORS
}

main "$@"
