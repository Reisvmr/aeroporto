# 🎯 COMO RODAR GRAFANA EM MODO INTERATIVO

**Versão:** 1.0  
**Data:** 24/10/2026  
**Servidor:** grafana-01 (10.31.38.66)

---

## ⚡ RESUMO RÁPIDO (3 passos)

```bash
# 1. Copiar script
scp scripts/automated-install/05-grafana-installer.sh root@10.31.38.66:/tmp/

# 2. Conectar no servidor
ssh root@10.31.38.66

# 3. Rodar o script interativo
sudo bash /tmp/05-grafana-installer.sh

# 4. Responder as 10 perguntas
# (Deixar ENTER nas que têm [padrão], digitar apenas a senha PostgreSQL)
```

---

## 📋 PASSO A PASSO DETALHADO

### 1️⃣ Conectar no Servidor

```bash
ssh root@10.31.38.66
```

Esperado:
```
root@grafana-01:~#
```

---

### 2️⃣ Copiar o Script

Escolha uma das 3 opções:

#### Opção A: SCP (do seu computador)
```bash
scp scripts/automated-install/05-grafana-installer.sh root@10.31.38.66:/tmp/
```

#### Opção B: Git clone (no servidor)
```bash
git clone https://github.com/Reisvmr/aeroporto.git
cd aeroporto/scripts/automated-install/
```

#### Opção C: Curl (do GitHub direto)
```bash
curl -fsSL -o /tmp/05-grafana-installer.sh \
  https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/automated-install/05-grafana-installer.sh
chmod +x /tmp/05-grafana-installer.sh
```

---

### 3️⃣ Executar o Script

```bash
sudo bash /tmp/05-grafana-installer.sh
```

ou (se já é root):
```bash
bash /tmp/05-grafana-installer.sh
```

---

### 4️⃣ Responder as 10 Perguntas

#### Pergunta 1: Username admin
```
Username (padrão: admin): 
```
**Ação:** Pressione ENTER para usar `admin` ou digite outro

#### Pergunta 2: Senha admin
```
Password: 
```
**Ação:** Pressione ENTER para auto-gerar (recomendado) ou digite uma senha
- A senha NÃO aparece na tela (read -s)

#### Pergunta 3: Host PostgreSQL
```
Host (padrão: 10.31.38.64): 
```
**Ação:** Pressione ENTER para usar padrão

#### Pergunta 4: Porta PostgreSQL
```
Port (padrão: 5432): 
```
**Ação:** Pressione ENTER para usar padrão

#### Pergunta 5: Database PostgreSQL
```
Database (padrão: grafana): 
```
**Ação:** Pressione ENTER para usar padrão

#### Pergunta 6: Username PostgreSQL
```
Username (padrão: grafana): 
```
**Ação:** Pressione ENTER para usar padrão

#### Pergunta 7: ⚠️ Senha PostgreSQL (OBRIGATÓRIA)
```
Password: 
```
**Ação:** Digitar a senha do usuário PostgreSQL (não pode deixar vazio!)
- A senha NÃO aparece na tela
- Script valida e exige essa entrada

#### Pergunta 8: Zabbix API URL
```
Zabbix API URL (padrão: http://10.31.38.60/api_jsonrpc.php): 
```
**Ação:** Pressione ENTER para usar padrão

#### Pergunta 9: Domain/FQDN
```
Domain/FQDN (padrão: grafana.example.com): 
```
**Ação:** Digitar seu domínio (ex: `matos.reisvmr.com`) ou pressione ENTER para padrão

#### Pergunta 10: HTTP Port
```
HTTP Port (padrão: 3000): 
```
**Ação:** Pressione ENTER para usar padrão (3000) ou digitar outra porta

---

### 5️⃣ Aguardar a Instalação

O script vai:
- ✅ Adicionar repositório Grafana
- ✅ Instalar Grafana
- ✅ Configurar grafana.ini
- ✅ Instalar plugins
- ✅ Iniciar serviço
- ✅ Validar instalação

Tempo: **20-30 minutos**

---

### 6️⃣ Ver as Credenciais

Ao final, você verá:

```
════════════════════════════════════════════════════════════════
INFORMAÇÕES DE ACESSO GRAFANA
════════════════════════════════════════════════════════════════

🎉 GRAFANA INSTALADO COM SUCESSO!

Acesso:
  URL:      http://10.31.38.66:3000
  Domain:   matos.reisvmr.com
  Porta:    3000

Credenciais de Acesso:
  Username: admin
  Password: [sua senha ou auto-gerada]

Banco de Dados (Backend):
  Host:     10.31.38.64
  Port:     5432
  Database: grafana
  User:     grafana

Integração Zabbix:
  API URL:  http://10.31.38.60/api_jsonrpc.php

...
════════════════════════════════════════════════════════════════
```

---

### 7️⃣ Acessar o Grafana

Abra no navegador:
```
http://10.31.38.66:3000
```

**Login:**
- Username: `admin`
- Password: [a senha que você digitou ou auto-gerada]

---

## 📝 EXEMPLO COMPLETO

```bash
# Do seu computador
$ scp scripts/automated-install/05-grafana-installer.sh root@10.31.38.66:/tmp/

# Conectar
$ ssh root@10.31.38.66

# Rodar (no servidor)
root@grafana-01:~# sudo bash /tmp/05-grafana-installer.sh

# Responder perguntas (como exemplo)
Username (padrão: admin): admin
[Enter]

Password: 
[Enter para auto-gerar]
[✓] Senha gerada: MySecurePass123!

Host (padrão: 10.31.38.64): 
[Enter]

Port (padrão: 5432): 
[Enter]

Database (padrão: grafana): 
[Enter]

Username (padrão: grafana): 
[Enter]

Password: 
[Digita a senha do PostgreSQL, ex: postgres123]

Zabbix API URL (padrão: http://10.31.38.60/api_jsonrpc.php): 
[Enter]

Domain/FQDN (padrão: grafana.example.com): 
matos.reisvmr.com
[Digite seu domínio]

HTTP Port (padrão: 3000): 
[Enter]

# Aguardar a instalação (20-30 minutos)
[✓] Instalar Grafana
[✓] Habilitar grafana-server
[✓] Iniciar grafana-server

# Ver credenciais
🎉 GRAFANA INSTALADO COM SUCESSO!
URL: http://10.31.38.66:3000
Username: admin
Password: MySecurePass123!

# Acessar no navegador
http://10.31.38.66:3000
Login: admin / MySecurePass123!
```

---

## 💡 DICAS

✅ **Deixar ENTER** nas que têm `[padrão]`:
- Host PostgreSQL
- Porta PostgreSQL
- Database
- Username PostgreSQL
- Zabbix API URL
- HTTP Port

✅ **Digitar APENAS** em:
- Username admin (se quiser customizar)
- Senha admin (ou deixar vazio para auto-gerar)
- **Senha PostgreSQL** ⚠️ (OBRIGATÓRIO)
- Domain/FQDN (se tiver domínio)

---

## ❌ ERROS COMUNS

| Erro | Solução |
|------|---------|
| "Senha do PostgreSQL é obrigatória!" | Digitar uma senha real na pergunta 7 |
| "Não foi possível conectar ao PostgreSQL" | Verificar se pg-01 está online |
| "Permission denied" | Rodar com `sudo bash ...` |
| "Nenhuma interface de rede" | Verificar conexão de rede do servidor |

---

## 🔍 VERIFICAR LOGS

```bash
# Ver arquivo de log
tail -f /var/log/grafana-install.log

# Ver status do serviço
systemctl status grafana-server

# Ver logs da aplicação
tail -f /var/log/grafana/grafana.log
```

---

## 🎯 PRÓXIMOS PASSOS

Após instalar:
1. ✅ Acessar `http://10.31.38.66:3000`
2. ✅ Fazer login com `admin` / `[sua_senha]`
3. ✅ Mudar a senha padrão
4. ✅ Configurar data source Zabbix
5. ✅ Criar dashboards
6. ✅ Configurar alertas

---

**Repositório:** https://github.com/Reisvmr/aeroporto.git
