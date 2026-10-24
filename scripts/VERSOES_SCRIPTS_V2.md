# 📊 SCRIPTS DE VALIDAÇÃO - VERSÃO 2.0

**Data:** 23/10/2024  
**Projeto:** Aeroporto - Zabbix 7.0 LTS + PostgreSQL 16

---

## 🔄 Mudança de Foco: v1.1 → v2.0

### v1.1 (Original)
- ✅ Testava software (PostgreSQL, Zabbix, Nginx, PHP-FPM)
- ❌ Problema: Software não estava instalado ainda
- ❌ Resultado: Maioria dos testes falhava por ferramentas faltando

### v2.0 (Nova - RECOMENDADA)
- ✅ **Foco: Hardware + Conectividade**
- ✅ Testa CPU, RAM, Disco, Network
- ✅ Testa DNS, TCP, HTTPS
- ✅ Testa 14 domínios críticos
- ✅ Conectividade com PostgreSQL remoto e Zabbix Server
- ✅ Firewall pode estar desativado (não interfere)
- ❌ Não testa software (será instalado depois)

---

## ✅ O Que Mudou

### Hardware (Nova seção)

```bash
# CPU
✅ Valida vCPU (mínimo 8 para PostgreSQL, 4 para Frontend)
✅ Modifica spec conforme tipo de servidor

# RAM
✅ Valida memória (mínimo 16GB PostgreSQL, 4GB Frontend)
✅ Calcula em GB automaticamente

# Disco
✅ Valida espaço livre
✅ Detecta NVMe (preferido para PostgreSQL)
✅ Detecta SATA/SSD
✅ Valida MTU da interface
```

### Conectividade (Melhorada)

```bash
# DNS
✅ Testa resolução nslookup
✅ Valida nameservers em /etc/resolv.conf

# TCP (14 domínios)
✅ repo.zabbix.com
✅ www.zabbix.com
✅ rpm.grafana.com
✅ apt.grafana.com
✅ grafana.com
✅ download.postgresql.org
✅ github.com
✅ api.github.com
✅ raw.githubusercontent.com
✅ objects.githubusercontent.com
✅ release-assets.githubusercontent.com
✅ quay.io
✅ galaxy.ansible.com
✅ auth.docker.io

# HTTPS
✅ Testa acesso com curl
✅ Retorna HTTP status code
✅ Valida certificados SSL

# ICMP (Ping)
✅ Testa conectividade básica
⚠️  Pode estar bloqueado (firewall corporativo)

# Conectividade Remota (novo)
✅ PostgreSQL (10.31.38.64:5432)
✅ Zabbix Server (zbx-server-01:10051)
```

### O Que NÃO Testa Mais

```bash
❌ PostgreSQL binário
❌ Zabbix Server binário
❌ Nginx/Apache
❌ PHP-FPM
❌ Systemd services
❌ Configurações de software
```

---

## 📂 Scripts Disponíveis

### Versão 1.1 (Original - NÃO RECOMENDADA)

```bash
scripts/check-server-pg-01-IMPROVED.sh
scripts/check-server-zbx-server-01-IMPROVED.sh
scripts/check-server-zbx-fe-01-IMPROVED.sh
```

**Quando usar:**
- ❌ Não recomendado (software não está instalado)

**Problemas:**
- Muitos testes falham por falta de software
- Gera muitos avisos desnecessários

---

### Versão 2.0 (Nova - RECOMENDADA)

```bash
scripts/check-server-pg-01-v2.sh           ✅
scripts/check-server-zbx-server-01-v2.sh   ✅
scripts/check-server-zbx-fe-01-v2.sh       ✅
```

**Quando usar:**
- ✅ SEMPRE (antes de começar setup)

**Vantagens:**
- Foco em hardware e conectividade
- Software não é problema
- Testa 14 domínios críticos
- Relatórios mais úteis

---

## 🚀 Como Usar v2.0

### PostgreSQL Primary (10.31.38.64)

```bash
# Copiar script
scp scripts/check-server-pg-01-v2.sh root@10.31.38.64:/tmp/

# Conectar no servidor
ssh root@10.31.38.64

# Executar
chmod +x /tmp/check-server-pg-01-v2.sh
sudo /tmp/check-server-pg-01-v2.sh

# Verificar relatório
cat /tmp/check-pg-01-YYYYMMDD_HHMMSS.txt
```

### Zabbix Server

```bash
# Copiar script
scp scripts/check-server-zbx-server-01-v2.sh root@<IP>:/tmp/

# Conectar no servidor
ssh root@<IP>

# Executar
chmod +x /tmp/check-server-zbx-server-01-v2.sh
sudo /tmp/check-server-zbx-server-01-v2.sh

# Verificar relatório
cat /tmp/check-zbx-server-01-YYYYMMDD_HHMMSS.txt
```

### Zabbix Frontend

```bash
# Copiar script
scp scripts/check-server-zbx-fe-01-v2.sh root@<IP>:/tmp/

# Conectar no servidor
ssh root@<IP>

# Executar
chmod +x /tmp/check-server-zbx-fe-01-v2.sh
sudo /tmp/check-server-zbx-fe-01-v2.sh

# Verificar relatório
cat /tmp/check-zbx-fe-01-YYYYMMDD_HHMMSS.txt
```

---

## 📋 Checklist de Validação v2.0

### PostgreSQL (10.31.38.64)

- [ ] ✅ Hostname apropriado (contém "pg" ou "postgres")
- [ ] ✅ OS suportado (Ubuntu 22.04+, CentOS 8+, RHEL 8+)
- [ ] ✅ CPU: mínimo 8 vCPU (recomendado 16+)
- [ ] ✅ RAM: mínimo 16 GB (recomendado 32+ GB)
- [ ] ✅ Disco: 500+ GB livres em / (melhor em NVMe)
- [ ] ✅ Interface de rede: 1+ interface configurada
- [ ] ✅ DNS: Resolução funcionando
- [ ] ✅ TCP 443: 14/14 domínios abertos
- [ ] ✅ HTTPS: 14/14 domínios acessíveis
- [ ] ✅ Ping: Acessível (ou firewall bloqueia ICMP)
- [ ] ✅ MTU: 1500 (padrão)

### Zabbix Server

- [ ] ✅ Hostname apropriado (contém "server" ou "zbx")
- [ ] ✅ OS suportado (Ubuntu 22.04+, CentOS 8+, RHEL 8+)
- [ ] ✅ CPU: mínimo 8 vCPU (recomendado 12+)
- [ ] ✅ RAM: mínimo 8 GB (recomendado 16+ GB)
- [ ] ✅ Disco: 100+ GB livres
- [ ] ✅ Interface de rede: 1+ interface configurada
- [ ] ✅ DNS: Resolução funcionando
- [ ] ✅ TCP 443: 14/14 domínios abertos
- [ ] ✅ HTTPS: 14/14 domínios acessíveis
- [ ] ✅ TCP 5432: Conecta em PostgreSQL (10.31.38.64:5432)
- [ ] ✅ MTU: 1500 (padrão)

### Zabbix Frontend

- [ ] ✅ Hostname apropriado (contém "fe" ou "frontend")
- [ ] ✅ OS suportado (Ubuntu 22.04+, CentOS 8+, RHEL 8+)
- [ ] ✅ CPU: mínimo 4 vCPU (recomendado 8+)
- [ ] ✅ RAM: mínimo 4 GB (recomendado 8+ GB)
- [ ] ✅ Disco: 100+ GB livres (recomendado 100+ GB)
- [ ] ✅ Interface de rede: 1+ interface configurada
- [ ] ✅ DNS: Resolução funcionando
- [ ] ✅ TCP 443: 14/14 domínios abertos
- [ ] ✅ HTTPS: 14/14 domínios acessíveis
- [ ] ✅ TCP 5432: Conecta em PostgreSQL (10.31.38.64:5432)
- [ ] ✅ TCP 10051: Conecta em Zabbix Server (zbx-server-01:10051)
- [ ] ✅ MTU: 1500 (padrão)

---

## 📊 Saída Esperada v2.0

### PASS (servidor pronto)

```
════════════════════════════════════════════════════════════════
RESUMO DA VALIDAÇÃO
════════════════════════════════════════════════════════════════

Total de verificações: 13
  ✅ Passou: 13
  ❌ Falhou: 0
  ⚠️  Aviso: 0

✅ SERVIDOR APROVADO PARA SETUP!

Próximas etapas:
  1. Executar SETUP_*.md correspondente
  2. Instalar software

Relatório completo: /tmp/check-pg-01-20241023_153045.txt
```

### WARN (ajustes menores)

```
════════════════════════════════════════════════════════════════
RESUMO DA VALIDAÇÃO
════════════════════════════════════════════════════════════════

Total de verificações: 13
  ✅ Passou: 11
  ❌ Falhou: 0
  ⚠️  Aviso: 2

⚠️  SERVIDOR COM AVISOS MENORES

Possíveis avisos:
  • CPU: 8 vCPU (mínimo, recomenda-se 16+)
  • RAM: 16 GB (mínimo, recomenda-se 32+)
  • NVMe não detectado (SATA/SSD ok)
  • 1-2 domínios com TCP lento

Próximas etapas:
  1. Resolver avisos se possível
  2. Pode prosseguir com setup mesmo com avisos

Relatório completo: /tmp/check-pg-01-20241023_153045.txt
```

### FAIL (bloqueador)

```
════════════════════════════════════════════════════════════════
RESUMO DA VALIDAÇÃO
════════════════════════════════════════════════════════════════

Total de verificações: 13
  ✅ Passou: 9
  ❌ Falhou: 3
  ⚠️  Aviso: 1

⚠️  SERVIDOR NECESSITA AJUSTES

Erros encontrados:
  ❌ TCP 443: 10/14 domínios FECHADOS
  ❌ HTTPS: 10/14 domínios INACESSÍVEIS
  ❌ Conectividade PostgreSQL falhou

Próximas etapas:
  1. BLOQUEAR: Resolver conectividade TCP/HTTPS
  2. Verificar firewall corporativo
  3. Pedir liberação de portas
  4. Re-executar validação

Relatório completo: /tmp/check-pg-01-20241023_153045.txt
```

---

## 🔧 Especificações por Tipo de Servidor

### PostgreSQL Primary (10.31.38.64)

| Recurso | Mínimo | Recomendado | Crítico |
|---------|--------|-------------|---------|
| CPU | 8 vCPU | 16+ vCPU | ❌ |
| RAM | 16 GB | 32+ GB | ❌ |
| Disco | 500 GB | 1+ TB | ✅ |
| NVMe | Não | Sim | ✅ |
| Network | 1 Gbps | 10 Gbps | ❌ |
| Conectividade | TCP/HTTPS | TCP/HTTPS | ✅ |

### Zabbix Server

| Recurso | Mínimo | Recomendado | Crítico |
|---------|--------|-------------|---------|
| CPU | 8 vCPU | 12+ vCPU | ❌ |
| RAM | 8 GB | 16+ GB | ❌ |
| Disco | 100 GB | 200+ GB | ❌ |
| Network | 1 Gbps | 1 Gbps | ❌ |
| Conectividade | TCP/HTTPS + PG | TCP/HTTPS + PG | ✅ |

### Zabbix Frontend

| Recurso | Mínimo | Recomendado | Crítico |
|---------|--------|-------------|---------|
| CPU | 4 vCPU | 8+ vCPU | ❌ |
| RAM | 4 GB | 8+ GB | ❌ |
| Disco | 50 GB | 100+ GB | ❌ |
| Network | 1 Gbps | 1 Gbps | ❌ |
| Conectividade | TCP/HTTPS + PG + Server | TCP/HTTPS + PG + Server | ✅ |

---

## 🎯 Recomendação Final

**USE SEMPRE V2.0 ANTES DE COMEÇAR SETUP**

```bash
✅ check-server-pg-01-v2.sh
✅ check-server-zbx-server-01-v2.sh
✅ check-server-zbx-fe-01-v2.sh
```

**Motivos:**
- Foco em hardware + conectividade (não em software)
- Identifica problemas antes do setup
- Testa 14 domínios críticos
- Firewall desativado não interfere
- Relatórios mais úteis e orientados

---

**Status:** ✅ Scripts v2.0 prontos para uso  
**GitHub:** https://github.com/Reisvmr/aeroporto.git  
**Scripts:** `scripts/check-server-*-v2.sh`
