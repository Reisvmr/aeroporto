# TUTORIAL 04d — Zabbix Server (porta 10051) e o HAProxy

> **Versão revisada:** 2.0 — 05/11/2026  
> **Alvo:** `vip-01` (`10.31.38.70`) e `vip-02` (`10.31.38.71`); VIP flutuante planejado `10.31.38.72` (confirmar com `ip -br addr` no MASTER)  
> **Pré-requisito:** TUTORIAL_04 e TUTORIAL_04c v2.0 concluídos: `zabbix_server -R ha_status` mostra um nó **active** e o outro **standby**  
> **Objetivo:** decidir e, se aprovado, publicar o trapper do Zabbix Server (10051) pelo VIP.  
> **Escopo:** somente a porta 10051. O frontend web (porta 80) é tratado no TUTORIAL_04f.

## 0. Alterações importantes em relação ao tutorial original

- O tutorial anterior fazia `sed` em `server zabbix_01 10.31.38.60:10051 disabled`, linha que **não existe** em nenhum `haproxy.cfg` gerado pelo projeto: no TUTORIAL_03 o `backend_zabbix` aponta para a porta **80** (frontend web) e o script `03-vip-haproxy-keepalived.sh` não cria backend 10051. Os `sed` não alteravam nada e o `reload` passava em silêncio.
- Reutilizar `backend_zabbix` (HTTP:80) para 10051 misturaria tráfego web e trapper; o 10051 exige **`mode tcp`** e frontend próprio.
- Com HA nativo, **apenas o nó active escuta em 10051**. O standby ficará `DOWN` no HAProxy, e isso é o esperado.
- Removido `PGPASSWORD` em linha de comando; o estado do cluster é verificado com `zabbix_server -R ha_status`.
- Removida a credencial do stats web em comandos `curl`; a verificação usa o socket administrativo local.

## 1. Decisão de arquitetura (registrar antes de alterar)

O Zabbix suporta HA nativo **sem balanceador** para a porta 10051: agentes e proxies recebem os dois endereços e descobrem o nó ativo sozinhos.

| Opção | Configuração | Prós | Contras |
|---|---|---|---|
| **A — Recomendada** | Agentes: `Server=10.31.38.60,10.31.38.61` e `ServerActive=10.31.38.60;10.31.38.61`. Proxies: `Server=10.31.38.60;10.31.38.61` | Método oficial; preserva o IP de origem real; sem dependência do VIP | Lista de nós em cada agente/proxy (gerenciável via AWX) |
| B — VIP TCP | Agentes/proxies apontam para `10.31.38.72:10051` | Endpoint único | O Zabbix passa a ver o IP do HAProxy como origem (afeta autorregistro por IP, `Allowed hosts` de trapper e diagnóstico); um ponto a mais de falha e de latência no failover |

**Se a decisão for A, este tutorial termina aqui**: não altere o HAProxy. Siga para a etapa 6 (validação) e depois para o TUTORIAL_04f.

As etapas 2 a 5 aplicam-se **somente à opção B**, aprovada formalmente.

## 2. Inspecionar o `haproxy.cfg` real (vip-01 e vip-02)

```bash
hostname; ip -br addr | grep -E '10\.31\.38\.7[0-4]' || true
haproxy -v | head -1
grep -nE '^\s*(frontend|backend|listen)\b|10051|zabbix|zbx_' /etc/haproxy/haproxy.cfg
echo 'show servers state' | socat /run/haproxy/admin.sock stdio | grep -iE 'zabbix|zbx' || true
```

**PARE** e anote se:

- já existir algum `bind` em `:10051` (evitar duplicidade);
- os dois VIPs tiverem `haproxy.cfg` diferentes entre si (`sha256sum /etc/haproxy/haproxy.cfg` nos dois): alinhe-os antes.

## 3. Backup

```bash
cp -a /etc/haproxy/haproxy.cfg "/etc/haproxy/haproxy.cfg.bak-04d-$(date +%Y%m%d-%H%M%S)"
```

## 4. Adicionar o bloco TCP 10051 (somente opção B)

Acrescente ao final do `haproxy.cfg`, **sem** alterar `backend_zabbix`/`backend_zabbix_frontend`:

```bash
cat >> /etc/haproxy/haproxy.cfg <<'EOF'

# ── Zabbix Server trapper (HA nativo: apenas o nó active escuta) ─────────
frontend zabbix_trapper
    mode tcp
    option tcplog
    bind 10.31.38.72:10051
    timeout client 5m
    default_backend backend_zabbix_trapper

backend backend_zabbix_trapper
    mode tcp
    option tcp-check
    timeout server 5m
    server zbx_srv_01 10.31.38.60:10051 check inter 5s fall 3 rise 2
    server zbx_srv_02 10.31.38.61:10051 check inter 5s fall 3 rise 2
EOF
```

> O `bind` no IP do VIP exige `net.ipv4.ip_nonlocal_bind = 1` no nó BACKUP (configurado no TUTORIAL_03; confirme com `sysctl net.ipv4.ip_nonlocal_bind`). Ajuste o IP se o VIP real for diferente.

Valide e recarregue, **primeiro no BACKUP e depois no MASTER**:

```bash
haproxy -c -f /etc/haproxy/haproxy.cfg && systemctl reload haproxy
systemctl status haproxy --no-pager -l | head -15
```

Se `haproxy -c` falhar, **não recarregue**: restaure o backup da etapa 3.

## 5. Ajustar o Zabbix para a origem via HAProxy (somente opção B)

Como as conexões chegam com o IP do HAProxy (`10.31.38.70`/`.71`):

- Nos agentes em modo passivo, isso **não se aplica** (o servidor é que conecta no agente; o tráfego não passa pelo VIP).
- Em itens *trapper* com `Allowed hosts` e em regras de autorregistro que usem IP, inclua os IPs dos VIPs ou revise a regra.
- Documente no inventário (AWX) que `ServerActive` aponta para o VIP.

## 6. Validação

Nos nós Zabbix (vale para as duas opções):

```bash
zabbix_server -R ha_status
```

Nos VIPs (opção B):

```bash
echo 'show servers state backend_zabbix_trapper' | socat /run/haproxy/admin.sock stdio
echo 'show stat' | socat /run/haproxy/admin.sock stdio | awk -F, '$1=="backend_zabbix_trapper"{print $2, $18}'
timeout 5 bash -c '</dev/tcp/10.31.38.72/10051' && echo 'VIP:10051 OK' || echo 'VIP:10051 FALHA'
```

**Critérios de aceite (opção B):**

1. Exatamente **um** servidor `UP`, o que `ha_status` indica como active; o outro `DOWN` (L4CON).
2. Um agente de teste com `ServerActive=10.31.38.72` recebe a lista de checks ativos (`zabbix_agent2 -t` não basta; confira em *Monitoring → Hosts* a disponibilidade ZBX ativa).
3. Após failover controlado (TUTORIAL_04c, etapa 9.1), o HAProxy inverte `UP`/`DOWN` em até `fall × inter` (≈15 s) **após** o novo nó assumir.

**Critérios de aceite (opção A):** um agente de teste com os dois endereços permanece disponível durante o failover controlado.

## 7. Rollback (opção B)

```bash
cp -a /etc/haproxy/haproxy.cfg.bak-04d-<timestamp> /etc/haproxy/haproxy.cfg
haproxy -c -f /etc/haproxy/haproxy.cfg && systemctl reload haproxy
```

Reaponte agentes/proxies para a opção A **antes** de remover o bloco, para não perder coleta.

## 8. Próxima etapa

➡️ **TUTORIAL_04f** — Backends do frontend web Zabbix (porta 80) no HAProxy.

## Fontes de validação

- Tutorial original do projeto: https://github.com/Reisvmr/aeroporto/blob/main/scripts/automated-install/phase-2-ha/TUTORIAL_04d-haproxy-zabbix-backends.md
- Zabbix 7.0 — Alta disponibilidade (configuração de agentes e proxies): https://www.zabbix.com/documentation/7.0/en/manual/concepts/server/ha
- HAProxy — Configuration Manual (`mode tcp`, `option tcp-check`): https://docs.haproxy.org/

> **Nota operacional:** este documento revisa o procedimento, mas não substitui testes executados no ambiente.
