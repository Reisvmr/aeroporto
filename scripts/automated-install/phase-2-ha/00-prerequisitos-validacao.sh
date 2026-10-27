#!/bin/bash

################################################################################
# Script: 00-prerequisitos-validacao.sh
# Descrição: Validação de pré-requisitos para todos os servidores HA
# Data: 27/10/2026
# Versão: 2.0 (HA)
# Autor: Aeroporto - Infraestrutura HA
#
# Uso: ./00-prerequisitos-validacao.sh <tipo_servidor>
# Tipos: postgresql-primary, postgresql-standby, zabbix-server, grafana, awx, vip
#
# Exemplo:
#   ./00-prerequisitos-validacao.sh postgresql-primary
#   ./00-prerequisitos-validacao.sh zabbix-server
#   ./00-prerequisitos-validacao.sh grafana
################################################################################

set -e

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURAÇÕES
# ═══════════════════════════════════════════════════════════════════════════

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variáveis de controle
TIPO_SERVIDOR="${1:-}"
DATA=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME_ATUAL=$(hostname)
IP_ATUAL=$(hostname -I | awk '{print $1}')
DISTRIBUICAO=$(lsb_release -d | awk -F: '{print $2}' | xargs)
VERSAO_KERNEL=$(uname -r)

# Contadores
REQUISITOS_OK=0
REQUISITOS_FALHADOS=0
AVISOS=0

# ═══════════════════════════════════════════════════════════════════════════
# FUNÇÕES
# ═══════════════════════════════════════════════════════════════════════════

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                    ║"
    echo "║         ✓ VALIDAÇÃO DE PRÉ-REQUISITOS - PROJETO AEROPORTO         ║"
    echo "║                                                                    ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_ok() {
    echo -e "${GREEN}[✓]${NC} $1"
    ((REQUISITOS_OK++))
}

print_falha() {
    echo -e "${RED}[✗]${NC} $1"
    ((REQUISITOS_FALHADOS++))
}

print_aviso() {
    echo -e "${YELLOW}[⚠]${NC} $1"
    ((AVISOS++))
}

print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ═══════════════════════════════════════════════════════════════════════════
# VALIDAÇÕES GERAIS
# ═══════════════════════════════════════════════════════════════════════════

validar_sistema_operacional() {
    print_section "VALIDAÇÃO: Sistema Operacional"
    
    # Verificar se é Linux
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        print_ok "Sistema operacional: Linux"
    else
        print_falha "Sistema operacional não é Linux (encontrado: $OSTYPE)"
        return 1
    fi
    
    # Verificar distribuição
    if [[ "$DISTRIBUICAO" == *"Ubuntu"* ]] || [[ "$DISTRIBUICAO" == *"Debian"* ]]; then
        print_ok "Distribuição: $DISTRIBUICAO"
    else
        print_aviso "Distribuição não é Ubuntu/Debian (encontrada: $DISTRIBUICAO)"
    fi
    
    # Verificar versão do kernel
    print_ok "Kernel: $VERSAO_KERNEL"
}

validar_usuario() {
    print_section "VALIDAÇÃO: Usuário e Permissões"
    
    if [[ $EUID -eq 0 ]]; then
        print_ok "Executando como root"
    else
        print_falha "Deve ser executado como root (use: sudo)"
        exit 1
    fi
}

validar_rede() {
    print_section "VALIDAÇÃO: Conectividade de Rede"
    
    print_info "Hostname: $HOSTNAME_ATUAL"
    print_info "IP Local: $IP_ATUAL"
    
    # Verificar IP estático
    if grep -q "static" /etc/netplan/*.yaml 2>/dev/null || grep -q "static" /etc/network/interfaces 2>/dev/null; then
        print_ok "IP estático configurado"
    else
        print_aviso "IP pode ser DHCP (verifique configuração manual)"
    fi
    
    # Verificar DNS
    if ping -c 1 8.8.8.8 &> /dev/null; then
        print_ok "Conectividade de rede: OK"
    else
        print_aviso "Sem conectividade com 8.8.8.8 (teste de internet)"
    fi
    
    # Verificar resolução DNS
    if ping -c 1 google.com &> /dev/null; then
        print_ok "Resolução DNS: OK"
    else
        print_aviso "Resolução DNS pode estar lenta ou offline"
    fi
}

validar_recursos() {
    print_section "VALIDAÇÃO: Recursos de Hardware"
    
    # CPU
    CPU_COUNT=$(nproc)
    print_info "CPUs: $CPU_COUNT"
    if [[ $CPU_COUNT -ge 2 ]]; then
        print_ok "CPU: $CPU_COUNT cores (mínimo 2 recomendado)"
    else
        print_aviso "CPU: Menos de 2 cores pode afetar performance"
    fi
    
    # Memória
    MEMORIA_MB=$(free -m | awk 'NR==2{print $2}')
    print_info "Memória RAM: ${MEMORIA_MB} MB"
    if [[ $MEMORIA_MB -ge 2048 ]]; then
        print_ok "Memória: ${MEMORIA_MB} MB (mínimo 2 GB recomendado)"
    else
        print_aviso "Memória: Menos de 2 GB pode afetar performance"
    fi
    
    # Disco
    DISCO_LIVRE=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    print_info "Disco livre: ${DISCO_LIVRE} GB"
    if [[ $DISCO_LIVRE -ge 20 ]]; then
        print_ok "Disco: ${DISCO_LIVRE} GB livre (mínimo 20 GB recomendado)"
    else
        print_falha "Disco: Menos de 20 GB livre"
    fi
}

validar_pacotes_basicos() {
    print_section "VALIDAÇÃO: Pacotes Base"
    
    PACOTES_NECESSARIOS=("curl" "wget" "git" "openssh-server" "openssh-client" "sudo")
    
    for pacote in "${PACOTES_NECESSARIOS[@]}"; do
        if dpkg -l | grep -q "^ii  $pacote"; then
            print_ok "Pacote: $pacote"
        else
            print_falha "Pacote faltando: $pacote"
        fi
    done
}

validar_repositorios() {
    print_section "VALIDAÇÃO: Repositórios APT"
    
    # Atualizar cache
    print_info "Verificando repositórios..."
    
    if apt-get update > /dev/null 2>&1; then
        print_ok "Repositórios APT: Acessíveis"
    else
        print_aviso "Alguns repositórios podem estar inacessíveis"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# VALIDAÇÕES ESPECÍFICAS POR SERVIDOR
# ═══════════════════════════════════════════════════════════════════════════

validar_postgresql_primary() {
    print_section "VALIDAÇÃO: PostgreSQL Primary (pg-01)"
    
    print_info "IP esperado: 10.31.38.64"
    print_info "Verificando..."
    
    # Verificar se PostgreSQL já está instalado
    if command -v psql &> /dev/null; then
        print_aviso "PostgreSQL já está instalado (pode estar em upgrade)"
        VERSAO_PG=$(psql --version)
        print_info "Versão atual: $VERSAO_PG"
    else
        print_ok "PostgreSQL não instalado (pronto para instalação fresca)"
    fi
    
    # Verificar porta 5432
    if ! ss -tlnp | grep -q ":5432 "; then
        print_ok "Porta 5432: Livre"
    else
        print_aviso "Porta 5432: Já em uso"
    fi
    
    # Verificar espaço em disco para dados
    DISCO_LIVRE=$(df -BG /var | awk 'NR==2{print $4}' | sed 's/G//')
    if [[ $DISCO_LIVRE -ge 50 ]]; then
        print_ok "Espaço /var: ${DISCO_LIVRE} GB (recomendado 50+ GB)"
    else
        print_aviso "Espaço /var: ${DISCO_LIVRE} GB (mínimo 50 GB recomendado)"
    fi
}

validar_postgresql_standby() {
    print_section "VALIDAÇÃO: PostgreSQL Standby (pg-02)"
    
    print_info "IP esperado: 10.31.38.65"
    print_info "Verificando..."
    
    # Mesmo que Primary
    if command -v psql &> /dev/null; then
        print_aviso "PostgreSQL já está instalado (pode estar em upgrade)"
    else
        print_ok "PostgreSQL não instalado (pronto para instalação fresca)"
    fi
    
    if ! ss -tlnp | grep -q ":5432 "; then
        print_ok "Porta 5432: Livre"
    else
        print_aviso "Porta 5432: Já em uso"
    fi
    
    DISCO_LIVRE=$(df -BG /var | awk 'NR==2{print $4}' | sed 's/G//')
    if [[ $DISCO_LIVRE -ge 50 ]]; then
        print_ok "Espaço /var: ${DISCO_LIVRE} GB"
    else
        print_aviso "Espaço /var: ${DISCO_LIVRE} GB (mínimo 50 GB)"
    fi
}

validar_zabbix() {
    print_section "VALIDAÇÃO: Zabbix Server (zbx-server-01/02)"
    
    print_info "IPs esperados: 10.31.38.60 / 10.31.38.61"
    print_info "Verificando..."
    
    if command -v zabbix_server &> /dev/null; then
        print_aviso "Zabbix já está instalado (pode estar em upgrade)"
    else
        print_ok "Zabbix não instalado (pronto para instalação fresca)"
    fi
    
    if ! ss -tlnp | grep -q ":10051 "; then
        print_ok "Porta 10051 (Zabbix): Livre"
    else
        print_aviso "Porta 10051: Já em uso"
    fi
}

validar_grafana() {
    print_section "VALIDAÇÃO: Grafana (grafana-01/02)"
    
    print_info "IPs esperados: 10.31.38.66 / 10.31.38.67"
    print_info "Verificando..."
    
    if command -v grafana-server &> /dev/null; then
        print_aviso "Grafana já está instalado (pode estar em upgrade)"
    else
        print_ok "Grafana não instalado (pronto para instalação fresca)"
    fi
    
    if ! ss -tlnp | grep -q ":3000 "; then
        print_ok "Porta 3000 (Grafana): Livre"
    else
        print_aviso "Porta 3000: Já em uso"
    fi
}

validar_awx() {
    print_section "VALIDAÇÃO: AWX (awx-01/02)"
    
    print_info "IPs esperados: 10.31.38.68 / 10.31.38.69"
    print_info "Verificando..."
    
    # Verificar Docker
    if command -v docker &> /dev/null; then
        VERSAO_DOCKER=$(docker --version)
        print_ok "Docker instalado: $VERSAO_DOCKER"
    else
        print_ok "Docker não instalado (será instalado)"
    fi
    
    if ! ss -tlnp | grep -q ":8080 "; then
        print_ok "Porta 8080 (AWX): Livre"
    else
        print_aviso "Porta 8080: Já em uso"
    fi
    
    # Verificar docker-compose
    if command -v docker-compose &> /dev/null; then
        VERSAO_COMPOSE=$(docker-compose --version)
        print_ok "Docker Compose instalado: $VERSAO_COMPOSE"
    else
        print_ok "Docker Compose não instalado (será instalado)"
    fi
}

validar_vip() {
    print_section "VALIDAÇÃO: VIP/Load Balancer (vip-01/02)"
    
    print_info "IPs esperados: 10.31.38.70 / 10.31.38.71"
    print_info "Verificando..."
    
    if ! ss -tlnp | grep -q ":80 "; then
        print_ok "Porta 80 (HTTP): Livre"
    else
        print_aviso "Porta 80: Já em uso"
    fi
    
    if ! ss -tlnp | grep -q ":443 "; then
        print_ok "Porta 443 (HTTPS): Livre"
    else
        print_aviso "Porta 443: Já em uso"
    fi
    
    if ! ss -tlnp | grep -q ":3000 "; then
        print_ok "Porta 3000 (Grafana): Livre"
    else
        print_aviso "Porta 3000: Já em uso"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# RESUMO FINAL
# ═══════════════════════════════════════════════════════════════════════════

imprimir_resumo() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                    ║"
    echo "║                    📊 RESUMO DA VALIDAÇÃO                         ║"
    echo "║                                                                    ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "Data:                  $DATA"
    echo -e "Hostname:              $HOSTNAME_ATUAL"
    echo -e "IP Local:              $IP_ATUAL"
    echo -e "Tipo Servidor:         ${TIPO_SERVIDOR:-Não especificado}"
    echo -e "Distribuição:          $DISTRIBUICAO"
    echo -e "Kernel:                $VERSAO_KERNEL"
    echo ""
    echo -e "${GREEN}✓ Validações OK:${NC}       $REQUISITOS_OK"
    echo -e "${RED}✗ Validações Falhadas:${NC} $REQUISITOS_FALHADOS"
    echo -e "${YELLOW}⚠ Avisos:${NC}             $AVISOS"
    echo ""
    
    if [[ $REQUISITOS_FALHADOS -eq 0 ]]; then
        echo -e "${GREEN}✓ Servidor pronto para instalação${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ Corriga os erros antes de prosseguir${NC}"
        echo ""
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════

main() {
    print_header
    
    # Validações gerais (todos os servidores)
    validar_usuario
    validar_sistema_operacional
    validar_rede
    validar_recursos
    validar_pacotes_basicos
    validar_repositorios
    
    # Validações específicas por tipo
    case "$TIPO_SERVIDOR" in
        postgresql-primary)
            validar_postgresql_primary
            ;;
        postgresql-standby)
            validar_postgresql_standby
            ;;
        zabbix-server)
            validar_zabbix
            ;;
        grafana)
            validar_grafana
            ;;
        awx)
            validar_awx
            ;;
        vip)
            validar_vip
            ;;
        *)
            if [[ -z "$TIPO_SERVIDOR" ]]; then
                print_info "Nenhum tipo especificado, validação genérica concluída"
            else
                print_falha "Tipo desconhecido: $TIPO_SERVIDOR"
                echo ""
                echo "Tipos suportados:"
                echo "  - postgresql-primary"
                echo "  - postgresql-standby"
                echo "  - zabbix-server"
                echo "  - grafana"
                echo "  - awx"
                echo "  - vip"
                exit 1
            fi
            ;;
    esac
    
    # Resumo final
    imprimir_resumo
    
    # Retornar status
    if [[ $REQUISITOS_FALHADOS -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Executar main
main "$@"
