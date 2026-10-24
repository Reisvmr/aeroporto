# 🔧 PLANO DE AÇÃO POR SERVIDOR - O QUE FAZER COM ACESSO LOCAL

**Data:** 24/10/2026  
**Objetivo:** Otimizar tempo enquanto PostgreSQL recupera  
**Status:** Ações que você pode executar NOS SERVIDORES que tem acesso

---

## 📊 MAPA DE ACESSO

| Servidor | IP | Acesso SSH | Status | Ações Possíveis |
|----------|----|----|--------|-----------------|
| **pg-01** | 10.31.38.64 | ❌ SEM SSH | 🔴 Offline | Aguarda recuperação |
| **zbx-server-01** | 10.31.38.60 | ✅ SIM | ✅ Online | **Pode executar agora** |
| **zbx-fe-01** | 10.31.38.62 | ✅ SIM | ✅ Online | **Pode executar agora** |

---

## 🟢 SERVIDOR: ZABBIX SERVER 01 (zbx-server-01 - 10.31.38.60)

**Status:** Online e com acesso SSH  
**Hardware:** 8 vCPU, 22 GB RAM, 45 GB disco livres  
**SO:** Ubuntu 26.04  

### ✅ AÇÕES QUE PODE FAZER AGORA

#### 1. **Criar estrutura de diretórios do Zabbix**

```bash
# Conectar no servidor
ssh root@10.31.38.60

# Criar usuário zabbix (se não existir)
useradd --system --no-create-home --shell /bin/false zabbix 2>/dev/null || echo "Usuário zabbix já existe"

# Criar diretórios necessários
mkdir -p /var/lib/zabbix/alertscripts
mkdir -p /var/lib/zabbix/externalscripts
mkdir -p /var/log/zabbix
mkdir -p /etc/zabbix/web
mkdir -p /etc/zabbix/conf.d

# Configurar permissões
chown -R zabbix:zabbix /var/lib/zabbix
chown -R zabbix:zabbix /var/log/zabbix
chmod -R 755 /var/lib/zabbix
chmod -R 755 /var/log/zabbix

# Verificar
ls -la /var/lib/zabbix/
ls -la /var/log/zabbix/
```

**Tempo:** 5 minutos  
**Benefício:** Quando PostgreSQL online, já tem estrutura pronta

---

#### 2. **Preparar arquivo de configuração do Zabbix Server**

```bash
# Criar arquivo de configuração (substituir valores)
cat > /tmp/zabbix_server.conf.template << 'EOF'
# Zabbix Server Configuration File
LogFile=/var/log/zabbix/zabbix_server.log
LogFileSize=100
PidFile=/var/run/zabbix/zabbix_server.pid

# Database configuration (será preenchido quando PG online)
DBHost=10.31.38.64
DBName=zabbix
DBUser=zabbix
DBPassword=SENHA_AQUI  # Será definida durante setup
DBPort=5432

# Server configuration
ListenPort=10051
SourceIP=10.31.38.60
HistoryStorageDateIndex=1

# Performance tuning
StartPollers=100
StartPollersUnreachable=20
StartTrappers=10
StartDBSyncers=8
CacheSize=128M
HistoryCacheSize=64M
TrendCacheSize=32M

# Security
TLSCAFile=/etc/zabbix/ssl/ca.pem
TLSCertFile=/etc/zabbix/ssl/cert.pem
TLSKeyFile=/etc/zabbix/ssl/key.pem

# Logging
DebugLevel=3
StatsAllowedIP=127.0.0.1
EOF

echo "✅ Arquivo template criado em /tmp/zabbix_server.conf.template"
cat /tmp/zabbix_server.conf.template
```

**Tempo:** 5 minutos  
**Benefício:** Configuração pronta para pós-setup PostgreSQL

---

#### 3. **Instalar pré-requisitos do SO (sem dependências de BD)**

```bash
# Atualizar package manager
apt-get update

# Instalar ferramentas necessárias
apt-get install -y \
    curl \
    wget \
    net-tools \
    telnet \
    iputils-ping \
    dnsutils \
    traceroute \
    vim \
    nano \
    git \
    jq \
    htop \
    iostat \
    sysstat

# Verificar instalação
curl --version
wget --version
telnet -h 2>&1 | head -5

echo "✅ Ferramentas instaladas com sucesso"
```

**Tempo:** 5-10 minutos  
**Benefício:** Sistema pronto para setup

---

#### 4. **Resolver problema de DNS (zbx-server-01)**

```bash
# Testar resolução atual
nslookup 10.31.38.60
nslookup zbx-server-01

# Se DNS não funciona bem, adicionar em /etc/hosts
cat >> /etc/hosts << 'EOF'
10.31.38.60 zbx-server-01
10.31.38.62 zbx-fe-01
10.31.38.64 pg-01
10.31.38.1  gateway
EOF

# Verificar
cat /etc/hosts

# Testar resolução
ping -c 1 zbx-server-01
ping -c 1 zbx-fe-01
ping -c 1 pg-01
```

**Tempo:** 5 minutos  
**Benefício:** Comunicação entre servidores funcionando

---

#### 5. **Validar e corrigir MTU**

```bash
# Verificar MTU atual
ip link show eth0 2>/dev/null || ip link show ens18

# Se MTU for 65536 (incorreto), corrigir para 1500
ip link set dev ens18 mtu 1500

# Fazer permanente (Ubuntu 22.04+)
cat > /etc/netplan/99-mtu.yaml << 'EOF'
network:
  version: 2
  ethernets:
    ens18:
      mtu: 1500
EOF

# Aplicar
netplan apply

# Verificar
ip link show ens18 | grep mtu
```

**Tempo:** 5-10 minutos  
**Benefício:** Network otimizada, evita timeouts

---

#### 6. **Criar script de teste de conectividade**

```bash
# Script de teste
cat > /usr/local/bin/test-connectivity.sh << 'EOF'
#!/bin/bash

echo "=== TESTE DE CONECTIVIDADE ZABBIX SERVER 01 ==="
echo ""

# Teste 1: PostgreSQL
echo "1. Testando PostgreSQL (10.31.38.64:5432)..."
nc -zv 10.31.38.64 5432 2>&1 | grep -q "succeeded" && echo "   ✅ OK" || echo "   ❌ FALHOU"

# Teste 2: Frontend
echo "2. Testando Frontend (zbx-fe-01:10051)..."
nc -zv 10.31.38.62 10051 2>&1 | grep -q "succeeded" && echo "   ✅ OK" || echo "   ❌ FALHOU"

# Teste 3: Gateway
echo "3. Testando Gateway (10.31.38.1)..."
ping -c 1 10.31.38.1 2>&1 | grep -q "bytes from" && echo "   ✅ OK" || echo "   ❌ FALHOU"

# Teste 4: Domínios críticos
echo "4. Testando domínios críticos..."
for domain in repo.zabbix.com www.zabbix.com github.com; do
    curl -s -m 2 -o /dev/null -w "%{http_code}" "https://$domain" 2>/dev/null | grep -q "200\|000" && \
        echo "   ✅ $domain" || echo "   ❌ $domain"
done

echo ""
echo "=== FIM DO TESTE ==="
EOF

chmod +x /usr/local/bin/test-connectivity.sh

# Executar teste
/usr/local/bin/test-connectivity.sh
```

**Tempo:** 10 minutos  
**Benefício:** Script pronto para validar conectividade pós-setup

---

#### 7. **Preparar logs e auditoria**

```bash
# Criar diretório de logs
mkdir -p /var/log/zabbix/auditoria
chmod 755 /var/log/zabbix

# Verificar espaço disponível
df -h / | tail -1

# Criar script de limpeza de logs (futuro)
cat > /usr/local/bin/cleanup-logs.sh << 'EOF'
#!/bin/bash
# Remover logs com mais de 30 dias
find /var/log/zabbix -name "*.log*" -mtime +30 -delete
echo "Logs antigos removidos"
EOF

chmod +x /usr/local/bin/cleanup-logs.sh

echo "✅ Logging preparado"
```

**Tempo:** 5 minutos  
**Benefício:** Logs organizados, espaço preservado

---

#### 8. **Validação final do servidor**

```bash
# Rerun validação v2.0
bash <(curl -fsSL https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/run-check-v2.sh) zbx-server

# Salvar resultado
bash <(curl -fsSL https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/run-check-v2.sh) zbx-server > /tmp/zbx-server-validacao.txt 2>&1

# Verificar resultado
cat /tmp/zbx-server-validacao.txt | grep -E "PASS|FAIL|WARN" | head -20
```

**Tempo:** 5 minutos  
**Benefício:** Validar se tudo está OK pós-preparação

---

### 📋 CHECKLIST ZABBIX SERVER 01

Execute na ordem:

- [ ] 1. Criar estrutura de diretórios (5 min)
- [ ] 2. Preparar arquivo de configuração (5 min)
- [ ] 3. Instalar pré-requisitos SO (10 min)
- [ ] 4. Resolver DNS /etc/hosts (5 min)
- [ ] 5. Validar/Corrigir MTU (10 min)
- [ ] 6. Criar script de teste (10 min)
- [ ] 7. Preparar logs e auditoria (5 min)
- [ ] 8. Re-validar com v2.0 (5 min)

**Tempo Total:** ~55 minutos

---

## 🟢 SERVIDOR: ZABBIX FRONTEND 01 (zbx-fe-01 - 10.31.38.62)

**Status:** Online e com acesso SSH  
**Hardware:** 2 vCPU ❌, 7 GB RAM ⚠️, 11 GB disco  
**SO:** Ubuntu 26.04

### ⚠️ PRIMEIRO: UPGRADE CPU/RAM

**Crítico antes de qualquer ação:**

```bash
# Contatar virtualização:
echo "SOLICITAÇÃO: Upgrade CPU 2→4 vCPU, RAM 7→8 GB"
echo "Justificativa: Mínimo para Zabbix Frontend é 4 vCPU, 8 GB RAM"
echo "Impacto: Sem upgrade, Frontend ficará lento"

# Após upgrade, validar
nproc  # Deve mostrar 4+
free -h | grep -i total  # Deve mostrar 8GB+
```

**Depois do upgrade, prosseguir com:**

---

#### 1. **Criar estrutura de diretórios do Frontend**

```bash
# Conectar no servidor
ssh root@10.31.38.62

# Criar diretórios para Nginx + PHP-FPM
mkdir -p /var/www/zabbix
mkdir -p /var/lib/php/session
mkdir -p /var/cache/nginx
mkdir -p /etc/nginx/conf.d
mkdir -p /etc/php/8.1/fpm/pool.d

# Verificar
ls -la /var/www/
ls -la /var/lib/php/
```

**Tempo:** 5 minutos

---

#### 2. **Preparar configuração Nginx**

```bash
# Criar arquivo de configuração Nginx
cat > /tmp/zabbix-nginx.conf.template << 'EOF'
server {
    listen       80;
    server_name  zbx-fe-01;
    
    root /var/www/zabbix;
    index index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }

    client_max_body_size 16M;
    client_body_buffer_size 128k;
}

# HTTPS (será configurado com certificados)
server {
    listen       443 ssl;
    server_name  zbx-fe-01;
    
    ssl_certificate /etc/nginx/ssl/zabbix.crt;
    ssl_certificate_key /etc/nginx/ssl/zabbix.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    # Mesmo conteúdo acima...
}
EOF

echo "✅ Configuração Nginx template criada"
```

**Tempo:** 5 minutos

---

#### 3. **Preparar configuração PHP-FPM**

```bash
# Criar arquivo de configuração PHP-FPM
cat > /tmp/zabbix-php-fpm.conf.template << 'EOF'
[zabbix]
user = www-data
group = www-data
listen = /var/run/php/php-fpm.sock
listen.owner = www-data
listen.group = www-data

pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35

; PHP Settings
php_flag[display_errors] = off
php_value[memory_limit] = 256M
php_value[max_execution_time] = 300
php_value[upload_max_filesize] = 16M
php_value[post_max_size] = 16M
php_value[max_input_time] = 300

; Session settings
php_value[session.save_path] = /var/lib/php/session
EOF

echo "✅ Configuração PHP-FPM template criada"
```

**Tempo:** 5 minutos

---

#### 4. **Instalar pré-requisitos**

```bash
# Atualizar
apt-get update

# Instalar ferramentas
apt-get install -y \
    curl \
    wget \
    net-tools \
    telnet \
    vim \
    nano \
    git \
    htop

echo "✅ Ferramentas instaladas"
```

**Tempo:** 10 minutos

---

#### 5. **Resolver DNS (Frontend)**

```bash
# Adicionar em /etc/hosts (se não existir)
grep -q "10.31.38.60 zbx-server-01" /etc/hosts || \
cat >> /etc/hosts << 'EOF'
10.31.38.60 zbx-server-01
10.31.38.62 zbx-fe-01
10.31.38.64 pg-01
EOF

# Validar
cat /etc/hosts

# Testar
ping -c 1 zbx-server-01
```

**Tempo:** 5 minutos

---

#### 6. **Corrigir MTU**

```bash
# Verificar
ip link show ens18

# Corrigir se necessário
ip link set dev ens18 mtu 1500

# Fazer permanente
cat > /etc/netplan/99-mtu.yaml << 'EOF'
network:
  version: 2
  ethernets:
    ens18:
      mtu: 1500
EOF

netplan apply

# Validar
ip link show ens18 | grep mtu
```

**Tempo:** 5 minutos

---

#### 7. **Criar scripts de teste**

```bash
# Script de teste Frontend
cat > /usr/local/bin/test-frontend-connectivity.sh << 'EOF'
#!/bin/bash

echo "=== TESTE DE CONECTIVIDADE FRONTEND 01 ==="
echo ""

# Teste 1: PostgreSQL
echo "1. PostgreSQL (10.31.38.64:5432)..."
nc -zv 10.31.38.64 5432 2>&1 | grep -q "succeeded" && echo "   ✅ OK" || echo "   ❌ FALHOU"

# Teste 2: Zabbix Server
echo "2. Zabbix Server (zbx-server-01:10051)..."
nc -zv zbx-server-01 10051 2>&1 | grep -q "succeeded" && echo "   ✅ OK" || echo "   ❌ FALHOU"

# Teste 3: Portas HTTP/HTTPS
echo "3. Porta HTTP (80)..."
nc -zv localhost 80 2>&1 | grep -q "succeeded" && echo "   ✅ OK" || echo "   ⚠️ FALHOU (esperado - Nginx não instalado)"

echo "4. Porta HTTPS (443)..."
nc -zv localhost 443 2>&1 | grep -q "succeeded" && echo "   ✅ OK" || echo "   ⚠️ FALHOU (esperado - Nginx não instalado)"

# Teste 4: Domínios
echo "5. Domínios críticos..."
for domain in www.zabbix.com github.com; do
    curl -s -m 2 -o /dev/null -w "%{http_code}" "https://$domain" 2>/dev/null | grep -q "200\|000" && \
        echo "   ✅ $domain" || echo "   ❌ $domain"
done

echo ""
echo "=== FIM DO TESTE ==="
EOF

chmod +x /usr/local/bin/test-frontend-connectivity.sh
/usr/local/bin/test-frontend-connectivity.sh
```

**Tempo:** 10 minutos

---

#### 8. **Re-validar com v2.0**

```bash
# Executar validação
bash <(curl -fsSL https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/run-check-v2.sh) zbx-fe

# Salvar
bash <(curl -fsSL https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/run-check-v2.sh) zbx-fe > /tmp/zbx-fe-validacao.txt 2>&1

# Ver resultado
cat /tmp/zbx-fe-validacao.txt | tail -20
```

**Tempo:** 5 minutos

---

### 📋 CHECKLIST ZABBIX FRONTEND 01

**Pré-requisito:** Upgrade CPU/RAM (contatar virtualização)

Execute após upgrade:

- [ ] 1. Criar estrutura de diretórios (5 min)
- [ ] 2. Preparar config Nginx (5 min)
- [ ] 3. Preparar config PHP-FPM (5 min)
- [ ] 4. Instalar pré-requisitos SO (10 min)
- [ ] 5. Resolver DNS /etc/hosts (5 min)
- [ ] 6. Corrigir MTU (10 min)
- [ ] 7. Criar scripts de teste (10 min)
- [ ] 8. Re-validar com v2.0 (5 min)

**Tempo Total:** ~55 minutos (+ upgrade de hardware)

---

## 🔴 SERVIDOR: POSTGRESQL PRIMARY (pg-01 - 10.31.38.64)

**Status:** ❌ SEM SSH - Aguarda recuperação  
**Ações:** Nenhuma até ter acesso SSH novamente

### Quando PostgreSQL voltar online:

```bash
# PRIORIDADE 1: Validar que está online
ping 10.31.38.64

# PRIORIDADE 2: Conectar e verificar
ssh root@10.31.38.64
systemctl status postgresql

# PRIORIDADE 3: Testar conectividade
netstat -tlnap | grep 5432

# PRIORIDADE 4: Re-validar
bash <(curl -fsSL https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/run-check-v2.sh) pg01

# PRIORIDADE 5: Prosseguir com setup PostgreSQL
cat docs/execucao/SETUP_POSTGRESQL_PRIMARY.md
```

---

## ⏱️ CRONOGRAMA PARALELIZADO

### **AGORA (Enquanto PostgreSQL em recuperação):**

```
00:00-00:15 (Paralelo)
├─ Zabbix Server: Criar diretórios + pré-config
├─ Frontend: Diretórios + pré-config + contatar virtualização
└─ PostgreSQL: Aguardando SSH

00:15-00:45 (Paralelo)
├─ Zabbix Server: Instalar pré-requisitos SO
├─ Frontend: Instalar pré-requisitos SO (após upgrade)
└─ PostgreSQL: Aguardando

00:45-01:15 (Paralelo)
├─ Zabbix Server: DNS, MTU, scripts
├─ Frontend: DNS, MTU, scripts
└─ PostgreSQL: Esperado estar online!

01:15-01:30 (Paralelo)
├─ Zabbix Server: Re-validação v2.0
├─ Frontend: Re-validação v2.0
└─ PostgreSQL: Validação + setup início
```

---

## 📊 RESULTADO ESPERADO

### Zabbix Server (zbx-server-01):
- ✅ Diretórios criados e permissões OK
- ✅ Configuração template pronta
- ✅ Pré-requisitos instalados
- ✅ DNS configurado
- ✅ MTU corrigido
- ✅ Scripts de teste prontos
- **Timeline: ~55 min**

### Zabbix Frontend (zbx-fe-01):
- ✅ CPU/RAM upgraded (contatar virtualização)
- ✅ Diretórios criados
- ✅ Configs Nginx/PHP-FPM templates prontas
- ✅ Pré-requisitos instalados
- ✅ DNS configurado
- ✅ MTU corrigido
- ✅ Scripts de teste prontos
- **Timeline: ~55 min + upgrade hardware**

### PostgreSQL (pg-01):
- 🚗 Em recuperação SSH
- 📍 ETA: Desconhecido
- ✅ Plano de ação pronto
- ✅ Setup docs preparado

---

## 🎯 META FINAL

**Quando PostgreSQL voltar online:**

```
PostgreSQL ONLINE
    ↓
[Validação em 5 min]
    ↓
[Setup PostgreSQL em 2-3h - SETUP_POSTGRESQL_PRIMARY.md]
    ↓
[Setup Zabbix Server em 1-2h - usa pré-config já pronta]
    ↓
[Setup Zabbix Frontend em 1-2h - usa pré-config já pronta]
    ↓
PROJETO COMPLETO ✅
```

**Tempo total pós-PG:** ~4-6 horas (ao invés de 8-10h)

---

**Documento:** PLANO_ACAO_POR_SERVIDOR.md  
**Versão:** 1.0  
**Gerado:** 24/10/2026  
**Para:** Execução com acesso local aos servidores
