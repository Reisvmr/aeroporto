# Documentação de Instalação - AWX 22.x e Grafana 10.x

**Projeto:** Aeroporto - Zabbix 7.0 LTS + PostgreSQL + AWX + Grafana  
**Data:** 24/10/2026  
**Versão:** 1.0  
**Última atualização:** 24 de outubro de 2026

---

## 📋 Índice

1. [Visão Geral](#visão-geral)
2. [Componentes](#componentes)
3. [Pré-requisitos](#pré-requisitos)
4. [Checklist de Validação](#checklist-de-validação)
5. [Instalação do AWX](#instalação-do-awx)
6. [Instalação do Grafana](#instalação-do-grafana)
7. [Configurações Pós-Instalação](#configurações-pós-instalação)
8. [Troubleshooting](#troubleshooting)
9. [Referências](#referências)

---

## 🎯 Visão Geral

Este documento descreve o processo de instalação e configuração de **AWX 22.x** e **Grafana 10.x** para o ambiente de monitoramento do Aeroporto.

### Arquitetura Geral (5 Servidores)

| # | Hostname | IP | Função | CPU | RAM | Disco | Status |
|---|----------|----|----|-----|-----|-------|--------|
| 1 | pg-01 | 10.31.38.64 | PostgreSQL 16 | 20 vCPU | 96 GB | NVMe | 🔴 Offline |
| 2 | zbx-server-01 | 10.31.38.60 | Zabbix Server 7.0 | 8 vCPU | 22 GB | 45 GB | ✅ Online |
| 3 | zbx-fe-01 | 10.31.38.62 | Zabbix Frontend | 2 vCPU⚠️ | 7 GB⚠️ | 11 GB | ✅ Online |
| 4 | awx-01 | 10.31.38.68 | AWX 22.x | 4 vCPU | 16 GB | 150 GB | 🔵 Novo |
| 5 | grafana-01 | 10.31.38.66 | Grafana 10.x | 4 vCPU | 8 GB | 50 GB | 🔵 Novo |

---

## 🔧 Componentes

### AWX (Ansible AWX) - awx-01

**Finalidade:** Plataforma de automação Ansible com interface web

**Características:**
- Versão: 22.x
- Containerizado com Docker Compose
- Backend: PostgreSQL 16 (remoto em pg-01)
- Cache: Redis (local em container)
- Web UI: Porta 80/443
- Porta SSH: 22

**Arquitetura:**
```
┌─────────────────────────────────────┐
│     AWX 22.x (10.31.38.68)         │
├─────────────────────────────────────┤
│                                     │
│  ┌──────────┐  ┌──────────┐        │
│  │  AWX-WEB │  │ AWX-TASK │        │
│  └──────────┘  └──────────┘        │
│       ↓              ↓              │
│  ┌───────────────────────────┐     │
│  │  Redis (Cache)            │     │
│  └───────────────────────────┘     │
│       ↓                            │
│  ┌───────────────────────────┐     │
│  │ PostgreSQL (10.31.38.64)  │     │
│  └───────────────────────────┘     │
│                                     │
└─────────────────────────────────────┘
```

---

### Grafana (Visualização) - grafana-01

**Finalidade:** Dashboards e visualização de dados de monitoramento

**Características:**
- Versão: 10.x
- Instalação nativa via apt
- Backend: PostgreSQL 16 (remoto em pg-01)
- Web UI: Porta 3000
- Porta SSH: 22
- Integração: Zabbix como data source

**Arquitetura:**
```
┌─────────────────────────────────────┐
│  Grafana 10.x (10.31.38.66)        │
├─────────────────────────────────────┤
│                                     │
│  ┌──────────────────────────┐      │
│  │   Grafana Server         │      │
│  │   (Port 3000)            │      │
│  └──────────────────────────┘      │
│       ↓         ↓                  │
│  ┌──────────────────────────┐      │
│  │  PostgreSQL  │  Zabbix   │      │
│  │  (10.31.38.64)(10.31.38.60)    │
│  └──────────────────────────┘      │
│                                     │
└─────────────────────────────────────┘
```

---

## 📋 Pré-requisitos

### Sistema Operacional

- **Ubuntu 26.04 LTS** (confirmado em ambos servidores)
- Kernel: 7.0.0-30-generic ou superior
- Acesso root ou sudo sem senha

### Hardware Mínimo

#### AWX (awx-01)
- **CPU:** 4 vCPU (mínimo), 8 vCPU (recomendado)
- **RAM:** 16 GB (mínimo), 32 GB (recomendado)
- **Disco:** 150 GB espaço livre (SSD recomendado)
- **Rede:** 1 Gbps ou superior

#### Grafana (grafana-01)
- **CPU:** 4 vCPU (mínimo), 8 vCPU (recomendado)
- **RAM:** 8 GB (mínimo), 16 GB (recomendado)
- **Disco:** 50 GB espaço livre
- **Rede:** 1 Gbps ou superior

### Conectividade

**Todos os servidores devem poder acessar:**

| Serviço | Host | Porta | Protocolo |
|---------|------|-------|-----------|
| PostgreSQL | 10.31.38.64 | 5432 | TCP |
| Zabbix API | 10.31.38.60 | 80 | HTTP |
| Docker Registry | registry.docker.io | 443 | HTTPS |
| Docker Auth | auth.docker.io | 443 | HTTPS |
| Quay.io | quay.io | 443 | HTTPS |
| PyPI | pypi.org | 443 | HTTPS |
| GitHub | github.com | 443 | HTTPS |

**⚠️ Domínios com TCP 443 bloqueado:** Use proxy transparente ou configure firewall

### Software Obrigatório

#### AWX (awx-01)

```bash
# Verificar
docker --version
docker-compose --version
python3 --version
git --version

# Instalar se necessário
sudo apt-get update
sudo apt-get install -y docker.io docker-compose python3 git curl
```

#### Grafana (grafana-01)

```bash
# Verificar
apt --version
curl --version

# Instalar se necessário
sudo apt-get update
sudo apt-get install -y curl gnupg2 apt-transport-https software-properties-common
```

### Banco de Dados

**PostgreSQL 16** deve estar funcional em `10.31.38.64:5432`

Verificar conectividade:
```bash
# De AWX ou Grafana
nc -zv 10.31.38.64 5432
```

---

## ✅ Checklist de Validação

Antes de instalar, execute os scripts de validação de hardware:

### AWX (awx-01)

```bash
# Copiar script para o servidor
scp scripts/check-hardware-awx-01.sh root@10.31.38.68:/tmp/

# Executar validação
ssh root@10.31.38.68 'bash /tmp/check-hardware-awx-01.sh'
```

**Esperado:** 12 testes, 0 FAIL, máximo 2-3 WARN

### Grafana (grafana-01)

```bash
# Copiar script para o servidor
scp scripts/check-hardware-grafana-01.sh root@10.31.38.66:/tmp/

# Executar validação
ssh root@10.31.38.66 'bash /tmp/check-hardware-grafana-01.sh'
```

**Esperado:** 11 testes, 0 FAIL, máximo 1-2 WARN

---

## 🚀 Instalação do AWX

### Passo 1: Preparar Servidor AWX

```bash
# Conectar ao servidor
ssh root@10.31.38.68

# Verificar SO
cat /etc/os-release | grep VERSION

# Criar diretórios
mkdir -p /opt/awx /opt/awx/projects /var/log/awx
```

### Passo 2: Instalar Docker e Docker Compose

```bash
# Atualizar repositórios
apt-get update

# Instalar dependências
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Adicionar chave Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Adicionar repositório Docker
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Iniciar Docker
systemctl start docker
systemctl enable docker

# Verificar instalação
docker --version
docker-compose --version
```

### Passo 3: Executar Script de Instalação

```bash
# Copiar script
scp scripts/automated-install/04-awx-installer.sh root@10.31.38.68:/tmp/

# Executar instalação (interativa)
ssh root@10.31.38.68 'bash /tmp/04-awx-installer.sh'
```

**O script vai perguntar:**
1. Username administrador (padrão: admin)
2. Senha administrador (gerada aleatoriamente se vazio)
3. Host PostgreSQL (padrão: 10.31.38.64)
4. Porta PostgreSQL (padrão: 5432)
5. Database (padrão: awx)
6. Username PostgreSQL (padrão: awx)
7. Senha PostgreSQL (obrigatória)
8. Hostname/FQDN (padrão: awx.example.com)

### Passo 4: Aguardar Inicialização

```bash
# Ver logs em tempo real
ssh root@10.31.38.68 'docker-compose -f /opt/awx/docker-compose.yml logs -f'

# Aguardar 3-5 minutos
# Sinal de sucesso: "INFO: Starting Daphne..."
```

### Passo 5: Verificar Acesso

```bash
# Testar HTTP
curl -s http://10.31.38.68:80 | head -20

# Testar com credenciais
curl -u admin:SUA_SENHA http://10.31.38.68/api/v2/me/
```

---

## 🚀 Instalação do Grafana

### Passo 1: Preparar Servidor Grafana

```bash
# Conectar ao servidor
ssh root@10.31.38.66

# Verificar SO
cat /etc/os-release | grep VERSION

# Criar diretórios de log
mkdir -p /var/log/grafana
```

### Passo 2: Executar Script de Instalação

```bash
# Copiar script
scp scripts/automated-install/05-grafana-installer.sh root@10.31.38.66:/tmp/

# Executar instalação (interativa)
ssh root@10.31.38.66 'bash /tmp/05-grafana-installer.sh'
```

**O script vai perguntar:**
1. Username administrador (padrão: admin)
2. Senha administrador (gerada aleatoriamente se vazio)
3. Host PostgreSQL (padrão: 10.31.38.64)
4. Porta PostgreSQL (padrão: 5432)
5. Database (padrão: grafana)
6. Username PostgreSQL (padrão: grafana)
7. Senha PostgreSQL (obrigatória)
8. Zabbix API URL (padrão: http://10.31.38.60/api_jsonrpc.php)
9. Domain/FQDN (padrão: grafana.example.com)
10. HTTP Port (padrão: 3000)

### Passo 3: Aguardar Inicialização

```bash
# Ver status do serviço
ssh root@10.31.38.66 'systemctl status grafana-server'

# Ver logs
ssh root@10.31.38.66 'tail -f /var/log/grafana/grafana.log'
```

### Passo 4: Verificar Acesso

```bash
# Testar HTTP
curl -s http://10.31.38.66:3000 | head -20

# Testando com credenciais
curl -u admin:SUA_SENHA http://10.31.38.66:3000/api/datasources
```

---

## ⚙️ Configurações Pós-Instalação

### AWX - Configurar Credenciais Zabbix

1. Acesse: `http://10.31.38.68`
2. Login: `admin` / `<sua_senha>`
3. Menu: **Administration** → **Credentials**
4. Clique em **Create**
5. Preencha:
   - **Name:** Zabbix API
   - **Credential Type:** Machine
   - **Username:** Admin (Zabbix)
   - **Password:** <senha Zabbix>
   - **Host:** 10.31.38.60

### Grafana - Configurar Data Source Zabbix

1. Acesse: `http://10.31.38.66:3000`
2. Login: `admin` / `<sua_senha>`
3. Menu: **Configuration** → **Data Sources**
4. Clique em **Add data source**
5. Selecione **Zabbix**
6. Configure:
   - **Name:** Zabbix
   - **URL:** http://10.31.38.60/api_jsonrpc.php
   - **Access:** Proxy
   - **Zabbix API Details:**
     - **User:** Admin (Zabbix)
     - **Password:** <senha Zabbix>
7. Clique em **Save & Test**

### Grafana - Criar Dashboard Zabbix

1. Menu: **Create** → **Dashboard**
2. Clique em **Add new panel**
3. Selecione data source: **Zabbix**
4. Configure query para mostrar métricas desejadas
5. Salve o dashboard

### Mudar Senha Padrão

#### AWX

1. Acesse: `http://10.31.38.68`
2. Login: `admin` / `<senha_atual>`
3. Menu superior: Seu usuário → **Change password**
4. Digite nova senha
5. Clique em **Change password**

#### Grafana

1. Acesse: `http://10.31.38.66:3000`
2. Login: `admin` / `<senha_atual>`
3. Menu: **Profile** → **Change password**
4. Digite nova senha
5. Clique em **Change password**

---

## 🔧 Troubleshooting

### AWX - Contêineres não iniciam

```bash
# Verificar logs
docker-compose -f /opt/awx/docker-compose.yml logs

# Reiniciar
docker-compose -f /opt/awx/docker-compose.yml restart

# Limpar e reiniciar
docker-compose -f /opt/awx/docker-compose.yml down
docker-compose -f /opt/awx/docker-compose.yml up -d
```

### AWX - Erro de conexão PostgreSQL

```bash
# Verificar conectividade
nc -zv 10.31.38.64 5432

# Verificar credenciais
docker-compose -f /opt/awx/docker-compose.yml exec awx-web \
  psql -h 10.31.38.64 -U awx -d awx -c "SELECT 1"
```

### Grafana - Serviço não inicia

```bash
# Ver status
systemctl status grafana-server

# Ver logs
journalctl -u grafana-server -n 50

# Reiniciar
systemctl restart grafana-server
```

### Grafana - Data source Zabbix não conecta

1. Verificar conectividade:
   ```bash
   curl -v http://10.31.38.60/api_jsonrpc.php
   ```

2. Verificar credenciais Zabbix
3. Em Grafana: Configuration → Data Sources → Zabbix → Test

### Firewall bloqueando portas

Se TCP 443 está bloqueado para alguns domínios:

```bash
# Verificar regras
iptables -L -n | grep 443

# Liberar domínio específico
ufw allow from any to any port 443 proto tcp
```

---

## 📚 Referências

### Documentação Oficial

- [AWX Documentation](https://docs.ansible.com/ansible-tower/latest/)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [PostgreSQL 16 Documentation](https://www.postgresql.org/docs/16/)
- [Docker Documentation](https://docs.docker.com/)

### Scripts Fornecidos

| Script | Descrição | Localização |
|--------|-----------|-------------|
| `check-hardware-awx-01.sh` | Validação hardware AWX | `scripts/` |
| `check-hardware-grafana-01.sh` | Validação hardware Grafana | `scripts/` |
| `04-awx-installer.sh` | Instalação AWX | `scripts/automated-install/` |
| `05-grafana-installer.sh` | Instalação Grafana | `scripts/automated-install/` |

### Arquivo de Log de Instalação

Os logs de instalação são salvos em:
- **AWX:** `/var/log/awx-install.log`
- **Grafana:** `/var/log/grafana-install.log`

---

## 📊 Status dos Servidores (24/10/2026)

| Servidor | Status | Validação | Instalação |
|----------|--------|-----------|------------|
| pg-01 | 🔴 Offline | ❌ Não executada | ❌ Não iniciar |
| zbx-server-01 | ✅ Online | ✅ 35 PASS, 8 FAIL | ✅ Completa |
| zbx-fe-01 | ✅ Online | ✅ 35 PASS, 9 FAIL | ✅ Completa |
| awx-01 | 🔵 Novo | ⏳ Pendente | ⏳ Pendente |
| grafana-01 | 🔵 Novo | ⏳ Pendente | ⏳ Pendente |

---

## ⚠️ Problemas Conhecidos

### 1. PostgreSQL (pg-01) Offline
- **Status:** 🔴 CRÍTICO
- **Impacto:** Nenhum (AWX e Grafana usam container/instância local temporariamente)
- **Solução:** Aguardar recuperação via IPMI/KVM (contato Kaique)

### 2. Zabbix Frontend (zbx-fe-01) - CPU Insuficiente
- **Problema:** 2 vCPU (mínimo: 4)
- **Impacto:** Performance reduzida
- **Solução:** Solicitar upgrade para 4 vCPU mínimo

### 3. TCP 443 Bloqueado em 6+ Domínios
- **Problema:** Firewall bloqueia download de imagens Docker
- **Solução:** Usar proxy transparente ou liberar domínios críticos

---

**Documento preparado por:** Vinicius Reis (reisvmr@gmail.com)  
**Data de criação:** 24 de outubro de 2026  
**Última revisão:** 24 de outubro de 2026
