# ⚖️ TUTORIAL — VIP HAProxy + Keepalived

> **Script:** `03-vip-haproxy-keepalived.sh`
> **Objetivo:** Instalar HAProxy + Keepalived com VIP flutuante para load balancing HA
> **Servidores:** vip-01 (`10.31.38.70` - Master) e vip-02 (`10.31.38.71` - Backup)
> **VIP flutuante:** `10.31.38.72` — migra automaticamente em failover

---

## 🗺️ Visão geral de execução

| Etapa | vip-01 (`10.31.38.70`) | vip-02 (`10.31.38.71`) |
|-------|------------------------|------------------------|
| Script | `sudo ./03-vip-haproxy-keepalived.sh master` | `sudo ./03-vip-haproxy-keepalived.sh backup` |
| 1 — Pré-requisitos | ✅ executar | ✅ executar |
| 2 — Instalar pacotes | ✅ executar | ✅ executar |
| 3 — Configurar HAProxy | ✅ mesma config | ✅ mesma config |
| 4 — Configurar Keepalived | ✅ config MASTER | ✅ config BACKUP |
| 5 — IP forwarding + firewall | ✅ executar | ✅ executar |
| 6 — Iniciar serviços | ✅ executar | ✅ executar |
| 7 — Teste de failover | ✅ simular falha aqui | ✅ verificar VIP migrado |

---

## 📋 Pré-requisitos

> ⚠️ **Esta etapa é executada na Semana 2.**
> Neste ponto apenas o PostgreSQL (Semana 1) está instalado.
> Zabbix (Semana 3), Grafana (Semana 4) e AWX (Semana 5) serão configurados depois —
> os seus backends no HAProxy são criados já **desabilitados** (`disabled`) e
> ativados automaticamente pelos respectivos scripts de instalação.

- ✅ PostgreSQL HA concluído (pg-01 `10.31.38.64` + pg-02 `10.31.38.65`)
- IPs estáticos configurados: vip-01 `10.31.38.70` · vip-02 `10.31.38.71` · VIP flutuante `10.31.38.72`
- Ambos os servidores na mesma sub-rede `/24` (necessário para VRRP unicast)
- Acesso root/sudo em vip-01 e vip-02

---

## ETAPA 1 — Verificar pré-requisitos

> 🖥️ **Execute em: vip-01 E vip-02** (cada servidor verifica o próprio ambiente)

```bash
# Confirmar IP do servidor atual
hostname -I | awk '{print $1}'
# Esperado: 10.31.38.70 (vip-01) | 10.31.38.71 (vip-02)

# Verificar interface de rede padrão
ip route | grep default | awk '{print $5}' | head -1

# Confirmar que PostgreSQL está acessível
timeout 5 bash -c '</dev/tcp/10.31.38.64/5432' && echo "✓ pg-01:5432" || echo "✗ pg-01:5432"
```

> 🖥️ **Execute em: vip-01** (testar conectividade com vip-02)

```bash
ping -c 2 10.31.38.71   # vip-01 → vip-02 (unicast VRRP)
```

> 🖥️ **Execute em: vip-02** (testar conectividade com vip-01)

```bash
ping -c 2 10.31.38.70   # vip-02 → vip-01 (unicast VRRP)
```

> 📌 **Não testar Zabbix/Grafana/AWX aqui** — esses serviços ainda não foram instalados.

> **Os backends são ativados automaticamente pelos próprios scripts de instalação:**
> - **Semana 3** → Zabbix: `04-zabbix-server-ha.sh` ativa `backend_zabbix` via SSH nos VIPs
> - **Semana 4** → Grafana: `05-grafana-ha.sh` ativa `backend_grafana` via SSH nos VIPs
> - **Semana 5** → AWX: `06-awx-ha.sh` ativa `backend_awx` via SSH nos VIPs
>
> Cada script conecta em vip-01 (`10.31.38.70`) e vip-02 (`10.31.38.71`) ao final da instalação.
> Se o SSH não estiver disponível, o script exibe os comandos manuais.

---

## ETAPA 2 — Instalar HAProxy + Keepalived

> 🖥️ **Execute em: vip-01 E vip-02** (mesmos pacotes nos dois servidores)

O script `03-vip-haproxy-keepalived.sh` executa automaticamente:

```bash
# O que o script faz (não precisa rodar manualmente):
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
apt-get install -y haproxy keepalived socat
```

✅ **Verificação pós-instalação:**
```bash
haproxy -v
keepalived --version
command -v socat && echo "socat ok"
```

---

## ETAPA 3 — Configurar HAProxy

> 🖥️ **Execute em: vip-01 E vip-02** (configuração idêntica nos dois servidores)

```bash
# Backup da configuração original
cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.backup

# Criar configuração principal
cat > /etc/haproxy/haproxy.cfg << 'EOF'
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

# ── Zabbix Frontend ──────────────────────────────────────────────────────
frontend zabbix_front
    bind *:80
    acl is_zabbix path_beg /zabbix
    use_backend backend_zabbix if is_zabbix
    default_backend backend_zabbix

backend backend_zabbix
    balance roundrobin
    option httpchk GET /zabbix/
    # DISABLED — ativado pelo 04-zabbix-server-ha.sh (Semana 3)
    server zabbix_01 10.31.38.60:80 disabled
    server zabbix_02 10.31.38.61:80 disabled

# ── Grafana ───────────────────────────────────────────────────────────────
frontend grafana_front
    bind *:3000
    default_backend backend_grafana

backend backend_grafana
    balance roundrobin
    option httpchk GET /api/health
    # DISABLED — ativado pelo 05-grafana-ha.sh (Semana 4)
    server grafana_01 10.31.38.66:3000 disabled
    server grafana_02 10.31.38.67:3000 disabled

# ── AWX ──────────────────────────────────────────────────────────────────
frontend awx_front
    bind *:8080
    default_backend backend_awx

backend backend_awx
    balance roundrobin
    option httpchk GET /api/v2/ping/
    # DISABLED — ativado pelo 06-awx-ha.sh (Semana 5)
    server awx_01 10.31.38.68:8080 disabled
    server awx_02 10.31.38.69:8080 disabled

# ── Stats ─────────────────────────────────────────────────────────────────
listen stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 30s
    stats auth admin:haproxy@stats
EOF
```

✅ **Verificação da sintaxe:**
```bash
haproxy -c -f /etc/haproxy/haproxy.cfg
```

---

## ETAPA 4 — Configurar Keepalived (VRRP Failover)

> ⚠️ **As configurações 4.1 e 4.2 são DIFERENTES** — cada servidor tem o seu próprio arquivo.

### 4.1 — MASTER

> 🖥️ **Execute SOMENTE em: vip-01 (`10.31.38.70`)**

```bash
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

cat > /etc/keepalived/keepalived.conf << EOF
global_defs {
    notification_email {
        admin@aeroporto.local
    }
    notification_email_from keepalived@aeroporto.local
    smtp_server localhost
    smtp_connect_timeout 30
    router_id AEROPORTO_HA
    script_user root
    enable_script_security
}

vrrp_script check_haproxy {
    script "/etc/keepalived/check_haproxy.sh"
    interval 5
    weight 2
    fall 2
    rise 2
}

vrrp_instance VI_1 {
    state MASTER
    interface ${INTERFACE}
    virtual_router_id 50
    priority 100
    advert_int 1
    unicast_src_ip 10.31.38.70
    unicast_peer {
        10.31.38.71
    }
    authentication {
        auth_type PASS
        auth_pass aeroporto_ha
    }
    virtual_ipaddress {
        10.31.38.72/24
    }
    track_script {
        check_haproxy
    }
    notify_master "/etc/keepalived/notify_master.sh"
    notify_backup "/etc/keepalived/notify_backup.sh"
    notify_fault  "/etc/keepalived/notify_fault.sh"
}
EOF
```

### 4.2 — BACKUP

> 🖥️ **Execute SOMENTE em: vip-02 (`10.31.38.71`)**

```bash
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

cat > /etc/keepalived/keepalived.conf << EOF
global_defs {
    notification_email {
        admin@aeroporto.local
    }
    notification_email_from keepalived@aeroporto.local
    smtp_server localhost
    smtp_connect_timeout 30
    router_id AEROPORTO_HA
    script_user root
    enable_script_security
}

vrrp_script check_haproxy {
    script "/etc/keepalived/check_haproxy.sh"
    interval 5
    weight 2
    fall 2
    rise 2
}

vrrp_instance VI_1 {
    state BACKUP
    interface ${INTERFACE}
    virtual_router_id 50
    priority 99
    advert_int 1
    unicast_src_ip 10.31.38.71
    unicast_peer {
        10.31.38.70
    }
    authentication {
        auth_type PASS
        auth_pass aeroporto_ha
    }
    virtual_ipaddress {
        10.31.38.72/24
    }
    track_script {
        check_haproxy
    }
    notify_master "/etc/keepalived/notify_master.sh"
    notify_backup "/etc/keepalived/notify_backup.sh"
    notify_fault  "/etc/keepalived/notify_fault.sh"
}
EOF
```

---

## ETAPA 5 — Habilitar IP forwarding e configurar firewall

> 🖥️ **Execute em: vip-01 E vip-02** (configuração idêntica nos dois servidores)

```bash
# IP forwarding — permite ao kernel atribuir o VIP flutuante
echo "net.ipv4.ip_nonlocal_bind = 1" >> /etc/sysctl.conf
sysctl -p

# Firewall — liberar portas dos serviços e VRRP
ufw allow 80/tcp    comment "HAProxy → Zabbix"
ufw allow 3000/tcp  comment "HAProxy → Grafana"
ufw allow 8080/tcp  comment "HAProxy → AWX"
ufw allow 8404/tcp  comment "HAProxy Stats"
ufw allow 112       comment "VRRP Keepalived (unicast)"
ufw allow ssh
ufw --force enable
ufw status verbose
```

---

## ETAPA 6 — Iniciar HAProxy e Keepalived

> 🖥️ **Execute em: vip-01 E vip-02** (mesmos comandos nos dois servidores)

```bash
systemctl enable haproxy keepalived
systemctl restart haproxy keepalived

# Verificar status
systemctl status haproxy  --no-pager
systemctl status keepalived --no-pager
```

✅ **Verificação do VIP flutuante:**

> 🖥️ **Execute em: vip-01** (VIP deve estar ativo aqui após o start)

```bash
# VIP flutuante deve aparecer em vip-01 (MASTER)
ip addr show | grep 10.31.38.72
# Saída esperada: inet 10.31.38.72/24 ...
```

> 🖥️ **Execute em: vip-02** (VIP NÃO deve aparecer aqui enquanto vip-01 estiver UP)

```bash
# VIP flutuante NÃO deve aparecer no BACKUP enquanto o MASTER estiver ativo
ip addr show | grep 10.31.38.72
# Saída esperada: (vazia)
```

```bash
# Stats HAProxy (executar em qualquer um dos dois)
curl -s -u admin:haproxy@stats http://localhost:8404/stats | head -5
```

---

## ETAPA 7 — Teste de failover manual

> 🖥️ **Execute em: vip-01** — simular falha do HAProxy (MASTER)

```bash
systemctl stop haproxy
sleep 5
```

> 🖥️ **Execute em: vip-02** — verificar que o VIP migrou para cá

```bash
# VIP 10.31.38.72 deve aparecer agora em vip-02
ip addr show | grep 10.31.38.72
# Saída esperada: inet 10.31.38.72/24 ...

# Confirmar via log
tail -5 /var/log/keepalived_notify.log
```

> 🖥️ **Execute em: vip-01** — restaurar serviço (VIP volta automaticamente)

```bash
systemctl start haproxy
sleep 5

# VIP deve ter voltado para vip-01
ip addr show | grep 10.31.38.72
```

⏱️ **RTO esperado:** < 5 segundos

---

## 📝 Próximos passos

1. Execute o script em **vip-02** com `sudo ./03-vip-haproxy-keepalived.sh backup`
2. Após Semana 3: acesse Zabbix via `http://10.31.38.72/zabbix`
3. Após Semana 4: acesse Grafana via `http://10.31.38.72:3000`
4. Após Semana 5: acesse AWX via `http://10.31.38.72:8080`
5. Prossiga com `07-pre-execution-validation.sh` para validação final

---

## 🔍 Monitoramento

> 🖥️ **Execute em: vip-01 OU vip-02** (qualquer um dos dois)

```bash
# Status VRRP em tempo real
journalctl -u keepalived -f

# Log de eventos de failover
tail -f /var/log/keepalived_notify.log

# Stats HAProxy (Runtime API)
watch -n 2 "echo 'show stat' | socat /run/haproxy/admin.sock stdio | cut -d',' -f1,2,18,19 | column -t -s','"

# Log HAProxy
tail -f /var/log/haproxy.log
```

> 🖥️ **Execute em: vip-01** (verificar quem detém o VIP no momento)

```bash
# Verificar qual servidor está com o VIP ativo
ip addr show | grep 10.31.38.72 && echo "VIP ATIVO AQUI (MASTER)" || echo "VIP em outro servidor (BACKUP)"
```
