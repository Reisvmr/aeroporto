# 🔍 TUTORIAL — Validação Pré-Execução (Phase 2 HA)
> **Script:** `07-pre-execution-validation.sh`  
> **Objetivo:** Validar que todos os pré-requisitos estão OK antes de executar os scripts de instalação  
> **Uso:** `sudo ./07-pre-execution-validation.sh [--auto-fix]`

---

## 📋 O que este script valida

| # | Validação | Descrição |
|---|-----------|-----------|
| 1 | Sintaxe bash | Verifica shellcheck em todos os scripts |
| 2 | Dependências | Comandos necessários presentes |
| 3 | Permissões | Scripts com chmod +x |
| 4 | Espaço em disco | Mínimos por servidor |
| 5 | Conectividade | Rede entre todos os nodes |
| 6 | Acesso root | Sudo funcional |
| 7 | Variáveis de ambiente | Senhas e parâmetros definidos |
| 8 | Funções críticas | Blocos obrigatórios em cada script |
| 9 | Tratamento de erros | `set +e`, `trap ERR` |
| 10 | Log files | Caminhos de log configurados |

---

## 🔧 Parâmetros

```bash
# Sem parâmetros: apenas valida e exibe relatório
sudo ./07-pre-execution-validation.sh

# Com --auto-fix: tenta corrigir problemas simples automaticamente
sudo ./07-pre-execution-validation.sh --auto-fix

# Modo silencioso (só erros)
sudo ./07-pre-execution-validation.sh --quiet
```

---

## ETAPA 1 — Executar a validação completa

```bash
cd /home/reisvmr/Documentos/REPOS/aeroporto/scripts/automated-install/phase-2-ha
sudo ./07-pre-execution-validation.sh
```

✅ **Resultado esperado:**
```
╔════════════════════════════════════════════╗
║  VALIDAÇÃO PRÉ-EXECUÇÃO - PHASE 2 HA      ║
╚════════════════════════════════════════════╝

[✓] Sintaxe bash: 12/12 scripts OK
[✓] Dependências: todas presentes
[✓] Permissões: todos executáveis
[✓] Espaço em disco: suficiente
[✓] Conectividade: todos os nodes acessíveis
[✓] Acesso root: OK

RESULTADO: 60/60 checks passaram ✅ PRONTO PARA INSTALAR
```

---

## ETAPA 2 — Interpretar falhas

### Falha de sintaxe bash

```
[✗] Sintaxe: 01-postgresql-primary.sh — erro na linha 42
```

**Ação:**
```bash
bash -n scripts/automated-install/phase-2-ha/01-postgresql-primary.sh
# ou
shellcheck scripts/automated-install/phase-2-ha/01-postgresql-primary.sh
```

---

### Falha de dependência

```
[✗] Dependência: 'shellcheck' não encontrado
```

**Ação:**
```bash
apt-get install -y shellcheck
```

---

### Falha de permissão

```
[✗] Permissão: 04-zabbix-server-ha.sh não é executável
```

**Ação:**
```bash
chmod +x scripts/automated-install/phase-2-ha/*.sh
# ou use --auto-fix
```

---

### Falha de espaço em disco

```
[✗] Disco: pg-01 /var/lib/pgsql livre=45GB (mínimo 50GB)
```

**Ação:** Verificar particionamento do servidor antes de prosseguir.  
Consulte `DECISAO_FINAL_DISCO_pg01.txt` para contexto do pg-01.

---

### Falha de conectividade

```
[✗] Conectividade: 10.31.38.65:22 timeout
```

**Ação:**
```bash
# Verificar se o servidor está ligado
ping -c3 10.31.38.65

# Verificar firewall
nmap -p 22 10.31.38.65
```

---

## ETAPA 3 — Modo auto-fix

```bash
sudo ./07-pre-execution-validation.sh --auto-fix
```

O `--auto-fix` corrige automaticamente:
- ✅ Permissões de arquivo (`chmod +x`)
- ✅ Instalação de dependências simples (apt-get)
- ❌ **Não** corrige problemas de disco, rede ou sintaxe

---

## ETAPA 4 — Verificação manual rápida (alternativa)

```bash
BASE="/home/reisvmr/Documentos/REPOS/aeroporto/scripts/automated-install/phase-2-ha"

# 1. Listar scripts e verificar permissões
ls -la "$BASE"/*.sh

# 2. Verificar sintaxe de todos
for s in "$BASE"/*.sh; do
    bash -n "$s" && echo "✓ $(basename $s)" || echo "✗ $(basename $s)"
done

# 3. Verificar conectividade com todos os servidores
for ip in 10.31.38.60 10.31.38.61 10.31.38.64 10.31.38.65 10.31.38.66 10.31.38.67 10.31.38.68 10.31.38.69 10.31.38.70 10.31.38.71; do
    ping -c1 -W2 $ip &>/dev/null && echo "✓ $ip" || echo "✗ $ip"
done
```

---

## 📝 Próximos passos

Após **RESULTADO: PRONTO PARA INSTALAR**, siga a ordem de instalação:

1. `00-prerequisitos-validacao.sh` — em todos os servidores  
2. `01-postgresql-primary.sh` — em pg-01  
3. `02-postgresql-standby.sh` — em pg-02  
4. `03-vip-haproxy-keepalived.sh master` — em vip-01  
5. `03-vip-haproxy-keepalived.sh backup` — em vip-02  
6. `04-zabbix-server-ha.sh node1` — em zbx-server-01  
7. `04-zabbix-server-ha.sh node2` — em zbx-server-02  
8. `05-grafana-ha.sh node1` — em grafana-01  
9. `05-grafana-ha.sh node2` — em grafana-02  
10. `06-awx-ha.sh node1` — em awx-01  
11. `06-awx-ha.sh node2` — em awx-02  
12. `08-validate-ha-health.sh` — em qualquer servidor (validação final)  
