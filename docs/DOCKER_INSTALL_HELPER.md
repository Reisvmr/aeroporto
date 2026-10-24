# Instalação Docker - Helper Script

## 📋 Visão Geral

Script auxiliar para instalar **Docker Engine + Docker Compose** em servidores Ubuntu via repositório oficial Docker.

**Versão:** 1.0  
**Servidor:** awx-01 (10.31.38.68)  
**Data:** 24/10/2026

---

## ⚠️ Problema Resolvido

**Erro Original:**
```
Error: Unable to locate package docker
```

**Causa:**
- Repositório padrão Ubuntu não contém pacote `docker`
- Pacote correto é `docker-ce` (Docker Community Edition)

**Solução:**
- Adicionar repositório oficial Docker
- Instalar `docker-ce` e `docker-compose-plugin`

---

## ✅ O que o Script Faz

1. **Preparar repositório**
   - Instala dependências (ca-certificates, curl, gnupg, lsb-release)
   - Adiciona chave GPG oficial Docker
   - Adiciona repositório Docker oficial

2. **Instalar Docker**
   - Docker Engine (`docker-ce`)
   - Docker CLI (`docker-ce-cli`)
   - Containerd
   - Buildx Plugin
   - Compose Plugin (ou standalone como fallback)

3. **Habilitar serviço**
   - Ativa Docker para iniciar com sistema
   - Inicia serviço Docker

4. **Testar instalação**
   - Executa teste simples (hello-world)
   - Verifica versões instaladas

---

## 📥 Como Usar

### Opção 1: SCP + Execução Local

```bash
# No seu computador
scp scripts/automated-install/docker-install-helper.sh root@10.31.38.68:/tmp/

# No servidor awx-01
ssh root@10.31.38.68
sudo bash /tmp/docker-install-helper.sh
```

### Opção 2: Git Clone

```bash
# No servidor awx-01
git clone https://github.com/Reisvmr/aeroporto.git
cd aeroporto/scripts/automated-install/
sudo bash docker-install-helper.sh
```

### Opção 3: Curl Direto

```bash
curl -fsSL -o /tmp/docker-install-helper.sh \
  https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/automated-install/docker-install-helper.sh

sudo bash /tmp/docker-install-helper.sh
```

---

## ⏱️ Tempo de Execução

| Etapa | Tempo |
|-------|-------|
| Pré-requisitos | 1 min |
| Setup repositório | 2-3 min |
| Instalação Docker | 5-10 min |
| Verificação | 2 min |
| **TOTAL** | **10-15 min** |

---

## 📊 Saída Esperada

```
════════════════════════════════════════════════════════════════
VALIDAÇÃO PRÉ-REQUISITOS
════════════════════════════════════════════════════════════════
[✓] Executando como root
[✓] Ubuntu detectado
[✓] Conectividade com internet OK

════════════════════════════════════════════════════════════════
PREPARAR REPOSITÓRIO DOCKER OFICIAL
════════════════════════════════════════════════════════════════
[✓] Atualizar cache apt
[✓] Instalar dependências
[✓] Criar diretório keyrings
[✓] Baixar e instalar chave GPG Docker
[✓] Repositório Docker adicionado

════════════════════════════════════════════════════════════════
INSTALAR DOCKER ENGINE
════════════════════════════════════════════════════════════════
[✓] Instalar Docker packages

════════════════════════════════════════════════════════════════
VERIFICAR INSTALAÇÃO DOCKER
════════════════════════════════════════════════════════════════
[✓] Docker instalado: Docker version 24.0.x
[✓] Docker Compose plugin instalado

════════════════════════════════════════════════════════════════
HABILITAR SERVIÇO DOCKER
════════════════════════════════════════════════════════════════
[✓] Habilitar docker.service
[✓] Iniciar docker.service
[✓] Docker está rodando

════════════════════════════════════════════════════════════════
TESTAR DOCKER
════════════════════════════════════════════════════════════════
[✓] Docker funcionando corretamente

════════════════════════════════════════════════════════════════
RESUMO - DOCKER INSTALADO COM SUCESSO
════════════════════════════════════════════════════════════════

✅ Docker pronto para AWX 22.x

Versões instaladas:
Docker version 24.0.7, build afdd53b

Docker Compose (plugin):
Docker Compose version v2.23.0

Próximos passos:
  1. Voltar à instalação AWX:
     $ sudo bash 04-awx-installer.sh

  2. O script detectará Docker e continuará
```

---

## ✅ Após Instalar

### 1. Verificar instalação

```bash
docker --version
docker ps
docker compose version
```

### 2. Retomar instalação AWX

```bash
sudo bash 04-awx-installer.sh
```

### 3. Script AWX continuará automaticamente

---

## 🔧 Troubleshooting

### Problema: "Permission denied"

**Solução:**
```bash
sudo bash docker-install-helper.sh
```

### Problema: "Sem conectividade com internet"

**Solução:**
- Verificar firewall
- Verificar DNS: `ping 8.8.8.8`
- Verificar conectividade: `curl https://download.docker.com`

### Problema: "unable to locate package ca-certificates"

**Solução:**
```bash
sudo apt-get update
sudo bash docker-install-helper.sh
```

### Problema: "Docker não está rodando"

**Solução:**
```bash
# Verificar status
systemctl status docker

# Ver logs
journalctl -u docker -n 50 -f

# Reiniciar
systemctl restart docker
```

### Problema: "Docker Compose não encontrado"

**Solução:**
Script tenta instalar versão standalone se plugin não estiver disponível. Se ainda não funcionar:

```bash
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version
```

---

## 📚 Arquivos Relacionados

- **Script AWX:** `scripts/automated-install/04-awx-installer.sh`
- **Documentação AWX:** `scripts/automated-install/docs/INSTALACAO_AWX_GRAFANA.md`
- **Documentação Geral:** `docs/SCRIPTS_INSTALACAO_INTERATIVOS.md`

---

## 🔍 Logs

Todas as ações são registradas em:
```
/var/log/docker-install-helper.log
```

Para ver em tempo real:
```bash
tail -f /var/log/docker-install-helper.log
```

---

## 📋 Servidores que Usam Docker

| Servidor | IP | Usa Docker? | Status |
|----------|----|----|--------|
| pg-01 | 10.31.38.64 | ❌ NÃO | PostgreSQL nativo |
| zbx-server-01 | 10.31.38.60 | ❌ NÃO | Instalar via apt |
| zbx-fe-01 | 10.31.38.62 | ❌ NÃO | Instalar via apt |
| **awx-01** | **10.31.38.68** | **✅ SIM** | **CORRIGIR** |
| grafana-01 | 10.31.38.66 | ❌ NÃO | Instalar via apt |

---

## 👤 Autor

**Vinicius Reis** (reisvmr@gmail.com)

Projeto: Aeroporto - Zabbix + AWX + Grafana  
Repositório: https://github.com/Reisvmr/aeroporto.git

---

## 📄 Licença

MIT License
