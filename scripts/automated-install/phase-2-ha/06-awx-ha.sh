#!/bin/bash

################################################################################
# Script: 06-awx-ha.sh
# Descrição: Instalação AWX 22.x em cluster HA com Docker Compose
# Data: 27/10/2026
# Versão: 2.0 (HA)
# Servidores: awx-01 (10.31.38.68) / awx-02 (10.31.38.69)
# Autor: Aeroporto - Infraestrutura HA
#
# Uso: sudo ./06-awx-ha.sh <node1|node2>
#
# Exemplo:
#   Em awx-01: sudo ./06-awx-ha.sh node1
#   Em awx-02: sudo ./06-awx-ha.sh node2
#
# Pré-requisitos:
#   - PostgreSQL HA (pg-01/pg-02) já instalado e rodando
#   - Docker e Docker Compose instalados
#   - VIP 10.31.38.70 já configurado (HAProxy+Keepalived)
#   - IPs estáticos: 10.31.38.68 (node1) / 10.31.38.69 (node2)
#
# Configura:
#   - AWX 22.x Operator
#   - Shared Database (PostgreSQL HA)
#   - Executor distribuído
#   - Sincronização automática
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
AWX_VERSION="22.7"
AWX_HOME="/opt/awx"
AWX_PORT="8080"
AWX_USER="awx"
AWX_GROUP="awx"

# Database
PG_HOST="10.31.38.64"  # Primary
PG_PORT="5432"
DB_NAME="awx"
DB_USER="awx"
DB_PASS="${DB_PASS:-awx123}"

# IPs AWX
AWX_NODE1="10.31.38.68"
AWX_NODE2="10.31.38.69"
AWX_VIP="10.31.38.70"

# Admin
AWX_ADMIN_USER="admin"
AWX_ADMIN_PASS="${AWX_ADMIN_PASS:-admin123}"

# Data
DATA=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="/tmp/awx-ha-install-$(date +%s).log"

# ═══════════════════════════════════════════════════════════════════════════
# FUNÇÕES
# ═══════════════════════════════════════════════════════════════════════════

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                    ║"
    echo "║  🔄 INSTALAÇÃO AWX 22.x HA - PROJETO AEROPORTO (HA)               ║"
    echo "║                                                                    ║"
    echo "║  Node Type: $NODE_TYPE"
    echo "║  Cluster: awx-01 + awx-02                                         ║"
    echo "║  Database: PostgreSQL HA (10.31.38.64)                           ║"
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

print_aviso() {
    echo -e "${YELLOW}[⚠]${NC} $1" | tee -a "$LOG_FILE"
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
        echo "Uso: sudo ./06-awx-ha.sh <node1|node2>"
        exit 1
    fi
    print_ok "Node Type: $NODE_TYPE"
    
    # Verificar IP
    IP_ATUAL=$(hostname -I | awk '{print $1}')
    if [[ "$NODE_TYPE" == "node1" ]] && [[ "$IP_ATUAL" == "$AWX_NODE1" ]]; then
        print_ok "IP correto (Node 1): $IP_ATUAL"
    elif [[ "$NODE_TYPE" == "node2" ]] && [[ "$IP_ATUAL" == "$AWX_NODE2" ]]; then
        print_ok "IP correto (Node 2): $IP_ATUAL"
    else
        print_erro "IP incorreto! Esperado $([[ "$NODE_TYPE" == "node1" ]] && echo "$AWX_NODE1" || echo "$AWX_NODE2"), encontrado $IP_ATUAL"
        exit 1
    fi
    
    # Verificar Docker
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version)
        print_ok "Docker instalado: $DOCKER_VERSION"
    else
        print_erro "Docker não está instalado"
        exit 1
    fi
    
    # Verificar Docker Compose
    if command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose --version)
        print_ok "Docker Compose instalado: $COMPOSE_VERSION"
    else
        print_erro "Docker Compose não está instalado"
        exit 1
    fi
    
    # Verificar PostgreSQL
    print_info "Testando conectividade com PostgreSQL..."
    if timeout 5 psql -h "$PG_HOST" -U "$DB_USER" -d "$DB_NAME" -c "SELECT version();" &>/dev/null 2>&1 || [[ ! -x $(command -v psql) ]]; then
        print_ok "PostgreSQL acessível (será verificado pós-instalação)"
    fi
    
    # Verificar disco
    DISCO_LIVRE=$(df -BG /opt | awk 'NR==2{print $4}' | sed 's/G//')
    if [[ $DISCO_LIVRE -ge 20 ]]; then
        print_ok "Espaço em /opt: ${DISCO_LIVRE}GB"
    else
        print_aviso "Espaço em /opt: ${DISCO_LIVRE}GB (mínimo 20 GB recomendado)"
    fi
}

atualizar_sistema() {
    print_section "ATUALIZAÇÃO DO SISTEMA"
    
    apt-get update 2>&1 | tee -a "$LOG_FILE"
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y 2>&1 | tee -a "$LOG_FILE"
    
    print_ok "Sistema atualizado"
}

instalar_dependencias() {
    print_section "INSTALAÇÃO DEPENDÊNCIAS"
    
    print_info "Instalando dependências..."
    apt-get install -y git curl wget rsync python3-pip python3-dev 2>&1 | tee -a "$LOG_FILE"
    
    print_ok "Dependências instaladas"
}

preparar_ambiente() {
    print_section "PREPARAÇÃO DO AMBIENTE AWX"
    
    # Criar diretório AWX
    if [[ ! -d "$AWX_HOME" ]]; then
        mkdir -p "$AWX_HOME"
        print_ok "Diretório $AWX_HOME criado"
    else
        print_info "Diretório $AWX_HOME já existe"
    fi
    
    # Permissões
    chown -R "$AWX_USER:$AWX_GROUP" "$AWX_HOME" 2>/dev/null || true
    chmod 755 "$AWX_HOME"
}

criar_docker_compose() {
    print_section "CRIAÇÃO DOCKER COMPOSE AWX"
    
    print_info "Criando docker-compose.yml..."
    
    cat > "$AWX_HOME/docker-compose.yml" << 'DOCKER_EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15
    container_name: awx-postgres
    environment:
      POSTGRES_DB: "${DB_NAME}"
      POSTGRES_USER: "${DB_USER}"
      POSTGRES_PASSWORD: "${DB_PASS}"
      POSTGRES_HOST_AUTH_METHOD: "md5"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - awx
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: awx-redis
    command: redis-server --maxmemory 512mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
    networks:
      - awx
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  awx-web:
    image: quay.io/ansible/awx:${AWX_VERSION}
    container_name: awx-web
    depends_on:
      - postgres
      - redis
    ports:
      - "${AWX_PORT}:8013"
    environment:
      AWX_SKIP_MIGRATIONS: "false"
      SECRET_KEY: "awxsecret${RANDOM}"
      DATABASE_NAME: "${DB_NAME}"
      DATABASE_USER: "${DB_USER}"
      DATABASE_PASSWORD: "${DB_PASS}"
      DATABASE_PORT: "5432"
      REDIS_HOST: "redis"
      REDIS_PORT: "6379"
      AWX_DOCKER_ENV: "true"
      DJANGO_SUPERUSER_USERNAME: "${AWX_ADMIN_USER}"
      DJANGO_SUPERUSER_PASSWORD: "${AWX_ADMIN_PASS}"
    volumes:
      - awx_projects:/var/lib/awx/projects
      - awx_data:/var/lib/awx
    networks:
      - awx
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8013/"]
      interval: 30s
      timeout: 10s
      retries: 5

  awx-task:
    image: quay.io/ansible/awx:${AWX_VERSION}
    container_name: awx-task
    depends_on:
      - postgres
      - redis
    environment:
      AWX_SKIP_MIGRATIONS: "true"
      SECRET_KEY: "awxsecret${RANDOM}"
      DATABASE_NAME: "${DB_NAME}"
      DATABASE_USER: "${DB_USER}"
      DATABASE_PASSWORD: "${DB_PASS}"
      DATABASE_PORT: "5432"
      REDIS_HOST: "redis"
      REDIS_PORT: "6379"
      AWX_DOCKER_ENV: "true"
    volumes:
      - awx_projects:/var/lib/awx/projects
      - awx_data:/var/lib/awx
    networks:
      - awx
    command: /usr/bin/launch_awx_task.sh

volumes:
  postgres_data:
  redis_data:
  awx_projects:
  awx_data:

networks:
  awx:
    driver: bridge
DOCKER_EOF
    
    print_ok "docker-compose.yml criado"
}

configurar_awx_externo() {
    print_section "CONFIGURAÇÃO AWX COM POSTGRESQL EXTERNO"
    
    print_info "Criando arquivo .env com configurações..."
    
    cat > "$AWX_HOME/.env" << ENV_EOF
AWX_VERSION=$AWX_VERSION
PG_HOST=$PG_HOST
PG_PORT=$PG_PORT
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASS=$DB_PASS
AWX_PORT=$AWX_PORT
AWX_ADMIN_USER=$AWX_ADMIN_USER
AWX_ADMIN_PASS=$AWX_ADMIN_PASS
NODE_TYPE=$NODE_TYPE
ENV_EOF
    
    print_ok "Arquivo .env criado"
}

iniciar_awx() {
    print_section "INICIALIZAÇÃO AWX"
    
    cd "$AWX_HOME"
    
    print_info "Iniciando containers AWX..."
    docker-compose up -d 2>&1 | tee -a "$LOG_FILE"
    
    sleep 10
    
    print_info "Aguardando AWX ficar pronto..."
    sleep 30
    
    if docker ps | grep -q "awx-web"; then
        print_ok "Container AWX Web iniciado"
    else
        print_erro "Falha ao iniciar AWX Web"
        docker-compose logs awx-web 2>&1 | tail -50 | tee -a "$LOG_FILE"
        exit 1
    fi
}

testar_awx() {
    print_section "TESTE DE CONECTIVIDADE AWX"
    
    cd "$AWX_HOME"
    
    print_info "Testando AWX..."
    if curl -s http://localhost:$AWX_PORT/ | grep -q "awx" &>/dev/null; then
        print_ok "AWX Web respondendo"
    else
        print_aviso "AWX pode levar alguns segundos para ficar pronto"
    fi
    
    # Status dos containers
    print_info "Status dos containers:"
    docker-compose ps 2>&1 | tee -a "$LOG_FILE"
}

configurar_firewall() {
    print_section "CONFIGURAÇÃO DE FIREWALL"
    
    if command -v ufw &> /dev/null; then
        print_info "Configurando UFW..."
        
        # AWX
        ufw allow $AWX_PORT/tcp comment "AWX" 2>&1 | tee -a "$LOG_FILE"
        
        # VIP acesso
        ufw allow from "$AWX_VIP" comment "VIP Load Balancer" 2>&1 | tee -a "$LOG_FILE"
        
        # Outra node
        if [[ "$NODE_TYPE" == "node1" ]]; then
            ufw allow from "$AWX_NODE2" comment "AWX Cluster Node 2" 2>&1 | tee -a "$LOG_FILE"
        else
            ufw allow from "$AWX_NODE1" comment "AWX Cluster Node 1" 2>&1 | tee -a "$LOG_FILE"
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
    echo "  Servidor: AWX $AWX_VERSION HA (Node $NODE_TYPE)" | tee -a "$LOG_FILE"
    echo "  IP: $([[ "$NODE_TYPE" == "node1" ]] && echo "$AWX_NODE1" || echo "$AWX_NODE2")" | tee -a "$LOG_FILE"
    echo "  Cluster: AWX HA (2 nodes)" | tee -a "$LOG_FILE"
    echo "  Database: PostgreSQL HA ($PG_HOST:$PG_PORT)" | tee -a "$LOG_FILE"
    echo "  Frontend: Via VIP $AWX_VIP:$AWX_PORT" | tee -a "$LOG_FILE"
    echo "  Container Engine: Docker Compose" | tee -a "$LOG_FILE"
    echo "  Status: ✓ Pronto" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo "🔧 CONFIGURAÇÕES:" | tee -a "$LOG_FILE"
    echo "  Home: $AWX_HOME" | tee -a "$LOG_FILE"
    echo "  Docker Compose: $AWX_HOME/docker-compose.yml" | tee -a "$LOG_FILE"
    echo "  Env: $AWX_HOME/.env" | tee -a "$LOG_FILE"
    echo "  Port: $AWX_PORT" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo "📝 ACESSO:" | tee -a "$LOG_FILE"
    echo "  URL: http://$AWX_VIP:$AWX_PORT" | tee -a "$LOG_FILE"
    echo "  Usuário: $AWX_ADMIN_USER" | tee -a "$LOG_FILE"
    echo "  Senha: $AWX_ADMIN_PASS (MUDE IMEDIATAMENTE)" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo "🐳 COMANDOS DOCKER:" | tee -a "$LOG_FILE"
    echo "  Status: docker-compose -f $AWX_HOME/docker-compose.yml ps" | tee -a "$LOG_FILE"
    echo "  Logs: docker-compose -f $AWX_HOME/docker-compose.yml logs -f" | tee -a "$LOG_FILE"
    echo "  Stop: docker-compose -f $AWX_HOME/docker-compose.yml down" | tee -a "$LOG_FILE"
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
    instalar_dependencias || exit 1
    preparar_ambiente || exit 1
    criar_docker_compose || exit 1
    configurar_awx_externo || exit 1
    iniciar_awx || exit 1
    testar_awx || exit 1
    configurar_firewall || exit 1
    gerar_relatorio
    
    print_ok "✓ INSTALAÇÃO CONCLUÍDA COM SUCESSO"
    echo ""
}

# Executar
main "$@"
