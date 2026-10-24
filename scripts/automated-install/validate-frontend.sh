#!/bin/bash

################################################################################
#  VALIDAÇÃO PÓS-INSTALAÇÃO - ZABBIX FRONTEND 7.0                             #
#  Verifica funcionamento completo do Zabbix Frontend                          #
################################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configurações
ZABBIX_SERVER="${ZABBIX_SERVER:-10.31.38.60}"
ZABBIX_SERVER_PORT="${ZABBIX_SERVER_PORT:-10051}"
PG_HOST="${PG_HOST:-10.31.38.64}"
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
    log_info "Validação Zabbix Frontend 7.0 - Iniciada"
    echo "=================================================="
    
    # 1. Verificar Nginx
    if systemctl is-active --quiet nginx; then
        log_pass "Nginx serviço ativo"
    else
        log_fail "Nginx serviço inativo"
    fi
    
    # 2. Verificar PHP-FPM
    if systemctl is-active --quiet php-fpm; then
        log_pass "PHP-FPM serviço ativo"
    else
        log_fail "PHP-FPM serviço inativo"
    fi
    
    # 3. Verificar porta HTTP
    if netstat -tlnap 2>/dev/null | grep -q ":80" || ss -tlnap 2>/dev/null | grep -q ":80"; then
        log_pass "Nginx escutando na porta 80"
    else
        log_fail "Nginx não escuta na porta 80"
    fi
    
    # 4. Conectividade HTTP
    if curl -s -o /dev/null -w "%{http_code}" http://localhost/ | grep -q "^[2345]"; then
        log_pass "Frontend HTTP respondendo"
    else
        log_warn "Frontend HTTP pode não estar respondendo"
    fi
    
    # 5. Verificar diretório Frontend
    if [ -d /usr/share/zabbix ]; then
        log_pass "Diretório Zabbix Frontend existe"
        if [ -f /usr/share/zabbix/index.php ]; then
            log_pass "Arquivo index.php existe"
        else
            log_fail "Arquivo index.php não encontrado"
        fi
    else
        log_fail "Diretório Frontend não existe"
    fi
    
    # 6. Verificar configuração Zabbix
    if [ -f /etc/zabbix/web/zabbix.conf.php ]; then
        log_pass "Configuração zabbix.conf.php existe"
    else
        log_fail "zabbix.conf.php não encontrado"
    fi
    
    # 7. Conectividade PostgreSQL
    if psql -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" -c "SELECT 1" > /dev/null 2>&1; then
        log_pass "Conectividade PostgreSQL OK"
    else
        log_fail "Falha ao conectar no PostgreSQL"
    fi
    
    # 8. Conectividade Zabbix Server
    if timeout 5 bash -c "cat < /dev/null > /dev/tcp/$ZABBIX_SERVER/$ZABBIX_SERVER_PORT" 2>/dev/null; then
        log_pass "Conectividade Zabbix Server OK"
    else
        log_warn "Falha ao conectar no Zabbix Server"
    fi
    
    # 9. Logs Nginx
    if [ -f /var/log/nginx/zabbix-access.log ]; then
        log_pass "Log de acesso Nginx existe"
    else
        log_warn "Log de acesso não encontrado"
    fi
    
    # 10. Espaço em disco
    local disk_free=$(df /var/www | awk 'NR==2 {print $4}')
    if [ "$disk_free" -gt 5242880 ]; then
        log_pass "Espaço em disco OK: $((disk_free / 1048576)) GB"
    else
        log_warn "Espaço em disco baixo: $((disk_free / 1048576)) GB"
    fi
    
    # 11. Verificar PHP
    if php -v | grep -q "PHP"; then
        log_pass "PHP instalado"
    else
        log_fail "PHP não encontrado"
    fi
    
    # 12. Verificar módulos PHP críticos
    local critical_modules=("pdo_pgsql" "mbstring" "gd")
    for mod in "${critical_modules[@]}"; do
        if php -m | grep -qi "$mod"; then
            log_pass "Módulo PHP $mod encontrado"
        else
            log_fail "Módulo PHP $mod não encontrado"
        fi
    done
    
    echo "=================================================="
    log_info "Validação concluída"
    log_info "Erros: $ERRORS | Avisos: $WARNINGS"
    
    [ $ERRORS -eq 0 ] && log_pass "VALIDAÇÃO PASSOU" || log_fail "VALIDAÇÃO FALHOU"
    exit $ERRORS
}

main "$@"
