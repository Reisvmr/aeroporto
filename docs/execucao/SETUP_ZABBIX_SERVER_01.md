# 🔧 PROCEDIMENTO DE SETUP - ZABBIX SERVER 01

**Data:** 23/10/2024  
**Versão:** 1.0  
**Status:** Pronto para execução  
**Ambiente:** Linux (CentOS/RHEL 8+, Ubuntu 20.04+, Debian 11+)

---

## 📋 PRÉ-REQUISITOS

### Informações de Conectividade
- **Servidor Zabbix Server 01:** `zbx-server-01` (IP: A DEFINIR)
- **PostgreSQL (Remoto):** `10.31.38.64:5432`
- **Usuário BD Zabbix:** `zabbix`
- **Password BD Zabbix:** `(será fornecido)`
- **Database:** `zabbix`

### Hardware Esperado
- **CPU:** 8 vCPU
- **RAM:** 24 GB
- **Disco:** 120 GB SSD
- **Rede:** Conectividade com 10.31.38.64 (PostgreSQL)

### SO Esperado
- CentOS 8+ / RHEL 8+
- OU Ubuntu 20.04+ / Debian 11+
- Servidor zerado (fresh install)

---

## ✅ PASSO 1: PREPARAÇÃO DO SISTEMA OPERACIONAL

### 1.1 Atualizar o Sistema
```bash
# Para CentOS/RHEL
sudo yum update -y
sudo yum upgrade -y

# Para Ubuntu/Debian
sudo apt-get update
sudo apt-get upgrade -y
```

### 1.2 Instalar Ferramentas Básicas
```bash
# CentOS/RHEL
sudo yum install -y \
  wget curl git vim nano htop net-tools \
  ntp ntpdate chrony \
  gcc make devel-headers \
  openssl openssl-devel \
  zlib zlib-devel \
  libevent libevent-devel

# Ubuntu/Debian
sudo apt-get install -y \
  wget curl git vim nano htop net-tools \
  ntp ntpdate chrony \
  build-essential \
  libssl-dev \
  zlib1g zlib1g-dev \
  libevent-dev
```

### 1.3 Configurar NTP (Sincronismo Horário) ⭐ CRÍTICO
```bash
# Verificar status NTP
sudo systemctl status chrony

# Se não estiver rodando
sudo systemctl start chrony
sudo systemctl enable chrony

# Validar sincronismo
chronyc tracking
timedatectl
```

**Esperado:** Horário sincronizado (<1ms de diferença)

### 1.4 Configurar Firewall
```bash
# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-port=10051/tcp  # Zabbix Server
sudo firewall-cmd --permanent --add-port=10050/tcp  # Zabbix Agent
sudo firewall-cmd --reload

# Ubuntu/Debian (ufw)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 10051/tcp
sudo ufw allow 10050/tcp
sudo ufw enable
```

### 1.5 Configurar Hostname
```bash
# Definir hostname
sudo hostnamectl set-hostname zbx-server-01

# Validar
hostname

# Adicionar ao /etc/hosts
sudo nano /etc/hosts
# Adicionar: 127.0.0.1  zbx-server-01
```

### 1.6 Configurar DNS (resolver)
```bash
# Validar DNS
cat /etc/resolv.conf

# Se necessário, configurar manualmente
sudo nano /etc/resolv.conf
# Adicionar: nameserver 8.8.8.8
#           nameserver 1.1.1.1
```

---

## ✅ PASSO 2: PREPARAR REPOSITÓRIOS

### 2.1 Adicionar Repositório Zabbix Oficial
```bash
# CentOS/RHEL 8
sudo yum install -y https://repo.zabbix.com/zabbix/7.0/rhel/8/x86_64/zabbix-release-7.0-1.el8.noarch.rpm

# Ubuntu 20.04
sudo apt-get install -y curl gnupg2
curl https://repo.zabbix.com/zabbix-official-repo.key | sudo apt-key add -
echo "deb https://repo.zabbix.com/zabbix/7.0/ubuntu focal main" | sudo tee /etc/apt/sources.list.d/zabbix.list
sudo apt-get update

# Debian 11
curl https://repo.zabbix.com/zabbix-official-repo.key | sudo apt-key add -
echo "deb https://repo.zabbix.com/zabbix/7.0/debian bullseye main" | sudo tee /etc/apt/sources.list.d/zabbix.list
sudo apt-get update
```

### 2.2 Habilitar Repositórios EPEL (CentOS/RHEL)
```bash
sudo yum install -y epel-release
```

---

## ✅ PASSO 3: INSTALAR ZABBIX SERVER

### 3.1 Instalar Pacotes Zabbix Server
```bash
# CentOS/RHEL
sudo yum install -y zabbix-server-pgsql zabbix-sql-scripts zabbix-selinux-policy

# Ubuntu/Debian
sudo apt-get install -y zabbix-server-pgsql zabbix-sql-scripts zabbix-selinux-policy
```

### 3.2 Verificar Instalação
```bash
# Validar versão
zabbix_server -V

# Verificar binário
which zabbix_server
```

**Esperado:** Zabbix Server 7.0.x

---

## ✅ PASSO 4: CONFIGURAR CONECTIVIDADE COM POSTGRESQL

### 4.1 Instalar Cliente PostgreSQL
```bash
# CentOS/RHEL
sudo yum install -y postgresql-client

# Ubuntu/Debian
sudo apt-get install -y postgresql-client
```

### 4.2 Testar Conectividade com PostgreSQL Remoto
```bash
# Substituir senha quando solicitado
psql -h 10.31.38.64 -U zabbix -d zabbix -c "SELECT version();"
```

**Esperado:** 
```
PostgreSQL 16.x on ...
```

Se **FALHAR**, verificar:
- Firewall em 10.31.38.64 (porta 5432)
- Credenciais (usuario/senha)
- IP de origem liberado em postgresql.conf (listen_addresses)
- pg_hba.conf com host entry para este servidor

### 4.3 Copiar Schema do Zabbix para PostgreSQL
```bash
# Localizar arquivo schema
ls /usr/share/doc/zabbix-server-pgsql*/

# Descompactar schema (se necessário)
cd /usr/share/doc/zabbix-server-pgsql-*/
sudo gunzip create.sql.gz

# Aplicar schema no PostgreSQL
psql -h 10.31.38.64 -U zabbix -d zabbix -f create.sql

# Validar
psql -h 10.31.38.64 -U zabbix -d zabbix -c "\dt" | head -20
```

**Esperado:** Tabelas zabbix criadas (hosts, events, history, etc.)

---

## ✅ PASSO 5: CONFIGURAR ZABBIX SERVER

### 5.1 Editar Arquivo de Configuração
```bash
sudo nano /etc/zabbix/zabbix_server.conf
```

### 5.2 Parâmetros Críticos a Configurar
```bash
# Database
DBHost=10.31.38.64
DBName=zabbix
DBUser=zabbix
DBPassword=<senha_do_postgres>  # ⭐ IMPORTANTÍSSIMO
DBPort=5432

# Cache (Ajustar conforme RAM disponível)
CacheSize=512M
HistoryCacheSize=512M
TrendCacheSize=256M
ValueCacheSize=512M

# Logs
LogFile=/var/log/zabbix/zabbix_server.log
LogFileSize=50
DebugLevel=3

# Alerting
AlertScriptsPath=/usr/lib/zabbix/alertscripts
ExternalScripts=/usr/lib/zabbix/externalscripts

# Portas (padrão)
ListenPort=10051
```

### 5.3 Criar Diretórios Necessários
```bash
sudo mkdir -p /usr/lib/zabbix/alertscripts
sudo mkdir -p /usr/lib/zabbix/externalscripts
sudo chown zabbix:zabbix /usr/lib/zabbix/alertscripts
sudo chown zabbix:zabbix /usr/lib/zabbix/externalscripts
sudo chmod 755 /usr/lib/zabbix/alertscripts
sudo chmod 755 /usr/lib/zabbix/externalscripts
```

### 5.4 Validar Sintaxe da Configuração
```bash
zabbix_server -c /etc/zabbix/zabbix_server.conf -t
```

**Esperado:** `Zabbix Server loaded successfully`

---

## ✅ PASSO 6: INICIAR ZABBIX SERVER

### 6.1 Habilitar e Iniciar Serviço
```bash
sudo systemctl enable zabbix-server
sudo systemctl start zabbix-server
sudo systemctl status zabbix-server
```

### 6.2 Validar Logs
```bash
# Verificar logs em tempo real
sudo tail -f /var/log/zabbix/zabbix_server.log

# Procurar por erros
sudo grep -i error /var/log/zabbix/zabbix_server.log | tail -20
```

**Esperado:**
```
Zabbix Server started
Server #0 started [main process]
Server #1 started [configuration syncer]
...
```

### 6.3 Validar Conectividade
```bash
# Verificar porta TCP 10051
sudo netstat -tlnp | grep 10051
# ou
sudo ss -tlnp | grep 10051
```

**Esperado:**
```
tcp  0  0 0.0.0.0:10051  0.0.0.0:*  LISTEN  <pid>/zabbix_server
```

---

## ✅ PASSO 7: TESTES DE VALIDAÇÃO

### 7.1 Teste de Banco de Dados
```bash
psql -h 10.31.38.64 -U zabbix -d zabbix -c "SELECT COUNT(*) FROM hosts;"
```

**Esperado:** Retorna número de hosts (0 se novo)

### 7.2 Teste de Conectividade com TCP
```bash
# Do servidor Zabbix
telnet localhost 10051

# De outro servidor
telnet <IP-zbx-server-01> 10051
```

**Esperado:** Conexão estabelecida

### 7.3 Teste de Processo
```bash
ps aux | grep zabbix_server
```

**Esperado:** Vários processos zabbix_server rodando

### 7.4 Monitorar Health Check
```bash
# Verificar logs continuamente
sudo journalctl -u zabbix-server -f
```

---

## ⚠️ TROUBLESHOOTING

### Erro: "Cannot connect to database"
```bash
# Verificar credenciais
psql -h 10.31.38.64 -U zabbix -d zabbix

# Verificar firewall
sudo firewall-cmd --list-all
# ou
sudo ufw status

# Verificar pg_hba.conf em 10.31.38.64
# Deve conter: host  zabbix  zabbix  <IP-zbx-server-01>/32  md5
```

### Erro: "Cannot create schema"
```bash
# Verificar se schema já existe
psql -h 10.31.38.64 -U zabbix -d zabbix -c "\dt" | grep hosts

# Se existir, remover (cuidado!)
psql -h 10.31.38.64 -U zabbix -d zabbix -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
```

### Erro: "Cache initialization failed"
```bash
# Aumentar CacheSize no zabbix_server.conf
# Se RAM não for suficiente, reduzir
CacheSize=256M
HistoryCacheSize=256M
```

### Port 10051 já em uso
```bash
# Identificar processo
sudo lsof -i :10051

# Matar processo (se necessário)
sudo kill -9 <PID>
```

---

## ✅ CHECKLIST FINAL

- [ ] Sistema operacional atualizado
- [ ] NTP sincronizado
- [ ] Firewall configurado (porta 10051)
- [ ] Repositório Zabbix adicionado
- [ ] Zabbix Server instalado
- [ ] PostgreSQL cliente instalado
- [ ] Conectividade com 10.31.38.64:5432 validada
- [ ] Schema Zabbix importado no PostgreSQL
- [ ] zabbix_server.conf configurado corretamente
- [ ] Zabbix Server iniciado e rodando
- [ ] Logs sem erros críticos
- [ ] Porta 10051 respondendo

---

## 📞 PRÓXIMA ETAPA

Após completar este procedimento com sucesso:
1. Validar conectividade com Zabbix Frontend
2. Configurar Zabbix Frontend (próximo documento)
3. Testar coleta do primeiro host

---

**Status:** ✅ Pronto para execução  
**Data:** 23/10/2024  
**Versão:** 1.0
