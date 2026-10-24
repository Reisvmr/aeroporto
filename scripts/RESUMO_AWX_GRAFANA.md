# Scripts AWX + Grafana - Resumo Executivo

**Projeto:** Aeroporto - Infraestrutura Zabbix 7.0 LTS + AWX + Grafana  
**Data:** 24/10/2026  
**Versão:** 1.0

---

## 📦 Arquivos Criados

### 1. Scripts de Validação Hardware

#### `check-hardware-awx-01.sh` (461 linhas)
- **Descrição:** Validação completa de hardware para AWX (10.31.38.68)
- **Testes:** 12 validações automatizadas
  - Hostname e informações servidor
  - Sistema Operacional (Ubuntu 26.04)
  - CPU (mínimo 4 vCPU)
  - RAM (mínimo 16 GB)
  - Disco (mínimo 150 GB)
  - Interface de rede
  - Resolução DNS
  - TCP 443 para 8 domínios críticos
  - HTTPS com curl
  - NTP/Sincronização
  - Conectividade para servidores internos
  - Docker + Docker Compose

**Uso:**
```bash
sudo bash check-hardware-awx-01.sh
```

#### `check-hardware-grafana-01.sh` (416 linhas)
- **Descrição:** Validação completa de hardware para Grafana (10.31.38.66)
- **Testes:** 11 validações automatizadas
  - Hostname e informações servidor
  - Sistema Operacional (Ubuntu 26.04)
  - CPU (mínimo 4 vCPU)
  - RAM (mínimo 8 GB)
  - Disco (mínimo 50 GB)
  - Interface de rede
  - Resolução DNS
  - TCP 443 para 6 domínios críticos
  - HTTPS com curl
  - NTP/Sincronização
  - Conectividade Zabbix Server

**Uso:**
```bash
sudo bash check-hardware-grafana-01.sh
```

---

### 2. Scripts de Instalação Automática

#### `04-awx-installer.sh` (509 linhas, 17.9 KB)
- **Descrição:** Instalação completa e interativa do AWX 22.x
- **Método:** Docker Compose
- **Recursos:**
  - ✅ Validação pré-requisitos (Docker, Docker Compose, Python, Git)
  - ✅ Perguntas interativas para customização
  - ✅ Geração segura de credenciais (senhas aleatórias)
  - ✅ Download automático AWX 22.x
  - ✅ Criação arquivo docker-compose.yml
  - ✅ Inicialização serviços (web + task + postgres + redis)
  - ✅ Validação pós-instalação
  - ✅ Logs detalhados (/var/log/awx-install.log)

**Perguntas Interativas:**
1. Username administrador (padrão: admin)
2. Senha administrador (gerada aleatoriamente se vazio)
3. Host PostgreSQL (padrão: 10.31.38.64)
4. Porta PostgreSQL (padrão: 5432)
5. Database (padrão: awx)
6. Username PostgreSQL (padrão: awx)
7. Senha PostgreSQL (obrigatória)
8. Hostname/FQDN (padrão: awx.example.com)

**Uso:**
```bash
sudo bash 04-awx-installer.sh
```

**Resultado:**
```
AWX instalado em: http://10.31.38.68:80
Login: admin / <senha_gerada>
Acesso via: docker-compose -f /opt/awx/docker-compose.yml logs
```

---

#### `05-grafana-installer.sh` (458 linhas, 18.6 KB)
- **Descrição:** Instalação completa e interativa do Grafana 10.x
- **Método:** Instalação nativa via apt
- **Recursos:**
  - ✅ Validação pré-requisitos (Ubuntu, espaço disco, RAM)
  - ✅ Perguntas interativas para customização
  - ✅ Adição repositório oficial Grafana
  - ✅ Instalação pacote Grafana 10.x
  - ✅ Configuração arquivo grafana.ini
  - ✅ Instalação plugins recomendados
  - ✅ Inicialização serviço systemd
  - ✅ Integração com Zabbix como data source
  - ✅ Validação pós-instalação
  - ✅ Logs detalhados (/var/log/grafana-install.log)

**Perguntas Interativas:**
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

**Uso:**
```bash
sudo bash 05-grafana-installer.sh
```

**Resultado:**
```
Grafana instalado em: http://10.31.38.66:3000
Login: admin / <senha_gerada>
Acesso via: systemctl status grafana-server
```

---

### 3. Documentação

#### `INSTALACAO_AWX_GRAFANA.md` (464 linhas, 15.2 KB)
- **Descrição:** Guia completo de instalação e configuração
- **Conteúdo:**
  - Visão geral da arquitetura (5 servidores)
  - Componentes (AWX e Grafana)
  - Pré-requisitos detalhados
  - Checklist de validação de hardware
  - Instruções passo-a-passo para AWX
  - Instruções passo-a-passo para Grafana
  - Configurações pós-instalação
  - Troubleshooting detalhado
  - Referências e links úteis
  - Status atual dos servidores
  - Problemas conhecidos

---

## 📊 Resumo Técnico

### Especificações de Hardware

| Componente | AWX | Grafana |
|------------|-----|---------|
| **CPU** | 4 vCPU (8+ recomendado) | 4 vCPU (8+ recomendado) |
| **RAM** | 16 GB (32+ recomendado) | 8 GB (16+ recomendado) |
| **Disco** | 150 GB SSD | 50 GB SSD |
| **SO** | Ubuntu 26.04 | Ubuntu 26.04 |
| **Rede** | 1 Gbps | 1 Gbps |

### Portas e Serviços

**AWX (10.31.38.68):**
- 22/TCP → SSH
- 80/TCP → HTTP (Web UI)
- 443/TCP → HTTPS (Web UI)
- 5432/TCP → PostgreSQL (conexão remota para pg-01)
- Redis: Internal (container)

**Grafana (10.31.38.66):**
- 22/TCP → SSH
- 3000/TCP → Web UI (padrão)
- 80/TCP → HTTP (redirecionamento opcional)
- 5432/TCP → PostgreSQL (conexão remota para pg-01)

### Domínios Críticos (Firewall)

**Deve liberar TCP 443 para:**
- registry.docker.io
- auth.docker.io
- docker.io
- quay.io
- grafana.com
- apt.grafana.com
- github.com
- pypi.org

---

## 🚀 Fluxo de Execução Recomendado

### Fase 1: Validação (15-30 minutos)

```bash
# AWX
ssh root@10.31.38.68 'bash /tmp/check-hardware-awx-01.sh'

# Grafana
ssh root@10.31.38.66 'bash /tmp/check-hardware-grafana-01.sh'
```

**Esperado:**
- ✅ Máximo 2-3 WARN (não FAIL)
- ✅ Todos pré-requisitos OK
- ✅ Conectividade com PostgreSQL funcionando

### Fase 2: Instalação (75-110 minutos)

**AWX (40-50 minutos)**
```bash
ssh root@10.31.38.68
bash /tmp/04-awx-installer.sh
# Responder às perguntas interativas
```

**Grafana (20-30 minutos)**
```bash
ssh root@10.31.38.66
bash /tmp/05-grafana-installer.sh
# Responder às perguntas interativas
```

### Fase 3: Configuração Pós-Instalação (30-45 minutos)

1. **AWX:**
   - Acessar Web UI
   - Mudar senha padrão
   - Configurar credenciais Zabbix

2. **Grafana:**
   - Acessar Web UI
   - Mudar senha padrão
   - Adicionar data source Zabbix
   - Criar dashboard de exemplo

---

## 📋 Checklist de Implementação

- [ ] Validar hardware AWX (check-hardware-awx-01.sh)
- [ ] Validar hardware Grafana (check-hardware-grafana-01.sh)
- [ ] Instalar AWX (04-awx-installer.sh)
- [ ] Instalar Grafana (05-grafana-installer.sh)
- [ ] Configurar credenciais AWX
- [ ] Configurar credenciais Grafana
- [ ] Integrar Zabbix em AWX
- [ ] Integrar Zabbix em Grafana
- [ ] Criar dashboards de exemplo
- [ ] Testar e-mail/notificações
- [ ] Documentar configurações finais
- [ ] Fazer backup das configurações

---

## 🔍 Validação Pós-Instalação

### AWX

```bash
# Verificar contêineres
docker-compose -f /opt/awx/docker-compose.yml ps

# Verificar acesso
curl -u admin:<senha> http://10.31.38.68/api/v2/me/

# Verificar logs
docker-compose -f /opt/awx/docker-compose.yml logs awx-web | tail -20
```

### Grafana

```bash
# Verificar serviço
systemctl status grafana-server

# Verificar acesso
curl -u admin:<senha> http://10.31.38.66:3000/api/datasources

# Verificar logs
tail -f /var/log/grafana/grafana.log
```

---

## ⚙️ Configurações Importantes

### Senhas e Segurança

**⚠️ IMPORTANTE:**
- Senhas são geradas aleatoriamente (se não fornecidas)
- Armazenar em local seguro (Vault, 1Password, etc.)
- Mudar senha padrão IMEDIATAMENTE após instalação
- Não compartilhar credenciais via e-mail não criptografado

### Backup

Recomenda-se backup:
- `/opt/awx/docker-compose.yml` (AWX)
- `/etc/grafana/grafana.ini` (Grafana)
- Banco de dados PostgreSQL (pg-01)

### Monitoramento

- AWX logs: `/var/log/awx-install.log`
- AWX container logs: `docker-compose logs`
- Grafana logs: `/var/log/grafana/grafana.log`
- Grafana systemd: `journalctl -u grafana-server -f`

---

## 📞 Suporte e Troubleshooting

### Erros Comuns

1. **"Docker not found"**
   - Executar: `sudo apt-get install docker.io docker-compose`

2. **"PostgreSQL connection refused"**
   - Verificar: `nc -zv 10.31.38.64 5432`
   - Verificar credenciais
   - Verificar firewall

3. **"Service not responding"**
   - Verificar logs (docker-compose ou journalctl)
   - Aumentar timeout de inicialização
   - Verificar disponibilidade de recursos

### Recurso de Contato

Para problemas:
1. Verificar logs em `/var/log/`
2. Executar checklist de troubleshooting em INSTALACAO_AWX_GRAFANA.md
3. Contatar: Vinicius Reis (reisvmr@gmail.com)

---

## 📝 Notas da Implementação

- Scripts criados em: 24/10/2026
- Versões: AWX 22.x, Grafana 10.x
- Ubuntu 26.04 confirmado em todos os servidores
- PostgreSQL 16 será compartilhado (quando pg-01 for recuperado)
- Firewall pode bloquear TCP 443 para alguns domínios (solucionar com proxy ou liberar manualmente)

---

**Preparado por:** Vinicius Reis (reisvmr@gmail.com)  
**Data:** 24 de outubro de 2026  
**Repositório:** https://github.com/Reisvmr/aeroporto.git
