# TUTORIAL 02b — VIP do PostgreSQL com Keepalived (VIP-DB)

> **Versão:** 1.0 — 06/11/2026  
> **Alvo:** `pg-01` (`10.31.38.64`) e `pg-02` (`10.31.38.65`)  
> **VIP-DB proposto:** `10.31.38.75/25` — **a confirmar com a infraestrutura** (registrar como `IP-016 VIP-PostgreSQL` na planilha de IPs, VLAN 338, gateway `10.31.38.1`)  
> **Pré-requisito:** TUTORIAL_01 e 02 concluídos (pg-01 primário, pg-02 réplica em streaming)  
> **Objetivo:** dar a Zabbix, Grafana e AWX um endereço de banco que acompanhe **sempre o nó primário**, eliminando a troca manual de `DBHost` após a promoção da réplica.  
> **Escopo:** VIP e reconfiguração dos clientes. **Não automatiza a promoção**: ela continua manual (TUTORIAL_08-09, etapa 3).

## 0. Decisão e premissas

Registrar a decisão (00-controle-evidencias, "Controlar decisões") antes de executar:

| Item | Valor |
|---|---|
| Tema | Endpoint estável para o PostgreSQL |
| Opção escolhida | Keepalived nos nós do banco, VIP apenas no nó **não em recuperação** |
| Custo | 1 IP na VLAN 338; pacote `keepalived` em pg-01/pg-02 |
| Impacto | Reinício controlado do Zabbix Server (um nó por vez), Grafana e AWX ao trocar `DBHost` |

**Por que não usar o HAProxy dos vip-01/02:** um health check TCP na 5432 marca a réplica como `UP`, e as gravações iriam para um nó somente leitura. O VIP precisa seguir o **papel** (primário), não apenas a porta aberta.

**Comportamento resultante:**

| Situação | Onde fica o VIP-DB |
|---|---|
| Normal (pg-01 primário, pg-02 réplica) | pg-01 |
| PostgreSQL do pg-01 parado | **Em nenhum nó** (a réplica nunca recebe o VIP) — aplicações aguardam |
| pg-02 promovido (failover manual) | pg-02, automaticamente |
| pg-01 volta **como primário** sem ser reconstruído | **Split-brain** — ver etapa 8 (isolamento) |

## 1. Pré-requisitos e pontos de parada

**PARE** se:

1. O VIP `10.31.38.75` (ou o definido) não estiver formalmente reservado — confirme que não responde: `ping -c 2 10.31.38.75` deve falhar e `ip neigh | grep 10.31.38.75` deve estar vazio.
2. O `virtual_router_id` escolhido (**60**) já estiver em uso na VLAN 338. Em uso pelo projeto: `50` (TUTORIAL_03) e `51–53` (script `03-vip-haproxy-keepalived.sh`). Confira nos vip-01/02: `grep virtual_router_id /etc/keepalived/keepalived.conf`.
3. A replicação não estiver saudável. No **pg-01**:

```bash
sudo -u postgres psql -Xc "SELECT client_addr, state, sync_state, replay_lag FROM pg_stat_replication;"
sudo -u postgres psql -XtAc "SELECT pg_is_in_recovery();"   # esperado: f
```

No **pg-02**:

```bash
sudo -u postgres psql -XtAc "SELECT pg_is_in_recovery();"   # esperado: t
```

Em ambos:

```bash
hostname; ip -br addr; sudo -u postgres psql -XtAc "SHOW listen_addresses;"
```

`listen_addresses` deve ser `*` (o PostgreSQL passa a aceitar conexões no VIP sem reinício). Anote o nome da interface (ex.: `ens18`).

## 2. Firewall: liberar VRRP e clientes no pg-02

### 2.1 Clientes no pg-02 (achado importante)

O TUTORIAL_02 libera a 5432 do pg-02 **apenas para o pg-01**. Após uma promoção, Zabbix, Grafana e AWX seriam bloqueados mesmo com o VIP correto. No **pg-02**, replique as regras do pg-01:

```bash
ufw status | head -3
for ip in 10.31.38.60 10.31.38.61 10.31.38.66 10.31.38.67 10.31.38.68 10.31.38.69; do
  ufw allow from "$ip" to any port 5432 proto tcp comment 'Cliente PostgreSQL (VIP-DB)'
done
```

Confira também o `pg_hba.conf` do pg-02: ele precisa das mesmas linhas de clientes do pg-01 (`grep -v '^#' /etc/postgresql/16/main/pg_hba.conf | grep -v '^$'` nos dois e compare). Se faltar, copie as linhas e rode `sudo -u postgres psql -c 'SELECT pg_reload_conf();'`.

### 2.2 VRRP entre os nós (se o `ufw` estiver ativo)

O VRRP é o protocolo IP 112 (`-p 112`). Em **cada nó**, adicione antes da linha `COMMIT` da tabela `*filter` em `/etc/ufw/before.rules`, usando o IP do **outro** nó:

```text
# VRRP do VIP-DB (keepalived)
-A ufw-before-input -p 112 -s 10.31.38.65 -j ACCEPT
```

(no pg-02, use `-s 10.31.38.64`). Depois:

```bash
ufw reload
```

## 3. Instalar o Keepalived (pg-01 e pg-02)

```bash
apt-get update
apt-get -s install keepalived
DEBIAN_FRONTEND=noninteractive apt-get install -y keepalived
keepalived --version 2>&1 | head -1
```

## 4. Script de verificação do papel (pg-01 e pg-02)

O script retorna sucesso **somente** se o PostgreSQL local responde e **não** está em recuperação.

```bash
cat > /usr/local/bin/pg_is_primary.sh <<'EOF'
#!/bin/sh
# Retorna 0 apenas se o PostgreSQL local estiver ativo e for primario.
out=$(timeout 3 psql -X -qtA -h /var/run/postgresql -d postgres \
      -c 'SELECT NOT pg_is_in_recovery()' 2>/dev/null)
[ "$out" = "t" ]
EOF
chown root:root /usr/local/bin/pg_is_primary.sh
chmod 755 /usr/local/bin/pg_is_primary.sh
sudo -u postgres /usr/local/bin/pg_is_primary.sh; echo "retorno=$?"
```

Esperado: `retorno=0` no **pg-01** e `retorno=1` no **pg-02**. Se ambos retornarem `0`, **PARE**: há dois primários.

## 5. Configurar o Keepalived

Defina a senha VRRP **sem ecoar** (máximo 8 caracteres; o VRRPv2 trunca o restante). Use um valor diferente do `aeroporto_ha` dos vip-01/02:

```bash
read -r -s -p 'Senha VRRP (ate 8 caracteres): ' VRRP_PASS; echo
```

No **pg-01** (ajuste `IFACE` se a interface não for `ens18`):

```bash
IFACE=ens18; SELF=10.31.38.64; PEER=10.31.38.65; PRIO=110
```

No **pg-02**:

```bash
IFACE=ens18; SELF=10.31.38.65; PEER=10.31.38.64; PRIO=100
```

Em **ambos**:

```bash
cp -a /etc/keepalived/keepalived.conf "/etc/keepalived/keepalived.conf.bak-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
cat > /etc/keepalived/keepalived.conf <<EOF
global_defs {
    router_id $(hostname -s)
    enable_script_security
}

vrrp_script chk_pg_primary {
    script "/usr/local/bin/pg_is_primary.sh"
    user postgres
    interval 2
    timeout 5
    fall 2
    rise 2
}

vrrp_instance VI_PGSQL {
    state BACKUP
    nopreempt
    interface ${IFACE}
    virtual_router_id 60
    priority ${PRIO}
    advert_int 1
    unicast_src_ip ${SELF}
    unicast_peer {
        ${PEER}
    }
    authentication {
        auth_type PASS
        auth_pass ${VRRP_PASS}
    }
    virtual_ipaddress {
        10.31.38.75/25 dev ${IFACE} label ${IFACE}:pgvip
    }
    track_script {
        chk_pg_primary
    }
}
EOF
unset VRRP_PASS
chmod 600 /etc/keepalived/keepalived.conf
keepalived -t -f /etc/keepalived/keepalived.conf && echo 'CONFIG OK'
```

> O `track_script` **sem `weight`** faz o nó entrar em estado `FAULT` quando o teste falha. Assim, a réplica **nunca** disputa o VIP, independentemente da prioridade. `nopreempt` evita que o VIP mude de nó apenas por diferença de prioridade.

Inicie **primeiro no pg-01**, confirme, e depois no pg-02:

```bash
systemctl enable --now keepalived
sleep 5
journalctl -u keepalived -n 20 --no-pager
ip -br addr | grep 10.31.38.75 || echo 'VIP nao esta neste no'
```

Esperado: pg-01 com `Entering MASTER STATE` e o VIP; pg-02 com `Entering FAULT STATE` (script falhou = réplica) e sem o VIP.

## 6. Validar o VIP antes de mudar as aplicações

De **um nó Zabbix** (cliente):

```bash
timeout 5 bash -c '</dev/tcp/10.31.38.75/5432' && echo 'VIP-DB:5432 OK'
psql -W -h 10.31.38.75 -U zabbix -d zabbix -XtAc "SELECT inet_server_addr(), pg_is_in_recovery();"
```

Esperado: `10.31.38.75 | f` (conectou no VIP e o servidor é o primário).

**Teste de segurança (sem impacto nas aplicações, que ainda usam o IP do pg-01):** no **pg-02**, `systemctl restart keepalived` — o VIP deve continuar no pg-01. No **pg-01**, `systemctl stop keepalived` — o VIP **some** e **não** vai para o pg-02 (réplica em FAULT). Religue: `systemctl start keepalived` e confirme o VIP de volta no pg-01.

## 7. Apontar as aplicações para o VIP-DB

Faça em janela aprovada, **um componente por vez**, validando antes de seguir.

### 7.1 Zabbix Server — nó standby primeiro

Identifique o nó ativo (`zabbix_server -R ha_status`). No nó **standby**:

```bash
cp -a /etc/zabbix/zabbix_server.conf /etc/zabbix/zabbix_server.conf.bak-vipdb
sed -i 's/^DBHost=.*/DBHost=10.31.38.75/' /etc/zabbix/zabbix_server.conf
grep '^DBHost=' /etc/zabbix/zabbix_server.conf
systemctl restart zabbix-server; sleep 15; zabbix_server -R ha_status
```

Esperado: o nó volta como `standby`, sem `database is down` no log. Repita no nó **ativo**; ao reiniciar, o outro nó assume (failover nativo) e o ambiente fica sem coleta apenas por alguns segundos.

### 7.2 Frontend Zabbix — nos dois nós

```bash
F=$(find /etc/zabbix /usr/share/zabbix -name zabbix.conf.php 2>/dev/null | head -1); echo "$F"
cp -a "$F" "$F.bak-vipdb"
sed -i "s/^\(\$DB\['SERVER'\][[:space:]]*=[[:space:]]*\)'[^']*'/\1'10.31.38.75'/" "$F"
grep -n "\$DB\['SERVER'\]" "$F"
```

Recarregue a página do frontend em cada nó e confirme o login.

### 7.3 Grafana e AWX

Altere o host do banco para `10.31.38.75` nas respectivas configurações (seção `[database]` do `grafana.ini`; variáveis de banco do AWX) e reinicie conforme o TUTORIAL_05 e o TUTORIAL_06, um nó por vez.

### 7.4 Conferir que ninguém usa mais o IP do pg-01 diretamente

No **pg-01**:

```bash
sudo -u postgres psql -Xc "SELECT inet_server_addr() AS destino, client_addr, usename, count(*) FROM pg_stat_activity WHERE client_addr IS NOT NULL GROUP BY 1,2,3 ORDER BY 2;"
```

`inet_server_addr()` só mostra a sessão atual; para as demais, use `ss -tnp state established '( sport = :5432 )'` e confira que a coluna de endereço local é `10.31.38.75`, exceto a replicação vinda do pg-02.

## 8. Failover do banco com o VIP (procedimento operacional)

Atualize o TUTORIAL_08-09, etapa 3, com esta sequência:

1. **Isolar o pg-01** (se ainda estiver acessível): `systemctl stop postgresql@16-main keepalived`. Se não estiver acessível, garanta que não voltará sozinho (desligar a VM ou bloquear a rede) **antes** de promover.
2. **Promover o pg-02**: `sudo -u postgres psql -c 'SELECT pg_promote();'`.
3. Em até ~4 s (`interval 2` × `rise 2`) o pg-02 sai de `FAULT`, vira `MASTER` e assume o VIP. Confirme: `ip -br addr | grep 10.31.38.75`.
4. As aplicações reconectam sozinhas (o Zabbix tenta a cada 10 s). Valide `ha_status` e o frontend.
5. **Nunca religue o pg-01 como primário.** Reconstrua-o como réplica do pg-02 (`pg_rewind` ou novo `pg_basebackup`, conforme TUTORIAL_02 com os papéis invertidos) e só então inicie o `keepalived` nele — ele ficará em `FAULT`, como réplica.

> **Risco residual:** se o pg-01 voltar como primário enquanto o pg-02 também é primário, o script aprova os dois e o VRRP escolhe um — as gravações podem divergir. O passo 1 (isolamento) é obrigatório e deve constar no runbook.

## 9. Evidências

- `ip -br addr` dos dois nós mostrando o VIP apenas no primário.
- `journalctl -u keepalived` com `MASTER` (pg-01) e `FAULT` (pg-02).
- Saída do teste da etapa 6 (`10.31.38.75 | f`).
- `grep '^DBHost=' /etc/zabbix/zabbix_server.conf` nos dois nós Zabbix e `ha_status` após a troca.
- Registro da decisão e da reserva do IP na planilha.

## 10. Rollback

Nos clientes, restaure os arquivos `*.bak-vipdb` (Zabbix Server: um nó por vez; frontend: os dois) e reinicie os serviços — eles voltam a usar `10.31.38.64`. Nos nós do banco:

```bash
systemctl disable --now keepalived
```

O VIP é removido; o PostgreSQL não é afetado.

## Fontes de validação

- Keepalived — `keepalived.conf(5)` (`vrrp_script`, `track_script`, `nopreempt`, `unicast_peer`): https://keepalived.readthedocs.io/
- PostgreSQL 16 — `pg_is_in_recovery()`, `pg_promote()`: https://www.postgresql.org/docs/16/functions-admin.html
- PostgreSQL 16 — `pg_rewind`: https://www.postgresql.org/docs/16/app-pgrewind.html
- Zabbix 7.0 — Alta disponibilidade (reconexão ao banco): https://www.zabbix.com/documentation/7.0/en/manual/concepts/server/ha

> **Nota operacional:** este documento não foi executado no ambiente. Confirme IP, interface e `virtual_router_id` antes de aplicar.
