# AWX Automações - Projeto Aeroporto

## 📋 Visão Geral

Este diretório contém todas as automações Ansible/AWX para o Projeto Aeroporto de Monitoramento Integrado.

**Escopo:** 676 ativos distribuídos em 5 categorias
- 🎥 **382 Câmeras IP** (entrada, pátios, corredores)
- 🔐 **240 Sistemas de Controle de Acesso** (biometria, cartão, painéis)
- 🚧 **7 Cancelas/Barreiras** (automáticas, motorizadas)
- 📸 **4 Sistemas UVSS** (Under Vehicle Scanning)
- 🖥️ **Infraestrutura** (PostgreSQL, Zabbix, AWX, Grafana)

---

## 📁 Estrutura de Diretórios

```
awx_automacoes/
├── inventories/              # Definições de hosts/grupos
│   ├── cameras.yml          # 382 câmeras IP
│   ├── access_control.yml   # 240 sistemas de controle
│   ├── gates.yml            # 7 cancelas/barreiras
│   ├── uvss.yml             # 4 sistemas UVSS
│   └── infrastructure.yml    # 5 servidores
│
├── group_vars/              # Variáveis por grupo
│   ├── cameras.yml
│   ├── access_control.yml
│   ├── gates.yml
│   ├── uvss.yml
│   └── infrastructure.yml
│
├── playbooks/               # Playbooks Ansible
│   ├── 01-deploy-camera-config.yml
│   ├── 02-deploy-access-control-config.yml
│   ├── 03-restart-failed-services.yml
│   ├── 04-backup-configurations.yml
│   ├── 05-update-firmware.yml
│   ├── 06-synchronize-ntp.yml
│   ├── 07-connectivity-test.yml
│   ├── 08-cleanup-logs.yml
│   ├── 09-sync-zabbix-grafana.yml
│   └── 10-generate-reports.yml
│
├── roles/                   # Roles Ansible reutilizáveis
│   ├── camera_deployment/
│   ├── access_control_deployment/
│   ├── service_recovery/
│   ├── firmware_update/
│   └── monitoring_integration/
│
├── docs/                    # Documentação
│   ├── INVENTORIES.md
│   ├── PLAYBOOKS.md
│   ├── ROLES.md
│   └── TROUBLESHOOTING.md
│
└── scripts/                 # Scripts auxiliares
    ├── validate_inventory.sh
    └── dry_run.sh
```

---

## 🚀 Começar Rápido

### 1. Validar Inventário

```bash
bash scripts/validate_inventory.sh
```

### 2. Executar Teste de Conectividade

```bash
ansible-playbook playbooks/07-connectivity-test.yml
```

### 3. Fazer Backup de Configurações

```bash
ansible-playbook playbooks/04-backup-configurations.yml
```

### 4. Deploy de Configurações

```bash
# Câmeras
ansible-playbook playbooks/01-deploy-camera-config.yml

# Controle de Acesso
ansible-playbook playbooks/02-deploy-access-control-config.yml
```

---

## 📋 Playbooks Disponíveis

| # | Playbook | Função | Frequência |
|---|----------|--------|-----------|
| 1 | Deploy Camera Config | Configurar câmeras IP | Por demanda |
| 2 | Deploy Access Control | Configurar controle de acesso | Por demanda |
| 3 | Restart Failed Services | Recuperação automática | Contínua |
| 4 | Backup Configurations | Backup de config | Diária |
| 5 | Update Firmware | Atualizar firmware | Semanal |
| 6 | Synchronize NTP | Sincronizar hora | Horária |
| 7 | Connectivity Test | Teste de conectividade | A cada 6 horas |
| 8 | Cleanup Logs | Limpeza de logs | Diária |
| 9 | Sync Zabbix-Grafana | Sincronizar dados | A cada 30 min |
| 10 | Generate Reports | Gerar relatórios | Diária |

---

## 🔧 Configuração Inicial

### 1. Instalar Ansible

```bash
sudo apt-get install ansible ansible-core
```

### 2. Configurar SSH

Garantir que SSH está configurado em todos os hosts:

```bash
ssh-keyscan -f inventories/cameras.yml >> ~/.ssh/known_hosts
```

### 3. Teste de Conexão

```bash
ansible -i inventories/cameras.yml all -m ping
```

---

## 📊 Variáveis Importantes

### Câmeras
```yaml
camera_http_port: 80
camera_https_port: 443
camera_rtsp_port: 554
ntp_server: "10.31.38.60"
retention_days: 30
video_resolution: "1080p"
```

### Controle de Acesso
```yaml
sync_interval: 300
sync_timeout: 30
alert_on_sync_fail: true
db_host: "10.31.38.64"
```

### Infraestrutura
```yaml
backup_enabled: true
backup_retention_days: 30
health_check_interval: 60
alert_on_down: true
```

---

## ⚠️ Requisitos

- **Ansible:** 2.9+
- **Python:** 3.6+
- **SSH:** Acesso SSH aos hosts
- **Conectividade:** Rede entre AWX e todos os dispositivos
- **Credenciais:** Usuário/senha configurados nos inventários

---

## 🔐 Segurança

### Senhas e Credenciais

Usar Ansible Vault para senhas:

```bash
ansible-vault create group_vars/all/vault.yml
```

### Chaves SSH

Configurar chaves SSH públicas nos dispositivos:

```bash
ssh-copy-id -i ~/.ssh/id_rsa.pub admin@192.168.1.101
```

---

## 📖 Documentação Completa

- [Inventários](docs/INVENTORIES.md) - Definições de hosts
- [Playbooks](docs/PLAYBOOKS.md) - Detalhes de cada playbook
- [Roles](docs/ROLES.md) - Roles reutilizáveis
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Resolução de problemas

---

## 🐛 Troubleshooting

### Conexão SSH Recusada

```bash
ansible -i inventories/cameras.yml all -m ping -u admin -k
```

### Host não encontrado

```bash
ansible all -i inventories/cameras.yml --list-hosts
```

### Erro de Sintaxe

```bash
ansible-lint playbooks/*.yml
```

---

## 📈 Monitoramento

Todos os playbooks geram logs em `/tmp/`:

```bash
tail -f /tmp/*.log
```

---

## 📞 Suporte

Para problemas, consultar:
1. [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
2. Logs em `/tmp/`
3. Zabbix Frontend para status dos hosts

---

## 📝 Versão

**Versão:** 1.0  
**Data:** 24/10/2026  
**Autor:** Vinicius Reis  
**Projeto:** Aeroporto - Monitoramento Integrado

---

## 📄 Licença

MIT License
