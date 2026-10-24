# 📦 GUIA DE INSTALAÇÃO - ZABBIX 7.0 LTS FASE 1

**Projeto:** Aeroporto - Zabbix + PostgreSQL  
**Data:** 24/10/2026  
**Versão:** 1.0  
**Status:** Completo e pronto para execução  

---

## 📋 Índice

1. [Visão Geral](#visão-geral)
2. [Pré-requisitos](#pré-requisitos)
3. [Estrutura de Diretórios](#estrutura-de-diretórios)
4. [Instalação Passo a Passo](#instalação-passo-a-passo)
5. [Validação](#validação)
6. [Troubleshooting](#troubleshooting)
7. [Pós-Instalação](#pós-instalação)
8. [Preparação para Fase 2 (HA)](#preparação-para-fase-2-ha)

---

## Visão Geral

Esta instalação implanta **Zabbix 7.0 LTS** em três servidores separados:

| Servidor | IP | Função | SO |
|----------|----|----|-----|
| **pg-01** | 10.31.38.64 | PostgreSQL 16 Primary | Ubuntu/CentOS |
| **zbx-server-01** | 10.31.38.60 | Zabbix Server | Ubuntu/CentOS |
| **zbx-fe-01** | 10.31.38.62 | Zabbix Frontend | Ubuntu/CentOS |

**Ordem obrigatória de instalação:**
```
1️⃣  PostgreSQL 16 (pg-01)
    ↓
2️⃣  Zabbix Server (zbx-server-01)
    ↓
3️⃣  Zabbix Frontend (zbx-fe-01)
```

---

## Pré-requisitos

### Checklist Geral

- [ ] PostgreSQL 16 instalado e rodando em pg-01
- [ ] Zabbix Server online em zbx-server-01
- [ ] Zabbix Frontend online em zbx-fe-01
- [ ] Conectividade TCP entre servidores:
  - zbx-server-01 → pg-01:5432 ✅
  - zbx-fe-01 → pg-01:5432 ✅
  - zbx-fe-01 → zbx-server-01:10051 ✅
- [ ] NTP sincronizado em todos os servidores
- [ ] Firewall permitindo portas necessárias:
  - 5432/tcp (PostgreSQL)
  - 10051/tcp (Zabbix Server)
  - 80/tcp e 443/tcp (Frontend)
- [ ] Mínimo 50GB livres em cada servidor
- [ ] CPU: PostgreSQL 20 vCPU, Server 8 vCPU, Frontend 4+ vCPU

### Upgrades Necessários (ANTES de iniciar)

⚠️ **zbx-fe-01:** Upgrade CPU 2→4 vCPU e RAM 7→8 GB

---

## Estrutura de Diretórios

```
scripts/automated-install/
├── 01-postgresql.sh              ← Instalar PostgreSQL
├── 02-zabbix-server.sh          ← Instalar Zabbix Server
├── 03-zabbix-frontend.sh        ← Instalar Zabbix Frontend
├── validate-postgresql.sh       ← Validar PostgreSQL
├── validate-server.sh           ← Validar Zabbix Server
├── validate-frontend.sh         ← Validar Frontend
├── common/
│   └── functions.sh             ← Lib compartilhada
├── config/
│   └── environment.example      ← Template de variáveis
└── docs/
    ├── INSTALACAO.md            ← Este arquivo
    ├── VALIDACAO.md             ← Guia de validação
    └── TROUBLESHOOTING.md       ← Soluções de problemas
```

---

## Instalação Passo a Passo

### 1️⃣ PostgreSQL Primary (pg-01 / 10.31.38.64)

#### 1.1 Preparação do Servidor

```bash
# SSH para o servidor
ssh root@10.31.38.64

# Verificar espaço em disco
df -h /var/lib/postgresql || df -h /pgdata

# Verificar espaço: mínimo 50GB
# Se NVMe não estiver montado:
lsblk  # Listar discos
# Montar NVMe conforme VALIDACAO_DISCO_PG01.md
```

#### 1.2 Download do Script

```bash
# Clone do repositório ou download direto
cd /tmp
curl -fsSL https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/automated-install/01-postgresql.sh \
    -o 01-postgresql.sh
chmod +x 01-postgresql.sh
```

#### 1.3 Configurar Variáveis (Opcional)

```bash
# Copiar template de ambiente
cp config/environment.example config/environment.local
nano config/environment.local  # Editar conforme necessário

# Ou usar defaults (recomendado para Fase 1)
```

#### 1.4 Executar Instalação

```bash
# IMPORTANTE: Executar como root
sudo bash 01-postgresql.sh

# Output esperado:
# ✓ PostgreSQL 16 instalado
# ✓ Database 'zabbix' criado
# ✓ Usuário 'zabbix' criado
# ✓ pgBackRest configurado
```

**Tempo estimado:** 30-45 minutos

#### 1.5 Definir Senha Zabbix

```bash
# Após sucesso da instalação:
sudo -u postgres psql

psql> ALTER USER zabbix WITH PASSWORD 'sua_senha_segura';
psql> \q
```

#### 1.6 Validar Instalação

```bash
bash validate-postgresql.sh

# Esperado:
# ✓ PostgreSQL serviço ativo
# ✓ Escutando na porta 5432
# ✓ Database 'zabbix' existe
# ✓ Usuário 'zabbix' existe
```

---

### 2️⃣ Zabbix Server (zbx-server-01 / 10.31.38.60)

#### 2.1 Preparação do Servidor

```bash
# SSH para o servidor
ssh root@10.31.38.60

# Verificar conectividade PostgreSQL
psql -h 10.31.38.64 -U zabbix -d zabbix -c "SELECT 1"

# Se falhar, verificar:
# - Firewall: ufw allow 5432/tcp
# - PostgreSQL: netstat -tlnp | grep 5432
# - /etc/hosts: 10.31.38.64  pg-01
```

#### 2.2 Download do Script

```bash
cd /tmp
curl -fsSL https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/automated-install/02-zabbix-server.sh \
    -o 02-zabbix-server.sh
chmod +x 02-zabbix-server.sh
```

#### 2.3 Executar Instalação

```bash
# Exportar variáveis antes de executar
export PG_PASSWORD="sua_senha_do_postgresql"
export PG_HOST="10.31.38.64"

# Executar
sudo bash 02-zabbix-server.sh

# Output esperado:
# ✓ Zabbix Server 7.0 instalado
# ✓ Conectado ao PostgreSQL
# ✓ Database inicializado
# ✓ Serviço rodando na porta 10051
```

**Tempo estimado:** 20-30 minutos

#### 2.4 Verificar Status

```bash
systemctl status zabbix-server
systemctl status zabbix-agent2
tail -50 /var/log/zabbix/zabbix_server.log
```

#### 2.5 Validar Instalação

```bash
bash validate-server.sh

# Esperado:
# ✓ Zabbix Server serviço ativo
# ✓ Zabbix Agent 2 serviço ativo
# ✓ Porta 10051 aberta
# ✓ Conectado ao PostgreSQL
```

---

### 3️⃣ Zabbix Frontend (zbx-fe-01 / 10.31.38.62)

#### ⚠️ PRÉ-REQUISITO: Upgrade CPU/RAM

```bash
# ANTES de executar este script:
# CPU: upgrade 2 vCPU → 4 vCPU
# RAM: upgrade 7 GB → 8+ GB

# Contatar time de virtualização
# Após upgrade, reiniciar VM
shutdown -r now
```

#### 3.1 Preparação do Servidor

```bash
# SSH para o servidor
ssh root@10.31.38.62

# Verificar upgrade foi aplicado
nproc       # Deve mostrar 4+
free -g     # Deve mostrar 8+

# Verificar conectividade
psql -h 10.31.38.64 -U zabbix -d zabbix -c "SELECT 1"
timeout 5 bash -c 'cat < /dev/null > /dev/tcp/10.31.38.60/10051' && echo "OK" || echo "FAIL"
```

#### 3.2 Download do Script

```bash
cd /tmp
curl -fsSL https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/automated-install/03-zabbix-frontend.sh \
    -o 03-zabbix-frontend.sh
chmod +x 03-zabbix-frontend.sh
```

#### 3.3 Executar Instalação

```bash
# Exportar variáveis
export PG_PASSWORD="sua_senha_do_postgresql"
export PG_HOST="10.31.38.64"
export ZABBIX_SERVER="10.31.38.60"

# Executar
sudo bash 03-zabbix-frontend.sh

# Output esperado:
# ✓ Nginx instalado
# ✓ PHP-FPM instalado
# ✓ Zabbix Frontend instalado
# ✓ Serviço rodando na porta 80
```

**Tempo estimado:** 25-35 minutos

#### 3.4 Acessar Interface Web

```bash
# Abrir navegador
http://10.31.38.62

# Login padrão:
# Username: Admin
# Password: zabbix
```

#### 3.5 Validar Instalação

```bash
bash validate-frontend.sh

# Esperado:
# ✓ Nginx serviço ativo
# ✓ PHP-FPM serviço ativo
# ✓ Frontend respondendo na porta 80
# ✓ Conectado ao PostgreSQL
# ✓ Conectado ao Zabbix Server
```

---

## Validação

### Validação Rápida

```bash
# Teste de conectividade entre servidores
# De zbx-server-01:
ssh root@10.31.38.60
psql -h 10.31.38.64 -U zabbix -d zabbix -c "SELECT version()"

# De zbx-fe-01:
ssh root@10.31.38.62
psql -h 10.31.38.64 -U zabbix -d zabbix -c "SELECT version()"
timeout 5 bash -c 'cat < /dev/null > /dev/tcp/10.31.38.60/10051' && echo "Connected" || echo "Failed"
curl -s http://localhost/api/version | jq .
```

### Validação Completa

```bash
# Execute os scripts de validação em cada servidor:

# PostgreSQL
ssh root@10.31.38.64 'bash validate-postgresql.sh'

# Zabbix Server
ssh root@10.31.38.60 'bash validate-server.sh'

# Zabbix Frontend
ssh root@10.31.38.62 'bash validate-frontend.sh'
```

### Monitoramento Inicial

```bash
# Acessar Zabbix Frontend
# http://10.31.38.62

# Menu: Configuration → Hosts
# Deve aparecer em breve:
# - Zabbix Server (auto-monitoramento)
# - Zabbix Frontend (se configurado)

# Menu: Monitoring → Latest Data
# Verificar se métricas estão sendo coletadas
```

---

## Troubleshooting

### PostgreSQL Não Inicia

```bash
# Verificar erros
systemctl status postgresql
journalctl -u postgresql -n 50

# Verificar arquivo de log
tail -50 /var/log/postgresql/postgresql.log

# Tentar iniciar manualmente
sudo -u postgres /usr/lib/postgresql/16/bin/postgres -D /var/lib/postgresql/16/main

# Comum: falta de permissões
ls -la /var/lib/postgresql/
# Deve ser: postgres:postgres
```

### Zabbix Server Não Conecta PostgreSQL

```bash
# Verificar conectividade
psql -h 10.31.38.64 -U zabbix -d zabbix -c "SELECT 1"

# Verificar ACL PostgreSQL
sudo -u postgres psql -c "SELECT * FROM pg_hba_file_rules WHERE database = 'zabbix'"

# Erro comum: pg_hba.conf não configurado
sudo nano /etc/postgresql/16/main/pg_hba.conf
# Adicionar linha:
# host    zabbix      zabbix    10.31.38.60/32  md5

# Recarregar
sudo -u postgres psql -c "SELECT pg_reload_conf()"
```

### Frontend Não Conecta Zabbix Server

```bash
# Testar conectividade
timeout 5 bash -c 'cat < /dev/null > /dev/tcp/10.31.38.60/10051'

# Verificar configuração
cat /etc/zabbix/web/zabbix.conf.php | grep -i server

# Comum: Firewall bloqueando
# Abrir porta:
sudo ufw allow 10051/tcp
# ou
sudo firewall-cmd --permanent --add-port=10051/tcp
sudo firewall-cmd --reload
```

### Disco Cheio

```bash
# PostgreSQL
df /var/lib/postgresql/
# Se < 10GB, limpar antigos:
sudo -u postgres vacuumdb -d zabbix -f

# Zabbix
df /var/lib/zabbix/
# Limpar caches
rm -rf /var/lib/zabbix/alertscripts/*tmp*
```

### NTP Não Sincronizado

```bash
# Verificar status
timedatectl
chronyc tracking  # ou ntpq -p

# Se desincronizado:
sudo systemctl restart chrony
sudo systemctl restart ntpd

# Usar servidor NTP manual:
sudo ntpdate pool.ntp.org
```

---

## Pós-Instalação

### 1. Alterar Senha Padrão

```bash
# Acessar Frontend
# Profile → Change Password
# Mudar senha de 'Admin' para senha segura
```

### 2. Configurar Email (Opcional)

```bash
# Administration → Media types → Email
# Preencher SMTP details
# Testar envio de notificação
```

### 3. Criar Hosts de Monitoramento

```bash
# Importar hosts da arquitetura
# 676 ativos: câmeras, controle acesso, etc

# Usar templates:
# - Template App Zabbix Server
# - Criar templates customizados para ativos
```

### 4. Configurar Backup

```bash
# PostgreSQL está com pgBackRest
# Verificar backup inicial:
sudo -u postgres pgbackrest info

# Agendar backup diário:
sudo crontab -e
# Adicionar:
# 0 2 * * * /usr/bin/pgbackrest backup --stanza=PostgreSQL
```

### 5. Documentar Senhas

```bash
# Armazenar senhas em local seguro:
# - 1Password
# - Vault
# - Encrypted password manager

# NUNCA em arquivo plano ou repositório Git
```

---

## Preparação para Fase 2 (HA)

### Configurações Já Feitas para HA

✅ PostgreSQL com pgBackRest (backup/restore automático)  
✅ pg_hba.conf permite múltiplos hosts (preparado para replicação)  
✅ Zabbix Server sem configurações que bloqueiem clustering  
✅ Arquitetura de 3 servidores (permite adicionar réplicas)  

### O Que Será Necessário na Fase 2

1. **PostgreSQL HA:**
   - Instalar segundo servidor PostgreSQL (pg-02)
   - Configurar streaming replication
   - Instalar pgPool-II para load balancing
   - Keepalived para VIP automático

2. **Zabbix Server HA:**
   - Instalar segundo servidor Zabbix (zbx-server-02)
   - Configurar heartbeat/clustering
   - Keepalived para VIP Zabbix Server

3. **Zabbix Frontend HA:**
   - Instalar segundo frontend (zbx-fe-02)
   - Configurar shared NFS para uploads
   - Nginx upstream para balanceamento

4. **Networking:**
   - Definir VIPs (Virtual IPs)
   - Configurar DHCP/DNS para HA
   - Testar failover

### Documentação de Fase 2

Consulte: `docs/MIGRACAO_HA.md` (a ser criado após Fase 1 estabilizada)

---

## Checklist Final

- [ ] PostgreSQL instalado e validado
- [ ] Zabbix Server instalado e validado
- [ ] Zabbix Frontend instalado e validado
- [ ] Todos os serviços rodando
- [ ] Conectividade entre servidores testada
- [ ] Senhas configuradas e documentadas (seguro)
- [ ] Backup PostgreSQL funcionando
- [ ] Acesso web ao Frontend OK
- [ ] Interface mostrando dados coletados
- [ ] Documentação atualizada para seu ambiente

---

## Suporte e Documentação Adicional

- **Validação Completa:** `scripts/automated-install/docs/VALIDACAO.md`
- **Troubleshooting Detalhado:** `scripts/automated-install/docs/TROUBLESHOOTING.md`
- **Matriz de Arquitetura:** `docs/instalacao/MATRIZ_ANALISE_ARQUITETURA_FASE1.md`
- **Runbooks:** `docs/runbooks/`

---

**Documento:** scripts/automated-install/docs/INSTALACAO.md  
**Versão:** 1.0  
**Última atualização:** 24/10/2026  
**Autor:** Vinicius Reis  
**Status:** ✅ Pronto para produção

