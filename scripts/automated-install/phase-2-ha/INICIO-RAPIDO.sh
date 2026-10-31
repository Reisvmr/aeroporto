#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# GUIA RÁPIDO - INICIAR INSTALAÇÃO PHASE 2 HA
# Projeto Aeroporto - 27/10/2026
# ═══════════════════════════════════════════════════════════════════════════

# Este arquivo contém os comandos para começar a instalação
# Copie e adapte conforme sua infraestrutura

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                                                                    ║"
echo "║    🚀 GUIA RÁPIDO - INSTALAÇÃO HA FASE 2 PROJETO AEROPORTO         ║"
echo "║                                                                    ║"
echo "║    Data: 27/10/2026                                               ║"
echo "║    Status: Pronto para Semana 1 (PostgreSQL HA)                   ║"
echo "║                                                                    ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# PASSO 1: COPIAR SCRIPTS PARA OS SERVIDORES
# ═══════════════════════════════════════════════════════════════════════════

echo "PASSO 1: COPIAR SCRIPTS PARA OS SERVIDORES"
echo "═════════════════════════════════════════════════════════════════════"
echo ""
echo "Execute os seguintes comandos no seu desktop/servidor de controle:"
echo ""

cat << 'EOF'
#!/bin/bash

# Substitua <usuario> pelo seu usuário SSH
USUARIO="usuario"
SCRIPTS_DIR="/home/reisvmr/.hermes/cache/scratch/aeroporto/scripts/automated-install/phase-2-ha"

echo "Copiando scripts para todos os 10 servidores..."

# pg-01 Primary
scp -r "$SCRIPTS_DIR" $USUARIO@10.31.38.64:/tmp/phase-2-ha

# pg-02 Standby
scp -r "$SCRIPTS_DIR" $USUARIO@10.31.38.65:/tmp/phase-2-ha

# vip-01 Master
scp -r "$SCRIPTS_DIR" $USUARIO@10.31.38.70:/tmp/phase-2-ha

# vip-02 Backup
scp -r "$SCRIPTS_DIR" $USUARIO@10.31.38.71:/tmp/phase-2-ha

# Zabbix, Grafana, AWX (para referência)
for ip in 10.31.38.60 10.31.38.61 10.31.38.66 10.31.38.67 10.31.38.68 10.31.38.69; do
    scp -r "$SCRIPTS_DIR" $USUARIO@$ip:/tmp/phase-2-ha
done

echo "✓ Scripts copiados para todos os servidores"
EOF

echo ""
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# PASSO 2: VALIDAR PRÉ-REQUISITOS (SEMANA 1)
# ═══════════════════════════════════════════════════════════════════════════

echo "PASSO 2: VALIDAR PRÉ-REQUISITOS (SEMANA 1)"
echo "═════════════════════════════════════════════════════════════════════"
echo ""
echo "Execute em cada servidor:"
echo ""

cat << 'EOF'
# Em pg-01:
ssh -t usuario@10.31.38.64 'cd /tmp/phase-2-ha && sudo chmod +x *.sh && sudo ./00-prerequisitos-validacao.sh postgresql-primary'

# Em pg-02:
ssh -t usuario@10.31.38.65 'cd /tmp/phase-2-ha && sudo chmod +x *.sh && sudo ./00-prerequisitos-validacao.sh postgresql-standby'

# Próximos servidores (quando chegarem em Semana 3-5):
# Zabbix, Grafana, AWX...

# VIP (não é crítico agora, mas pode validar):
ssh -t usuario@10.31.38.70 'cd /tmp/phase-2-ha && sudo chmod +x *.sh && sudo ./00-prerequisitos-validacao.sh vip'
ssh -t usuario@10.31.38.71 'cd /tmp/phase-2-ha && sudo chmod +x *.sh && sudo ./00-prerequisitos-validacao.sh vip'
EOF

echo ""
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# PASSO 3: INSTALAR POSTGRESQL HA (SEMANA 1)
# ═══════════════════════════════════════════════════════════════════════════

echo "PASSO 3: INSTALAR POSTGRESQL HA (SEMANA 1)"
echo "═════════════════════════════════════════════════════════════════════"
echo ""
echo "IMPORTANTE: Executar em ORDEM, aguardar conclusão de cada etapa"
echo ""

cat << 'EOF'
# ETAPA 1: PostgreSQL Primary em pg-01 (demora ~10 minutos)
echo "Instalando PostgreSQL Primary em pg-01..."
ssh -t usuario@10.31.38.64 'cd /tmp/phase-2-ha && sudo ./01-postgresql-primary.sh'

echo "✓ PostgreSQL Primary instalado em pg-01"
echo ""
echo "Aguarde 2-3 minutos antes de prosseguir..."
sleep 180

# ETAPA 2: PostgreSQL Standby em pg-02 (demora ~15 minutos, inclui base backup)
echo "Instalando PostgreSQL Standby em pg-02..."
ssh -t usuario@10.31.38.65 'cd /tmp/phase-2-ha && sudo ./02-postgresql-standby.sh'

echo "✓ PostgreSQL Standby instalado em pg-02"
echo ""
echo "Aguarde 2-3 minutos para sincronização..."
sleep 180

# ETAPA 3: Validar replicação
echo "Validando replicação..."
ssh -t usuario@10.31.38.64 'sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"'

echo ""
echo "✓ SEMANA 1 CONCLUÍDA - PostgreSQL HA operacional"
EOF

echo ""
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# PASSO 4: INSTALAR VIP/LOAD BALANCER (SEMANA 2)
# ═══════════════════════════════════════════════════════════════════════════

echo "PASSO 4: INSTALAR VIP/LOAD BALANCER (SEMANA 2)"
echo "═════════════════════════════════════════════════════════════════════"
echo ""
echo "IMPORTANTE: Executar em ORDEM, vip-01 ANTES de vip-02"
echo ""

cat << 'EOF'
# ETAPA 1: HAProxy+Keepalived Master em vip-01 (demora ~8 minutos)
echo "Instalando HAProxy+Keepalived Master em vip-01..."
ssh -t usuario@10.31.38.70 'cd /tmp/phase-2-ha && sudo ./03-vip-haproxy-keepalived.sh master'

echo "✓ HAProxy+Keepalived Master instalado em vip-01"
echo ""
echo "Aguarde 2 minutos..."
sleep 120

# ETAPA 2: HAProxy+Keepalived Backup em vip-02 (demora ~8 minutos)
echo "Instalando HAProxy+Keepalived Backup em vip-02..."
ssh -t usuario@10.31.38.71 'cd /tmp/phase-2-ha && sudo ./03-vip-haproxy-keepalived.sh backup'

echo "✓ HAProxy+Keepalived Backup instalado em vip-02"
echo ""

# ETAPA 3: Validar VIP
echo "Validando VIP..."
ssh -t usuario@10.31.38.70 'ip addr | grep 10.31.38.70'
ssh -t usuario@10.31.38.70 'curl -s http://localhost:8081/stats | head -20'

echo ""
echo "✓ SEMANA 2 CONCLUÍDA - VIP/Load Balancer HA operacional"
EOF

echo ""
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# RESUMO
# ═══════════════════════════════════════════════════════════════════════════

echo "═════════════════════════════════════════════════════════════════════"
echo "📊 RESUMO - INSTALAÇÃO POSTGRESQL HA + VIP/LB"
echo "═════════════════════════════════════════════════════════════════════"
echo ""
echo "SEMANA 1: PostgreSQL HA (~8 horas)"
echo "  ✓ Instalar PostgreSQL Primary em pg-01"
echo "  ✓ Instalar PostgreSQL Standby em pg-02"
echo "  ✓ Validar replicação (pg_stat_replication)"
echo ""
echo "SEMANA 2: VIP/Load Balancer (~6 horas)"
echo "  ✓ Instalar HAProxy+Keepalived Master em vip-01"
echo "  ✓ Instalar HAProxy+Keepalived Backup em vip-02"
echo "  ✓ Validar VIP ativo (ip addr | grep 10.31.38.72)"
echo ""
echo "PRÓXIMAS SEMANAS: Zabbix/Grafana/AWX HA (Scripts a criar)"
echo ""
echo "═════════════════════════════════════════════════════════════════════"
echo ""
echo "✅ Scripts prontos em:"
echo "   /home/reisvmr/.hermes/cache/scratch/aeroporto/scripts/automated-install/phase-2-ha/"
echo ""
echo "📖 Documentação completa em:"
echo "   README.md (no mesmo diretório)"
echo ""
echo "═════════════════════════════════════════════════════════════════════"
