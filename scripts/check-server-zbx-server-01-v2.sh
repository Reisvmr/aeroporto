#!/bin/bash

################################################################################
#                                                                              #
#  SCRIPT DE VALIDAÇÃO - SERVIDOR ZABBIX SERVER 01                            #
#                                                                              #
#  Projeto: Aeroporto - Zabbix 7.0 LTS + PostgreSQL 16                        #
#  Data: 23/10/2024                                                           #
#  Versão: 2.0 - FOCO EM HARDWARE + CONECTIVIDADE                             #
#                                                                              #
#  ÊNFASE:                                                                     #
#    ✅ Hardware (CPU, RAM, Disco, Network)                                   #
#    ✅ Conectividade (DNS, TCP, HTTPS)                                       #
#    ✅ 14 Domínios críticos liberados                                        #
#    ✅ Conectividade com PostgreSQL (10.31.38.64:5432)                       #
#    ✅ Firewall pode estar desativado (não testa)                            #
#    ❌ Software (não será testado - instalado depois)                        #
#                                                                              #
################################################################################

# Configuração
set +e  # Continua mesmo com erros
REPORT_FILE="/tmp/check-zbx-server-01-$(date +%Y%m%d_%H%M%S).txt"
PASS=0
FAIL=0
WARN=0

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

################################################################################
# FUNÇÕES DE OUTPUT
################################################################################

print_header() {
    echo -e "\n${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}\n"
    echo "" >> "$REPORT_FILE"
    echo "════════════════════════════════════════════════════════════════" >> "$REPORT_FILE"
    echo "$1" >> "$REPORT_FILE"
    echo "════════════════════════════════════════════════════════════════" >> "$REPORT_FILE"
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
}

print_spec() {
    echo -e "  ${BOLD}Esperado:${NC} $1"
    echo "  Esperado: $1" >> "$REPORT_FILE"
}

print_current() {
    echo -e "  ${BOLD}Atual:${NC}    $1"
    echo "  Atual: $1" >> "$REPORT_FILE"
}

################################################################################
# INICIALIZAR RELATÓRIO
################################################################################

cat > "$REPORT_FILE" << EOF
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║  VALIDAÇÃO - SERVIDOR ZABBIX SERVER 01                         ║
║  Projeto: Aeroporto - Zabbix 7.0 LTS + PostgreSQL 16           ║
║                                                                ║
║  Foco: HARDWARE + CONECTIVIDADE                                ║
║  Data: $(date '+%Y-%m-%d %H:%M:%S')                                  ║
║  Versão: 2.0                                                   ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

EOF

################################################################################
# 1. HOSTNAME
################################################################################

print_header "1. HOSTNAME E INFORMAÇÕES DO SERVIDOR"

HOSTNAME=$(hostname 2>/dev/null || echo "DESCONHECIDO")
print_spec "zbx-server-01 ou zabbix-server"
print_current "$HOSTNAME"

if [[ "$HOSTNAME" == *"server"* ]] || [[ "$HOSTNAME" == *"zbx"* ]]; then
    print_pass "Hostname configurado apropriadamente"
else
    print_warn "Hostname não segue convenção (esperado: *server* ou *zbx*)"
fi

################################################################################
# 2. SISTEMA OPERACIONAL
################################################################################

print_header "2. SISTEMA OPERACIONAL"

if [ -f /etc/os-release ]; then
    source /etc/os-release
    OS_NAME="$NAME"
    OS_VERSION="$VERSION_ID"
else
    OS_NAME="DESCONHECIDO"
    OS_VERSION="DESCONHECIDO"
fi

print_spec "Ubuntu 22.04+, CentOS 8+, RHEL 8+ ou equivalente"
print_current "$OS_NAME $OS_VERSION"

if [[ "$OS_NAME" == *"Ubuntu"* ]] || [[ "$OS_NAME" == *"Debian"* ]] || [[ "$OS_NAME" == *"CentOS"* ]] || [[ "$OS_NAME" == *"RHEL"* ]]; then
    print_pass "Sistema operacional suportado detectado"
else
    print_fail "Sistema operacional não suportado ou desconhecido"
fi

################################################################################
# 3. HARDWARE - CPU
################################################################################

print_header "3. HARDWARE - CPU"

CPU_COUNT=$(nproc 2>/dev/null || echo "DESCONHECIDO")
CPU_MODEL=$(lscpu 2>/dev/null | grep "Model name" | cut -d: -f2 | xargs || echo "DESCONHECIDO")

print_spec "Mínimo 8 vCPU (recomendado 12+)"
print_current "vCPU: $CPU_COUNT | Modelo: $CPU_MODEL"

if [ "$CPU_COUNT" != "DESCONHECIDO" ] && [ "$CPU_COUNT" -ge 8 ]; then
    if [ "$CPU_COUNT" -ge 12 ]; then
        print_pass "CPU OK: $CPU_COUNT vCPU (recomendado)"
    else
        print_warn "CPU OK: $CPU_COUNT vCPU (mínimo atendido, mas recomenda-se 12+)"
    fi
else
    print_fail "CPU insuficiente ou desconhecida: $CPU_COUNT vCPU"
fi

################################################################################
# 4. HARDWARE - MEMÓRIA RAM
################################################################################

print_header "4. HARDWARE - MEMÓRIA RAM"

RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
RAM_GB=$((RAM_KB / 1024 / 1024))

print_spec "Mínimo 8 GB (recomendado 16+ GB)"
print_current "$RAM_GB GB"

if [ "$RAM_GB" -ge 16 ]; then
    print_pass "RAM OK: $RAM_GB GB (recomendado)"
elif [ "$RAM_GB" -ge 8 ]; then
    print_warn "RAM OK: $RAM_GB GB (mínimo atendido, recomenda-se 16+)"
else
    print_fail "RAM insuficiente: $RAM_GB GB (mínimo 8 GB)"
fi

################################################################################
# 5. HARDWARE - DISCO
################################################################################

print_header "5. HARDWARE - DISCO"

# Espaço em disco disponível
DISK_USAGE=$(df -h / 2>/dev/null | tail -1 | awk '{print $2, $3, $4, $5}' || echo "DESCONHECIDO")
print_spec "Mínimo 100 GB livres para /var/lib/zabbix"
print_current "Disco raiz: $DISK_USAGE"

ROOT_FREE=$(df / 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/K//' | sed 's/M/000/' || echo "0")
ROOT_FREE_GB=$((ROOT_FREE / 1024))

if [ "$ROOT_FREE_GB" -ge 100 ]; then
    print_pass "Espaço em disco OK: ${ROOT_FREE_GB} GB livres"
else
    print_warn "Espaço em disco limitado: ${ROOT_FREE_GB} GB livres (mínimo 100 GB recomendado)"
fi

print_info "Tipo de disco:"
DISK_TYPE=$(lsblk -d -o NAME | head -5 | tr '\n' ',' | sed 's/,$//')
print_info "  Discos detectados: $DISK_TYPE"

################################################################################
# 6. HARDWARE - NETWORK
################################################################################

print_header "6. HARDWARE - INTERFACE DE REDE"

IFACE_COUNT=$(ip link show 2>/dev/null | grep "^[0-9]" | grep -v "lo" | wc -l)
print_spec "Mínimo 1 interface de rede configurada"
print_current "Interfaces ativas: $IFACE_COUNT"

if [ "$IFACE_COUNT" -ge 1 ]; then
    print_pass "Interface de rede detectada"
    ip link show 2>/dev/null | grep "^[0-9]" | grep -v "lo" | while read line; do
        IFACE=$(echo "$line" | awk -F: '{print $2}' | xargs)
        IP=$(ip -4 addr show "$IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1 || echo "SEM IP")
        print_info "  $IFACE: $IP"
    done
else
    print_fail "Nenhuma interface de rede configurada"
fi

################################################################################
# 7. CONECTIVIDADE - DNS
################################################################################

print_header "7. CONECTIVIDADE - RESOLUÇÃO DNS"

print_spec "Resolução de nomes funcionando"

TEST_DOMAIN="repo.zabbix.com"
DNS_RESULT=$(nslookup "$TEST_DOMAIN" 2>&1 | grep "Address" | head -1 || echo "FALHOU")

print_current "Teste: $TEST_DOMAIN → $DNS_RESULT"

if [[ "$DNS_RESULT" == *"Address"* ]] || [[ "$DNS_RESULT" == *"."* ]]; then
    print_pass "Resolução DNS funcionando"
else
    print_fail "Resolução DNS falhou - verificar /etc/resolv.conf"
fi

NAMESERVERS=$(grep -h "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ',' | sed 's/,$//')
if [ -n "$NAMESERVERS" ]; then
    print_info "Nameservers configurados: $NAMESERVERS"
else
    print_warn "Nenhum nameserver configurado em /etc/resolv.conf"
fi

################################################################################
# 8. CONECTIVIDADE - PORTS TCP (14 DOMÍNIOS)
################################################################################

print_header "8. CONECTIVIDADE - TESTE DE PORTAS TCP"

declare -a DOMAINS=(
    "repo.zabbix.com"
    "www.zabbix.com"
    "rpm.grafana.com"
    "apt.grafana.com"
    "grafana.com"
    "download.postgresql.org"
    "github.com"
    "api.github.com"
    "raw.githubusercontent.com"
    "objects.githubusercontent.com"
    "release-assets.githubusercontent.com"
    "quay.io"
    "galaxy.ansible.com"
    "auth.docker.io"
)

print_info "Testando conectividade TCP para 14 domínios críticos...\n"

TCP_PASS=0
TCP_FAIL=0

for domain in "${DOMAINS[@]}"; do
    timeout 5 bash -c "echo >/dev/tcp/$domain/443" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        print_pass "TCP 443 ABERTO: $domain"
        ((TCP_PASS++))
    else
        print_fail "TCP 443 FECHADO/TIMEOUT: $domain"
        ((TCP_FAIL++))
    fi
done

echo ""
print_info "Resumo TCP: $TCP_PASS/14 portas ABERTAS, $TCP_FAIL/14 FECHADAS"

if [ "$TCP_FAIL" -eq 0 ]; then
    print_pass "Todas as portas TCP estão abertas"
elif [ "$TCP_FAIL" -le 2 ]; then
    print_warn "$TCP_FAIL domínios com TCP fechado - pode ser firewall corporativo"
else
    print_fail "$TCP_FAIL domínios com TCP fechado - verificar firewall/conectividade"
fi

################################################################################
# 9. CONECTIVIDADE - HTTPS
################################################################################

print_header "9. CONECTIVIDADE - TESTE HTTPS"

print_info "Testando HTTPS com curl para domínios críticos...\n"

HTTPS_PASS=0
HTTPS_FAIL=0

for domain in "${DOMAINS[@]}"; do
    RESPONSE=$(curl -s -m 5 -o /dev/null -w "%{http_code}" "https://$domain/" 2>/dev/null || echo "000")
    
    if [ "$RESPONSE" != "000" ] && [ "$RESPONSE" != "Connection refused" ]; then
        print_pass "HTTPS OK: $domain (HTTP $RESPONSE)"
        ((HTTPS_PASS++))
    else
        print_fail "HTTPS FALHOU: $domain"
        ((HTTPS_FAIL++))
    fi
done

echo ""
print_info "Resumo HTTPS: $HTTPS_PASS/14 domínios ACESSÍVEIS, $HTTPS_FAIL/14 FALHOU"

if [ "$HTTPS_FAIL" -eq 0 ]; then
    print_pass "Todos os domínios HTTPS estão acessíveis"
elif [ "$HTTPS_FAIL" -le 2 ]; then
    print_warn "$HTTPS_FAIL domínios com HTTPS falho - pode ser proxy/firewall"
else
    print_fail "$HTTPS_FAIL domínios com HTTPS falho - verificar conectividade"
fi

################################################################################
# 10. CONECTIVIDADE - POSTGRESQL REMOTO
################################################################################

print_header "10. CONECTIVIDADE - POSTGRESQL REMOTO (10.31.38.64:5432)"

print_spec "Deve conseguir conectar em 10.31.38.64:5432"

PG_HOST="10.31.38.64"
PG_PORT="5432"

# Testar TCP na porta 5432
timeout 5 bash -c "echo >/dev/tcp/$PG_HOST/$PG_PORT" 2>/dev/null

if [ $? -eq 0 ]; then
    print_pass "TCP ABERTO: $PG_HOST:$PG_PORT"
else
    print_fail "TCP FECHADO/TIMEOUT: $PG_HOST:$PG_PORT"
fi

print_info "Verificando ferramentas para conectar PostgreSQL..."

if command -v pg_isready &> /dev/null; then
    print_info "pg_isready disponível (será usado em setup PostgreSQL)"
else
    print_info "pg_isready não instalado (será instalado no setup)"
fi

################################################################################
# 11. CONECTIVIDADE - CONECTIVIDADE GERAL
################################################################################

print_header "11. CONECTIVIDADE - PING E ROTEAMENTO"

print_info "Testando ICMP (ping) para domínios selecionados...\n"

PING_TEST_DOMAINS=("repo.zabbix.com" "github.com" "8.8.8.8")
PING_PASS=0
PING_FAIL=0

for domain in "${PING_TEST_DOMAINS[@]}"; do
    ping -c 1 -W 2 "$domain" 2>&1 | grep -q "bytes from\|bytes of data from"
    
    if [ $? -eq 0 ]; then
        print_pass "PING OK: $domain"
        ((PING_PASS++))
    else
        print_warn "PING FALHOU: $domain (pode estar bloqueado)"
        ((PING_FAIL++))
    fi
done

# Roteamento
print_info "\nVerificando roteamento..."
DEFAULT_ROUTE=$(ip route show 2>/dev/null | grep "default" | awk '{print $3}' || echo "DESCONHECIDO")
print_info "  Gateway padrão: $DEFAULT_ROUTE"

################################################################################
# 12. FERRAMENTAS NECESSÁRIAS
################################################################################

print_header "12. FERRAMENTAS DE CONECTIVIDADE DISPONÍVEIS"

TOOLS=("curl" "wget" "nc" "netstat" "ip" "dig" "nslookup" "traceroute")
TOOLS_FOUND=0

for tool in "${TOOLS[@]}"; do
    if command -v "$tool" &> /dev/null; then
        print_pass "$tool disponível"
        ((TOOLS_FOUND++))
    else
        print_info "$tool não encontrado (opcional)"
    fi
done

################################################################################
# 13. INFORMAÇÕES ADICIONAIS
################################################################################

print_header "13. INFORMAÇÕES ADICIONAIS"

print_info "Kernel: $(uname -r 2>/dev/null || echo 'DESCONHECIDO')"
print_info "Uptime: $(uptime -p 2>/dev/null || uptime | cut -d',' -f1 || echo 'DESCONHECIDO')"
print_info "Data/Hora: $(date '+%Y-%m-%d %H:%M:%S %Z')"

MTU=$(ip link show 2>/dev/null | grep mtu | head -1 | grep -oP 'mtu \K[0-9]+' || echo "DESCONHECIDO")
print_info "MTU da interface: $MTU (esperado: 1500)"

################################################################################
# RESUMO FINAL
################################################################################

print_header "RESUMO DA VALIDAÇÃO"

echo -e "${BOLD}Total de verificações:${NC} $((PASS + FAIL + WARN))"
echo -e "  ${GREEN}✅ Passou: $PASS${NC}"
echo -e "  ${RED}❌ Falhou: $FAIL${NC}"
echo -e "  ${YELLOW}⚠️  Aviso: $WARN${NC}"

if [ "$FAIL" -eq 0 ]; then
    echo -e "\n${GREEN}${BOLD}✅ SERVIDOR APROVADO PARA SETUP!${NC}\n"
    echo "Próximas etapas:" >> "$REPORT_FILE"
    echo "  1. Executar SETUP_ZABBIX_SERVER_01.md" >> "$REPORT_FILE"
else
    echo -e "\n${YELLOW}${BOLD}⚠️  SERVIDOR NECESSITA AJUSTES${NC}\n"
    echo "Próximas etapas:" >> "$REPORT_FILE"
    echo "  1. Revisar erros acima" >> "$REPORT_FILE"
    echo "  2. Corrigir conectividade/hardware" >> "$REPORT_FILE"
    echo "  3. Re-executar validação" >> "$REPORT_FILE"
fi

echo -e "\n${BOLD}Relatório completo:${NC} $REPORT_FILE\n"
echo "" >> "$REPORT_FILE"
echo "════════════════════════════════════════════════════════════════" >> "$REPORT_FILE"
echo "FIM DA VALIDAÇÃO - $(date '+%Y-%m-%d %H:%M:%S')" >> "$REPORT_FILE"
echo "════════════════════════════════════════════════════════════════" >> "$REPORT_FILE"

exit 0
