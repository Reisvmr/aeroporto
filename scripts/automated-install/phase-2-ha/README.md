# 📚 Scripts de Instalação HA - Projeto Aeroporto (Fase 2)

**Data:** 27/10/2026  
**Versão:** 2.0 (Alta Disponibilidade)  
**Status:** ✅ Pronto para Instalação

---

## 📋 Índice de Scripts

### ✅ Scripts Criados (4 arquivos)

#### 1. **00-prerequisitos-validacao.sh** ⭐ (CRÍTICO)
- **Descrição:** Validação de pré-requisitos para qualquer servidor
- **Uso:** `sudo ./00-prerequisitos-validacao.sh <tipo_servidor>`
- **Tipos suportados:**
  - `postgresql-primary` — PostgreSQL Primary (pg-01)
  - `postgresql-standby` — PostgreSQL Standby (pg-02)
  - `zabbix-server` — Zabbix Server (zbx-server-01/02)
  - `grafana` — Grafana (grafana-01/02)
  - `awx` — AWX (awx-01/02)
  - `vip` — VIP Load Balancer (vip-01/02)
- **Exemplo:**
  ```bash
  sudo ./00-prerequisitos-validacao.sh postgresql-primary
  ```
- **Validações:**
  - ✓ Sistema operacional (Linux)
  - ✓ Usuário (root)
  - ✓ IP estático
  - ✓ Conectividade de rede
  - ✓ Recursos de hardware (CPU, RAM, Disco)
  - ✓ Portas livres
  - ✓ Pacotes base instalados
  - ✓ Repositórios APT acessíveis

---

#### 2. **01-postgresql-primary.sh** 🐘 (SEMANA 1)
- **Descrição:** Instalação e configuração PostgreSQL 16 Primary com replicação
- **Servidor:** pg-01 (10.31.38.64)
- **Uso:** `sudo ./01-postgresql-primary.sh`
- **Pré-requisitos:**
  - Executar validação: `00-prerequisitos-validacao.sh postgresql-primary`
  - IP estático: 10.31.38.64
  - 50+ GB disco em /var
- **Configura:**
  - PostgreSQL 16 LTS
  - Streaming Replication (WAL)
  - Replication user: `replication`
  - 3 bancos de dados: zabbix, grafana, awx
  - Firewall (porta 5432)
- **Tempo estimado:** ~10 minutos
- **Output:**
  ```
  ✓ INSTALAÇÃO CONCLUÍDA COM SUCESSO
  ```
- **Próximo passo:** Executar `01-postgresql-standby.sh` em pg-02

---

#### 3. **01-postgresql-standby.sh** 🐘 (SEMANA 1)
- **Descrição:** Instalação PostgreSQL 16 Standby com replicação streaming
- **Servidor:** pg-02 (10.31.38.65)
- **Uso:** `sudo ./01-postgresql-standby.sh`
- **Pré-requisitos:**
  - PostgreSQL Primary (pg-01) já instalado e rodando
  - Executar validação: `00-prerequisitos-validacao.sh postgresql-standby`
  - IP estático: 10.31.38.65
  - 50+ GB disco em /var
  - Mesma senha de replicação do Primary
- **Configura:**
  - PostgreSQL 16 LTS (Standby)
  - Replicação streaming desde pg-01
  - Hot Standby (aceita consultas de leitura)
  - pg_basebackup automático
  - Firewall (porta 5432)
- **Tempo estimado:** ~15 minutos (inclui base backup)
- **Validação pós-instalação:**
  ```bash
  # Em pg-01:
  psql -c "SELECT * FROM pg_stat_replication;"
  ```
- **Próximo passo:** Executar `06-vip-haproxy-keepalived.sh` em vip-01/vip-02

---

#### 4. **06-vip-haproxy-keepalived.sh** ⚖️ (SEMANA 2)
- **Descrição:** Instalação HAProxy + Keepalived para VIP HA Load Balancer
- **Servidores:** vip-01 (10.31.38.70 - Master) / vip-02 (10.31.38.71 - Backup)
- **Uso:** `sudo ./06-vip-haproxy-keepalived.sh <master|backup>`
- **Exemplo:**
  ```bash
  # Em vip-01:
  sudo ./06-vip-haproxy-keepalived.sh master
  
  # Em vip-02:
  sudo ./06-vip-haproxy-keepalived.sh backup
  ```
- **Pré-requisitos:**
  - Executar validação: `00-prerequisitos-validacao.sh vip`
  - IP estático: 10.31.38.70 (master) / 10.31.38.71 (backup)
- **Configura:**
  - HAProxy 2.x (Load Balancing)
  - Keepalived (VRRP Failover)
  - VIP flutuante: 10.31.38.70
  - 3 backends: Zabbix, Grafana, AWX
  - Health checks (5s interval)
  - Firewall (portas 80, 443)
- **Tempo estimado:** ~8 minutos
- **Failover automático:** <5 segundos
- **Validação pós-instalação:**
  ```bash
  # Verificar VIP ativo:
  ip addr | grep 10.31.38.70
  
  # HAProxy stats:
  curl http://localhost:8081/stats
  ```
- **Próximo passo:** Scripts Zabbix/Grafana/AWX HA

---

## 📅 Ordem de Instalação (Fase 2 HA)

### **SEMANA 1: PostgreSQL HA** (~8 horas)
```bash
# Em todos os servidores
sudo ./00-prerequisitos-validacao.sh <tipo>

# Em pg-01:
sudo ./01-postgresql-primary.sh

# Em pg-02:
sudo ./01-postgresql-standby.sh

# Validação:
psql -c "SELECT * FROM pg_stat_replication;"
```

### **SEMANA 2: VIP/Load Balancer** (~6 horas)
```bash
# Em vip-01:
sudo ./00-prerequisitos-validacao.sh vip
sudo ./06-vip-haproxy-keepalived.sh master

# Em vip-02:
sudo ./00-prerequisitos-validacao.sh vip
sudo ./06-vip-haproxy-keepalived.sh backup

# Validação:
curl http://10.31.38.70/stats
```

### **SEMANA 3: Zabbix HA** (~4 horas)
```bash
# Scripts a criar:
# - 02-zabbix-server-ha.sh (zbx-server-01/02)
```

### **SEMANA 4: Grafana HA** (~3 horas)
```bash
# Scripts a criar:
# - 05-grafana-ha.sh (grafana-01/02)
```

### **SEMANA 5: AWX HA** (~4 horas)
```bash
# Scripts a criar:
# - 04-awx-ha.sh (awx-01/02)
```

### **SEMANA 6: Validação e Testes** (~4 horas)
```bash
# Scripts a criar:
# - validate-ha-health.sh
# - failover-test.sh
```

---

## 🔧 Variáveis de Ambiente

Você pode customizar alguns parâmetros exportando variáveis:

```bash
# PostgreSQL Primary
export POSTGRES_PASS="sua_senha_aqui"
export REPLICATION_PASS="senha_replicacao"
./01-postgresql-primary.sh

# Keepalived
export INTERFACE="eth0"  # Se não for detectada automaticamente
./06-vip-haproxy-keepalived.sh master
```

---

## 📊 Fluxo de Instalação Recomendado

```
┌─────────────────────────────────────┐
│   VALIDAÇÃO EM TODOS OS SERVERS     │
│   00-prerequisitos-validacao.sh     │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  POSTGRESQL HA (Semana 1)           │
│  01-postgresql-primary.sh (pg-01)   │
│  01-postgresql-standby.sh (pg-02)   │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  VIP LOAD BALANCER (Semana 2)       │
│  06-vip-haproxy-keepalived.sh       │
│  (vip-01 master, vip-02 backup)     │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  ZABBIX HA (Semana 3)               │
│  02-zabbix-server-ha.sh             │
│  (zbx-server-01/02)                 │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  GRAFANA HA (Semana 4)              │
│  05-grafana-ha.sh                   │
│  (grafana-01/02)                    │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  AWX HA (Semana 5)                  │
│  04-awx-ha.sh                       │
│  (awx-01/02)                        │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  TESTES HA (Semana 6)               │
│  validate-ha-health.sh              │
│  failover-test.sh                   │
└─────────────────────────────────────┘
```

---

## ✅ Checklist de Instalação

### Semana 1: PostgreSQL HA
- [ ] Executar validação em pg-01 e pg-02
- [ ] Instalar PostgreSQL Primary em pg-01
- [ ] Instalar PostgreSQL Standby em pg-02
- [ ] Validar replicação com `pg_stat_replication`
- [ ] Monitorar lag de replicação <1s

### Semana 2: VIP/Load Balancer
- [ ] Executar validação em vip-01 e vip-02
- [ ] Instalar HAProxy+Keepalived em vip-01 (master)
- [ ] Instalar HAProxy+Keepalived em vip-02 (backup)
- [ ] Verificar VIP ativo em vip-01
- [ ] Testar failover manual
- [ ] Validar health checks

### Semana 3-5: Aplicações HA
- [ ] Instalar Zabbix Server HA (zbx-server-01/02)
- [ ] Instalar Grafana HA (grafana-01/02)
- [ ] Instalar AWX HA (awx-01/02)
- [ ] Configurar backends no HAProxy

### Semana 6: Validação Final
- [ ] Testes de failover completos
- [ ] Testes de carga (5x volume)
- [ ] Testes de recovery
- [ ] Documentação final

---

## 📝 Logs

Cada script gera um log detalhado:

```bash
# Logs de instalação (padrão):
/tmp/postgresql-primary-install-*.log
/tmp/postgresql-standby-install-*.log
/tmp/vip-haproxy-keepalived-install-*.log

# Acompanhar instalação em tempo real:
tail -f /tmp/postgresql-primary-install-*.log
```

---

## 🆘 Troubleshooting

### PostgreSQL não inicia
```bash
# Verificar logs
sudo tail -f /var/log/postgresql/postgresql.log

# Status
sudo systemctl status postgresql

# Reiniciar
sudo systemctl restart postgresql
```

### VIP não ativa em master
```bash
# Verificar Keepalived
sudo systemctl status keepalived
sudo tail -f /var/log/syslog | grep -i keepalived

# Verificar VRRP
sudo ip addr show
```

### HAProxy mostra backends down
```bash
# Stats:
curl http://localhost:8081/stats

# Testar conectividade aos backends:
nc -zv 10.31.38.60 80
nc -zv 10.31.38.66 3000
nc -zv 10.31.38.68 8080
```

---

## 📞 Referências

- **Repositório:** https://github.com/Reisvmr/aeroporto.git
- **Documentação:** PLANO_REFATORACAO_HA.md
- **Inventários Ansible:** awx_automacoes/inventories/

---

## 🎯 Próximas Ações

✅ **Semana 1:** PostgreSQL HA  
⬜ **Semana 2:** VIP/Load Balancer  
⬜ **Semana 3:** Zabbix Server HA  
⬜ **Semana 4:** Grafana HA  
⬜ **Semana 5:** AWX HA  
⬜ **Semana 6:** Validação Final  

---

**Status:** Pronto para Instalação Semana 1 ✅

*Última atualização: 27/10/2026*
