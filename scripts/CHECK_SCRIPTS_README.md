# 🔍 SCRIPTS DE VALIDAÇÃO - PROJETO AEROPORTO

**Data:** 23/10/2024  
**Versão:** 1.0  
**Projeto:** Aeroporto - Zabbix 7.0 LTS + PostgreSQL 16 (676 ativos)

---

## 📋 Resumo

Três scripts bash que validam se cada servidor está **de acordo com a especificação do projeto**. Cada script:

1. ✅ Verifica hardware (CPU, RAM, disco)
2. ✅ Verifica software (SO, versões, serviços)
3. ✅ Valida configurações críticas
4. ✅ Testa conectividade
5. ✅ **Mostra como está vs. como deveria estar**
6. ✅ **Fornece opções de ação** para problemas detectados
7. ✅ **Gera relatório de auditoria** em arquivo

---

## 🎯 Uso Rápido

### Script 1: Validar PostgreSQL (10.31.38.64)

```bash
# No servidor 10.31.38.64
scp scripts/check-server-pg-01.sh root@10.31.38.64:/tmp/
ssh root@10.31.38.64
chmod +x /tmp/check-server-pg-01.sh
sudo /tmp/check-server-pg-01.sh

# Resultado:
# ✅ PASS, ❌ FAIL, ⚠️ WARN, ℹ️ INFO
# Relatório em: /tmp/check-pg-01-YYYYMMDD_HHMMSS.txt
```

### Script 2: Validar Zabbix Server (zbx-server-01)

```bash
# No servidor zbx-server-01
scp scripts/check-server-zbx-server-01.sh root@<IP-zbx-server>:/tmp/
ssh root@<IP-zbx-server>
chmod +x /tmp/check-server-zbx-server-01.sh
sudo /tmp/check-server-zbx-server-01.sh
```

### Script 3: Validar Zabbix Frontend (zbx-fe-01)

```bash
# No servidor zbx-fe-01
scp scripts/check-server-zbx-fe-01.sh root@<IP-zbx-fe>:/tmp/
ssh root@<IP-zbx-fe>
chmod +x /tmp/check-server-zbx-fe-01.sh
sudo /tmp/check-server-zbx-fe-01.sh
```

---

## 📊 O Que Cada Script Valida

### ✅ check-server-pg-01.sh (PostgreSQL Primary)

| # | Verificação | Esperado | Ações |
|----|-------|----------|--------|
| 1 | Hostname | `pg-primary-01` ou `pg-01` | Alterar via `hostnamectl` |
| 2 | Sistema Operacional | Ubuntu 20.04+, Debian 11+, CentOS 8+, RHEL 8+ | Atualizar SO |
| 3 | CPU | 20 vCPU | Upgrade no datacenter |
| 4 | RAM | 96 GB | Upgrade no datacenter |
| 5 | Firewall | Porta 5432 aberta | Configurar `firewall-cmd` ou `ufw` |
| 6 | NTP | Chrony/NTP sincronizado | Iniciar serviço |
| 7 | Storage | NVMe 800GB-1TB em `/pgdata` | **CRÍTICO**: Opção 1/2/3 em `VALIDACAO_DISCO_PG01.md` |
| 8 | PostgreSQL 16 | Instalado e rodando | Seguir `SETUP_POSTGRESQL_PRIMARY.md` |
| 9 | Database Zabbix | `zabbix` criado com usuário `zabbix` | Setup PostgreSQL |
| 10 | Espaço Disponível | >= 800GB em `/pgdata` | Expandir ou limpar dados |
| 11 | Conectividade | DNS + HTTPS OK | Testar: `curl https://github.com` |
| 12 | Parâmetros Kernel | `kernel.shmmax` >= 16GB | Ajustar `/etc/sysctl.conf` |

---

### ✅ check-server-zbx-server-01.sh (Zabbix Server)

| # | Verificação | Esperado | Ações |
|----|-------|----------|--------|
| 1 | Hostname | `zbx-server-01` ou `zabbix-server` | Alterar via `hostnamectl` |
| 2 | Sistema Operacional | Ubuntu 20.04+, Debian 11+, CentOS 8+, RHEL 8+ | Atualizar SO |
| 3 | CPU | 16 vCPU (mín. 8) | Upgrade no datacenter |
| 4 | RAM | 32 GB (mín. 16) | Upgrade no datacenter |
| 5 | Firewall | Porta 10051 aberta | Configurar firewall |
| 6 | NTP | Chrony/NTP sincronizado | Iniciar serviço |
| 7 | Storage | SSD 120GB-200GB | Expandir se necessário |
| 8 | Zabbix Server 7.0 | Instalado e rodando | Seguir `SETUP_ZABBIX_SERVER_01.md` |
| 9 | Zabbix Agent 2.0 | Instalado para auto-monitoring | Setup Zabbix |
| 10 | Conectividade PostgreSQL | TCP 10.31.38.64:5432 OK | Verificar firewall/rede |
| 11 | Config Zabbix | `/etc/zabbix/zabbix_server.conf` OK | Editar arquivo |
| 12 | Conectividade Rede | DNS + IP OK | Testar DNS |

---

### ✅ check-server-zbx-fe-01.sh (Zabbix Frontend)

| # | Verificação | Esperado | Ações |
|----|-------|----------|--------|
| 1 | Hostname | `zbx-fe-01` ou `zabbix-frontend` | Alterar via `hostnamectl` |
| 2 | Sistema Operacional | Ubuntu 20.04+, Debian 11+, CentOS 8+, RHEL 8+ | Atualizar SO |
| 3 | CPU | 8 vCPU (mín. 4) | Upgrade no datacenter |
| 4 | RAM | 16 GB (mín. 8) | Upgrade no datacenter |
| 5 | Firewall | Portas 80, 443 abertas | Configurar firewall |
| 6 | NTP | Chrony/NTP sincronizado | Iniciar serviço |
| 7 | Servidor Web | Nginx ou Apache | Instalar conforme setup |
| 8 | PHP | 7.4+ com FPM | Instalar PHP-FPM |
| 9 | Zabbix Frontend 7.0 | Instalado | Seguir `SETUP_ZABBIX_FRONTEND_01.md` |
| 10 | Certificado SSL | Auto-assinado OK | Gerar auto-assinado |
| 11 | Conectividade PostgreSQL | TCP 10.31.38.64:5432 OK | Verificar firewall/rede |
| 12 | Conectividade Zabbix Server | Port 10051 acessível | Testar `telnet <IP> 10051` |

---

## 📤 Relatórios Gerados

Cada script gera um **arquivo de relatório** em `/tmp/`:

```bash
/tmp/check-pg-01-20241023_153045.txt
/tmp/check-zbx-server-01-20241023_153045.txt
/tmp/check-zbx-fe-01-20241023_153045.txt
```

**Conteúdo do relatório:**
```
╔════════════════════════════════════════════════════════════════╗
║  RELATÓRIO DE VALIDAÇÃO - SERVIDOR POSTGRESQL PRIMARY          ║
║  Data: 2024-10-23 15:30:45
║  Hostname: pg-01
╚════════════════════════════════════════════════════════════════╝

✅ PASS: Hostname configurado corretamente
❌ FAIL: Disco NVMe NÃO está montado em /pgdata
⚠️  WARN: Storage < 800GB disponível
ℹ️  INFO: IP: 10.31.38.64

[... mais 50+ linhas com detalhes ...]

Resumo:
  Passou: 8
  Falhou: 2
  Aviso: 3
  Informação: 5
```

---

## 🎯 Fluxo de Uso Recomendado

### Fase 1: Pré-Setup (Antes de qualquer procedimento)

```bash
# 1. Em cada servidor, rodar o script de validação
sudo /tmp/check-server-pg-01.sh     # PostgreSQL
sudo /tmp/check-server-zbx-server-01.sh   # Zabbix Server
sudo /tmp/check-server-zbx-fe-01.sh       # Zabbix Frontend

# 2. Analisar os relatórios gerados
cat /tmp/check-pg-01-*.txt
cat /tmp/check-zbx-server-01-*.txt
cat /tmp/check-zbx-fe-01-*.txt

# 3. Resolver as falhas (❌ FAIL) listadas
#    Avisos (⚠️ WARN) são opcionais dependendo da situação

# 4. Re-rodar scripts para confirmar
```

### Fase 2: Pós-Setup (Após instalação)

```bash
# Re-executar scripts para validar que setup funcionou
sudo /tmp/check-server-pg-01.sh
sudo /tmp/check-server-zbx-server-01.sh
sudo /tmp/check-server-zbx-fe-01.sh

# Deve ter:
# ✅ Mais PASS (serviços instalados)
# ❌ Menos FAIL (problemas resolvidos)
# ✅ Todos os serviços rodando
```

---

## 🔧 Componentes de Cada Script

### 1. Funções Utilitárias
```bash
print_header()     # Cabeçalho de seção
print_pass()       # ✅ PASS
print_fail()       # ❌ FAIL
print_warn()       # ⚠️ WARN
print_info()       # ℹ️ INFO
print_spec()       # O que era esperado
print_current()    # O que foi encontrado
print_options()    # Opções de ação
```

### 2. Checagens Estruturadas
Cada checagem:
- Define o esperado (specification)
- Mostra o atual (reality)
- Classifica em PASS/FAIL/WARN/INFO
- Fornece opções de ação

### 3. Relatório Automático
- Cada print também escreve em arquivo
- Arquivo salvo em `/tmp/check-server-*.txt`
- Permite auditoria posterior

### 4. Resumo Final
- Contagem de PASS/FAIL/WARN/INFO
- Status final: ✅ Pronto / ❌ Não pronto
- Localização do relatório

---

## 📝 Exemplo de Output

```bash
root@pg-01:~# sudo /tmp/check-server-pg-01.sh

╔════════════════════════════════════════════════════════════════╗
║  SCRIPT DE VALIDAÇÃO - SERVIDOR POSTGRESQL PRIMARY             ║
║  IP: 10.31.38.64                                              ║
║  Projeto: Aeroporto - Zabbix 7.0 LTS + PostgreSQL 16           ║
╚════════════════════════════════════════════════════════════════╝

════════════════════════════════════════════════════════════════
  1. HOSTNAME
════════════════════════════════════════════════════════════════

  Esperado: pg-primary-01 ou pg-01
  Atual:    pg-01

✅ PASS  : Hostname configurado corretamente

════════════════════════════════════════════════════════════════
  2. SISTEMA OPERACIONAL
════════════════════════════════════════════════════════════════

  Esperado: Ubuntu 20.04+, Debian 11+, CentOS 8+, RHEL 8+
  Atual:    Ubuntu 24.04

✅ PASS  : Ubuntu >= 20.04 detectado

[... mais 80+ linhas ...]

════════════════════════════════════════════════════════════════
RESUMO DA CHECAGEM
════════════════════════════════════════════════════════════════

Total de verificações: 12
  Passou: 8
  Falhou: 1
  Aviso: 2
  Informação: 1

⚠️  SERVIDOR QUASE PRONTO - RESOLVER FALHAS CRÍTICAS

Relatório completo salvo em:
  /tmp/check-pg-01-20241023_153045.txt

════════════════════════════════════════════════════════════════
```

---

## 🚀 Instalação Rápida

### Opção 1: Via Git (Recomendado)

```bash
# Clonar repositório
git clone https://github.com/Reisvmr/aeroporto.git
cd aeroporto

# Usar scripts direto
bash scripts/check-server-pg-01.sh
bash scripts/check-server-zbx-server-01.sh
bash scripts/check-server-zbx-fe-01.sh
```

### Opção 2: Copiar Scripts para Servidor

```bash
# Em sua máquina local
cd aeroporto

# Copiar para servidor PostgreSQL
scp scripts/check-server-pg-01.sh root@10.31.38.64:/tmp/

# Copiar para Zabbix Server
scp scripts/check-server-zbx-server-01.sh root@<IP-zbx-server>:/tmp/

# Copiar para Zabbix Frontend
scp scripts/check-server-zbx-fe-01.sh root@<IP-zbx-fe>:/tmp/

# Executar nos servidores
ssh root@10.31.38.64 "chmod +x /tmp/check-server-pg-01.sh && /tmp/check-server-pg-01.sh"
```

---

## 📋 Requisitos para Usar Scripts

Os scripts requerem:
- ✅ Bash 4.0+
- ✅ `sudo` acesso (ou rodar como root)
- ✅ Ferramentas comuns: `nc`, `curl`, `psql` (opcionais para testes)
- ✅ Acesso de leitura a arquivos de configuração

---

## 🔐 Segurança

Os scripts:
- ✅ Não modificam nada (apenas leem e reportam)
- ✅ Salvam relatórios em `/tmp` (protegido por permissões do SO)
- ✅ Podem ser rodados múltiplas vezes sem efeitos colaterais
- ✅ Suportem tanto CentOS como Ubuntu/Debian

---

## 📞 Documentação Relacionada

- **VALIDACAO_DISCO_PG01.md** - Se disco NVMe não detectado
- **SETUP_POSTGRESQL_PRIMARY.md** - Setup PostgreSQL (referência)
- **SETUP_ZABBIX_SERVER_01.md** - Setup Zabbix Server (referência)
- **SETUP_ZABBIX_FRONTEND_01.md** - Setup Zabbix Frontend (referência)
- **SETUP_PROCEDURES_README.md** - Guia geral do projeto

---

## ✅ Checklist - Usar Scripts

- [ ] Clonar repositório `git clone https://github.com/Reisvmr/aeroporto.git`
- [ ] Copiar scripts para cada servidor
- [ ] Executar `check-server-pg-01.sh` em 10.31.38.64
- [ ] Executar `check-server-zbx-server-01.sh` em zbx-server-01
- [ ] Executar `check-server-zbx-fe-01.sh` em zbx-fe-01
- [ ] Analisar relatórios em `/tmp/check-*.txt`
- [ ] Resolver falhas (❌ FAIL) conforme opções sugeridas
- [ ] Re-executar scripts para confirmar
- [ ] Prosseguir com setup procedures

---

**Status:** ✅ Scripts prontos para uso  
**Repositório:** https://github.com/Reisvmr/aeroporto.git  
**Localização:** `scripts/check-server-*.sh`

