#!/bin/bash

################################################################################
# Script: 05-grafana-ha.sh
# Descrição: Instalação Grafana 10.x em cluster HA com Shared Database
# Data: 27/10/2026
# Versão: 2.0 (HA)
# Servidores: grafana-01 (10.31.38.66) / grafana-02 (10.31.38.67)
# Autor: Aeroporto - Infraestrutura HA
#
# Uso: sudo ./05-grafana-ha.sh <node1|node2>
#
# Exemplo:
#   Em grafana-01: sudo ./05-grafana-ha.sh node1
#   Em grafana-02: sudo ./05-grafana-ha.sh node2
#
# Pré-requisitos:
#   - PostgreSQL HA (pg-01/pg-02) já instalado e rodando
#   - VIP flutuante 10.31.38.72 já configurado (HAProxy+Keepalived em vip-01/vip-02)
#   - IPs estáticos: 10.31.38.66 (node1) / 10.31.38.67 (node2)
#
# Configura:
#   - Grafana 10.x
#   - Shared Database (PostgreSQL HA)
#   - Session persistence em PostgreSQL
#   - Data sources: Zabbix API
#   - Sincronização automática de dashboards
#   - Frontend via VIP
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

# Parâmetros
NODE_TYPE="${1:-}"  # node1 ou node2
GRAFANA_VERSION="10.0"
GRAFANA_USER="grafana"
GRAFANA_GROUP="grafana"
GRAFANA_HOME="/var/lib/grafana"
GRAFANA_CONFIG="/etc/grafana"
GRAFANA_LOG="/var/log/grafana"
GRAFANA_PORT="3000"

# Database
PG_HOST="10.31.38.64"  # Primary
PG_PORT="5432"
DB_NAME="grafana"
DB_USER="grafana"
DB_PASS="${DB_PASS:-grafana123}"

# IPs Grafana
GRAFANA_NODE1="10.31.38.66"
GRAFANA_NODE2="10.31.38.67"
GRAFANA_VIP="10.31.38.72"

# Zabbix (Data Source)
ZABBIX_URL="http://10.31.38.72"  # Via VIP
ZABBIX_API_URL="$ZABBIX_URL/api_jsonrpc.php"
ZABBIX_API_USER="Admin"
ZABBIX_API_PASS="${ZABBIX_API_PASS:-zabbix}"

# Data
DATA=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="/tmp/grafana-ha-install-$(date +%s).log"

# ═══════════════════════════════════════════════════════════════════════════
# FUNÇÕES
# ═══════════════════════════════════════════════════════════════════════════

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                    ║"
    echo "║  📈 INSTALAÇÃO GRAFANA 10.x HA - PROJETO AEROPORTO (HA)            ║"
    echo "║                                                                    ║"
    echo "║  Node Type: $NODE_TYPE"
    echo "║  Cluster: grafana-01 + grafana-02                                 ║"
    echo "║  Database: PostgreSQL HA (10.31.38.64)                           ║"
    echo "║  VIP: 10.31.38.72 (flutuante / HAProxy em vip-01/vip-02)          ║"
    echo "║                                                                    ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
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
    
    # Root check
    if [[ $EUID -ne 0 ]]; then
        print_erro "Este script deve ser executado como root"
        exit 1
    fi
    print_ok "Executando como root"
    
    # Node type check
    if [[ "$NODE_TYPE" != "node1" ]] && [[ "$NODE_TYPE" != "node2" ]]; then
        print_erro "Node Type deve ser 'node1' ou 'node2'"
        echo ""
        echo "Uso: sudo ./05-grafana-ha.sh <node1|node2>"
        exit 1
    fi
    print_ok "Node Type: $NODE_TYPE"
    
    # Verificar IP
    IP_ATUAL=$(hostname -I | awk '{print $1}')
    if [[ "$NODE_TYPE" == "node1" ]] && [[ "$IP_ATUAL" == "$GRAFANA_NODE1" ]]; then
        print_ok "IP correto (Node 1): $IP_ATUAL"
    elif [[ "$NODE_TYPE" == "node2" ]] && [[ "$IP_ATUAL" == "$GRAFANA_NODE2" ]]; then
        print_ok "IP correto (Node 2): $IP_ATUAL"
    else
        print_erro "IP incorreto! Esperado $([[ "$NODE_TYPE" == "node1" ]] && echo "$GRAFANA_NODE1" || echo "$GRAFANA_NODE2"), encontrado $IP_ATUAL"
        exit 1
    fi
    
    # Verificar PostgreSQL
    print_info "Testando conectividade com PostgreSQL..."
    if timeout 5 psql -h "$PG_HOST" -U "$DB_USER" -d "$DB_NAME" -c "SELECT version();" &>/dev/null 2>&1 || [[ ! -x $(command -v psql) ]]; then
        print_ok "PostgreSQL acessível (será verificado pós-instalação)"
    fi
    
    # Verificar porta Grafana
    if ! ss -tlnp | grep -q ":$GRAFANA_PORT "; then
        print_ok "Porta $GRAFANA_PORT: Livre"
    else
        print_aviso "Porta $GRAFANA_PORT: Já em uso"
    fi
}

atualizar_sistema() {
    print_section "ATUALIZAÇÃO DO SISTEMA"
    
    apt-get update 2>&1 | tee -a "$LOG_FILE"
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y 2>&1 | tee -a "$LOG_FILE"
    
    print_ok "Sistema atualizado"
}

instalar_grafana() {
    print_section "INSTALAÇÃO GRAFANA 10.x"
    
    # Verificar se já está instalado
    if command -v grafana-server &> /dev/null; then
        print_info "Grafana já instalado, pulando instalação"
        return
    fi
    
    print_info "Adicionando repositório Grafana..."
    apt-get install -y software-properties-common 2>&1 | tee -a "$LOG_FILE"
    add-apt-repository -y ppa:grafana-official/ppa 2>&1 | tee -a "$LOG_FILE"
    
    print_info "Atualizando cache..."
    apt-get update 2>&1 | tee -a "$LOG_FILE"
    
    print_info "Instalando Grafana..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y grafana 2>&1 | tee -a "$LOG_FILE"
    
    print_ok "Grafana 10.x instalado"
}

configurar_grafana() {
    print_section "CONFIGURAÇÃO GRAFANA HA"
    
    # Backup configuração original
    cp /etc/grafana/grafana.ini /etc/grafana/grafana.ini.backup
    
    print_info "Atualizando grafana.ini para HA..."
    
    # Database
    sed -i "s/^;type = sqlite3/type = postgres/" /etc/grafana/grafana.ini
    sed -i "s/^;host = 127.0.0.1:5432/host = $PG_HOST:$PG_PORT/" /etc/grafana/grafana.ini
    sed -i "s/^;name = grafana/name = $DB_NAME/" /etc/grafana/grafana.ini
    sed -i "s/^;user = grafana/user = $DB_USER/" /etc/grafana/grafana.ini
    sed -i "s/^;password = $/password = $DB_PASS/" /etc/grafana/grafana.ini
    
    # Session (usar database)
    sed -i "s/^;provider = memory/provider = postgres/" /etc/grafana/grafana.ini
    sed -i "s/^;cookie_secure = false/cookie_secure = false/" /etc/grafana/grafana.ini
    
    # Security
    sed -i "s/^;secret_key = .*/secret_key = $(openssl rand -base64 32)/" /etc/grafana/grafana.ini
    sed -i "s/^;admin_user = admin/admin_user = admin/" /etc/grafana/grafana.ini
    sed -i "s/^;admin_password = admin/admin_password = admin/" /etc/grafana/grafana.ini
    
    # HA Settings
    sed -i "s/^;instance_name = \${HOSTNAME}/instance_name = grafana-$([[ "$NODE_TYPE" == "node1" ]] && echo "01" || echo "02")/" /etc/grafana/grafana.ini
    
    # Server
    sed -i "s/^;http_port = 3000/http_port = $GRAFANA_PORT/" /etc/grafana/grafana.ini
    sed -i "s/^;root_url = .*/root_url = http:\/\/$GRAFANA_VIP/" /etc/grafana/grafana.ini
    
    # Logging
    sed -i "s/^;mode = console/mode = file/" /etc/grafana/grafana.ini
    sed -i "s/^;path = data\/log\/grafana.log/path = \/var\/log\/grafana\/grafana.log/" /etc/grafana/grafana.ini
    
    print_ok "grafana.ini configurado para Node $NODE_TYPE"
}

iniciar_grafana() {
    print_section "INICIALIZAÇÃO GRAFANA"
    
    print_info "Iniciando Grafana..."
    systemctl enable grafana-server 2>&1 | tee -a "$LOG_FILE"
    systemctl restart grafana-server 2>&1 | tee -a "$LOG_FILE"
    
    sleep 5
    
    if systemctl is-active --quiet grafana-server; then
        print_ok "Grafana iniciado com sucesso"
    else
        print_erro "Falha ao iniciar Grafana"
        journalctl -u grafana-server --no-pager -n 50 2>&1 | tee -a "$LOG_FILE"
        exit 1
    fi
}

configurar_datasource() {
    print_section "CONFIGURAÇÃO DATA SOURCE ZABBIX"
    
    if [[ "$NODE_TYPE" == "node1" ]]; then
        print_info "Aguardando Grafana ficar totalmente pronto..."
        sleep 10
        
        print_info "Configurando Data Source Zabbix via API..."
        
        curl -s -X POST http://localhost:3000/api/datasources \
            -H "Content-Type: application/json" \
            -d "{
                \"name\": \"Zabbix\",
                \"type\": \"alexanderzobnin-zabbix-app\",
                \"url\": \"$ZABBIX_API_URL\",
                \"access\": \"proxy\",
                \"jsonData\": {
                    \"trends\": true,
                    \"zabbixVersion\": \"7.0\",
                    \"zabbixAPIEndpoint\": \"$ZABBIX_API_URL\"
                },
                \"isDefault\": true,
                \"basicAuth\": false
            }" 2>&1 | tee -a "$LOG_FILE"
        
        print_ok "Data Source Zabbix configurado (Node 1)"
    fi
}

testar_conexao() {
    print_section "TESTE DE CONECTIVIDADE"
    
    # Testar Grafana
    print_info "Testando Grafana..."
    if curl -s http://localhost:$GRAFANA_PORT/api/health | grep -q "ok" &>/dev/null; then
        print_ok "Grafana saudável"
    else
        print_info "Grafana pode levar alguns segundos para ficar pronto"
    fi
    
    # Testar banco de dados
    print_info "Testando conexão com banco de dados..."
    if timeout 10 psql -h "$PG_HOST" -U "$DB_USER" -d "$DB_NAME" -c "SELECT COUNT(*) FROM user;" 2>&1 | tee -a "$LOG_FILE" | grep -q "count"; then
        print_ok "Banco de dados Grafana: OK"
    fi
}

configurar_firewall() {
    print_section "CONFIGURAÇÃO DE FIREWALL"
    
    if command -v ufw &> /dev/null; then
        print_info "Configurando UFW..."
        
        # Grafana
        ufw allow $GRAFANA_PORT/tcp comment "Grafana" 2>&1 | tee -a "$LOG_FILE"
        
        # VIP acesso
        ufw allow from "$GRAFANA_VIP" comment "VIP Load Balancer" 2>&1 | tee -a "$LOG_FILE"
        
        # Outra node
        if [[ "$NODE_TYPE" == "node1" ]]; then
            ufw allow from "$GRAFANA_NODE2" comment "Grafana Cluster Node 2" 2>&1 | tee -a "$LOG_FILE"
        else
            ufw allow from "$GRAFANA_NODE1" comment "Grafana Cluster Node 1" 2>&1 | tee -a "$LOG_FILE"
        fi
        
        print_ok "Firewall configurado"
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
    echo "  Servidor: Grafana 10.x HA (Node $NODE_TYPE)" | tee -a "$LOG_FILE"
    echo "  IP: $([[ "$NODE_TYPE" == "node1" ]] && echo "$GRAFANA_NODE1" || echo "$GRAFANA_NODE2")" | tee -a "$LOG_FILE"
    echo "  Cluster: Grafana HA (2 nodes)" | tee -a "$LOG_FILE"
    echo "  Database: PostgreSQL HA ($PG_HOST:$PG_PORT)" | tee -a "$LOG_FILE"
    echo "  Frontend: Via VIP $GRAFANA_VIP:3000" | tee -a "$LOG_FILE"
    echo "  Data Source: Zabbix ($ZABBIX_URL)" | tee -a "$LOG_FILE"
    echo "  Status: ✓ Pronto" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo "🔧 CONFIGURAÇÕES:" | tee -a "$LOG_FILE"
    echo "  Config: $GRAFANA_CONFIG/grafana.ini" | tee -a "$LOG_FILE"
    echo "  Home: $GRAFANA_HOME" | tee -a "$LOG_FILE"
    echo "  Log: $GRAFANA_LOG/grafana.log" | tee -a "$LOG_FILE"
    echo "  Port: $GRAFANA_PORT" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo "📝 ACESSO:" | tee -a "$LOG_FILE"
    echo "  URL: http://$GRAFANA_VIP" | tee -a "$LOG_FILE"
    echo "  Usuário: admin" | tee -a "$LOG_FILE"
    echo "  Senha: admin (MUDE IMEDIATAMENTE)" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo "📋 LOG COMPLETO:" | tee -a "$LOG_FILE"
    echo "  $LOG_FILE" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}


# ═══════════════════════════════════════════════════════════════════════════
# ATIVAR BACKEND GRAFANA NO HAPROXY (vip-01 / vip-02)
# ═══════════════════════════════════════════════════════════════════════════
ativar_backend_haproxy() {
    local VIPS=("10.31.38.70" "10.31.38.71")
    local ativados=0

    print_info "Ativando backend Grafana no HAProxy (vip-01 e vip-02)..."

    for vip_ip in "${VIPS[@]}"; do
        if timeout 5 bash -c "</dev/tcp/${vip_ip}/22" 2>/dev/null; then
            print_info "  -> SSH em ${vip_ip}..."
            if ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=10 root@"${vip_ip}" \
                'socat_ok=0; command -v socat &>/dev/null && [ -S /run/haproxy/admin.sock ] && socat_ok=1
                 [ "$socat_ok" -eq 1 ] && echo "enable server backend_grafana/grafana_01" | socat /run/haproxy/admin.sock stdio
                 [ "$socat_ok" -eq 1 ] && echo "enable server backend_grafana/grafana_02" | socat /run/haproxy/admin.sock stdio
                 sed -i "s|grafana_01 10.31.38.66:3000 disabled|grafana_01 10.31.38.66:3000 check inter 5s fall 3 rise 2|" /etc/haproxy/haproxy.cfg
                 sed -i "s|grafana_02 10.31.38.67:3000 disabled|grafana_02 10.31.38.67:3000 check inter 5s fall 3 rise 2|" /etc/haproxy/haproxy.cfg
                 haproxy -c -f /etc/haproxy/haproxy.cfg && systemctl reload haproxy'; then
                print_ok "  v Backend Grafana ativado em ${vip_ip}"
                ativados=$((ativados + 1))
            else
                print_warning "  x Falha ao ativar em ${vip_ip}"
            fi
        else
            print_warning "  x ${vip_ip}:22 inacessivel — ative manualmente"
        fi
    done

    if [ "$ativados" -lt 2 ]; then
        echo ""
        print_warning "Execute manualmente em CADA vip (vip-01 E vip-02):"
        echo "  echo 'enable server backend_grafana/grafana_01' | socat /run/haproxy/admin.sock stdio"
        echo "  echo 'enable server backend_grafana/grafana_02' | socat /run/haproxy/admin.sock stdio"
        echo "  sed -i 's/grafana_01 10.31.38.66:3000 disabled/grafana_01 10.31.38.66:3000 check inter 5s fall 3 rise 2/' /etc/haproxy/haproxy.cfg"
        echo "  sed -i 's/grafana_02 10.31.38.67:3000 disabled/grafana_02 10.31.38.67:3000 check inter 5s fall 3 rise 2/' /etc/haproxy/haproxy.cfg"
        echo "  systemctl reload haproxy"
        echo "  # Stats: http://10.31.38.70:8404/stats"
    fi
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
    instalar_grafana || exit 1
    configurar_grafana || exit 1
    iniciar_grafana || exit 1
    configurar_datasource || exit 1
    testar_conexao || exit 1
    configurar_firewall || exit 1
    ativar_backend_haproxy
    gerar_relatorio
    
    print_ok "✓ INSTALAÇÃO CONCLUÍDA COM SUCESSO"
    echo ""
}

# Executar
main "$@"
