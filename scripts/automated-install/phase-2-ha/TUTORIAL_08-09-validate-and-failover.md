# 🏥 TUTORIAL — Validação de Saúde do Cluster HA
> **Script:** `08-validate-ha-health.sh`  
> **Objetivo:** Verificar que todos os componentes do cluster HA estão saudáveis após instalação  
> **Uso:** `sudo ./08-validate-ha-health.sh [--quiet] [--timeout=N]`

---

## 📋 O que este script verifica

| Componente | Verificação |
|------------|-------------|
| PostgreSQL Primary (pg-01) | Porta 5432, modo primary, replicação ativa |
| PostgreSQL Standby (pg-02) | Porta 5432, modo standby, lag de replicação |
| Zabbix Server 01 | Porta 10051, API HTTP |
| Zabbix Server 02 | Porta 10051, API HTTP |
| Grafana 01 | Porta 3000, `/api/health` |
| Grafana 02 | Porta 3000, `/api/health` |
| AWX 01 | Porta 8080, `/api/v2/ping/` |
| AWX 02 | Porta 8080, `/api/v2/ping/` |
| VIP Master | Porta 80, HAProxy Stats |
| HAProxy Backend | Todos os backends UP |
| Keepalived | VIP ativo no MASTER |

---

## 🔧 Parâmetros

```bash
# Execução completa (padrão)
sudo ./08-validate-ha-health.sh

# Silencioso (só mostra falhas)
sudo ./08-validate-ha-health.sh --quiet

# Timeout customizado em segundos (padrão: 10)
sudo ./08-validate-ha-health.sh --timeout=30

# Saída em JSON (para integração com monitoramento)
sudo ./08-validate-ha-health.sh --format=json
```

---

## ETAPA 1 — Executar validação de saúde

```bash
cd /home/reisvmr/Documentos/REPOS/aeroporto/scripts/automated-install/phase-2-ha
sudo ./08-validate-ha-health.sh
```

✅ **Resultado esperado (cluster saudável):**
```
╔════════════════════════════════════════════╗
║  VALIDAÇÃO DE SAÚDE HA - AEROPORTO        ║
╚════════════════════════════════════════════╝

PostgreSQL:
  [✓] pg-01 (10.31.38.64:5432) — PRIMARY, replicação: 1 standby
  [✓] pg-02 (10.31.38.65:5432) — STANDBY, lag: 0.02s

Zabbix:
  [✓] zbx-01 (10.31.38.60:10051) — UP
  [✓] zbx-02 (10.31.38.61:10051) — UP

Grafana:
  [✓] grafana-01 (10.31.38.66:3000) — UP, /api/health: ok
  [✓] grafana-02 (10.31.38.67:3000) — UP, /api/health: ok

AWX:
  [✓] awx-01 (10.31.38.68:8080) — UP, /api/v2/ping/: ok
  [✓] awx-02 (10.31.38.69:8080) — UP, /api/v2/ping/: ok

VIP/HAProxy:
  [✓] VIP 10.31.38.70 ativo no MASTER (vip-01)
  [✓] HAProxy: 8/8 backends UP

RESULTADO: 11/11 checks ✅ CLUSTER HA SAUDÁVEL
```

---

## ETAPA 2 — Verificação manual por componente

### PostgreSQL — verificar replicação

```bash
# No pg-01 (Primary)
sudo -u postgres psql -c "SELECT client_addr, state, sent_lsn, replay_lsn, sync_state FROM pg_stat_replication;"
# Esperado: 1 linha com pg-02 em 'streaming'

# No pg-02 (Standby)
sudo -u postgres psql -c "SELECT pg_is_in_recovery(), now() - pg_last_xact_replay_timestamp() AS lag;"
# Esperado: t, lag < 1s
```

### Zabbix — verificar porta e processo

```bash
# Em zbx-server-01
systemctl status zabbix-server
ss -tlnp | grep 10051
```

### Grafana — verificar API health

```bash
# Em grafana-01
curl -s http://localhost:3000/api/health | python3 -m json.tool
# Esperado: {"commit": "...", "database": "ok", "version": "10.x.x"}
```

### AWX — verificar API ping

```bash
# Em awx-01
curl -s http://localhost:8080/api/v2/ping/ | python3 -m json.tool
# Esperado: {"ha": true, "version": "22.x.x", ...}
```

### VIP/HAProxy — verificar qual node tem o VIP

```bash
# Em vip-01
ip addr show | grep 10.31.38.70
# Se aparecer: VIP está no MASTER ✓

# Stats do HAProxy
curl -s -u admin:haproxy@stats http://localhost:8404/stats?csv | \
    awk -F',' 'NR>1 {print $1, $2, $18, $19}' | column -t
# Esperado: status UP para todos os backends
```

---

## ETAPA 3 — Interpretar alertas

### Lag de replicação alto (> 30s)

```bash
# Verificar gargalo de rede
iperf3 -s &  # no pg-01
iperf3 -c 10.31.38.64  # no pg-02

# Verificar logs do PostgreSQL
tail -50 /var/log/postgresql/postgresql-16-main.log | grep -i "replication\|lag\|error"
```

### Backend DOWN no HAProxy

```bash
# Verificar se o serviço está rodando no servidor correspondente
systemctl status grafana-server  # em grafana-01 ou grafana-02

# Recarregar HAProxy sem downtime
systemctl reload haproxy
```

### VIP ausente (não aparece em nenhum dos dois nodes)

```bash
# Verificar Keepalived em ambos
journalctl -u keepalived --no-pager -n 30

# Reiniciar Keepalived no MASTER
systemctl restart keepalived
sleep 3
ip addr show | grep 10.31.38.70
```

---

## ETAPA 4 — Prosseguir com teste de failover

Após validação bem-sucedida, execute o teste de failover:

```bash
sudo ./09-failover-test.sh
```

---

## 🔍 Monitoramento contínuo (cron)

```bash
# Adicionar verificação horária ao cron
echo "0 * * * * root /opt/aeroporto/08-validate-ha-health.sh --quiet >> /var/log/ha-health.log 2>&1" \
    >> /etc/crontab
```

---

# 🔄 TUTORIAL — Teste de Failover do Cluster HA
> **Script:** `09-failover-test.sh`  
> **Objetivo:** Validar que o failover automático funciona com RTO < 5 segundos  
> **Uso:** `sudo ./09-failover-test.sh [--component=zabbix|grafana|awx|postgresql]`

---

## ⚠️ ATENÇÃO — Leia antes de executar

- Por padrão, o script roda em **DRY RUN** (não para serviços reais)  
- Para failover real, edite o script e defina `DRY_RUN=false`  
- Execute **fora do horário de pico** (janela de manutenção)  
- Tenha acesso console a todos os servidores antes de iniciar  

---

## 📋 Componentes testados

| Componente | Tipo de teste | RTO esperado |
|------------|---------------|--------------|
| VIP/HAProxy | Parar HAProxy no MASTER → VIP migra para BACKUP | < 5s |
| PostgreSQL | Parar pg-01 → Promover pg-02 para Primary | < 30s |
| Zabbix HA | Parar zbx-server-01 → zbx-server-02 assume | < 10s |
| Grafana | Parar grafana-01 → HAProxy redireciona para grafana-02 | < 5s |
| AWX | Parar awx-01 → HAProxy redireciona para awx-02 | < 5s |

---

## ETAPA 1 — Executar em DRY RUN (seguro, padrão)

```bash
cd /home/reisvmr/Documentos/REPOS/aeroporto/scripts/automated-install/phase-2-ha
sudo ./09-failover-test.sh
```

O DRY RUN **simula** os passos sem parar serviços:

```
╔════════════════════════════════════════════════════╗
║  TESTE DE FAILOVER - CLUSTER HA AEROPORTO         ║
║  Modo: DRY RUN (sem parar serviços reais)         ║
╚════════════════════════════════════════════════════╝

[DRY] Pararia HAProxy no vip-01...
[DRY] Verificaria VIP em vip-02 em 5s...
[DRY] Restauraria HAProxy no vip-01...

RESULTADO DRY RUN: 5/5 cenários simulados ✅
Para failover real: editar DRY_RUN=false no script
```

---

## ETAPA 2 — Teste de failover VIP (manual)

```bash
# TERMINAL 1 — monitorar VIP em loop
while true; do
    echo -n "$(date +%H:%M:%S) — VIP: "
    ssh root@10.31.38.70 "ip addr show | grep -c 10.31.38.70" 2>/dev/null \
        && echo "vip-01 (MASTER)" || echo "AUSENTE"
    ssh root@10.31.38.71 "ip addr show | grep -c 10.31.38.70" 2>/dev/null \
        && echo "vip-02 (BACKUP assumiu)" || true
    sleep 1
done

# TERMINAL 2 — simular falha do HAProxy no MASTER
ssh root@10.31.38.70 "systemctl stop haproxy"
# Observar TERMINAL 1: VIP deve migrar para vip-02 em < 5s

# Restaurar
ssh root@10.31.38.70 "systemctl start haproxy"
# VIP volta para vip-01 após ~5s
```

---

## ETAPA 3 — Teste de failover PostgreSQL (⚠️ impacto real)

> ⚠️ **Atenção:** Este teste causa interrupção real do banco. Execute em manutenção.

```bash
# 1. Verificar estado atual
ssh root@10.31.38.64 "sudo -u postgres psql -c 'SELECT pg_is_in_recovery();'"
# Esperado: f (primary)

# 2. Parar pg-01
ssh root@10.31.38.64 "systemctl stop postgresql@16-main"

# 3. Promover pg-02 para primary
ssh root@10.31.38.65 "sudo -u postgres pg_ctl promote -D /var/lib/postgresql/16/main"
# ou
ssh root@10.31.38.65 "sudo -u postgres psql -c 'SELECT pg_promote();'"

# 4. Verificar que pg-02 é agora Primary
ssh root@10.31.38.65 "sudo -u postgres psql -c 'SELECT pg_is_in_recovery();'"
# Esperado: f (agora é primary)

# 5. Restaurar — reconectar pg-01 como Standby (pg_basebackup necessário)
```

---

## ETAPA 4 — Teste de failover Grafana (via HAProxy)

```bash
# Parar grafana-01
ssh root@10.31.38.66 "systemctl stop grafana-server"

# Verificar que HAProxy redireciona para grafana-02
curl -s -o /dev/null -w "%{http_code}" http://10.31.38.72:3000/api/health
# Esperado: 200

# Verificar qual backend respondeu
curl -s http://10.31.38.72:3000/api/health | python3 -m json.tool

# Restaurar
ssh root@10.31.38.66 "systemctl start grafana-server"
```

---

## 📊 Métricas de sucesso

| Métrica | Meta | Como verificar |
|---------|------|----------------|
| VIP failover | < 5s | Loop de ping durante falha |
| Grafana failover | < 5s | curl em loop para `/api/health` |
| AWX failover | < 5s | curl em loop para `/api/v2/ping/` |
| PostgreSQL failover | < 30s | Tempo até `pg_promote()` concluir |
| Zero data loss | 0 transações | `pg_stat_replication.replay_lag` |

---

## 📝 Próximos passos

Após testes bem-sucedidos:
1. Documente os RTOs reais medidos  
2. Configure alertas no Zabbix para detecção automática de falhas  
3. Agende testes de failover periódicos (recomendado: mensal)  
4. Atualize o `PLANO_ACAO_INSTALACAO_FINAL.md` com resultados  
