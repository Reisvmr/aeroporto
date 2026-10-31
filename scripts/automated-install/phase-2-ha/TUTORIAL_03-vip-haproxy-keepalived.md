# ⚖️ TUTORIAL — VIP HAProxy + Keepalived
> **Script:** `03-vip-haproxy-keepalived.sh`  
> **Objetivo:** Instalar HAProxy + Keepalived com VIP flutuante para load balancing HA  
> **Servidores:** vip-01 (`10.31.38.70` - Master) e vip-02 (`10.31.38.71` - Backup)  
> **Uso:** `sudo ./03-vip-haproxy-keepalived.sh <master|backup>`

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

## 🔧 Variáveis — defina antes de executar

Não há variáveis obrigatórias. O script detecta automaticamente a interface de rede.

---

## ETAPA 1 — Verificar pré-requisitos

```bash
# IP do servidor
hostname -I | awk '{print $1}'   # master: 10.31.38.70 | backup: 10.31.38.71

# Verificar interface de rede padrão
ip route | grep default | awk '{print $5}' | head -1

# Confirmar conectividade entre vip-01 e vip-02 (VRRP unicast)
ping -c 2 10.31.38.71   # executar no vip-01
ping -c 2 10.31.38.70   # executar no vip-02

# Confirmar que PostgreSQL está acessível via pg-01
timeout 5 bash -c '</dev/tcp/10.31.38.64/5432' && echo "✓ pg-01:5432" || echo "✗ pg-01:5432"
```

> 📌 **Não testar Zabbix/Grafana/AWX aqui** — esses serviços ainda não foram instalados.  
> Os backends são criados com `disabled` e habilitados nas semanas 3-5.

> **Os backends são ativados automaticamente pelos próprios scripts de instalação:**
> - **Semana 3** → Zabbix: `04-zabbix-server-ha.sh` ativa `backend_zabbix` via SSH nos VIPs
> - **Semana 4** → Grafana: `05-grafana-ha.sh` ativa `backend_grafana` via SSH nos VIPs
> - **Semana 5** → AWX: `06-awx-ha.sh` ativa `backend_awx` via SSH nos VIPs
>
> Cada script conecta em vip-01 (`10.31.38.70`) e vip-02 (`10.31.38.71`) ao final da instalação.
> Se o SSH não estiver disponível, o script exibe os comandos manuais.

---

## ETAPA 2 — Instalar HAProxy + Keepalived (feito pelo script)

O script `03-vip-haproxy-keepalived.sh` executa automaticamente:

```bash
# O que o script faz (não precisa rodar manualmente):
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
apt-get install -y haproxy
apt-get install -y keepalived
```

✅ **Verificação pós-script:** `haproxy -v && keepalived --version`

---

## ETAPA 3 — Configurar HAProxy

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
    use_backend zabbix_back if is_zabbix
    default_backend zabbix_back

backend zabbix_back
    balance roundrobin
    option httpchk GET /zabbix/
    # DISABLED — ativado pelo 04-zabbix-server-ha.sh (Semana 3)
    server zbx-01 10.31.38.60:80 disabled
    server zbx-02 10.31.38.61:80 disabled

# ── Grafana ───────────────────────────────────────────────────────────────
frontend grafana_front
    bind *:3000
    default_backend grafana_back

backend grafana_back
    balance roundrobin
    option httpchk GET /api/health
    # DISABLED — ativado pelo 05-grafana-ha.sh (Semana 4)
    server grafana-01 10.31.38.66:3000 disabled
    server grafana-02 10.31.38.67:3000 disabled

# ── AWX ──────────────────────────────────────────────────────────────────
frontend awx_front
    bind *:8080
    default_backend awx_back

backend awx_back
    balance roundrobin
    option httpchk GET /api/v2/ping/
    # DISABLED — ativado pelo 06-awx-ha.sh (Semana 5)
    server awx-01 10.31.38.68:8080 disabled
    server awx-02 10.31.38.69:8080 disabled

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

### 4.1 — MASTER (vip-01: 10.31.38.70)

```bash
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

cat > /etc/keepalived/keepalived.conf << EOF
global_defs {
    router_id vip-01
    script_user root
    enable_script_security
}

vrrp_script chk_haproxy {
    script "killall -0 haproxy"
    interval 2
    weight 2
}

vrrp_instance VI_1 {
    state MASTER
    interface ${INTERFACE}
    virtual_router_id 50
    priority 100
    advert_int 1

    authentication {
        auth_type PASS
        auth_pass AeroportoHA2026
    }

    virtual_ipaddress {
        10.31.38.70
    }

    track_script {
        chk_haproxy
    }
}
EOF
```

### 4.2 — BACKUP (vip-02: 10.31.38.71)

```bash
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

cat > /etc/keepalived/keepalived.conf << EOF
global_defs {
    router_id vip-02
    script_user root
    enable_script_security
}

vrrp_script chk_haproxy {
    script "killall -0 haproxy"
    interval 2
    weight 2
}

vrrp_instance VI_1 {
    state BACKUP
    interface ${INTERFACE}
    virtual_router_id 50
    priority 99
    advert_int 1

    authentication {
        auth_type PASS
        auth_pass AeroportoHA2026
    }

    virtual_ipaddress {
        10.31.38.70
    }

    track_script {
        chk_haproxy
    }
}
EOF
```

---

## ETAPA 5 — Habilitar IP forwarding e configurar firewall

```bash
# IP forwarding (necessário para o VIP)
echo "net.ipv4.ip_nonlocal_bind = 1" >> /etc/sysctl.conf
sysctl -p

# Firewall — liberar portas dos serviços
ufw allow 80/tcp comment "HAProxy Zabbix"
ufw allow 3000/tcp comment "HAProxy Grafana"
ufw allow 8080/tcp comment "HAProxy AWX"
ufw allow 8404/tcp comment "HAProxy Stats"
ufw allow 112 comment "VRRP Keepalived"
```

---

## ETAPA 6 — Iniciar HAProxy e Keepalived

```bash
systemctl enable haproxy keepalived
systemctl restart haproxy keepalived

# Verificar status
systemctl status haproxy
systemctl status keepalived
```

✅ **Verificação:**
```bash
# VIP deve estar no MASTER
ip addr show | grep 10.31.38.70   # deve aparecer apenas no vip-01

# Stats HAProxy
curl -s -u admin:haproxy@stats http://localhost:8404/stats | head -5
```

---

## ETAPA 7 — Verificação de failover manual

```bash
# No vip-01 (MASTER) — simular falha do HAProxy
systemctl stop haproxy
sleep 3

# Em outro terminal, verificar que VIP migrou para vip-02:
# ssh root@10.31.38.71 "ip addr show | grep 10.31.38.70"

# Restaurar:
systemctl start haproxy
```

⏱️ **RTO esperado:** < 5 segundos

---

## 📝 Próximos passos

1. Execute em **vip-02** com argumento `backup`  
2. Teste acesso via VIP: `http://10.31.38.70` (Zabbix), `http://10.31.38.72:3000` (Grafana)  
3. Prossiga com `07-pre-execution-validation.sh` para validação final  

---

## 🔍 Monitoramento

```bash
# Status VRRP em tempo real
journalctl -u keepalived -f

# Stats HAProxy
watch -n 2 "echo 'show stat' | socat /run/haproxy/admin.sock stdio | cut -d',' -f1,2,18,19 | column -t -s','"

# Log HAProxy
tail -f /var/log/haproxy.log
```
