#!/bin/bash

################################################################################
#  VALIDAÇÃO PÓS-INSTALAÇÃO - ZABBIX SERVER 7.0                               #
#  Verifica funcionamento completo do Zabbix Server                            #
################################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configurações
PG_HOST="${PG_HOST:-10.31.38.64}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-zabbix}"
PG_DB="${PG_DB:-zabbix}"
SERVER_PORT="${SERVER_PORT:-10051}"
ERRORS=0
WARNINGS=0

log_pass() { echo -e "${GREEN}[✓]${NC} $*"; }
log_fail() { echo -e "${RED}[✗]${NC} $*"; ((ERRORS++)); }
log_warn() { echo -e "${YELLOW}[⚠]${NC} $*"; ((WARNINGS++)); }
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }

main() {
    log_info "Validação Zabbix Server 7.0 - Iniciada"
    echo "=================================================="
    
    # 1. Verificar serviço
    if systemctl is-active --quiet zabbix-server; then
        log_pass "Zabbix Server serviço ativo"
    else
        log_fail "Zabbix Server serviço inativo"
    fi
    
    # 2. Verificar Agent2
    if systemctl is-active --quiet zabbix-agent2; then
        log_pass "Zabbix Agent 2 serviço ativo"
    else
        log_fail "Zabbix Agent 2 serviço inativo"
    fi
    
    # 3. Verificar porta
    if netstat -tlnap 2>/dev/null | grep -q ":$SERVER_PORT" || ss -tlnap 2>/dev/null | grep -q ":$SERVER_PORT"; then
        log_pass "Zabbix Server escutando na porta $SERVER_PORT"
    else
        log_fail "Zabbix Server não escuta na porta $SERVER_PORT"
    fi
    
    # 4. Verificar conectividade PostgreSQL
    if psql -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" -c "SELECT 1" > /dev/null 2>&1; then
        log_pass "Conectividade PostgreSQL OK"
    else
        log_fail "Falha ao conectar no PostgreSQL"
    fi
    
    # 5. Verificar tabelas Zabbix
    if psql -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" -c "\dt" | grep -q "history"; then
        log_pass "Tabelas Zabbix encontradas"
    else
        log_fail "Tabelas Zabbix não encontradas"
    fi
    
    # 6. Verificar arquivo de log
    if [ -f /var/log/zabbix/zabbix_server.log ]; then
        log_pass "Arquivo de log existe"
        # Verificar erros nos últimos 5 min
        if tail -100 /var/log/zabbix/zabbix_server.log | grep -i "error\|failed" > /dev/null; then
            log_warn "Erros detectados no log"
        else
            log_pass "Nenhum erro recente no log"
        fi
    else
        log_fail "Arquivo de log não encontrado"
    fi
    
    # 7. Verificar configuração
    if grep -q "^DBHost=$PG_HOST" /etc/zabbix/zabbix_server.conf; then
        log_pass "Configuração PostgreSQL OK"
    else
        log_warn "Configuração PostgreSQL pode estar incorreta"
    fi
    
    # 8. Verificar diretórios
    if [ -d /var/lib/zabbix/alertscripts ] && [ -d /var/lib/zabbix/externalscripts ]; then
        log_pass "Diretórios Zabbix OK"
    else
        log_fail "Diretórios Zabbix não encontrados"
    fi
    
    # 9. Verificar espaço em disco
    local disk_free=$(df /var | awk 'NR==2 {print $4}')
    if [ "$disk_free" -gt 10485760 ]; then
        log_pass "Espaço em disco OK: $((disk_free / 1048576)) GB"
    else
        log_warn "Espaço em disco baixo: $((disk_free / 1048576)) GB"
    fi
    
    # 10. Verificar permissões
    if [ -O /var/log/zabbix ] && [ -O /var/lib/zabbix ]; then
        log_pass "Permissões OK"
    else
        log_warn "Permissões podem estar incorretas"
    fi
    
    echo "=================================================="
    log_info "Validação concluída"
    log_info "Erros: $ERRORS | Avisos: $WARNINGS"
    
    [ $ERRORS -eq 0 ] && log_pass "VALIDAÇÃO PASSOU" || log_fail "VALIDAÇÃO FALHOU"
    exit $ERRORS
}

main "$@"
