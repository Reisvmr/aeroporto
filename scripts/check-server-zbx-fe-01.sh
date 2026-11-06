#!/bin/bash

################################################################################
#                                                                              #
#  SCRIPT DE VALIDAÇÃO - SERVIDOR ZABBIX FRONTEND 01                         #
#                                                                              #
#  Projeto: Aeroporto - Zabbix 7.0 LTS + PostgreSQL 16                        #
#  Função: Validar se o servidor está de acordo com a especificação           #
#  Data: 23/10/2024                                                           #
#  Versão: 1.0                                                                #
#                                                                              #
################################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Contadores
PASS=0
FAIL=0
WARN=0
INFO=0

# Arquivo de relatório
REPORT_FILE="/tmp/check-zbx-fe-01-$(date +%Y%m%d_%H%M%S).txt"

################################################################################
# FUNÇÕES
################################################################################

print_header() {
    echo -e "\n${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}\n"
}

print_pass() {
    echo -e "${GREEN}✅ PASS${NC}  : $1"
    echo "✅ PASS: $1" >> "$REPORT_FILE"
    ((PASS++))
}

print_fail() {
    echo -e "${RED}❌ FAIL${NC}  : $1"
    echo "❌ FAIL: $1" >> "$REPORT_FILE"
    ((FAIL++))
}

print_warn() {
    echo -e "${YELLOW}⚠️  WARN${NC}  : $1"
    echo "⚠️  WARN: $1" >> "$REPORT_FILE"
    ((WARN++))
}

print_info() {
    echo -e "${BLUE}ℹ️  INFO${NC}  : $1"
    echo "ℹ️  INFO: $1" >> "$REPORT_FILE"
    ((INFO++))
}

print_spec() {
    echo -e "  ${BOLD}Esperado:${NC} $1"
    echo "  Esperado: $1" >> "$REPORT_FILE"
}

print_current() {
    echo -e "  ${BOLD}Atual:${NC}    $2"
    echo "  Atual: $2" >> "$REPORT_FILE"
}

print_options() {
    echo -e "  ${BOLD}Opções:${NC}"
    local i=1
    while [ $i -le $# ]; do
        echo -e "    $i) ${!i}"
        echo "    $i) ${!i}" >> "$REPORT_FILE"
        ((i++))
    done
}

################################################################################
# CHECAGENS
################################################################################

check_hostname() {
    print_header "1. HOSTNAME"
    
    local current_hostname=$(hostname)
    print_spec "zbx-fe-01 ou zabbix-frontend"
    print_current "" "$current_hostname"
    
    if [[ "$current_hostname" == "zbx-fe-01" ]] || [[ "$current_hostname" == "zabbix-frontend" ]]; then
        print_pass "Hostname configurado corretamente"
    else
        print_fail "Hostname não configurado conforme especificação"
        print_options \
            "Executar: sudo hostnamectl set-hostname zbx-fe-01" \
            "Executar: sudo hostnamectl set-hostname zabbix-frontend"
    fi
}

check_os() {
    print_header "2. SISTEMA OPERACIONAL"
    
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        local os_name="$NAME"
        local os_version="$VERSION_ID"
        
        print_spec "Ubuntu 20.04+, Debian 11+, CentOS 8+, RHEL 8+"
        print_current "" "$os_name $os_version"
        
        if [[ "$os_name" == *"Ubuntu"* ]] && [[ $(echo "$os_version >= 20.04" | bc) -eq 1 ]]; then
            print_pass "Ubuntu >= 20.04 detectado"
        elif [[ "$os_name" == *"Debian"* ]] && [[ $(echo "$os_version >= 11" | bc) -eq 1 ]]; then
            print_pass "Debian >= 11 detectado"
        elif [[ "$os_name" == *"CentOS"* ]] || [[ "$os_name" == *"Red Hat"* ]]; then
            print_pass "CentOS/RHEL detectado"
        else
            print_fail "SO não suportado"
        fi
    fi
}

check_cpu_ram() {
    print_header "3. CPU E MEMÓRIA RAM"
    
    # CPU
    local cpu_count=$(nproc)
    print_spec "4 vCPU (mínimo) - 8 vCPU (recomendado)"
    print_current "" "$cpu_count vCPU"
    
    if [ "$cpu_count" -ge 8 ]; then
        print_pass "CPU com $cpu_count vCPU (>= 8, recomendado)"
    elif [ "$cpu_count" -ge 4 ]; then
        print_pass "CPU com $cpu_count vCPU (mínimo)"
    else
        print_fail "CPU com apenas $cpu_count vCPU (< 4)"
    fi
    
    # RAM
    local ram_gb=$(free -g | awk '/^Mem:/ {print $2}')
    print_spec "8 GB RAM (mínimo) - 16 GB RAM (recomendado)"
    print_current "" "$ram_gb GB"
    
    if [ "$ram_gb" -ge 16 ]; then
        print_pass "RAM com $ram_gb GB (>= 16, recomendado)"
    elif [ "$ram_gb" -ge 8 ]; then
        print_pass "RAM com $ram_gb GB (mínimo)"
    else
        print_fail "RAM com apenas $ram_gb GB (< 8)"
    fi
}

check_firewall() {
    print_header "4. FIREWALL"
    
    print_spec "Portas 80 (HTTP) e 443 (HTTPS) abertas para entrada"
    print_spec "Porta 10051 aberta para saída (conecta em Zabbix Server)"
    print_spec "Porta 5432 aberta para saída (conecta em PostgreSQL 10.31.38.64)"
    
    if command -v firewall-cmd &> /dev/null; then
        local fw_status=$(sudo firewall-cmd --state 2>/dev/null || echo "inactive")
        
        if [[ "$fw_status" == "running" ]]; then
            for port in 80 443; do
                local port_check=$(sudo firewall-cmd --list-ports 2>/dev/null | grep -c "$port/tcp" || echo 0)
                if [ "$port_check" -gt 0 ]; then
                    print_pass "Porta $port/tcp liberada"
                else
                    print_fail "Porta $port/tcp NÃO está liberada"
                fi
            done
        fi
    elif command -v ufw &> /dev/null; then
        for port in 80 443; do
            local port_check=$(sudo ufw status | grep -c "$port" || echo 0)
            if [ "$port_check" -gt 0 ]; then
                print_pass "Porta $port liberada em UFW"
            else
                print_fail "Porta $port NÃO está liberada"
                print_options "Executar: sudo ufw allow $port/tcp"
            fi
        done
    fi
}

check_ntp() {
    print_header "5. NTP (SINCRONISMO DE HORA)"
    
    print_spec "NTP/Chrony sincronizado"
    
    if command -v chronyc &> /dev/null; then
        print_current "" "Chrony detectado"
        
        if sudo systemctl is-active --quiet chrony; then
            print_pass "Chrony está rodando"
        else
            print_warn "Chrony não está ativo"
        fi
    elif command -v ntpstat &> /dev/null; then
        print_current "" "NTP detectado"
        
        if sudo systemctl is-active --quiet ntp; then
            print_pass "NTP está rodando"
        else
            print_warn "NTP não está ativo"
        fi
    else
        print_warn "Nenhum NTP detectado"
    fi
    
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    print_info "Hora do sistema: $current_time"
}

check_web_server() {
    print_header "6. SERVIDOR WEB"
    
    print_spec "Nginx ou Apache instalado e rodando"
    
    if command -v nginx &> /dev/null; then
        local nginx_version=$(nginx -v 2>&1 | awk '{print $NF}')
        print_current "" "Nginx: $nginx_version"
        
        if sudo systemctl is-active --quiet nginx; then
            print_pass "Nginx está rodando"
        else
            print_warn "Nginx não está rodando"
            print_options "Iniciar: sudo systemctl start nginx"
        fi
    elif command -v apache2 &> /dev/null; then
        print_current "" "Apache2 detectado"
        
        if sudo systemctl is-active --quiet apache2; then
            print_pass "Apache2 está rodando"
        else
            print_warn "Apache2 não está rodando"
        fi
    else
        print_fail "Nenhum servidor web (Nginx/Apache) instalado"
        print_options "Segue: SETUP_ZABBIX_FRONTEND_01.md Passo 2"
    fi
}

check_php() {
    print_header "7. PHP"
    
    print_spec "PHP 7.4+ com FPM (FastCGI)"
    
    if command -v php &> /dev/null; then
        local php_version=$(php -v 2>/dev/null | head -1)
        print_current "" "$php_version"
        
        if command -v php-fpm &> /dev/null || command -v php-fpm7.4 &> /dev/null; then
            print_pass "PHP-FPM detectado"
            
            if sudo systemctl is-active --quiet php-fpm || sudo systemctl is-active --quiet php7.4-fpm; then
                print_pass "PHP-FPM está rodando"
            else
                print_warn "PHP-FPM não está rodando"
            fi
        else
            print_warn "PHP-FPM não está instalado (apenas CLI?)"
            print_options "Instalar: sudo apt install php-fpm (Ubuntu/Debian)"
        fi
    else
        print_fail "PHP não está instalado"
        print_options "Segue: SETUP_ZABBIX_FRONTEND_01.md Passo 2"
    fi
}

check_zabbix_frontend() {
    print_header "8. ZABBIX FRONTEND"
    
    print_spec "Zabbix Frontend 7.0 LTS instalado"
    
    if [ -d "/usr/share/zabbix" ] || [ -d "/var/www/zabbix" ]; then
        print_pass "Diretório Zabbix Frontend encontrado"
        
        # Verificar arquivo config
        if [ -f "/etc/zabbix/web/zabbix.conf.php" ]; then
            print_pass "Arquivo de configuração exists"
        else
            print_warn "Arquivo de configuração não encontrado"
        fi
    else
        print_fail "Zabbix Frontend NÃO está instalado"
        print_options "Segue: SETUP_ZABBIX_FRONTEND_01.md Passo 3"
    fi
}

check_ssl_certificate() {
    print_header "9. SSL/TLS - CERTIFICADO"
    
    print_spec "Certificado SSL/TLS configurado (auto-assinado OK para teste)"
    
    # Procurar certificado SSL
    local ssl_cert_found=0
    
    # Verificar locais comuns
    for location in /etc/nginx/certs /etc/ssl/certs /etc/apache2/certs /opt/zabbix/certs; do
        if [ -d "$location" ]; then
            if ls $location/*.crt &> /dev/null || ls $location/*.pem &> /dev/null; then
                print_info "Certificado(s) encontrado(s) em: $location"
                ssl_cert_found=1
            fi
        fi
    done
    
    if [ "$ssl_cert_found" -eq 1 ]; then
        print_pass "Certificado SSL/TLS detectado"
    else
        print_warn "Nenhum certificado SSL/TLS encontrado"
        print_options \
            "Gerar certificado auto-assinado" \
            "Seguir: SETUP_ZABBIX_FRONTEND_01.md Passo 4"
    fi
}

check_postgresql_connectivity() {
    print_header "10. CONECTIVIDADE COM POSTGRESQL (10.31.38.64)"
    
    print_spec "Conexão TCP aberta para 10.31.38.64:5432"
    
    if timeout 5 nc -z 10.31.38.64 5432 &> /dev/null; then
        print_pass "Conectividade TCP com 10.31.38.64:5432 OK"
    else
        print_fail "Não consegue conectar em 10.31.38.64:5432"
        print_options \
            "Verificar firewall (porta 5432 liberada)" \
            "Testar: telnet 10.31.38.64 5432"
    fi
    
    # Testar com psql
    if command -v psql &> /dev/null; then
        if timeout 5 psql -h 10.31.38.64 -U zabbix -d zabbix -c "SELECT 1;" &> /dev/null; then
            print_pass "Autenticação PostgreSQL OK"
        else
            print_warn "Não consegue autenticar no PostgreSQL"
        fi
    fi
}

check_zabbix_server_connectivity() {
    print_header "11. CONECTIVIDADE COM ZABBIX SERVER"
    
    print_spec "Conexão TCP aberta para Zabbix Server (porta 10051)"
    print_spec "IP do Zabbix Server deve ser configurado"
    
    # Procurar IP do Zabbix Server na config
    if [ -f "/etc/zabbix/web/zabbix.conf.php" ]; then
        local server_ip=$(grep -i "SERVER\|server" /etc/zabbix/web/zabbix.conf.php | grep -v "^//" | head -1)
        print_info "Config: $server_ip"
    else
        print_info "Arquivo de config não encontrado (normal se não instalado)"
    fi
    
    # Assumir que será zbx-server-01 (placeholder)
    print_warn "Validação de conectividade diferida - IP do Zabbix Server ainda não conhecido"
    print_options "Após instalação, testar: telnet <IP-zbx-server-01> 10051"
}

check_network() {
    print_header "12. CONECTIVIDADE DE REDE"
    
    print_spec "Servidor acessível via SSH, DNS funcionando"
    
    local current_ip=$(hostname -I | awk '{print $1}')
    print_current "" "IP: $current_ip"
    
    if [ -n "$current_ip" ]; then
        print_pass "IP configurado: $current_ip"
    else
        print_fail "Não conseguiu detectar IP"
    fi
    
    # DNS
    if nslookup 8.8.8.8 &> /dev/null; then
        print_pass "DNS funcionando"
    else
        print_warn "DNS pode não estar funcionando"
    fi
    
    # HTTPS
    if timeout 5 curl -I https://github.com &> /dev/null; then
        print_pass "Conectividade HTTPS OK"
    else
        print_warn "Conectividade HTTPS limitada"
    fi
}

check_selinux() {
    print_header "13. SELINUX (CentOS/RHEL)"
    
    if command -v getenforce &> /dev/null; then
        local selinux_status=$(getenforce)
        print_current "" "$selinux_status"
        
        if [[ "$selinux_status" == "Disabled" ]] || [[ "$selinux_status" == "Permissive" ]]; then
            print_pass "SELinux em modo adequado"
        else
            print_warn "SELinux em modo Enforcing"
            print_options "Desabilitar: setenforce 0"
        fi
    else
        print_info "SELinux não está instalado"
    fi
}

generate_summary() {
    print_header "RESUMO DA CHECAGEM"
    
    local total=$((PASS + FAIL + WARN + INFO))
    
    echo -e "Total de verificações: ${BOLD}$total${NC}"
    echo -e "  ${GREEN}Passou (✅):${NC} $PASS"
    echo -e "  ${RED}Falhou (❌):${NC} $FAIL"
    echo -e "  ${YELLOW}Aviso (⚠️):${NC}  $WARN"
    echo -e "  ${BLUE}Informação (ℹ️):${NC}  $INFO"
    echo ""
    
    if [ "$FAIL" -eq 0 ]; then
        echo -e "\n${GREEN}${BOLD}✅ SERVIDOR PRONTO PARA SETUP!${NC}\n"
        return 0
    else
        echo -e "\n${RED}${BOLD}❌ RESOLVER FALHAS ANTES DE PROSSEGUIR${NC}\n"
        return 1
    fi
}

print_report_location() {
    echo -e "${BOLD}Relatório completo salvo em:${NC}"
    echo -e "  ${BLUE}$REPORT_FILE${NC}\n"
}

################################################################################
# MAIN
################################################################################

main() {
    clear
    
    echo -e "${BOLD}${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║  SCRIPT DE VALIDAÇÃO - ZABBIX FRONTEND 01                      ║"
    echo "║  Projeto: Aeroporto - Zabbix 7.0 LTS + PostgreSQL 16           ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
    
    # Inicializar relatório
    {
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║  RELATÓRIO DE VALIDAÇÃO - ZABBIX FRONTEND 01                   ║"
        echo "║  Data: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "║  Hostname: $(hostname)"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""
    } > "$REPORT_FILE"
    
    # Executar checagens
    check_hostname
    check_os
    check_cpu_ram
    check_firewall
    check_ntp
    check_web_server
    check_php
    check_zabbix_frontend
    check_ssl_certificate
    check_postgresql_connectivity
    check_zabbix_server_connectivity
    check_network
    check_selinux
    
    # Resumo
    generate_summary
    print_report_location
    
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}\n"
}

# Executar
main "$@"
