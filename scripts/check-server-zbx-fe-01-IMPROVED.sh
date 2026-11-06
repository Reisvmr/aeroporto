#!/bin/bash

################################################################################
#                                                                              #
#  SCRIPT DE VALIDAÇÃO - SERVIDOR ZABBIX FRONTEND 01 (VERSÃO MELHORADA)      #
#                                                                              #
#  Projeto: Aeroporto - Zabbix 7.0 LTS + PostgreSQL 16                        #
#  Função: Validar se o servidor está de acordo com a especificação           #
#  Data: 23/10/2024                                                           #
#  Versão: 1.1 - Melhorada (continua mesmo com erros)                         #
#                                                                              #
################################################################################

# NÃO usar set -e (continua mesmo com erros)

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
    
    echo "" >> "$REPORT_FILE"
    echo "════════════════════════════════════════════════════════════════" >> "$REPORT_FILE"
    echo "  $1" >> "$REPORT_FILE"
    echo "════════════════════════════════════════════════════════════════" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
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
    echo "  Opções:" >> "$REPORT_FILE"
    local i=1
    while [ $i -le $# ]; do
        echo -e "    $i) ${!i}"
        echo "    $i) ${!i}" >> "$REPORT_FILE"
        ((i++))
    done
}

safe_run() {
    # Executa comando com tratamento de erro
    local output
    output=$("$@" 2>&1) || output="[ERRO: $?]"
    echo "$output"
}

################################################################################
# CHECAGENS
################################################################################

check_hostname() {
    print_header "1. HOSTNAME"
    
    local current_hostname=$(hostname 2>/dev/null || echo "DESCONHECIDO")
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
        
        if [[ "$os_name" == *"Ubuntu"* ]]; then
            print_pass "Ubuntu detectado: $os_version"
        elif [[ "$os_name" == *"Debian"* ]]; then
            print_pass "Debian detectado: $os_version"
        elif [[ "$os_name" == *"CentOS"* ]] || [[ "$os_name" == *"Red Hat"* ]]; then
            print_pass "CentOS/RHEL detectado"
        else
            print_fail "SO não suportado"
        fi
    else
        print_fail "Não foi possível detectar SO"
    fi
}

check_cpu_ram() {
    print_header "3. CPU E MEMÓRIA RAM"
    
    # CPU
    local cpu_count=$(nproc 2>/dev/null || echo "DESCONHECIDO")
    print_spec "4 vCPU (mínimo) - 8 vCPU (recomendado)"
    print_current "" "$cpu_count vCPU"
    
    if [[ "$cpu_count" != "DESCONHECIDO" ]]; then
        if [ "$cpu_count" -ge 8 ]; then
            print_pass "CPU com $cpu_count vCPU (>= 8, recomendado)"
        elif [ "$cpu_count" -ge 4 ]; then
            print_pass "CPU com $cpu_count vCPU (mínimo)"
        else
            print_fail "CPU com apenas $cpu_count vCPU (< 4)"
        fi
    else
        print_warn "Não foi possível detectar número de CPUs"
    fi
    
    # RAM
    local ram_gb=$(free -g 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "DESCONHECIDO")
    print_spec "8 GB RAM (mínimo) - 16 GB RAM (recomendado)"
    print_current "" "$ram_gb GB"
    
    if [[ "$ram_gb" != "DESCONHECIDO" ]]; then
        if [ "$ram_gb" -ge 16 ]; then
            print_pass "RAM com $ram_gb GB (>= 16, recomendado)"
        elif [ "$ram_gb" -ge 8 ]; then
            print_pass "RAM com $ram_gb GB (mínimo)"
        else
            print_fail "RAM com apenas $ram_gb GB (< 8)"
        fi
    else
        print_warn "Não foi possível detectar RAM"
    fi
}

check_firewall() {
    print_header "4. FIREWALL"
    
    print_spec "Portas 80 (HTTP) e 443 (HTTPS) abertas para entrada"
    
    if command -v firewall-cmd &> /dev/null; then
        local fw_status=$(sudo firewall-cmd --state 2>/dev/null || echo "ERRO")
        
        if [[ "$fw_status" == "running" ]]; then
            print_info "FirewallD está ativo"
            for port in 80 443; do
                local port_check=$(sudo firewall-cmd --list-ports 2>/dev/null | grep -c "$port/tcp" || echo 0)
                if [ "$port_check" -gt 0 ]; then
                    print_pass "Porta $port/tcp liberada"
                else
                    print_fail "Porta $port/tcp NÃO está liberada"
                fi
            done
        else
            print_warn "FirewallD não está ativo ou erro de acesso"
        fi
    elif command -v ufw &> /dev/null; then
        print_info "UFW detectado"
        local ufw_status=$(sudo ufw status 2>/dev/null | grep -c "active" || echo 0)
        
        if [ "$ufw_status" -gt 0 ]; then
            for port in 80 443; do
                local port_check=$(sudo ufw status 2>/dev/null | grep -c "$port" || echo 0)
                if [ "$port_check" -gt 0 ]; then
                    print_pass "Porta $port liberada em UFW"
                else
                    print_fail "Porta $port NÃO está liberada"
                fi
            done
        else
            print_warn "UFW não está ativo"
        fi
    else
        print_warn "Nenhum firewall (firewall-cmd/ufw) detectado"
    fi
}

check_ntp() {
    print_header "5. NTP (SINCRONISMO DE HORA)"
    
    print_spec "NTP/Chrony sincronizado"
    
    local ntp_found=0
    
    if command -v chronyc &> /dev/null; then
        print_info "Chrony detectado"
        ntp_found=1
        
        if sudo systemctl is-active --quiet chrony 2>/dev/null; then
            print_pass "Chrony está rodando"
        else
            print_warn "Chrony não está ativo"
        fi
    fi
    
    if command -v ntpstat &> /dev/null; then
        print_info "NTP detectado"
        ntp_found=1
        
        if sudo systemctl is-active --quiet ntp 2>/dev/null; then
            print_pass "NTP está rodando"
        else
            print_warn "NTP não está ativo"
        fi
    fi
    
    if [ "$ntp_found" -eq 0 ]; then
        print_warn "Nenhum NTP (chrony/ntp) detectado"
    fi
    
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    print_info "Hora do sistema: $current_time"
}

check_web_server() {
    print_header "6. SERVIDOR WEB"
    
    print_spec "Nginx ou Apache instalado e rodando"
    
    local web_found=0
    
    if command -v nginx &> /dev/null; then
        local nginx_version=$(nginx -v 2>&1 | head -1)
        print_info "Nginx: $nginx_version"
        web_found=1
        
        if sudo systemctl is-active --quiet nginx 2>/dev/null; then
            print_pass "Nginx está rodando"
        else
            print_warn "Nginx não está rodando"
            print_options "Iniciar: sudo systemctl start nginx"
        fi
    fi
    
    if command -v apache2 &> /dev/null; then
        print_info "Apache2 detectado"
        web_found=1
        
        if sudo systemctl is-active --quiet apache2 2>/dev/null; then
            print_pass "Apache2 está rodando"
        else
            print_warn "Apache2 não está rodando"
        fi
    fi
    
    if [ "$web_found" -eq 0 ]; then
        print_fail "Nenhum servidor web (Nginx/Apache) instalado"
        print_options "Segue: SETUP_ZABBIX_FRONTEND_01.md Passo 2"
    fi
}

check_php() {
    print_header "7. PHP"
    
    print_spec "PHP 7.4+ com FPM (FastCGI)"
    
    if command -v php &> /dev/null; then
        local php_version=$(php -v 2>/dev/null | head -1)
        print_info "$php_version"
        
        local php_fpm_found=0
        
        if command -v php-fpm &> /dev/null; then
            print_info "PHP-FPM detectado"
            php_fpm_found=1
            
            if sudo systemctl is-active --quiet php-fpm 2>/dev/null; then
                print_pass "PHP-FPM está rodando"
            else
                print_warn "PHP-FPM não está rodando"
            fi
        fi
        
        if command -v php-fpm7.4 &> /dev/null; then
            print_info "PHP 7.4-FPM detectado"
            php_fpm_found=1
            
            if sudo systemctl is-active --quiet php7.4-fpm 2>/dev/null; then
                print_pass "PHP 7.4-FPM está rodando"
            else
                print_warn "PHP 7.4-FPM não está rodando"
            fi
        fi
        
        if [ "$php_fpm_found" -eq 0 ]; then
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
    
    if [ -d "/usr/share/zabbix" ]; then
        print_pass "Diretório /usr/share/zabbix encontrado"
    elif [ -d "/var/www/zabbix" ]; then
        print_pass "Diretório /var/www/zabbix encontrado"
    else
        print_warn "Diretório Zabbix Frontend não encontrado (normal se não instalado)"
    fi
    
    if [ -f "/etc/zabbix/web/zabbix.conf.php" ]; then
        print_pass "Arquivo /etc/zabbix/web/zabbix.conf.php encontrado"
    else
        print_info "Arquivo de configuração não encontrado (será criado durante setup)"
    fi
}

check_ssl_certificate() {
    print_header "9. SSL/TLS - CERTIFICADO"
    
    print_spec "Certificado SSL/TLS configurado (auto-assinado OK para teste)"
    
    local ssl_found=0
    
    for location in /etc/nginx/certs /etc/ssl/certs /etc/apache2/certs /opt/zabbix/certs; do
        if [ -d "$location" ] 2>/dev/null; then
            local cert_count=$(ls "$location"/*.{crt,pem} 2>/dev/null | wc -l || echo 0)
            if [ "$cert_count" -gt 0 ]; then
                print_info "Certificado(s) encontrado(s) em: $location"
                ssl_found=1
            fi
        fi
    done
    
    if [ "$ssl_found" -eq 1 ]; then
        print_pass "Certificado SSL/TLS detectado"
    else
        print_warn "Nenhum certificado SSL/TLS encontrado"
        print_options \
            "Gerar certificado auto-assinado durante setup" \
            "Seguir: SETUP_ZABBIX_FRONTEND_01.md Passo 4"
    fi
}

check_postgresql_connectivity() {
    print_header "10. CONECTIVIDADE COM POSTGRESQL (10.31.38.64)"
    
    print_spec "Conexão TCP aberta para 10.31.38.64:5432"
    
    # Testar com nc (netcat)
    if command -v nc &> /dev/null; then
        if timeout 3 nc -z 10.31.38.64 5432 2>/dev/null; then
            print_pass "Conectividade TCP com 10.31.38.64:5432 OK"
        else
            print_fail "Não consegue conectar em 10.31.38.64:5432"
            print_options \
                "Verificar firewall (porta 5432 saída liberada)" \
                "Verificar conectividade: ping 10.31.38.64"
        fi
    else
        print_warn "nc (netcat) não instalado - teste TCP omitido"
    fi
    
    # Testar com psql se instalado
    if command -v psql &> /dev/null; then
        if timeout 3 psql -h 10.31.38.64 -U zabbix -d zabbix -c "SELECT 1;" 2>/dev/null >/dev/null; then
            print_pass "Autenticação PostgreSQL (usuário zabbix) OK"
        else
            print_info "Autenticação PostgreSQL não testada (banco pode não estar pronto)"
        fi
    fi
}

check_zabbix_server_connectivity() {
    print_header "11. CONECTIVIDADE COM ZABBIX SERVER"
    
    print_spec "Porta 10051 (Zabbix API) deve estar acessível"
    
    if [ -f "/etc/zabbix/web/zabbix.conf.php" ]; then
        local server_config=$(grep -i "ZBX_SERVER" /etc/zabbix/web/zabbix.conf.php 2>/dev/null | head -1)
        if [ -n "$server_config" ]; then
            print_info "Config encontrada: $server_config"
        fi
    else
        print_info "Arquivo de config não encontrado (normal se não instalado)"
    fi
    
    print_warn "Validação de conectividade diferida - IP do Zabbix Server ainda não conhecido"
    print_options "Após instalação, testar: telnet <IP-zbx-server-01> 10051"
}

check_network() {
    print_header "12. CONECTIVIDADE DE REDE"
    
    print_spec "Servidor acessível via SSH, DNS funcionando"
    
    local current_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    print_spec "IP do servidor"
    print_current "" "$current_ip"
    
    if [ -n "$current_ip" ]; then
        print_pass "IP detectado: $current_ip"
    else
        print_warn "Não conseguiu detectar IP"
    fi
    
    # DNS
    if nslookup 8.8.8.8 &>/dev/null; then
        print_pass "DNS funcionando (testado com 8.8.8.8)"
    else
        print_warn "DNS pode não estar funcionando"
    fi
    
    # HTTPS
    if command -v curl &> /dev/null; then
        if timeout 3 curl -I https://github.com 2>/dev/null | grep -q "HTTP"; then
            print_pass "Conectividade HTTPS OK (testado com github.com)"
        else
            print_warn "Conectividade HTTPS pode estar limitada"
        fi
    else
        print_info "curl não instalado - teste HTTPS omitido"
    fi
}

check_selinux() {
    print_header "13. SELINUX (CentOS/RHEL)"
    
    if command -v getenforce &> /dev/null; then
        local selinux_status=$(getenforce 2>/dev/null)
        print_current "" "$selinux_status"
        
        if [[ "$selinux_status" == "Disabled" ]] || [[ "$selinux_status" == "Permissive" ]]; then
            print_pass "SELinux em modo adequado"
        elif [[ "$selinux_status" == "Enforcing" ]]; then
            print_warn "SELinux em modo Enforcing (pode bloquear Zabbix)"
            print_options \
                "Desabilitar temporário: sudo setenforce 0" \
                "Desabilitar permanente: editar /etc/selinux/config"
        fi
    else
        print_info "SELinux não está instalado (típico em Ubuntu/Debian)"
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
    
    echo "Total de verificações: $total" >> "$REPORT_FILE"
    echo "  Passou: $PASS" >> "$REPORT_FILE"
    echo "  Falhou: $FAIL" >> "$REPORT_FILE"
    echo "  Aviso: $WARN" >> "$REPORT_FILE"
    echo "  Informação: $INFO" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    if [ "$FAIL" -eq 0 ]; then
        echo -e "\n${GREEN}${BOLD}✅ SERVIDOR PRONTO PARA SETUP!${NC}\n"
        echo "✅ SERVIDOR PRONTO PARA SETUP!" >> "$REPORT_FILE"
    elif [ "$FAIL" -le 2 ]; then
        echo -e "\n${YELLOW}${BOLD}⚠️  SERVIDOR QUASE PRONTO - RESOLVER ALGUMAS FALHAS${NC}\n"
        echo "⚠️  SERVIDOR QUASE PRONTO - RESOLVER ALGUMAS FALHAS" >> "$REPORT_FILE"
    else
        echo -e "\n${RED}${BOLD}❌ RESOLVER FALHAS ANTES DE PROSSEGUIR${NC}\n"
        echo "❌ RESOLVER FALHAS ANTES DE PROSSEGUIR" >> "$REPORT_FILE"
    fi
}

print_report_location() {
    echo -e "${BOLD}Relatório completo salvo em:${NC}"
    echo -e "  ${BLUE}$REPORT_FILE${NC}\n"
    echo "Relatório completo salvo em: $REPORT_FILE" >> "$REPORT_FILE"
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
    echo "║  Versão: 1.1 - Melhorada (continua mesmo com erros)            ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
    
    # Inicializar relatório
    {
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║  RELATÓRIO DE VALIDAÇÃO - ZABBIX FRONTEND 01                   ║"
        echo "║  Data: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "║  Hostname: $(hostname)"
        echo "║  Versão: 1.1 - Melhorada"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""
    } > "$REPORT_FILE"
    
    # Executar todas as checagens (não para em erro)
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
