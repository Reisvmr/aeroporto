# ✅ TUTORIAL — Validação de Pré-requisitos
> **Script:** `00-prerequisitos-validacao.sh`  
> **Objetivo:** Verificar se o servidor atende todos os requisitos antes da instalação  
> **Executar em:** Cada servidor individualmente (como root/sudo)  
> **Uso:** `sudo ./00-prerequisitos-validacao.sh <tipo_servidor>`

---

## 📋 Tipos de servidor disponíveis

| Tipo                  | Servidor           | IP           |
|-----------------------|--------------------|--------------|
| `postgresql-primary`  | pg-01              | 10.31.38.64  |
| `postgresql-standby`  | pg-02              | 10.31.38.65  |
| `zabbix-server`       | zbx-server-01/02   | 10.31.38.60/61 |
| `grafana`             | grafana-01/02      | 10.31.38.66/67 |
| `awx`                 | awx-01/02          | 10.31.38.68/69 |
| `vip`                 | vip-01/02          | 10.31.38.70/71 |

---

## Passo 1 — Verificar o hostname e IP do servidor

```bash
hostname
hostname -I | awk '{print $1}'
```

---

## Passo 2 — Verificar sistema operacional

```bash
lsb_release -d
uname -r
```

✅ **Esperado:** Ubuntu **26.04 LTS (resolute)**

---

## Passo 3 — Verificar espaço em disco

```bash
# Verificar /var (mínimo 50GB para pg, 20GB para demais)
df -BG /var | awk 'NR==2{print "Livre:", $4}'

# Verificar disco geral
df -h
lsblk
```

---

## Passo 4 — Verificar conectividade de rede

```bash
# Testar gateway
ping -c 3 10.31.38.1

# Testar DNS
nslookup google.com

# Testar acesso ao repositório PostgreSQL
curl -s --connect-timeout 5 https://apt.postgresql.org -o /dev/null && echo "OK" || echo "FALHA"

# Testar acesso ao repositório Zabbix
curl -s --connect-timeout 5 https://repo.zabbix.com -o /dev/null && echo "OK" || echo "FALHA"
```

---

## Passo 5 — Verificar recursos de hardware

```bash
# CPU
nproc
lscpu | grep -E "Model name|CPU\(s\)"

# Memória (mínimo 4GB)
free -h
cat /proc/meminfo | grep MemTotal
```

---

## Passo 6 — Verificar dependências básicas

```bash
# Comandos necessários
for cmd in curl wget ssh scp rsync systemctl; do
    command -v $cmd &>/dev/null && echo "✓ $cmd" || echo "✗ $cmd FALTANDO"
done
```

---

## Passo 7 — Instalar dependências faltantes (se necessário)

```bash
apt-get update
apt-get install -y curl wget rsync openssh-client
```

---

## Passo 8 — Executar o script de validação automática

```bash
# Exemplo para pg-01
cd /tmp/phase-2-ha
sudo chmod +x 00-prerequisitos-validacao.sh
sudo ./00-prerequisitos-validacao.sh postgresql-primary

# Para verificar o log gerado
ls -la /tmp/00-prerequisitos-validacao-*.log
cat /tmp/00-prerequisitos-validacao-*.log | tail -30
```

---

## ⚠️ O que verificar no resultado

- **[✓]** = Passou — pode continuar  
- **[✗] ERRO** = Falhou — corrija antes de prosseguir  
- **[⚠] AVISO** = Atenção, mas pode continuar com monitoramento  

---

## Passo 9 — Verificar conectividade entre servidores (para pg-01)

```bash
# pg-01 deve alcançar pg-02
timeout 5 bash -c '</dev/tcp/10.31.38.65/22' && echo "pg-02: OK" || echo "pg-02: FALHA"
timeout 5 bash -c '</dev/tcp/10.31.38.65/5432' 2>/dev/null && echo "PG pg-02: OK" || echo "PG pg-02: sem serviço (normal antes da instalação)"
```
