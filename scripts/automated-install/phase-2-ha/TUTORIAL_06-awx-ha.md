# 🔄 TUTORIAL — AWX 22.x HA
> **Script:** `06-awx-ha.sh`  
> **Objetivo:** Instalar AWX 22.x em cluster HA com Docker Compose  
> **Servidores:** awx-01 (`10.31.38.68`) e awx-02 (`10.31.38.69`)  
> **Uso:** `sudo ./06-awx-ha.sh <node1|node2>`

---

## 📋 Pré-requisitos

- PostgreSQL HA (pg-01/pg-02) já instalado  
- Docker e Docker Compose instalados  
- VIP `10.31.38.70` já configurado  
- IPs estáticos: `10.31.38.68` (node1) / `10.31.38.69` (node2)  

---

## 🔧 Variáveis — defina antes de executar

```bash
export DB_PASS="SUA_SENHA_AWX_DB"
export AWX_ADMIN_PASS="SUA_SENHA_ADMIN_AWX"
```

---

## ETAPA 1 — Verificar pré-requisitos

```bash
# IP do servidor
hostname -I | awk '{print $1}'   # node1: 10.31.38.68 | node2: 10.31.38.69

# Verificar Docker
docker --version
docker-compose --version

# Verificar conectividade com PostgreSQL
timeout 5 bash -c '</dev/tcp/10.31.38.64/5432' && echo "✓ pg-01 ok" || echo "✗ FALHA"

# Espaço em /opt (mínimo 20GB)
df -BG /opt | awk 'NR==2{print $4}'
```

---

## ETAPA 2 — Instalar Docker (se necessário)

```bash
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"     > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Verificar
docker --version
```

---

## ETAPA 3 — Atualizar sistema e instalar dependências

```bash
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
apt-get install -y git curl wget rsync python3-pip python3-dev
```

---

## ETAPA 4 — Preparar ambiente AWX

```bash
# Criar diretório principal
mkdir -p /opt/awx
chmod 755 /opt/awx
```

---

## ETAPA 5 — Criar docker-compose.yml

```bash
cat > /opt/awx/docker-compose.yml << 'DOCKER_EOF'
version: '3.8'

services:
  awx_web:
    image: ansible/awx:22.7.0
    container_name: awx_web
    depends_on:
      - redis
    ports:
      - "8080:8052"
    environment:
      AWX_ADMIN_USER: "admin"
      AWX_ADMIN_PASSWORD: "${AWX_ADMIN_PASS:-admin123}"
      DATABASE_HOST: "10.31.38.64"
      DATABASE_PORT: "5432"
      DATABASE_NAME: "awx"
      DATABASE_USER: "awx"
      DATABASE_PASSWORD: "${DB_PASS:-awx123}"
      REDIS_HOST: "redis"
      REDIS_PORT: "6379"
    volumes:
      - /opt/awx/projects:/var/lib/awx/projects
      - /opt/awx/data:/var/lib/awx/data
    networks:
      - awx_net
    restart: unless-stopped

  awx_task:
    image: ansible/awx:22.7.0
    container_name: awx_task
    command: /usr/bin/launch_awx_task.sh
    depends_on:
      - awx_web
      - redis
    environment:
      AWX_ADMIN_USER: "admin"
      AWX_ADMIN_PASSWORD: "${AWX_ADMIN_PASS:-admin123}"
      DATABASE_HOST: "10.31.38.64"
      DATABASE_PORT: "5432"
      DATABASE_NAME: "awx"
      DATABASE_USER: "awx"
      DATABASE_PASSWORD: "${DB_PASS:-awx123}"
      REDIS_HOST: "redis"
      REDIS_PORT: "6379"
    volumes:
      - /opt/awx/projects:/var/lib/awx/projects
    networks:
      - awx_net
    restart: unless-stopped

  redis:
    image: redis:7
    container_name: awx_redis
    networks:
      - awx_net
    restart: unless-stopped

networks:
  awx_net:
    driver: bridge

volumes:
  awx_projects:
  awx_data:
DOCKER_EOF
```

---

## ETAPA 6 — Criar usuário AWX no PostgreSQL

> ℹ️ **O banco `awx` já foi criado** em `TUTORIAL_01` (step 5 — PostgreSQL Primary). Aqui apenas cria o usuário e concede permissões.

```bash
# Execute no pg-01 como postgres
sudo -u postgres psql << EOF
CREATE USER awx WITH ENCRYPTED PASSWORD '${DB_PASS:-awx123}';
GRANT ALL PRIVILEGES ON DATABASE awx TO awx;
EOF
```

---

## ETAPA 7 — Criar diretórios e permissões

```bash
mkdir -p /opt/awx/projects /opt/awx/data
chmod -R 755 /opt/awx
```

---

## ETAPA 8 — Iniciar AWX

```bash
cd /opt/awx

# Iniciar serviços
docker-compose up -d

# Verificar status
docker-compose ps

# Aguardar inicialização (~2-3 minutos)
sleep 60
docker-compose logs --tail=30
```

✅ **Verificação:**
```bash
# Verificar porta 8080
ss -tlnp | grep 8080

# Teste HTTP
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080
```

---

## ETAPA 9 — Configurar sincronização entre nodes

```bash
# Configurar rsync SSH para projetos compartilhados
# NODE 1: gerar chave
ssh-keygen -t rsa -b 4096 -f /root/.ssh/awx_sync -N ""

# Copiar para node2
ssh-copy-id -i /root/.ssh/awx_sync.pub root@10.31.38.69

# Adicionar ao crontab para sincronização a cada 5 minutos
echo "*/5 * * * * rsync -avz --delete /opt/awx/projects/ root@10.31.38.69:/opt/awx/projects/" >> /etc/crontab
```

---

## ETAPA 10 — Configurar systemd para autostart

```bash
cat > /etc/systemd/system/awx.service << 'EOF'
[Unit]
Description=AWX Docker Compose
After=docker.service
Requires=docker.service

[Service]
WorkingDirectory=/opt/awx
ExecStart=/usr/bin/docker-compose up
ExecStop=/usr/bin/docker-compose down
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable awx
```

---

## ETAPA 11 — Verificação final

```bash
# Status dos containers
docker ps | grep awx

# Log do awx_web
docker logs awx_web --tail=30

# Acesso web
echo "AWX disponível em: http://$(hostname -I | awk '{print $1}'):8080"
echo "Login: admin / ${AWX_ADMIN_PASS:-admin123}"
```

---

## 📝 Próximos passos

1. Acesse: `http://10.31.38.70/awx` (via VIP)  
2. Configure credenciais e inventários  
3. Instale node2 (repita no awx-02 com `node2`)  

---

## 🔍 Monitoramento

```bash
# Status em tempo real
docker-compose -f /opt/awx/docker-compose.yml ps
docker stats --no-stream

# Logs
docker logs -f awx_web
```
