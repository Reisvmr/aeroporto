# Grafana 10.x Otimizado para 10GB de Disco

## 📋 Visão Geral

Script de instalação do **Grafana 10.x** especialmente otimizado para funcionar com apenas **10GB de espaço livre** em disco.

**Versão:** 2.0 (Otimizado para Disco Limitado)  
**Servidor:** grafana-01 (10.31.38.66)  
**Data:** 24/10/2026

---

## ✅ Otimizações Implementadas

### 1. **Rotação Agressiva de Logs**
```bash
Configuração: /etc/logrotate.d/grafana-server
├─ Frequência: Diária
├─ Retenção: 3 dias (vs padrão 30 dias)
├─ Compressão: Habilitada
└─ Efeito: Reduz ~500MB a 50MB em logs
```

**Por quê:** Logs do Grafana podem crescer rapidamente. Com retenção de 3 dias em vez de 30, economiza ~400MB de espaço crítico.

### 2. **Script de Limpeza Automática**
```bash
Local: /usr/local/bin/grafana-cleanup.sh
Frequência: Diária (02:00 AM)
Ações:
  • Se disco > 80%: Remove logs antigos
  • Se disco > 90%: Reinicia Grafana para liberar buffers
```

**Por quê:** Monitora continuamente espaço e remove dados antigos antes que disco fique crítico.

### 3. **PostgreSQL Remoto (Sem Dados Locais)**
```bash
Host: 10.31.38.64:5432
Database: grafana
User: grafana (credencial remota)

Impacto: Não ocupa espaço em disco local para dados
Tamanho: 0 MB na máquina grafana-01
Dados históricos: Armazenados no servidor PostgreSQL
```

**Por quê:** Ao usar PostgreSQL remoto, todos os dados históricos ficam no outro servidor. grafana-01 usa apenas cache local (~100MB).

### 4. **Plugins Minimizados**
```bash
Instalados:
  ✅ grafana-piechart-panel (essencial)

Não instalados por padrão:
  ❌ Plugins pesados de visualização
  ❌ Temas adicionais
  ❌ Extensões de datasource

Instalação futura: Pode adicionar plugins conforme necessário
```

**Por quê:** Cada plugin consome 10-50MB. Com 10GB, manter apenas o essencial economiza espaço.

### 5. **Configurações de Retenção de Dados**
```bash
Arquivo: /etc/grafana/grafana.ini

max_lines = 1000000
max_retention_days = 90

Efeito: Limita histórico de dados para últimos 3 meses
```

**Por quê:** Evita crescimento infinito da base de dados local.

### 6. **Verificação Contínua de Espaço**
```bash
Inicio do script:
  ✅ Verifica se há 10GB livres antes de instalar
  ✅ Alerta se disco > 80%
  ✅ Aborta se disco < 5GB

Durante execução:
  ✅ Monitora espaço constantemente
  ✅ Avisa se espaço fica crítico
```

**Por quê:** Previne travamento do sistema por falta de espaço.

---

## 📊 Ocupação de Espaço Esperada

### Com 10GB Livres

| Componente | Tamanho | % do Total |
|-----------|---------|-----------|
| **Instalação Grafana** | 650 MB | 6.5% |
| **PostgreSQL remoto** | 0 MB | 0% |
| **Dados iniciais** | 100 MB | 1% |
| **Logs (3 dias)** | 50-100 MB | 0.5-1% |
| **Cache** | 100-200 MB | 1-2% |
| **Buffer de segurança** | 8 GB+ | ~80% |
| **TOTAL DISPONÍVEL** | 10 GB | 100% |

**Conclusão:** Com essas otimizações, Grafana confortavelmente funciona em 10GB com margem de crescimento.

---

## 🔧 Recursos do Script

### Perguntas Interativas

1. **Credenciais Admin** (2 perguntas)
   - Username (padrão: admin)
   - Senha (auto-gerada se vazio)

2. **PostgreSQL Remoto** (4 perguntas)
   - Host (padrão: 10.31.38.64)
   - Port (padrão: 5432)
   - Database (padrão: grafana)
   - Username (padrão: grafana)
   - ⚠️ **Senha (OBRIGATÓRIA)**

3. **Zabbix Integration** (1 pergunta)
   - API URL (padrão: http://10.31.38.60/api_jsonrpc.php)

4. **Domain** (2 perguntas)
   - FQDN (padrão: grafana.example.com)
   - HTTP Port (padrão: 3000)

### Funções de Segurança

- Senhas digitadas são ocultas (`read -s`)
- Auto-geração de senhas com `openssl rand -base64 12`
- Backup automático de arquivo de configuração
- Validação de pré-requisitos antes de instalar

### Funções de Monitoramento

```bash
Integradas ao script:
  ✅ check_disk_space()        - Verifica espaço antes de instalar
  ✅ check_prerequisites()    - Valida SO, RAM, conectividade
  ✅ create_cleanup_script()  - Instala script de limpeza automática
  ✅ print_access_info()      - Mostra informações de acesso
```

---

## 📥 Como Usar

### Opção 1: Via SCP

```bash
# Seu computador
scp scripts/automated-install/05-grafana-installer.sh root@10.31.38.66:/tmp/

# No servidor
ssh root@10.31.38.66
sudo bash /tmp/05-grafana-installer.sh
```

### Opção 2: Via Git Clone

```bash
# No servidor
git clone https://github.com/Reisvmr/aeroporto.git
cd aeroporto/scripts/automated-install/
sudo bash 05-grafana-installer.sh
```

### Opção 3: Via Curl Direto

```bash
curl -fsSL -o /tmp/05-grafana-installer.sh \
  https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/automated-install/05-grafana-installer.sh

sudo bash /tmp/05-grafana-installer.sh
```

---

## ⚡ Tempo de Instalação

| Etapa | Tempo |
|-------|-------|
| Pré-requisitos | 1 min |
| Perguntas interativas | 2-5 min |
| Adicionar repositório | 2 min |
| Instalar Grafana | 5-10 min |
| Configurar | 1 min |
| Rodar testes | 2 min |
| **TOTAL** | **15-30 min** |

---

## 📊 Monitorar Espaço em Disco

### Comandos Essenciais

```bash
# Ver espaço total disponível
df -h /

# Ver uso específico de Grafana
du -sh /var/lib/grafana
du -sh /var/log/grafana
du -sh /etc/grafana

# Ver status de limpeza automática
tail -f /var/log/grafana/grafana.log

# Verificar se cron de limpeza está ativo
crontab -l | grep grafana-cleanup

# Executar limpeza manual se necessário
/usr/local/bin/grafana-cleanup.sh
```

### Alertas de Monitoramento

| Condição | Ação |
|----------|------|
| Disco < 10 GB | ❌ Script aborta instalação |
| Disco 80-90% | ⚠️ Script registra aviso |
| Disco > 90% | 🔴 Limpeza automática ativada |
| Disco > 95% | 🚨 Grafana reiniciado |

---

## 🔍 Verificar Instalação

### Status do Serviço

```bash
# Ver status
systemctl status grafana-server

# Ver logs recentes
journalctl -u grafana-server -n 50 -f

# Ver se está escutando porta 3000
netstat -tuln | grep 3000
```

### Acessar Grafana

```bash
URL: http://10.31.38.66:3000
Username: admin (ou que você configurou)
Password: (gerada no script ou que você digitou)
```

---

## ⚠️ Limites e Restrições com 10GB

### O que Funciona Bem ✅

- ✅ Instalação e configuração básica
- ✅ Dashboard simples com alguns gráficos
- ✅ Integração com Zabbix
- ✅ Histórico moderado (1-3 meses)
- ✅ Alertas e notificações

### O que Requer Cuidado ⚠️

- ⚠️ Muitos plugins adicionais (cada um ocupa 10-50MB)
- ⚠️ Histórico extenso de métricas (> 6 meses)
- ⚠️ Backup local (precisaria 2x de espaço)
- ⚠️ Temas e extensões pesadas

### O que NÃO Funciona ❌

- ❌ Histórico de 1-2 anos completo local
- ❌ Múltiplos backups simultâneos
- ❌ Instalação de 50+ plugins pesados
- ❌ Armazenamento de grande volume de logs

---

## 🔧 Manutenção Recomendada

### Diária (Automática)
- ✅ Rotação de logs (via logrotate)
- ✅ Script de limpeza (via cron)

### Semanal
- 🔍 `df -h /` - Verificar espaço
- 🔍 `du -sh /var/log/grafana` - Ver tamanho de logs

### Mensal
- 🔄 Revisar histórico de dados
- 🔄 Remover plugins não usados
- 🔄 Verificar se performance está aceitável

### Trimestral
- 🛠️ Avaliar expansão de disco
- 🛠️ Considerar upgrade para 20-30GB se crescimento for significativo

---

## 🐛 Troubleshooting

### Problema: "Espaço em disco INSUFICIENTE"

```bash
# Solução:
1. Limpar cache e logs:
   /usr/local/bin/grafana-cleanup.sh

2. Verificar espaço:
   df -h /
   du -sh /var/lib/grafana /var/log/grafana

3. Se ainda insuficiente, expandir disco
```

### Problema: "Grafana não está respondendo"

```bash
# Verificar se está rodando:
systemctl status grafana-server

# Se não, verificar disco cheio:
df -h /

# Se disco > 95%, limpeza automática rodou:
tail -f /var/log/grafana/grafana.log

# Reiniciar:
systemctl restart grafana-server
```

### Problema: "Não consegue conectar ao PostgreSQL"

```bash
# Verificar conectividade:
ping 10.31.38.64

# Verificar porta:
nc -zv 10.31.38.64 5432

# Verificar credenciais:
psql -h 10.31.38.64 -U grafana -d grafana -c "SELECT 1"

# Se falhar, verificar se usuário/database existem:
# (precisa acesso ao servidor PostgreSQL)
```

---

## 📚 Referências

- **Documentação oficial:** https://grafana.com/docs/grafana/latest/
- **PostgreSQL remoto:** `docs/INSTALACAO_AWX_GRAFANA.md`
- **Integração Zabbix:** `docs/SCRIPTS_INSTALACAO_INTERATIVOS.md`
- **Como rodar interativo:** `docs/COMO_RODAR_GRAFANA_INTERATIVO.md`

---

## 📝 Changelog

### Versão 2.0 (24/10/2026)
- ✨ **NOVO:** Otimizações para 10GB de disco
- ✨ **NOVO:** Rotação agressiva de logs (3 dias)
- ✨ **NOVO:** Script de limpeza automática diária
- ✨ **NOVO:** Plugins minimizados
- ✨ **NOVO:** Verificação contínua de espaço
- ✨ **NOVO:** Alertas automáticos em 80% e 90% de disco cheio

### Versão 1.0
- Instalação básica Grafana 10.x

---

## 👤 Autor

**Vinicius Reis** (reisvmr@gmail.com)

Projeto: Aeroporto - Zabbix + AWX + Grafana  
Repositório: https://github.com/Reisvmr/aeroporto.git

---

## 📄 Licença

MIT License
