# 🚨 PLANO DE AÇÃO EMERGENCIAL - POSTGRESQL 10.31.38.64

**Data:** 24/10/2026  
**Hora:** IMEDIATO  
**Prioridade:** 🔴 **CRÍTICO**  
**Status:** PostgreSQL perdeu acesso SSH após reboot

---

## ⚠️ SITUAÇÃO CRÍTICA

O servidor PostgreSQL (10.31.38.64) que hospeda o banco de dados central do projeto está **inacessível via SSH** após reinicialização.

**Impacto:**
- ❌ Zabbix Server não consegue conectar ao banco
- ❌ Zabbix Frontend não consegue conectar ao banco
- ❌ Setup não pode prosseguir
- ❌ Potencial perda de dados se não recuperado

---

## 🔍 Diagnóstico Rápido

### O que sabemos:
1. ✅ Servidor estava online antes (executou validação com sucesso)
2. ✅ Reboot foi solicitado/planejado
3. ❌ Após reboot, SSH não responde
4. ❌ Possível problema de rede, DHCP, firewall ou hardware

### O que testar:
```bash
# Do seu computador/jump host:

# 1. Ping simples
ping 10.31.38.64

# 2. Scan de portas
nmap -p 22 10.31.38.64

# 3. Verificar conectividade na rede local
ping -c 3 10.31.38.1  # Gateway

# 4. Tentar SSH com verbose
ssh -vvv root@10.31.38.64

# 5. Verificar console IPMI/VMware/Hyper-V
# (Se acesso físico/virtual disponível)
```

---

## 📋 Plano de Ação (Ordem de Prioridade)

### **Passo 1 - Verificar Conectividade (5-10 min)**

```bash
# Testar se o servidor responde
ping 10.31.38.64

# Se RESPONDE ao ping:
→ Problema é SSH específico (veja Passo 3)

# Se NÃO RESPONDE ao ping:
→ Problema é rede/IP (veja Passo 2)
```

---

### **Passo 2 - Se Sem Ping (Problema de Rede)**

**Causa Provável:** DHCP/IP não foi atribuído após reboot

**Ações:**
1. **Contatar Datacenter / Infraestrutura:**
   - Informar: Servidor 10.31.38.64 não responde a ping
   - Pedir: Acesso a console IPMI/KVM
   - Solicitar: Verificar IP, gateway, DHCP

2. **Se você tem acesso a console IPMI/VMware:**
   ```bash
   # Verificar IP:
   ip addr show
   
   # Verificar gateway:
   ip route show
   
   # Verificar conectividade:
   ping 10.31.38.1
   
   # Se IP está 0.0.0.0 ou não existe:
   # Restaurar manualmente ou reiniciar network
   systemctl restart networking
   ```

3. **Se DHCP falhou:**
   - Configurar IP estático em `/etc/netplan/`
   - Ou solicitar datacenter para investigar DHCP

**Timeline:** 30min-1h

---

### **Passo 3 - Se Ping Responde Mas SSH Não (Problema SSH)**

**Causa Provável:** Serviço SSH não iniciou ou porta bloqueada

**Ações:**
1. **Se você tem acesso a console IPMI/KVM:**
   ```bash
   # Verificar se SSH está rodando
   systemctl status ssh
   
   # Se não está rodando:
   systemctl start ssh
   
   # Se está rodando, verificar logs:
   tail -100 /var/log/auth.log
   tail -100 /var/log/syslog
   ```

2. **Se SSH está respondendo mas recusa conexão:**
   - Verificar permissões de chave
   - Verificar `/etc/ssh/sshd_config`
   - Tentar login local (console) se disponível

**Timeline:** 15-30min

---

### **Passo 4 - Se Problema Persiste**

**Escalação:**

1. **Contatar Infraestrutura:**
   - Descrever exatamente: Sem ping / Com ping mas sem SSH / SSH recusa
   - Fornecer IP: 10.31.38.64
   - Descrição: "PostgreSQL 16 - Servidor principal (BD crítico)"
   - Urgência: CRÍTICO

2. **Solicitar:**
   - Acesso a console físico ou IPMI/KVM
   - Logs de boot do servidor
   - Verificação de hardware

3. **Se nada funcionar:**
   - Pedir reboot forçado + recovery mode
   - Ou restore do último backup (se tiver)

**Timeline:** Depende da infraestrutura (30min-4h)

---

## 🔧 Passos Técnicos (Se Você Tem Acesso Local/Console)

### Recuperação via Console IPMI/KVM

```bash
# 1. Login no console
# (Usuário/senha do BIOS ou sistema)

# 2. Verificar status do sistema
uname -a
systemctl status

# 3. Verificar rede
ip addr show
ip route show
systemctl status systemd-networkd

# 4. Reiniciar rede (Ubuntu 22.04+)
netplan apply
# Ou
systemctl restart systemd-networkd

# 5. Iniciar SSH se não está rodando
systemctl restart ssh

# 6. Validar SSH está escutando
ss -tunap | grep 22
netstat -tlnap | grep 22

# 7. Verificar conectividade
ping 10.31.38.1
```

### Se IP está errado/não existe

```bash
# Editar netplan (Ubuntu 22.04+)
nano /etc/netplan/00-installer-config.yaml

# Adicionar algo como:
network:
  version: 2
  ethernets:
    ens18:
      dhcp4: true
      # OU configure estático:
      # addresses: [10.31.38.64/24]
      # gateway4: 10.31.38.1
      # nameservers:
      #   addresses: [8.8.8.8, 8.8.4.4]

# Aplicar
netplan apply

# Verificar
ip addr show
```

---

## 📞 Contatos Infraestrutura

**Informações para Fornecer:**

```
SERVIDOR: PostgreSQL Primary (pg-01)
IP: 10.31.38.64
Crítico: SIM (Banco de dados central)

PROBLEMA: Sem acesso SSH após reboot

TESTES REALIZADOS:
- Ping: [Responde/Não responde]
- SSH conecta: [Sim/Não]
- Se conecta: [Conecta mas recusa / Timeout]

URGÊNCIA: CRÍTICO - Projeto Aeroporto parado

CONTATO: Vinicius Reis (reisvmr@gmail.com)
```

---

## ⏱️ Timeline Estimado

| Ação | Tempo | Responsável |
|------|-------|-------------|
| Diagnosticar (Passo 1) | 5-10 min | Você |
| Contatar infraestrutura | 5 min | Você |
| Infraestrutura investigar | 15-30 min | Infraestrutura |
| Resolver problema | 15-60 min | Infraestrutura |
| **Total estimado** | **30-120 min** | - |

---

## 🔐 Dados Críticos Armazenados em 10.31.38.64

```
PostgreSQL 16 (Crítico)
├── Database: zabbix (Zabbix)
├── Database: awx (Ansible AWX)
└── Database: grafana (Grafana)

Arquivos PostgreSQL:
├── /var/lib/postgresql/16/main/
├── WAL (Write-Ahead Logs)
└── Backups: /home/backups/ (se houver)
```

**Se houver perda de dados:** Todos os 676 ativos em monitoramento serão perdidos.

---

## 📋 Checklist Pós-Recuperação

Quando o servidor ficar online novamente:

- [ ] Ping responde (10.31.38.64)
- [ ] SSH conecta (sem erro)
- [ ] PostgreSQL está rodando
  ```bash
  systemctl status postgresql
  ```
- [ ] Banco de dados acessível
  ```bash
  sudo -u postgres psql -l
  ```
- [ ] Re-executar validação PostgreSQL
  ```bash
  bash <(curl -fsSL https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/run-check-v2.sh) pg01
  ```

---

## 📞 AÇÕES IMEDIATAS

1. ✅ **AGORA:** Testar ping para 10.31.38.64
2. ✅ **AGORA:** Se sem ping, contatar infraestrutura IMEDIATAMENTE
3. ✅ **AGORA:** Se com ping, tentar SSH e diagnosticar
4. ✅ **ENQUANTO AGUARDA:** Documentar tudo (ping log, SSH tentativas, etc.)
5. ✅ **QUANDO ONLINE:** Re-validar antes de prosseguir com setup

---

## 🎯 Meta

**Trazer PostgreSQL online em máximo 2 horas**

Se após 2h ainda estiver offline:
- Contatar gerência/cliente
- Informar impacto
- Solicitar escalação de infraestrutura

---

**Documento:** PLANO_ACAO_EMERGENCIAL_POSTGRESQL.md  
**Versão:** 1.0  
**Urgência:** 🔴 CRÍTICO  
**Próxima Revisão:** A cada 30 min até resolver
