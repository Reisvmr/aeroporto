# ⚖️ TUTORIAL — VIP HAProxy + Keepalived
> **Script:** `06-vip-haproxy-keepalived.sh`  
> **Objetivo:** Instalar HAProxy + Keepalived com VIP flutuante para load balancing HA  
> **Servidores:** vip-01 (`10.31.38.70` - Master) e vip-02 (`10.31.38.71` - Backup)  
> **Uso:** `sudo ./06-vip-haproxy-keepalived.sh <master|backup>`

---

## 📋 Pré-requisitos

- PostgreSQL, Zabbix, Grafana e AWX já instalados nos seus respectivos nodes  
- IPs estáticos: `10.31.38.70` (master) / `10.31.38.71` (backup)  
- Ambos os servidores na mesma sub-rede (necessário para VRRP)  
- Acesso root/sudo  

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

# Testar conectividade com backends
timeout 5 bash -c '</dev/tcp/10.31.38.60/80' && echo "✓ zabbix-01" || echo "✗ zabbix-01"
timeout 5 bash -c '</dev/tcp/10.31.38.66/3000' && echo "✓ grafana-01" || echo "✗ grafana-01"
timeout 5 bash -c '</dev/tcp/10.31.38.68/8080' && echo "✓ awx-01" || echo "✗ awx-01"

# Verificar se protocolo VRRP (112) está permitido
# (Ambos os servidores precisam se "ver" via multicast 224.0.0.18)
```

---

## ETAPA 2 — Atualizar sistema e instalar HAProxy + Keepalived

```bash
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y haproxy keepalived
```

✅ **Verificação:** `haproxy -v && keepalived --version`

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
    server zbx-01 10.31.38.60:80 check
    server zbx-02 10.31.38.61:80 check backup

# ── Grafana ───────────────────────────────────────────────────────────────
frontend grafana_front
    bind *:3000
    default_backend grafana_back

backend grafana_back
    balance roundrobin
    option httpchk GET /api/health
    server grafana-01 10.31.38.66:3000 check
    server grafana-02 10.31.38.67:3000 check backup

# ── AWX ──────────────────────────────────────────────────────────────────
frontend awx_front
    bind *:8080
    default_backend awx_back

backend awx_back
    balance roundrobin
    option httpchk GET /api/v2/ping/
    server awx-01 10.31.38.68:8080 check
    server awx-02 10.31.38.69:8080 check backup

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
2. Teste acesso via VIP: `http://10.31.38.70` (Zabbix), `http://10.31.38.70:3000` (Grafana)  
3. Prossiga com `08-pre-execution-validation.sh` para validação final  

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
