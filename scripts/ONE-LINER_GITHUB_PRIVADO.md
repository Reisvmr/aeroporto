# 🚀 ONE-LINER - EXECUTAR VALIDAÇÃO DO GITHUB PRIVADO

**Data:** 23/10/2024  
**Projeto:** Aeroporto - Zabbix 7.0 LTS + PostgreSQL 16

---

## 📋 Resumo

Execute os scripts de validação **diretamente do GitHub privado** usando uma única linha de comando.

---

## 🔑 Opção 1: Com GitHub Token (Para Repositório Privado)

### Passo 1: Gerar Token GitHub

1. Acesse: https://github.com/settings/tokens
2. Clique em "Generate new token" → "Generate new token (classic)"
3. **Nome:** `aeroporto-validation`
4. **Escopo:** Selecione apenas `repo` (acesso ao repositório)
5. Copie o token gerado

### Passo 2: Executar One-Liner

**PostgreSQL (10.31.38.64):**
```bash
export GITHUB_TOKEN="seu_token_aqui"
bash <(curl -fsSL https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/run-check.sh) pg01
```

**Zabbix Server:**
```bash
export GITHUB_TOKEN="seu_token_aqui"
bash <(curl -fsSL https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/run-check.sh) zbx-server
```

**Zabbix Frontend:**
```bash
export GITHUB_TOKEN="seu_token_aqui"
bash <(curl -fsSL https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/run-check.sh) zbx-fe
```

---

## 🔐 Opção 2: Salvar Token em Arquivo (Mais Prático)

### Passo 1: Criar arquivo com token

```bash
# Salvar token de forma segura
echo "seu_token_github" > ~/.github_token
chmod 600 ~/.github_token
```

### Passo 2: Executar (sem definir GITHUB_TOKEN a cada vez)

```bash
# PostgreSQL
bash <(curl -fsSL https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/run-check.sh) pg01

# Zabbix Server
bash <(curl -fsSL https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/run-check.sh) zbx-server

# Zabbix Frontend
bash <(curl -fsSL https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/run-check.sh) zbx-fe
```

---

## 🔄 Opção 3: Interativo (Escolher no Menu)

```bash
# Será mostrado menu para escolher o servidor
bash <(curl -fsSL https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/run-check.sh)

# Ou com token
export GITHUB_TOKEN="seu_token"
bash <(curl -fsSL https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/run-check.sh)
```

---

## 📊 Exemplos Completos

### PostgreSQL com Token

```bash
GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
bash <(curl -fsSL https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/run-check.sh) pg01
```

### Zabbix Server com Token Salvo

```bash
# Primeiro (uma única vez):
echo "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxx" > ~/.github_token
chmod 600 ~/.github_token

# Depois (simples):
bash <(curl -fsSL https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/run-check.sh) zbx-server
```

### Zabbix Frontend Interativo

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/run-check.sh)
```

---

## ✅ Parâmetros Suportados

| Parâmetro | Descrição | Script |
|-----------|-----------|--------|
| `pg01` | PostgreSQL Primary (v1.1 melhorada) | `check-server-pg-01-IMPROVED.sh` |
| `pg01-orig` | PostgreSQL Primary (v1.0 original) | `check-server-pg-01.sh` |
| `zbx-server` | Zabbix Server (v1.1 melhorada) | `check-server-zbx-server-01-IMPROVED.sh` |
| `zbx-server-orig` | Zabbix Server (v1.0 original) | `check-server-zbx-server-01.sh` |
| `zbx-fe` | Zabbix Frontend (v1.1 melhorada) | `check-server-zbx-fe-01-IMPROVED.sh` |
| `zbx-fe-orig` | Zabbix Frontend (v1.0 original) | `check-server-zbx-fe-01.sh` |
| *(nenhum)* | Menu interativo | - |

---

## 🛡️ Segurança

### ⚠️ Cuidado com Tokens em Histórico

```bash
# ❌ NÃO faça (fica no histórico do shell):
bash ... GITHUB_TOKEN="seu_token" ...

# ✅ FAÇA (usando arquivo protegido):
echo "seu_token" > ~/.github_token
chmod 600 ~/.github_token
```

### ✅ Melhores Práticas

```bash
# 1. Salvar token de forma segura
echo "seu_token" > ~/.github_token
chmod 600 ~/.github_token  # Apenas você consegue ler

# 2. Ou usar SSH (sem token):
bash <(git clone ... && sh ./run-check.sh)

# 3. Ou variável de ambiente temporária:
(
  export GITHUB_TOKEN="seu_token"
  bash <(curl -fsSL ...)
)
# Token não persiste fora do subshell
```

---

## 🔍 Testando o Token

```bash
# Verificar se token funciona
export GITHUB_TOKEN="seu_token"
curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user | grep login

# Esperado: seu_login_github
```

---

## ❌ Troubleshooting

### "Bad credentials"
```bash
# Token inválido ou expirado
# Solução: Gerar novo token em https://github.com/settings/tokens
```

### "404 Not Found"
```bash
# Script não existe ou repo não acessível
# Solução: Verificar se repo é privado e usar token
```

### "Permission denied"
```bash
# Token sem permissão 'repo'
# Solução: Gerar novo token com escopo 'repo' selecionado
```

### Permissão negada em ~/.github_token
```bash
# Arquivo com permissões incorretas
chmod 600 ~/.github_token
```

---

## 📝 Resumo Rápido

**Para repositório PRIVADO:**

```bash
# Opção A (Rápido - salvar token uma vez):
echo "seu_github_token" > ~/.github_token && chmod 600 ~/.github_token
bash <(curl -fsSL https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/run-check.sh) pg01

# Opção B (Inline - sem salvar):
GITHUB_TOKEN="seu_github_token" \
bash <(curl -fsSL https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/run-check.sh) zbx-server
```

**Resultado:**
- ✅ Script baixado do GitHub privado
- ✅ Validação executada
- ✅ Relatório em `/tmp/check-*.txt`

---

## 🎯 Recomendação Final

**Use a Opção 2 (Arquivo ~/.github_token):**
- ✅ Mais seguro (arquivo protegido com chmod 600)
- ✅ Mais prático (não repete token em cada comando)
- ✅ Tokens não ficam no histórico do shell

---

**Status:** ✅ One-liner pronto para uso  
**GitHub:** https://github.com/Reisvmr/aeroporto.git  
**Script:** `scripts/run-check.sh`
