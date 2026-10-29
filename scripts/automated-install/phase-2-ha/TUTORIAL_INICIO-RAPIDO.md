# 🚀 TUTORIAL — INÍCIO RÁPIDO: Phase 2 HA
> **Script:** `INICIO-RAPIDO.sh`  
> **Objetivo:** Copiar os scripts para todos os servidores e iniciar a instalação Phase 2 HA  
> **Executar em:** Máquina de controle / desktop do operador

---

## 📋 Pré-requisitos

- Acesso SSH a todos os 10 servidores  
- Repositório clonado localmente  
- Chave SSH configurada para os servidores  

---

## Passo 1 — Definir variáveis do ambiente

```bash
# Ajuste com seu usuário SSH
export USUARIO="seu_usuario_ssh"
export SCRIPTS_DIR="/caminho/para/scripts/automated-install/phase-2-ha"
```

---

## Passo 2 — Copiar scripts para todos os servidores

```bash
# pg-01 (PostgreSQL Primary)
scp -r "$SCRIPTS_DIR" $USUARIO@10.31.38.64:/tmp/phase-2-ha

# pg-02 (PostgreSQL Standby)
scp -r "$SCRIPTS_DIR" $USUARIO@10.31.38.65:/tmp/phase-2-ha

# vip-01 (HAProxy Master)
scp -r "$SCRIPTS_DIR" $USUARIO@10.31.38.70:/tmp/phase-2-ha

# vip-02 (HAProxy Backup)
scp -r "$SCRIPTS_DIR" $USUARIO@10.31.38.71:/tmp/phase-2-ha

# Demais servidores (Zabbix, Grafana, AWX)
for ip in 10.31.38.60 10.31.38.61 10.31.38.66 10.31.38.67 10.31.38.68 10.31.38.69; do
    scp -r "$SCRIPTS_DIR" $USUARIO@$ip:/tmp/phase-2-ha
done
```

✅ **Verificação:** `ssh $USUARIO@10.31.38.64 'ls /tmp/phase-2-ha/'`

---

## Passo 3 — Dar permissão de execução nos scripts (em cada servidor)

```bash
# Executar em CADA servidor
ssh -t $USUARIO@10.31.38.64 'sudo chmod +x /tmp/phase-2-ha/*.sh'
ssh -t $USUARIO@10.31.38.65 'sudo chmod +x /tmp/phase-2-ha/*.sh'
ssh -t $USUARIO@10.31.38.70 'sudo chmod +x /tmp/phase-2-ha/*.sh'
ssh -t $USUARIO@10.31.38.71 'sudo chmod +x /tmp/phase-2-ha/*.sh'
for ip in 10.31.38.60 10.31.38.61 10.31.38.66 10.31.38.67 10.31.38.68 10.31.38.69; do
    ssh -t $USUARIO@$ip 'sudo chmod +x /tmp/phase-2-ha/*.sh'
done
```

---

## Passo 4 — Validar pré-requisitos (Semana 1)

```bash
# Em pg-01
ssh -t $USUARIO@10.31.38.64 'cd /tmp/phase-2-ha && sudo ./00-prerequisitos-validacao.sh postgresql-primary'

# Em pg-02
ssh -t $USUARIO@10.31.38.65 'cd /tmp/phase-2-ha && sudo ./00-prerequisitos-validacao.sh postgresql-standby'
```

---

## Passo 5 — Instalar PostgreSQL HA (Semana 1)

```bash
# pg-01 PRIMEIRO
ssh -t $USUARIO@10.31.38.64 'cd /tmp/phase-2-ha && sudo ./01-postgresql-primary.sh'

# pg-02 DEPOIS (aguardar pg-01 concluir)
ssh -t $USUARIO@10.31.38.65 'cd /tmp/phase-2-ha && sudo ./01-postgresql-standby.sh'
```

---

## Passo 6 — Instalar VIP + HAProxy + Keepalived (Semana 2)

```bash
# vip-01 (Master)
ssh -t $USUARIO@10.31.38.70 'cd /tmp/phase-2-ha && sudo ./06-vip-haproxy-keepalived.sh master'

# vip-02 (Backup)
ssh -t $USUARIO@10.31.38.71 'cd /tmp/phase-2-ha && sudo ./06-vip-haproxy-keepalived.sh backup'
```

---

## Passo 7 — Instalar Zabbix HA (Semana 3)

```bash
# zbx-server-01 (node1) 
ssh -t $USUARIO@10.31.38.60 'cd /tmp/phase-2-ha && sudo ./02-zabbix-server-ha.sh node1'

# zbx-server-02 (node2)
ssh -t $USUARIO@10.31.38.61 'cd /tmp/phase-2-ha && sudo ./02-zabbix-server-ha.sh node2'
```

---

## Passo 8 — Instalar Grafana HA (Semana 4)

```bash
# grafana-01 (node1)
ssh -t $USUARIO@10.31.38.66 'cd /tmp/phase-2-ha && sudo ./05-grafana-ha.sh node1'

# grafana-02 (node2)
ssh -t $USUARIO@10.31.38.67 'cd /tmp/phase-2-ha && sudo ./05-grafana-ha.sh node2'
```

---

## Passo 9 — Instalar AWX HA (Semana 5)

```bash
# awx-01 (node1)
ssh -t $USUARIO@10.31.38.68 'cd /tmp/phase-2-ha && sudo ./04-awx-ha.sh node1'

# awx-02 (node2)
ssh -t $USUARIO@10.31.38.69 'cd /tmp/phase-2-ha && sudo ./04-awx-ha.sh node2'
```

---

## Passo 10 — Validar saúde do cluster HA (Semana 6)

```bash
# Executar em qualquer servidor com acesso à rede
sudo ./09-validate-ha-health.sh

# Testar failover (dry-run por padrão)
sudo ./10-failover-test.sh
```

---

## 🗺️ Mapa de IPs

| Servidor       | IP            | Função                     |
|----------------|---------------|----------------------------|
| pg-01          | 10.31.38.64   | PostgreSQL Primary         |
| pg-02          | 10.31.38.65   | PostgreSQL Standby         |
| zbx-server-01  | 10.31.38.60   | Zabbix Server Node 1       |
| zbx-server-02  | 10.31.38.61   | Zabbix Server Node 2       |
| grafana-01     | 10.31.38.66   | Grafana Node 1             |
| grafana-02     | 10.31.38.67   | Grafana Node 2             |
| awx-01         | 10.31.38.68   | AWX Node 1                 |
| awx-02         | 10.31.38.69   | AWX Node 2                 |
| vip-01         | 10.31.38.70   | HAProxy Master (VIP)       |
| vip-02         | 10.31.38.71   | HAProxy Backup             |
