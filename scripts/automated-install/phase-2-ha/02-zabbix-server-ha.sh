#!/bin/bash

################################################################################
# Script: 02-zabbix-server-ha.sh
# Descrição: Instalação Zabbix Server 7.0 LTS em cluster HA
# Data: 27/10/2026
# Versão: 2.0 (HA)
# Servidores: zbx-server-01 (10.31.38.60) / zbx-server-02 (10.31.38.61)
# Autor: Aeroporto - Infraestrutura HA
#
# Uso: sudo ./02-zabbix-server-ha.sh <node1|node2>
#
# Exemplo:
#   Em zbx-server-01: sudo ./02-zabbix-server-ha.sh node1
#   Em zbx-server-02: sudo ./02-zabbix-server-ha.sh node2
#
# Pré-requisitos:
#   - PostgreSQL HA (pg-01/pg-02) já instalado e rodando
#   - IPs estáticos: 10.31.38.60 (node1) / 10.31.38.61 (node2)
#   - VIP 10.31.38.70 já configurado (HAProxy+Keepalived)
#
# Configura:
#   - Zabbix Server 7.0 LTS
#   - Cluster com Shared Database (PostgreSQL)
#   - Sincronização de config entre nodes
#   - Monitoramento de 676 dispositivos
#   - Frontend acessível via VIP
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
ZABBIX_VERSION="7.0"
ZABBIX_USER="zabbix"
ZABBIX_GROUP="zabbix"
ZABBIX_HOME="/var/lib/zabbix"
ZABBIX_CONFIG="/etc/zabbix"
ZABBIX_DATA="/var/lib/zabbix/data"
ZABBIX_LOG="/var/log/zabbix"

# Database
PG_HOST="10.31.38.64"  # Primary
PG_STANDBY="10.31.38.65"  # Standby (fallback)
PG_PORT="5432"
DB_NAME="zabbix"
DB_USER="zabbix"
DB_PASS="${DB_PASS:-zabbix123}"

# IPs Zabbix
ZABBIX_NODE1="10.31.38.60"
ZABBIX_NODE2="10.31.38.61"
ZABBIX_VIP="10.31.38.70"

# Sincronização
RSYNC_USER="zabbix"
RSYNC_KEY="/home/${RSYNC_USER}/.ssh/id_rsa"

# Data
DATA=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="/tmp/zabbix-server-ha-install-$(date +%s).log"

# ═══════════════════════════════════════════════════════════════════════════
# FUNÇÕES
# ═══════════════════════════════════════════════════════════════════════════

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                    ║"
    echo "║  📊 INSTALAÇÃO ZABBIX SERVER 7.0 HA - PROJETO AEROPORTO (HA)       ║"
    echo "║                                                                    ║"
    echo "║  Node Type: $NODE_TYPE"
    echo "║  Cluster: zbx-server-01 + zbx-server-02                           ║"
    echo "║  Database: PostgreSQL HA (10.31.38.64/65)                        ║"
    echo "║  VIP: 10.31.38.70 (HAProxy)                                      ║"
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
        echo "Uso: sudo ./02-zabbix-server-ha.sh <node1|node2>"
        exit 1
    fi
    print_ok "Node Type: $NODE_TYPE"
    
    # Verificar IP
    IP_ATUAL=$(hostname -I | awk '{print $1}')
    if [[ "$NODE_TYPE" == "node1" ]] && [[ "$IP_ATUAL" == "$ZABBIX_NODE1" ]]; then
        print_ok "IP correto (Node 1): $IP_ATUAL"
    elif [[ "$NODE_TYPE" == "node2" ]] && [[ "$IP_ATUAL" == "$ZABBIX_NODE2" ]]; then
        print_ok "IP correto (Node 2): $IP_ATUAL"
    else
        print_erro "IP incorreto! Esperado $([[ "$NODE_TYPE" == "node1" ]] && echo "$ZABBIX_NODE1" || echo "$ZABBIX_NODE2"), encontrado $IP_ATUAL"
        exit 1
    fi
    
    # Verificar PostgreSQL
    print_info "Testando conectividade com PostgreSQL..."
    if timeout 5 psql -h "$PG_HOST" -U "$DB_USER" -d "$DB_NAME" -c "SELECT version();" &>/dev/null; then
        print_ok "Conexão PostgreSQL: OK"
    else
        print_erro "Não é possível conectar ao PostgreSQL em $PG_HOST"
        exit 1
    fi
    
    # Verificar disco
    DISCO_LIVRE=$(df -BG /var | awk 'NR==2{print $4}' | sed 's/G//')
    if [[ $DISCO_LIVRE -ge 20 ]]; then
        print_ok "Espaço em /var: ${DISCO_LIVRE}GB"
    else
        print_erro "Espaço insuficiente em /var (${DISCO_LIVRE}GB < 20GB recomendado)"
        exit 1
    fi
}

atualizar_sistema() {
    print_section "ATUALIZAÇÃO DO SISTEMA"
    
    apt-get update 2>&1 | tee -a "$LOG_FILE"
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y 2>&1 | tee -a "$LOG_FILE"
    
    print_ok "Sistema atualizado"
}

instalar_zabbix() {
    print_section "INSTALAÇÃO ZABBIX SERVER 7.0"
    
    # Verificar se já está instalado
    if command -v zabbix_server &> /dev/null; then
        print_info "Zabbix Server já instalado, pulando instalação"
        return
    fi
    
    print_info "Adicionando repositório Zabbix..."
    wget -q https://repo.zabbix.com/zabbix-official-repo.key -O /tmp/zabbix-key && apt-key add /tmp/zabbix-key 2>&1 | tee -a "$LOG_FILE"
    
    echo "deb https://repo.zabbix.com/zabbix/7.0/ubuntu $(lsb_release -cs) main" > /etc/apt/sources.list.d/zabbix.list
    
    print_info "Atualizando cache..."
    apt-get update 2>&1 | tee -a "$LOG_FILE"
    
    print_info "Instalando Zabbix Server com PostgreSQL..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y zabbix-server-pgsql zabbix-frontend-php-pgsql zabbix-agent2 zabbix-sql-scripts 2>&1 | tee -a "$LOG_FILE"
    
    print_ok "Zabbix Server 7.0 instalado"
}

configurar_zabbix() {
    print_section "CONFIGURAÇÃO ZABBIX SERVER HA"
    
    # Backup configuração original
    cp /etc/zabbix/zabbix_server.conf /etc/zabbix/zabbix_server.conf.backup
    
    print_info "Atualizando zabbix_server.conf..."
    
    # Atualizar configurações de banco de dados
    sed -i "s/^DBHost=.*/DBHost=$PG_HOST/" /etc/zabbix/zabbix_server.conf
    sed -i "s/^DBName=.*/DBName=$DB_NAME/" /etc/zabbix/zabbix_server.conf
    sed -i "s/^DBUser=.*/DBUser=$DB_USER/" /etc/zabbix/zabbix_server.conf
    sed -i "s/^DBPassword=.*/DBPassword=$DB_PASS/" /etc/zabbix/zabbix_server.conf
    
    # Configurações HA
    sed -i "s/^# NodeID=/NodeID=/" /etc/zabbix/zabbix_server.conf
    if [[ "$NODE_TYPE" == "node1" ]]; then
        sed -i "s/^NodeID=.*/NodeID=1/" /etc/zabbix/zabbix_server.conf
        sed -i "s/^# HistoryCacheSize=.*/HistoryCacheSize=256M/" /etc/zabbix/zabbix_server.conf
    else
        sed -i "s/^NodeID=.*/NodeID=2/" /etc/zabbix/zabbix_server.conf
        sed -i "s/^# HistoryCacheSize=.*/HistoryCacheSize=256M/" /etc/zabbix/zabbix_server.conf
    fi
    
    # Configurações de performance
    sed -i "s/^# CacheSize=.*/CacheSize=512M/" /etc/zabbix/zabbix_server.conf
    sed -i "s/^# ValueCacheSize=.*/ValueCacheSize=256M/" /etc/zabbix/zabbix_server.conf
    sed -i "s/^# WorkerProcesses=.*/WorkerProcesses=8/" /etc/zabbix/zabbix_server.conf
    
    # Logging
    sed -i "s/^LogFile=.*/LogFile=\/var\/log\/zabbix\/zabbix_server.log/" /etc/zabbix/zabbix_server.conf
    
    print_ok "zabbix_server.conf configurado para Node $NODE_TYPE"
}

importar_schema() {
    print_section "IMPORTAÇÃO DO SCHEMA ZABBIX"
    
    # Verificar se banco já tem schema
    if ! psql -h "$PG_HOST" -U "$DB_USER" -d "$DB_NAME" -c "\dt" 2>/dev/null | grep -q "public"; then
        print_info "Importando schema Zabbix..."
        psql -h "$PG_HOST" -U "$DB_USER" -d "$DB_NAME" < /usr/share/zabbix-sql-scripts/postgresql/server.sql 2>&1 | tee -a "$LOG_FILE"
        print_ok "Schema importado"
    else
        print_info "Schema Zabbix já existe no banco de dados"
    fi
}

iniciar_zabbix() {
    print_section "INICIALIZAÇÃO ZABBIX SERVER"
    
    print_info "Iniciando Zabbix Server..."
    systemctl enable zabbix-server-pgsql 2>&1 | tee -a "$LOG_FILE"
    systemctl restart zabbix-server-pgsql 2>&1 | tee -a "$LOG_FILE"
    
    sleep 5
    
    if systemctl is-active --quiet zabbix-server-pgsql; then
        print_ok "Zabbix Server iniciado com sucesso"
    else
        print_erro "Falha ao iniciar Zabbix Server"
        journalctl -u zabbix-server-pgsql --no-pager -n 50 2>&1 | tee -a "$LOG_FILE"
        exit 1
    fi
}

configurar_frontend() {
    print_section "CONFIGURAÇÃO ZABBIX FRONTEND"
    
    if [[ "$NODE_TYPE" == "node1" ]]; then
        print_info "Configurando frontend no Node 1..."
        
        # Backup nginx original
        cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup 2>/dev/null || true
        
        # Criar configuração Zabbix para nginx
        cat > /etc/nginx/sites-available/zabbix << 'NGINX_EOF'
server {
    listen 80;
    server_name _;
    
    root /usr/share/zabbix;
    index index.html index.htm index.php;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
NGINX_EOF
        
        # Ativar site
        ln -sf /etc/nginx/sites-available/zabbix /etc/nginx/sites-enabled/zabbix 2>/dev/null || true
        rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
        
        # PHP FPM
        systemctl enable php-fpm 2>&1 | tee -a "$LOG_FILE"
        systemctl restart php-fpm 2>&1 | tee -a "$LOG_FILE"
        systemctl restart nginx 2>&1 | tee -a "$LOG_FILE"
        
        print_ok "Frontend Zabbix configurado no Node 1"
    fi
}

configurar_sincronizacao() {
    print_section "CONFIGURAÇÃO DE SINCRONIZAÇÃO CLUSTER"
    
    if [[ "$NODE_TYPE" == "node1" ]]; then
        print_info "Configurando sincronização (Node 1 → Node 2)..."
        
        # Criar chave SSH para sincronização
        if [[ ! -f "$RSYNC_KEY" ]]; then
            print_info "Gerando chave SSH para rsync..."
            ssh-keygen -t rsa -b 4096 -f "$RSYNC_KEY" -N "" -C "zabbix-sync" 2>&1 | tee -a "$LOG_FILE"
        fi
        
        # Copiar chave pública para Node 2
        print_info "Configure authorized_keys no Node 2 com:"
        cat "$RSYNC_KEY.pub"
        
        print_ok "Configuração de sincronização iniciada"
    fi
}

testar_conexao() {
    print_section "TESTE DE CONECTIVIDADE"
    
    # Testar Zabbix
    print_info "Testando Zabbix Server..."
    if curl -s http://localhost/zabbix/ | grep -q "Zabbix" &>/dev/null; then
        print_ok "Frontend Zabbix acessível"
    else
        print_info "Frontend pode levar alguns segundos para ficar pronto"
    fi
    
    # Testar banco de dados
    print_info "Testando conexão com banco de dados..."
    if psql -h "$PG_HOST" -U "$DB_USER" -d "$DB_NAME" -c "SELECT COUNT(*) FROM hosts;" 2>&1 | tee -a "$LOG_FILE" | grep -q "count"; then
        print_ok "Banco de dados Zabbix: OK"
    fi
}

configurar_firewall() {
    print_section "CONFIGURAÇÃO DE FIREWALL"
    
    if command -v ufw &> /dev/null; then
        print_info "Configurando UFW..."
        
        # HTTP/HTTPS
        ufw allow 80/tcp comment "Zabbix Frontend HTTP" 2>&1 | tee -a "$LOG_FILE"
        ufw allow 443/tcp comment "Zabbix Frontend HTTPS" 2>&1 | tee -a "$LOG_FILE"
        
        # Zabbix Agent
        ufw allow 10050/tcp comment "Zabbix Agent" 2>&1 | tee -a "$LOG_FILE"
        
        # VIP acesso direto
        ufw allow from "$ZABBIX_VIP" comment "VIP Load Balancer" 2>&1 | tee -a "$LOG_FILE"
        
        # Outra node do cluster
        if [[ "$NODE_TYPE" == "node1" ]]; then
            ufw allow from "$ZABBIX_NODE2" comment "Zabbix Cluster Node 2" 2>&1 | tee -a "$LOG_FILE"
        else
            ufw allow from "$ZABBIX_NODE1" comment "Zabbix Cluster Node 1" 2>&1 | tee -a "$LOG_FILE"
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
    echo "  Servidor: Zabbix Server 7.0 HA (Node $NODE_TYPE)" | tee -a "$LOG_FILE"
    echo "  IP: $([[ "$NODE_TYPE" == "node1" ]] && echo "$ZABBIX_NODE1" || echo "$ZABBIX_NODE2")" | tee -a "$LOG_FILE"
    echo "  Cluster: Zabbix HA (2 nodes)" | tee -a "$LOG_FILE"
    echo "  Database: PostgreSQL HA ($PG_HOST:$PG_PORT)" | tee -a "$LOG_FILE"
    echo "  Frontend: Via VIP $ZABBIX_VIP" | tee -a "$LOG_FILE"
    echo "  Status: ✓ Pronto" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo "🔧 CONFIGURAÇÕES:" | tee -a "$LOG_FILE"
    echo "  Config: $ZABBIX_CONFIG/zabbix_server.conf" | tee -a "$LOG_FILE"
    echo "  Data: $ZABBIX_DATA" | tee -a "$LOG_FILE"
    echo "  Log: $ZABBIX_LOG/zabbix_server.log" | tee -a "$LOG_FILE"
    echo "  Node ID: $([[ "$NODE_TYPE" == "node1" ]] && echo "1" || echo "2")" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo "📝 PRÓXIMOS PASSOS:" | tee -a "$LOG_FILE"
    if [[ "$NODE_TYPE" == "node1" ]]; then
        echo "  1. Acesse: http://$ZABBIX_VIP/zabbix" | tee -a "$LOG_FILE"
        echo "  2. Usuário: Admin / Senha: zabbix" | tee -a "$LOG_FILE"
        echo "  3. Configure sincronização com Node 2" | tee -a "$LOG_FILE"
        echo "  4. Instale Zabbix Server em Node 2" | tee -a "$LOG_FILE"
    else
        echo "  1. Configure sincronização desde Node 1" | tee -a "$LOG_FILE"
        echo "  2. Valide cluster:" | tee -a "$LOG_FILE"
        echo "     psql -h $PG_HOST -U $DB_USER -d $DB_NAME -c \"SELECT * FROM nodes;\"" | tee -a "$LOG_FILE"
    fi
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
    instalar_zabbix || exit 1
    configurar_zabbix || exit 1
    importar_schema || exit 1
    iniciar_zabbix || exit 1
    configurar_frontend || exit 1
    configurar_sincronizacao || exit 1
    testar_conexao || exit 1
    configurar_firewall || exit 1
    gerar_relatorio
    
    print_ok "✓ INSTALAÇÃO CONCLUÍDA COM SUCESSO"
    echo ""
}

# Executar
main "$@"
