# Templates Zabbix - Projeto Aeroporto

## 📋 Visão Geral

Este diretório contém todos os templates Zabbix para monitoramento dos 676 ativos do Projeto Aeroporto.

**Escopo de Monitoramento:**
- 🎥 **382 Câmeras IP** - Conectividade, disco, CPU, RAM, temperatura
- 🔐 **240 Sistemas de Controle de Acesso** - Status, banco de dados, sincronização
- 🚧 **7 Cancelas/Barreiras** - Motor, sensores, tempo de operação
- 📸 **4 Sistemas UVSS** - Câmera, processamento, banco de dados
- 🖥️ **Infraestrutura** - PostgreSQL, Zabbix Server, AWX, Grafana

---

## 📁 Arquivos de Template

| Template | Dispositivos | Linhas | Status |
|----------|-------------|--------|--------|
| `camera_template.yaml` | 382 câmeras | 180+ | ✅ Pronto |
| `access_control_template.yaml` | 240 sistemas | 100+ | ✅ Pronto |
| `gate_barrier_template.yaml` | 7 cancelas | 110+ | ✅ Pronto |
| `uvss_template.yaml` | 4 sistemas | 130+ | ✅ Pronto |
| `infrastructure_template.yaml` | 5 servidores | 120+ | ✅ Pronto |

---

## 🚀 Importação Rápida

### Opção 1: Via Zabbix Frontend

1. Acessar: `http://zbx-fe-01:80/` (Zabbix Frontend)
2. Menu: **Administration > Import**
3. Fazer upload de cada `*_template.yaml`
4. Clicar: **Import**

### Opção 2: Via Script de Automação

```bash
bash scripts/import_templates.sh
```

### Opção 3: Via Zabbix API

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d @camera_template.yaml \
  http://zbx-server-01:10051/api/
```

---

## 📊 Templates Detalhados

### 1. Câmera IP - Monitoramento Completo

**Items (Itens Monitorados):**
- Ping (ICMP) - Conectividade básica
- HTTP Status (porta 80) - Serviço web
- HTTPS Status (porta 443) - Serviço seguro
- Disco - Espaço livre e total
- CPU - Utilização percentual
- Memória - Utilização percentual
- Temperatura - Sensor interno

**Triggers (Alarmes):**
- 🔴 Câmera offline (sem resposta ICMP/HTTP por 3 min)
- 🟡 Disco baixo (< 20% livre)
- 🟡 CPU alta (> 80% por 5 min)
- 🟡 Memória alta (> 85%)
- 🟡 Temperatura alta (> 60°C)

**Gráficos:**
- CPU vs Memória vs Temperatura
- Utilização de Disco

**Aplicável a:** 382 câmeras em 3 zonas

---

### 2. Controle de Acesso - Monitoramento Completo

**Items:**
- Ping (ICMP) - Conectividade
- Banco de Dados - Status de conexão
- Sincronização - Última execução e status

**Triggers:**
- 🔴 Sistema offline
- 🟡 Falha de sincronização com banco

**Aplicável a:** 240 dispositivos de controle

---

### 3. Cancela/Barreira - Monitoramento Completo

**Items:**
- Motor - Status e temperatura
- Sensores - Fim de curso (aberta/fechada)
- Tempo de Operação - Abertura/fechamento

**Triggers:**
- 🔴 Falha de movimento do motor
- 🟡 Sensor travado (conflito de estado)

**Aplicável a:** 7 cancelas/barreiras automáticas

---

### 4. UVSS - Monitoramento Completo

**Items:**
- Status geral do sistema
- Câmera - Status e temperatura
- Processamento - Tempo médio e taxa de sucesso
- Banco de dados - Status e tamanho

**Triggers:**
- 🔴 Sistema offline
- 🟡 Taxa de processamento baixa (< 95%)

**Aplicável a:** 4 sistemas UVSS

---

### 5. Infraestrutura - Monitoramento Completo

**Items:**
- PostgreSQL - Status e conexões ativas
- Zabbix Server - Status
- AWX - Status e containers Docker
- Grafana - Status

**Triggers:**
- 🔴 PostgreSQL down (CRÍTICO)
- 🔴 Zabbix Server down (CRÍTICO)
- 🔴 AWX down
- 🔴 Grafana down

**Aplicável a:** 5 servidores de infraestrutura

---

## 📊 Severidades de Alertas

| Severidade | Cor | Significado | Ação |
|-----------|------|-----------|------|
| **CRITICAL** | 🔴 Vermelho | Sistema/Serviço inoperável | Ação imediata |
| **HIGH** | 🟠 Laranja | Serviço degradado | Investigar logo |
| **AVERAGE** | 🟡 Amarelo | Aviso/Limite próximo | Monitorar |
| **WARNING** | 🟢 Verde | Informação | Registrar |
| **INFO** | ⚪ Cinza | Evento normal | Ignorar |

---

## 🔧 Configuração Pós-Importação

### 1. Vincular Template aos Hosts

**No Zabbix Frontend:**
1. Infrastructure > Hosts
2. Selecionar host (ex: camera_entrada_01)
3. Templates tab: Adicionar template
4. Selecionar "Câmera IP - Monitoramento Completo"
5. Salvar

### 2. Configurar Macros (se necessário)

```
{$CAMERA_HTTP_PORT}: 80
{$CAMERA_HTTPS_PORT}: 443
{$ALERT_DISK_THRESHOLD}: 20
{$ALERT_CPU_THRESHOLD}: 80
{$ALERT_TEMP_THRESHOLD}: 60
```

### 3. Validar Coleta de Dados

1. Aguardar 5 minutos
2. Verificar se itens têm dados
3. Conferir gráficos em "Latest Data"

---

## 📈 Métricas Esperadas

### Câmeras
- Taxa de descoberta: 1-2 minutos após importação
- Intervalo de coleta: 60s (ping), 300s (disco)
- Tipo de dados: SNMP + HTTP Agent

### Controle de Acesso
- Taxa de descoberta: 2-3 minutos
- Intervalo: 60s (ping), 300s (banco de dados)
- Tipo: HTTP Agent

### Cancelas
- Taxa de descoberta: 1-2 minutos
- Intervalo: 30s (sensores), 60s (motor)
- Tipo: HTTP Agent

### UVSS
- Taxa de descoberta: 2-3 minutos
- Intervalo: 60s (status), 300s (processamento)
- Tipo: HTTP Agent

### Infraestrutura
- Taxa de descoberta: 1-2 minutos
- Intervalo: 60s (status), 300s (métricas)
- Tipo: HTTP Agent + SNMP

---

## 🔍 Validação de Templates

### Verificar Sintaxe

```bash
bash scripts/validate_templates.sh
```

### Verificar Items

```bash
# Listar todos os items
grep "name:" *_template.yaml | wc -l
# Esperado: ~80-100 items no total
```

### Verificar Triggers

```bash
# Listar todos os triggers
grep "expression:" *_template.yaml | wc -l
# Esperado: ~20-30 triggers no total
```

---

## ⚙️ Personalizações Comuns

### Aumentar Frequência de Coleta

No template, mudar `delay` de `300s` para `60s`:

```yaml
items:
  - name: "CPU - Utilização"
    delay: "60s"  # De 5 min para 1 min
```

### Adicionar Novo Item

```yaml
- name: "Novo Item"
  type: "HTTP_AGENT"
  key: "novo.item"
  delay: "120s"
  history: "7d"
  status: "ACTIVE"
  value_type: "UNSIGNED"
```

### Modificar Threshold de Trigger

```yaml
triggers:
  - name: "CPU alta (> 90%)"  # De 80% para 90%
    expression: |
      {Template:cpu.usage.avg(300)}>90
```

---

## 🐛 Troubleshooting

### Template não aparece na lista

1. Verificar permissões de importação
2. Confirmar arquivo YAML é válido
3. Ver logs: `tail -f /var/log/zabbix-server.log`

### Items não coletam dados

1. Verificar conectividade host: `ping 192.168.x.x`
2. Verificar porta HTTP: `nc -zv 192.168.x.x 80`
3. Verificar credenciais SNMP (se aplicável)
4. Ver "Latest Data" no Zabbix Frontend

### Triggers nunca acionam

1. Verificar `expression` da trigger
2. Confirmar item tem dados
3. Ajustar `nodata()` timeout se necessário

---

## 📖 Documentação Detalhada

- [CAMERA_MONITORING.md](docs/CAMERA_MONITORING.md)
- [ACCESS_CONTROL_MONITORING.md](docs/ACCESS_CONTROL_MONITORING.md)
- [GATE_MONITORING.md](docs/GATE_MONITORING.md)
- [UVSS_MONITORING.md](docs/UVSS_MONITORING.md)
- [INFRASTRUCTURE_MONITORING.md](docs/INFRASTRUCTURE_MONITORING.md)
- [IMPORT_GUIDE.md](docs/IMPORT_GUIDE.md)

---

## 📊 Estatísticas

| Métrica | Valor |
|---------|-------|
| **Templates Totais** | 5 |
| **Items Totais** | ~85 |
| **Triggers Totais** | ~25 |
| **Gráficos Totais** | ~15 |
| **Dispositivos Cobertos** | 676 |
| **Zonas Monitoradas** | 5 |

---

## 🔄 Atualização de Templates

Para atualizar um template após modificação:

1. Exportar versão anterior (se necessário): `Export > Export Template`
2. Deletar template antigo: `Templates > Selecionar > Delete`
3. Importar novo template: `Administration > Import`

---

## 📝 Versão

**Versão:** 1.0  
**Data:** 24/10/2026  
**Zabbix:** 7.0 LTS  
**Autor:** Vinicius Reis  
**Projeto:** Aeroporto - Monitoramento Integrado

---

## 📄 Licença

MIT License
