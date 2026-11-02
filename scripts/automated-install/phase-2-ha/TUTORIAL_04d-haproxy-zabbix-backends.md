# ⚡ TUTORIAL 04d — Ativar Backends Zabbix no HAProxy

> **Servidores:** vip-01 (`10.31.38.70`) e vip-02 (`10.31.38.71`)  
> **Objetivo:** Ativar os backends do Zabbix Server no HAProxy após os dois nodes estarem operacionais  
> **Pré-requisito:** TUTORIAL_04 (node1) e TUTORIAL_04c (node2) **totalmente concluídos**

---

## 📋 Pré-requisitos

- zbx-server-01 (`10.31.38.60`) rodando — `systemctl status zabbix-server` ativo
- zbx-server-02 (`10.31.38.61`) rodando — `systemctl status zabbix-server` ativo
- HAProxy com backends `zabbix_01` e `zabbix_02` no estado `disabled` (configurado no TUTORIAL_03)

---

## ETAPA 1 — Verificar estado atual dos backends

Execute em **vip-01 (`10.31.38.70`)**:

```bash
ssh administrator@10.31.38.70

# Listar estado dos backends Zabbix
echo 'show servers state backend_zabbix' | socat /run/haproxy/admin.sock stdio
```

> ✅ Esperado antes da ativação: backends com estado `disabled` ou `MAINT`.

---

## ETAPA 2 — Ativar backends via Runtime API

> ℹ️ A Runtime API ativa imediatamente **sem interromper** conexões existentes.  
> Execute em **vip-01 E em vip-02** (ambos precisam ser atualizados).

### vip-01 (`10.31.38.70`)

```bash
ssh administrator@10.31.38.70

# Ativar backend node1
echo 'enable server backend_zabbix/zabbix_01' | socat /run/haproxy/admin.sock stdio

# Ativar backend node2
echo 'enable server backend_zabbix/zabbix_02' | socat /run/haproxy/admin.sock stdio

# Confirmar ativação
echo 'show servers state backend_zabbix' | socat /run/haproxy/admin.sock stdio
```

### vip-02 (`10.31.38.71`)

```bash
ssh administrator@10.31.38.71

# Ativar backend node1
echo 'enable server backend_zabbix/zabbix_01' | socat /run/haproxy/admin.sock stdio

# Ativar backend node2
echo 'enable server backend_zabbix/zabbix_02' | socat /run/haproxy/admin.sock stdio

# Confirmar ativação
echo 'show servers state backend_zabbix' | socat /run/haproxy/admin.sock stdio
```

---

## ETAPA 3 — Persistir configuração no haproxy.cfg

> ⚠️ A Runtime API é temporária — reiniciar o HAProxy restaura o estado `disabled`.  
> Execute este bloco para persistir em **vip-01 E em vip-02**.

```bash
# Verificar linha atual no arquivo (confirmar padrão antes de substituir)
grep -n "zabbix_0" /etc/haproxy/haproxy.cfg

# Remover 'disabled' e adicionar healthcheck nas duas entradas
sed -i 's/server zabbix_01 10\.31\.38\.60:10051 disabled/server zabbix_01 10.31.38.60:10051 check inter 5s fall 3 rise 2/' /etc/haproxy/haproxy.cfg
sed -i 's/server zabbix_02 10\.31\.38\.61:10051 disabled/server zabbix_02 10.31.38.61:10051 check inter 5s fall 3 rise 2/' /etc/haproxy/haproxy.cfg

# Confirmar alteração
grep -n "zabbix_0" /etc/haproxy/haproxy.cfg

# Validar configuração e recarregar
haproxy -c -f /etc/haproxy/haproxy.cfg && systemctl reload haproxy
```

---

## ETAPA 4 — Validação completa

### 4.1 — Status dos backends no HAProxy

Execute em **vip-01 e vip-02**:

```bash
# Estado detalhado dos backends Zabbix
echo 'show servers state backend_zabbix' | socat /run/haproxy/admin.sock stdio

# Estatísticas resumidas
echo 'show stat' | socat /run/haproxy/admin.sock stdio | grep zabbix | cut -d',' -f1-2,18-19
```

> ✅ Ambos os backends devem aparecer com estado `UP`.

### 4.2 — Stats via interface web

```bash
# Abrir no browser ou verificar via curl
curl -s 'http://10.31.38.70:8404/stats' | grep -i "zabbix"
curl -s 'http://10.31.38.71:8404/stats' | grep -i "zabbix"
```

> ✅ Acesse `http://10.31.38.70:8404/stats` no browser para visualização gráfica.

### 4.3 — Testar acesso via VIP flutuante

```bash
# Testar porta 10051 via VIP flutuante (Keepalived)
timeout 5 bash -c '</dev/tcp/10.31.38.72/10051' && echo "✓ Zabbix VIP acessível na porta 10051" || echo "✗ VIP INACESSÍVEL"

# Verificar frontend (se zbx-fe-01/02 já estiver instalado)
curl -sk http://10.31.38.72/zabbix/ -o /dev/null -w "HTTP: %{http_code}\n"
```

### 4.4 — Confirmar HA pelo banco

```bash
# Verificar status dos nodes no cluster Zabbix (execute em zbx-server-01 ou 02)
PGPASSWORD="TROQUEPELASENHADOBANCO" psql -h 10.31.38.64 -U zabbix -d zabbix \
    -c "SELECT name, address, status, lastaccess FROM ha_node ORDER BY status;"
```

---

## ✅ Checklist final

| Item | vip-01 | vip-02 |
|---|---|---|
| `backend_zabbix/zabbix_01` | ✅ UP | ✅ UP |
| `backend_zabbix/zabbix_02` | ✅ UP | ✅ UP |
| `haproxy.cfg` persistido | ✅ | ✅ |
| HAProxy recarregado | ✅ | ✅ |
| VIP flutuante (`10.31.38.72`) | ✅ porta 10051 acessível | — |

---

## 🔍 Monitoramento contínuo

```bash
# Logs HAProxy em tempo real (execute em vip-01 ou vip-02)
journalctl -u haproxy -f

# Status HA Zabbix pelo banco (execute em qualquer zbx-server)
watch -n 10 "PGPASSWORD='TROQUEPELASENHADOBANCO' psql -h 10.31.38.64 -U zabbix -d zabbix \
    -c \"SELECT name, address, status, lastaccess FROM ha_node;\""
```

---

## 📌 Próximos passos

1. ➡️ **TUTORIAL_04b** — Instalar Zabbix Frontend (zbx-fe-01 / zbx-fe-02)
2. ➡️ Configurar templates e hosts no Zabbix via `http://10.31.38.72/zabbix`
3. ➡️ **TUTORIAL_05** — Instalar Grafana HA
