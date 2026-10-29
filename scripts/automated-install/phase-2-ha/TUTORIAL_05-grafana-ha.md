# 📈 TUTORIAL — Grafana 10.x HA
> **Script:** `05-grafana-ha.sh`  
> **Objetivo:** Instalar Grafana 10.x em cluster HA com Shared Database (PostgreSQL)  
> **Servidores:** grafana-01 (`10.31.38.66`) e grafana-02 (`10.31.38.67`)  
> **Uso:** `sudo ./05-grafana-ha.sh <node1|node2>`

---

## 📋 Pré-requisitos

- PostgreSQL HA (pg-01/pg-02) já instalado e rodando  
- VIP `10.31.38.70` já configurado  
- IPs estáticos: `10.31.38.66` (node1) / `10.31.38.67` (node2)  

---

## 🔧 Variáveis — defina antes de executar

```bash
export DB_PASS="SUA_SENHA_GRAFANA_DB"
export ZABBIX_API_PASS="SUA_SENHA_ZABBIX_API"   # Padrão: zabbix
```

---

## ETAPA 1 — Verificar pré-requisitos

```bash
# IP do servidor
hostname -I | awk '{print $1}'   # node1: 10.31.38.66 | node2: 10.31.38.67

# Conectividade com PostgreSQL
timeout 5 bash -c '</dev/tcp/10.31.38.64/5432' && echo "✓ pg-01 ok" || echo "✗ FALHA"

# Porta 3000 livre
ss -tlnp | grep 3000 && echo "⚠️ Porta 3000 em uso" || echo "✓ Porta 3000 livre"

# Espaço em /var (mínimo 20GB)
df -BG /var | awk 'NR==2{print $4}'
```

---

## ETAPA 2 — Atualizar sistema

```bash
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
```

---

## ETAPA 3 — Instalar Grafana 10.x

```bash
# Dependências
apt-get install -y software-properties-common apt-transport-https

# Adicionar repositório oficial Grafana
curl -fsSL https://packages.grafana.com/gpg.key | apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" > /etc/apt/sources.list.d/grafana.list

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y grafana
```

✅ **Verificação:** `grafana-server --version`

---

## ETAPA 4 — Criar usuário Grafana no PostgreSQL

```bash
# Execute no pg-01 como postgres
sudo -u postgres psql << EOF
CREATE USER grafana WITH ENCRYPTED PASSWORD '${DB_PASS:-grafana123}';
GRANT ALL PRIVILEGES ON DATABASE grafana TO grafana;
EOF
```

---

## ETAPA 5 — Configurar Grafana para HA

### 5.1 — Backup da configuração original

```bash
cp /etc/grafana/grafana.ini /etc/grafana/grafana.ini.backup
```

### 5.2 — Configurar banco de dados PostgreSQL

```bash
# Trocar SQLite por PostgreSQL
sed -i "s/^;type = sqlite3/type = postgres/" /etc/grafana/grafana.ini
sed -i "s/^;host = 127.0.0.1:5432/host = 10.31.38.64:5432/" /etc/grafana/grafana.ini
sed -i "s/^;name = grafana/name = grafana/" /etc/grafana/grafana.ini
sed -i "s/^;user = grafana/user = grafana/" /etc/grafana/grafana.ini
sed -i "s/^;password = $/password = ${DB_PASS:-grafana123}/" /etc/grafana/grafana.ini
```

### 5.3 — Configurar sessões em PostgreSQL (essencial para HA)

```bash
sed -i "s/^;provider = memory/provider = postgres/" /etc/grafana/grafana.ini
sed -i "s/^;cookie_secure = false/cookie_secure = false/" /etc/grafana/grafana.ini
```

### 5.4 — Configurar identidade do nó

```bash
# NODE 1:
sed -i "s/^;instance_name = .*/instance_name = grafana-01/" /etc/grafana/grafana.ini

# NODE 2 (usar no grafana-02):
# sed -i "s/^;instance_name = .*/instance_name = grafana-02/" /etc/grafana/grafana.ini
```

### 5.5 — Configurar security (chave secreta)

```bash
# Gerar chave aleatória
SECRET_KEY=$(openssl rand -base64 32)
sed -i "s/^;secret_key = .*/secret_key = $SECRET_KEY/" /etc/grafana/grafana.ini

# ⚠️ ATENÇÃO: use a MESMA chave em ambos os nodes!
# Anote a chave gerada:
echo "SECRET_KEY=$SECRET_KEY"
```

### 5.6 — Configurar URL raiz (via VIP)

```bash
sed -i "s/^;http_port = 3000/http_port = 3000/" /etc/grafana/grafana.ini
sed -i "s|^;root_url = .*|root_url = http://10.31.38.70|" /etc/grafana/grafana.ini
```

### 5.7 — Configurar logging

```bash
sed -i "s/^;mode = console/mode = file/" /etc/grafana/grafana.ini
sed -i "s|^;path = .*|path = /var/log/grafana/grafana.log|" /etc/grafana/grafana.ini
```

---

## ETAPA 6 — Iniciar Grafana

```bash
systemctl enable grafana-server
systemctl restart grafana-server

# Aguardar inicialização
sleep 10
systemctl status grafana-server
```

✅ **Verificação:**
```bash
# Verificar porta 3000
ss -tlnp | grep 3000

# Teste HTTP
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000
# Esperado: 302 (redirect para login) ou 200
```

---

## ETAPA 7 — Configurar Data Source Zabbix

```bash
# Instalar plugin Zabbix para Grafana
grafana-cli plugins install alexanderzobnin-zabbix-app

# Reiniciar Grafana após instalar plugin
systemctl restart grafana-server
sleep 10
```

### Configurar Data Source via API

```bash
# Configurar via API REST do Grafana
curl -s -X POST http://admin:admin@localhost:3000/api/datasources   -H "Content-Type: application/json"   -d '{
    "name": "Zabbix",
    "type": "alexanderzobnin-zabbix-datasource",
    "url": "http://10.31.38.70/zabbix/api_jsonrpc.php",
    "access": "proxy",
    "jsonData": {
      "username": "Admin",
      "trends": true,
      "trendsFrom": "7d",
      "trendsRange": "4d"
    },
    "secureJsonData": {
      "password": "${ZABBIX_API_PASS:-zabbix}"
    }
  }'
```

---

## ETAPA 8 — Sincronização entre nodes (dashboards)

```bash
# Exportar dashboards do node1 e copiar para node2
# Diretório de dashboards provisionados
ls /etc/grafana/provisioning/dashboards/

# Sincronizar via rsync
rsync -avz /etc/grafana/provisioning/ root@10.31.38.67:/etc/grafana/provisioning/
```

---

## ETAPA 9 — Verificação final

```bash
# Status do serviço
systemctl status grafana-server

# Logs
tail -30 /var/log/grafana/grafana.log

# Acesso web (local)
echo "Grafana local: http://$(hostname -I | awk '{print $1}'):3000"
echo "Login: admin / admin (troque na primeira entrada!)"
echo "Grafana via VIP: http://10.31.38.70"
```

---

## 📝 Próximos passos

1. Acesse: `http://10.31.38.70` e troque a senha do admin  
2. Instale node2 (repita os passos no grafana-02 com `node2`)  
3. **⚠️ Use a mesma `secret_key` em ambos os nodes!**  
4. Importe dashboards da comunidade Grafana  

---

## 🔍 Monitoramento

```bash
# Logs em tempo real
tail -f /var/log/grafana/grafana.log

# Verificar conexão com banco
PGPASSWORD="${DB_PASS:-grafana123}" psql -h 10.31.38.64 -U grafana -d grafana -c "\dt" | head
```
