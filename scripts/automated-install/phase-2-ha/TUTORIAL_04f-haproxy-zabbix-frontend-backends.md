# ⚡ TUTORIAL 04f — Ativar Backends Zabbix Frontend no HAProxy

> **Servidores:** vip-01 (`10.31.38.70`) e vip-02 (`10.31.38.71`)  
> **Objetivo:** Ativar os backends do Zabbix Frontend no HAProxy após os dois nodes web estarem operacionais  
> **Pré-requisito:** TUTORIAL_04b (zbx-fe-01) e TUTORIAL_04e (zbx-fe-02) **totalmente concluídos**

---

## 📋 Pré-requisitos

- zbx-fe-01 (`10.31.38.62`) respondendo na porta 80 — `curl http://10.31.38.62/zabbix/`
- zbx-fe-02 (`10.31.38.63`) respondendo na porta 80 — `curl http://10.31.38.63/zabbix/`
- HAProxy com backends `zbx_fe_01` e `zbx_fe_02` no estado `disabled` (configurado no TUTORIAL_03)

---

## ETAPA 1 — Verificar estado atual dos backends

Execute em **vip-01 (`10.31.38.70`)**:

```bash
ssh administrator@10.31.38.70

# Listar estado dos backends Zabbix Frontend
echo 'show servers state backend_zabbix_frontend' | socat /run/haproxy/admin.sock stdio
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
echo 'enable server backend_zabbix_frontend/zbx_fe_01' | socat /run/haproxy/admin.sock stdio

# Ativar backend node2
echo 'enable server backend_zabbix_frontend/zbx_fe_02' | socat /run/haproxy/admin.sock stdio

# Confirmar ativação
echo 'show servers state backend_zabbix_frontend' | socat /run/haproxy/admin.sock stdio
```

### vip-02 (`10.31.38.71`)

```bash
ssh administrator@10.31.38.71

# Ativar backend node1
echo 'enable server backend_zabbix_frontend/zbx_fe_01' | socat /run/haproxy/admin.sock stdio

# Ativar backend node2
echo 'enable server backend_zabbix_frontend/zbx_fe_02' | socat /run/haproxy/admin.sock stdio

# Confirmar ativação
echo 'show servers state backend_zabbix_frontend' | socat /run/haproxy/admin.sock stdio
```

---

## ETAPA 3 — Persistir configuração no haproxy.cfg

> ⚠️ A Runtime API é temporária — reiniciar o HAProxy restaura o estado `disabled`.  
> Execute este bloco para persistir em **vip-01 E em vip-02**.

```bash
# Verificar linha atual no arquivo (confirmar padrão antes de substituir)
grep -n "zbx_fe_0" /etc/haproxy/haproxy.cfg

# Remover 'disabled' e adicionar healthcheck nas duas entradas
sed -i 's/server zbx_fe_01 10\.31\.38\.62:80 disabled/server zbx_fe_01 10.31.38.62:80 check inter 5s fall 3 rise 2/' /etc/haproxy/haproxy.cfg
sed -i 's/server zbx_fe_02 10\.31\.38\.63:80 disabled/server zbx_fe_02 10.31.38.63:80 check inter 5s fall 3 rise 2/' /etc/haproxy/haproxy.cfg

# Confirmar alteração
grep -n "zbx_fe_0" /etc/haproxy/haproxy.cfg

# Validar configuração e recarregar
haproxy -c -f /etc/haproxy/haproxy.cfg && systemctl reload haproxy
```

---

## ETAPA 4 — Validação completa

### 4.1 — Status dos backends no HAProxy

Execute em **vip-01 e vip-02**:

```bash
# Estado detalhado dos backends Zabbix Frontend
echo 'show servers state backend_zabbix_frontend' | socat /run/haproxy/admin.sock stdio

# Estatísticas resumidas
echo 'show stat' | socat /run/haproxy/admin.sock stdio | grep zbx_fe | cut -d',' -f1-2,18-19
```

> ✅ Ambos os backends devem aparecer com estado `UP`.

### 4.2 — Stats via interface web HAProxy

```bash
# Via curl (vip-01 e vip-02)
curl -s 'http://10.31.38.70:8404/stats' | grep -i zbx_fe
curl -s 'http://10.31.38.71:8404/stats' | grep -i zbx_fe
```

> ✅ Acesse `http://10.31.38.70:8404/stats` no browser para visualização gráfica.

### 4.3 — Testar acesso via VIP flutuante

```bash
# Testar porta 80 via VIP flutuante (Keepalived)
timeout 5 bash -c '</dev/tcp/10.31.38.72/80' && echo "✓ Frontend VIP acessível na porta 80" || echo "✗ VIP INACESSÍVEL"

# Testar interface Zabbix via VIP
curl -Ls http://10.31.38.72/zabbix/ -o /dev/null -w "HTTP: %{http_code}\n"
# Esperado: 200 ou 302
```

### 4.4 — Verificar balanceamento entre nodes

```bash
# Fazer múltiplas requisições e verificar que ambos os backends respondem
for i in {1..6}; do
    curl -s -o /dev/null -w "Request $i — HTTP: %{http_code}\n" http://10.31.38.72/zabbix/
done

# Verificar contadores de conexão por backend
echo 'show stat' | socat /run/haproxy/admin.sock stdio | \
    grep -E 'zbx_fe|backend_zabbix_frontend' | cut -d',' -f1-2,48-49
```

---

## ✅ Checklist final

| Item | vip-01 | vip-02 |
|---|---|---|
| `backend_zabbix_frontend/zbx_fe_01` | ✅ UP | ✅ UP |
| `backend_zabbix_frontend/zbx_fe_02` | ✅ UP | ✅ UP |
| `haproxy.cfg` persistido | ✅ | ✅ |
| HAProxy recarregado | ✅ | ✅ |
| VIP `10.31.38.72:80` | ✅ acessível | — |
| HTTP `/zabbix/` via VIP | ✅ 200/302 | — |

---

## 🔍 Monitoramento contínuo

```bash
# Logs HAProxy em tempo real
journalctl -u haproxy -f

# Status dos backends Frontend em loop
watch -n 10 "echo 'show servers state backend_zabbix_frontend' | socat /run/haproxy/admin.sock stdio"

# Logs Apache nos nodes frontend
ssh administrator@10.31.38.62 'tail -f /var/log/apache2/access.log'
ssh administrator@10.31.38.63 'tail -f /var/log/apache2/access.log'
```

---

## 🎉 Primeiro acesso

1. Abra no browser: **`http://10.31.38.72/zabbix`**
2. Login padrão: `Admin` / `zabbix`
3. **Troque a senha imediatamente** (Menu → User → Profile → Change password)
4. Configure o timezone em: Administration → General → GUI

---

## 📌 Próximos passos

1. ➡️ **TUTORIAL_05** — Instalar Grafana HA (`grafana-01 / grafana-02`)
2. Configure o data source do Grafana apontando para `http://10.31.38.72/zabbix/api_jsonrpc.php`
