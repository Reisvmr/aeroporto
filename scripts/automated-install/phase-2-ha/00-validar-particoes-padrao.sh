#!/bin/bash

################################################################################
# Script: 00-validar-particoes-padrao.sh
# Descrição: Valida se a estrutura de partições segue o padrão documentado
# Data: 28/10/2026
# Versão: 1.0
# Autor: Aeroporto - Infraestrutura HA
#
# Uso: ./00-validar-particoes-padrao.sh <tipo_servidor>
# Tipos: postgresql-primary, postgresql-standby, zabbix-server, zabbix-frontend, 
#        grafana, awx, vip
#
# Exemplo:
#   ./00-validar-particoes-padrao.sh postgresql-primary
#   ./00-validar-particoes-padrao.sh zabbix-server
#   ./00-validar-particoes-padrao.sh grafana
#   ./00-validar-particoes-padrao.sh awx
#   ./00-validar-particoes-padrao.sh vip
################################################################################

set -e

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURAÇÕES
# ═══════════════════════════════════════════════════════════════════════════

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variáveis
HOSTNAME_ATUAL=$(hostname)
IP_ATUAL=$(hostname -I | awk '{print $1}')
DATA=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="/tmp/validacao-particoes-$(date +%s).log"

# Detectar tipo de servidor automaticamente do hostname se não foi passado argumento
TIPO_SERVIDOR="${1:-}"

if [ -z "$TIPO_SERVIDOR" ]; then
    # Detectar automaticamente pelo hostname
    case "$HOSTNAME_ATUAL" in
        pg-01)
            TIPO_SERVIDOR="postgresql-primary"
            ;;
        pg-02)
            TIPO_SERVIDOR="postgresql-standby"
            ;;
        zbx-server-01|zbx-server-02)
            TIPO_SERVIDOR="zabbix-server"
            ;;
        zbx-fe-01|zbx-fe-02)
            TIPO_SERVIDOR="zabbix-frontend"
            ;;
        grafana-01|grafana-02)
            TIPO_SERVIDOR="grafana"
            ;;
        awx-01|awx-02)
            TIPO_SERVIDOR="awx"
            ;;
        vip-01|vip-02)
            TIPO_SERVIDOR="vip"
            ;;
        *)
            TIPO_SERVIDOR="desconhecido"
            ;;
    esac
fi

# Contadores
CHECKS_OK=0
CHECKS_FALHOS=0
WARNINGS=0

# ═══════════════════════════════════════════════════════════════════════════
# FUNÇÕES
# ═══════════════════════════════════════════════════════════════════════════

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                    ║"
    echo "║      ✓ VALIDAÇÃO DE PARTIÇÕES - PADRÃO DOCUMENTADO               ║"
    echo "║                                                                    ║"
    echo "║         Projeto Aeroporto - Phase 2 HA                           ║"
    echo "║         Data: $(date '+%d/%m/%Y %H:%M:%S')                              ║"
    echo "║                                                                    ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_ok() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
    ((CHECKS_OK++))
}

print_error() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"
    ((CHECKS_FALHOS++))
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1" | tee -a "$LOG_FILE"
    ((WARNINGS++))
}

print_section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Verifica se montagem existe e tem tamanho esperado
check_mount_size() {
    local mount_point="$1"
    local expected_size_gb="$2"
    local tolerance_percent="${3:-10}"  # 10% por padrão
    
    if ! mountpoint -q "$mount_point" 2>/dev/null; then
        print_error "Ponto de montagem não existe: $mount_point"
        return 1
    fi
    
    local actual_size_gb=$(df -BG "$mount_point" | tail -1 | awk '{print $2}' | sed 's/G//')
    local min_size=$((expected_size_gb * (100 - tolerance_percent) / 100))
    local max_size=$((expected_size_gb * (100 + tolerance_percent) / 100))
    
    if [ "$actual_size_gb" -ge "$min_size" ] && [ "$actual_size_gb" -le "$max_size" ]; then
        print_ok "$mount_point: ${actual_size_gb}GB (esperado: ~${expected_size_gb}GB)"
        return 0
    else
        print_warning "$mount_point: ${actual_size_gb}GB (esperado: ~${expected_size_gb}GB, tolerância: ±${tolerance_percent}%)"
        return 1
    fi
}

# Verifica se filesystem é XFS
check_filesystem_xfs() {
    local mount_point="$1"
    
    local fs_type=$(df -T "$mount_point" | tail -1 | awk '{print $2}')
    
    if [ "$fs_type" = "xfs" ]; then
        print_ok "$mount_point: XFS ✓"
        return 0
    elif [ "$mount_point" = "/boot" ] && [ "$fs_type" = "ext4" ]; then
        print_ok "$mount_point: ext4 (OK para /boot)"
        return 0
    elif [ "$mount_point" = "/boot/efi" ] && [ "$fs_type" = "vfat" ]; then
        print_ok "$mount_point: vfat/FAT32 (OK para EFI)"
        return 0
    else
        print_warning "$mount_point: $fs_type (esperado: xfs)"
        return 1
    fi
}

# Valida LVM
check_lvm() {
    print_section "VALIDAÇÃO: Estrutura LVM"
    
    # Verificar PVs
    if command -v pvs &> /dev/null; then
        print_info "Physical Volumes (pvs):"
        pvs 2>/dev/null | tee -a "$LOG_FILE" || print_warning "Comando pvs não disponível"
    fi
    
    # Verificar VGs
    if command -v vgs &> /dev/null; then
        print_info "Volume Groups (vgs):"
        vgs 2>/dev/null | tee -a "$LOG_FILE" || print_warning "Comando vgs não disponível"
    fi
    
    # Verificar LVs
    if command -v lvs &> /dev/null; then
        print_info "Logical Volumes (lvs):"
        lvs 2>/dev/null | tee -a "$LOG_FILE" || print_warning "Comando lvs não disponível"
    fi
}

# Valida partições GPT
check_gpt() {
    print_section "VALIDAÇÃO: Tabela de Partições GPT"
    
    local discos=$(lsblk -d -n -o NAME,TYPE | grep disk | awk '{print $1}')
    
    if [ -z "$discos" ]; then
        print_error "Nenhum disco encontrado"
        return 1
    fi
    
    for disco in $discos; do
        local tipo=$(parted -s /dev/$disco print 2>/dev/null | grep "Partition Table:" | awk '{print $NF}')
        
        if [ "$tipo" = "gpt" ]; then
            print_ok "/dev/$disco: GPT ✓"
        else
            print_warning "/dev/$disco: $tipo (esperado: gpt)"
        fi
    done
}

# Valida fstab
check_fstab_uuids() {
    print_section "VALIDAÇÃO: /etc/fstab com UUIDs"
    
    local uuid_count=$(grep -c "UUID=" /etc/fstab || true)
    local total_lines=$(grep -c -v "^#\|^$" /etc/fstab || true)
    
    if [ "$uuid_count" -gt 0 ]; then
        print_ok "/etc/fstab: $uuid_count montagens com UUID"
    else
        print_warning "/etc/fstab: nenhuma montagem com UUID (verifique se está bem configurado)"
    fi
}

# Valida swap
check_swap() {
    print_section "VALIDAÇÃO: Swap"
    
    if command -v swapon &> /dev/null; then
        swapon --show 2>/dev/null | tee -a "$LOG_FILE"
        local swap_size=$(free -h | grep Swap | awk '{print $2}')
        print_ok "Swap configurado: $swap_size"
    else
        print_warning "Comando swapon não disponível"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# VALIDAÇÕES POR TIPO DE SERVIDOR
# ═══════════════════════════════════════════════════════════════════════════

validate_postgresql_primary() {
    print_section "VALIDAÇÃO: PostgreSQL Primary (pg-01)"
    
    print_info "Padrão esperado (1 TB): /var/lib/pgsql/16/data=650GB, /pgwal=90GB, /pgarchive=55GB"
    print_info "Padrão esperado (800GB): /var/lib/pgsql/16/data=475GB, /pgwal=75GB, /pgarchive=50GB"
    
    # Sistema
    check_mount_size "/" 38 15
    check_mount_size "/boot" 1 20
    check_mount_size "/boot/efi" 0.6 20
    check_mount_size "/var/log" 10 20
    
    # Dados PostgreSQL
    if mountpoint -q /var/lib/pgsql/16/data 2>/dev/null; then
        check_mount_size "/var/lib/pgsql/16/data" 475 20  # 800GB config
    elif mountpoint -q /var/lib/pgsql/16/data 2>/dev/null; then
        check_mount_size "/var/lib/pgsql/16/data" 650 20  # 1TB config
    else
        print_warning "/var/lib/pgsql/16/data não está montado"
    fi
    
    # WAL e Archive
    check_mount_size "/pgwal" 75 20
    check_mount_size "/pgarchive" 50 20
    
    # Verificar filesystems
    print_section "VALIDAÇÃO: Tipos de Filesystem"
    check_filesystem_xfs "/"
    check_filesystem_xfs "/var/log"
    check_filesystem_xfs "/var/lib/pgsql/16/data"
    check_filesystem_xfs "/pgwal"
    check_filesystem_xfs "/pgarchive"
    check_filesystem_xfs "/boot"
}

validate_postgresql_standby() {
    validate_postgresql_primary  # Mesmo padrão
}

validate_zabbix_server() {
    print_section "VALIDAÇÃO: Zabbix Server (zbx-server-01/02)"
    
    print_info "Padrão esperado (120GB): /var/log=10GB, /var/log/zabbix=18GB, /var/lib/zabbix=14GB, /opt=14GB"
    
    # Sistema
    check_mount_size "/" 28 15
    check_mount_size "/boot" 1 20
    check_mount_size "/boot/efi" 0.6 20
    
    # Dados Zabbix
    check_mount_size "/var/log" 10 20
    check_mount_size "/var/log/zabbix" 18 20
    check_mount_size "/var/lib/zabbix" 14 20
    check_mount_size "/opt" 14 20
    
    # Filesystems
    print_section "VALIDAÇÃO: Tipos de Filesystem"
    check_filesystem_xfs "/"
    check_filesystem_xfs "/var/log"
    check_filesystem_xfs "/opt"
}

validate_zabbix_frontend() {
    print_section "VALIDAÇÃO: Zabbix Frontend (zbx-fe-01/02)"
    
    print_info "Padrão esperado (40GB): /var/log=4GB, /var/www=3GB"
    
    # Sistema
    check_mount_size "/" 20 15
    check_mount_size "/boot" 1 20
    check_mount_size "/boot/efi" 0.6 20
    
    # Dados Zabbix Frontend
    check_mount_size "/var/log" 4 20
    if mountpoint -q /var/www 2>/dev/null; then
        check_mount_size "/var/www" 3 20
    else
        print_warning "/var/www não está montado (verifique se é necessário)"
    fi
    
    # Filesystems
    print_section "VALIDAÇÃO: Tipos de Filesystem"
    check_filesystem_xfs "/"
    check_filesystem_xfs "/var/log"
}

validate_grafana() {
    print_section "VALIDAÇÃO: Grafana (grafana-01/02)"
    
    print_info "Padrão esperado (50GB): /var/lib/grafana=11GB, /var/log/grafana=5GB"
    
    # Sistema
    check_mount_size "/" 20 15
    check_mount_size "/boot" 1 20
    check_mount_size "/boot/efi" 0.6 20
    
    # Dados Grafana
    check_mount_size "/var/lib/grafana" 11 20
    check_mount_size "/var/log/grafana" 5 20
    
    # Filesystems
    print_section "VALIDAÇÃO: Tipos de Filesystem"
    check_filesystem_xfs "/"
    check_filesystem_xfs "/var/lib/grafana"
    check_filesystem_xfs "/var/log/grafana"
}

validate_awx() {
    print_section "VALIDAÇÃO: AWX (awx-01/02)"
    
    print_info "Padrão esperado (150GB): /var/lib/rancher/k3s=55GB, /var/log=10GB, /data/awx=20GB"
    
    # Sistema
    check_mount_size "/" 32 15
    check_mount_size "/boot" 1 20
    check_mount_size "/boot/efi" 0.6 20
    
    # Dados AWX
    check_mount_size "/var/lib/rancher/k3s" 55 20
    check_mount_size "/var/log" 10 20
    check_mount_size "/data/awx" 20 20
    
    # Filesystems
    print_section "VALIDAÇÃO: Tipos de Filesystem"
    check_filesystem_xfs "/"
    check_filesystem_xfs "/var/lib/rancher/k3s"
    check_filesystem_xfs "/var/log"
    check_filesystem_xfs "/data/awx"
}

validate_vip() {
    print_section "VALIDAÇÃO: VIP/Proxy (vip-01/02)"
    
    print_info "Padrão esperado (30GB): /var/log=5GB, /opt/proxy=2GB"
    
    # Sistema
    check_mount_size "/" 12 15
    check_mount_size "/boot" 1 20
    check_mount_size "/boot/efi" 0.6 20
    
    # Dados VIP
    check_mount_size "/var/log" 5 20
    check_mount_size "/opt/proxy" 2 20
    
    # Filesystems
    print_section "VALIDAÇÃO: Tipos de Filesystem"
    check_filesystem_xfs "/"
    check_filesystem_xfs "/var/log"
    check_filesystem_xfs "/opt/proxy"
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════

main() {
    print_header
    
    print_info "Hostname: $HOSTNAME_ATUAL"
    print_info "IP: $IP_ATUAL"
    print_info "Log: $LOG_FILE"
    print_info "Tipo de Servidor: $TIPO_SERVIDOR"
    
    # Validações gerais
    check_gpt
    check_lvm
    check_fstab_uuids
    check_swap
    
    # Validações específicas por tipo
    case "$TIPO_SERVIDOR" in
        postgresql-primary)
            validate_postgresql_primary
            ;;
        postgresql-standby)
            validate_postgresql_standby
            ;;
        zabbix-server)
            validate_zabbix_server
            ;;
        zabbix-frontend)
            validate_zabbix_frontend
            ;;
        grafana)
            validate_grafana
            ;;
        awx)
            validate_awx
            ;;
        vip)
            validate_vip
            ;;
        *)
            print_error "Tipo de servidor inválido: $TIPO_SERVIDOR"
            echo "Tipos válidos: postgresql-primary, postgresql-standby, zabbix-server, zabbix-frontend, grafana, awx, vip"
            exit 1
            ;;
    esac
    
    # Resumo
    print_section "RESUMO"
    echo ""
    echo "Checks OK:     $CHECKS_OK"
    echo "Checks Falhos: $CHECKS_FALHOS"
    echo "Warnings:      $WARNINGS"
    echo ""
    
    if [ $CHECKS_FALHOS -eq 0 ]; then
        echo -e "${GREEN}✓ VALIDAÇÃO COMPLETA - SEM ERROS${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ VALIDAÇÃO COM ERROS - REVISE ANTES DE PROSSEGUIR${NC}"
        echo ""
        return 1
    fi
}

# Executar
if [ "$EUID" -ne 0 ]; then
    print_error "Este script deve ser executado como root"
    exit 1
fi

main "$@"
