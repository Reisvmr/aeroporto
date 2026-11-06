# TUTORIAL 04c — Zabbix 7.0 LTS: Server HA + Frontend Nginx — NODE 2

> **Versão revisada:** 2.0 — 05/11/2026  
> **Alvo:** `zbx-server-02` — **IP planejado:** `10.31.38.61` (confirmar com `ip -br addr`; o TUTORIAL_04 registrou uma captura SSH ambígua entre `.60` e `.61`)  
> **SO:** Ubuntu 26.04 *Resolute*  
> **Banco compartilhado:** PostgreSQL `10.31.38.64:5432`, banco `zabbix` (o **mesmo** do NODE 1)  
> **Primeiro nó:** `zbx-server-01` — `10.31.38.60` (TUTORIAL_04 concluído e validado)  
> **Objetivo:** instalar o segundo nó do HA nativo do Zabbix Server e o frontend **Nginx + PHP-FPM**, idêntico ao NODE 1.  
> **Escopo:** NODE 2. Não configura VIP, HAProxy nem HA do PostgreSQL.

## 0. Alterações importantes em relação ao tutorial original

- Mesma arquitetura do TUTORIAL_04 v2.0: **Nginx + PHP-FPM**, sem `zabbix-apache-conf` ativo.
- HA nativo via `HANodeName=zbx-server-02` e `NodeAddress=10.31.38.61:10051`. **`NodeID=2` não existe no Zabbix 7.0** e foi removido.
- `WorkerProcesses=8` removido: não é parâmetro válido do Zabbix Server 7.0.
- **O schema não é importado neste nó.** O banco já foi populado pelo NODE 1.
- `zabbix.conf.php` **não fixa** `$ZBX_SERVER`/`$ZBX_SERVER_PORT`: o frontend descobre o nó ativo pela tabela `ha_node`. O tutorial anterior apontava para `10.31.38.61`, o que quebraria o frontend sempre que o NODE 2 estivesse em standby.
- A senha **não aparece em comandos, variáveis exportadas nem no Markdown**; é lida sem eco.
- Removidos `apt-get upgrade -y`, a remoção cega do repositório e o `sed noble→resolute` sem verificação prévia.
- Removida a troca de chaves SSH entre usuários `zabbix`: **o HA nativo não utiliza SSH**; a comunicação entre nós é feita exclusivamente pelo banco. Se houver outra necessidade (ex.: sincronizar scripts externos), trate-a em procedimento próprio, com usuário e chave dedicados.

## 1. Pré-requisitos e pontos de parada

Execute como `root` no **zbx-server-02**.

**PARE** se qualquer item abaixo falhar:

1. TUTORIAL_04 concluído: `zabbix_server -R ha_status` no NODE 1 mostra `zbx-server-01` como **active**.
2. O IP real deste host confere com o planejado (`10.31.38.61`) e **é diferente** do `NodeAddress` do NODE 1.
3. O hostname/`HANodeName` `zbx-server-02` ainda não está registrado por outro host.

```bash
set -o pipefail
hostnamectl --static
ip -br addr
cat /etc/os-release | grep -E '^(PRETTY_NAME|VERSION_CODENAME)='
ss -lntp | grep -E ':(80|443|8080|10051)\b' || true
systemctl is-active zabbix-server apache2 nginx || true
apt-cache policy zabbix-server-pgsql zabbix-frontend-php zabbix-nginx-conf
command -v zabbix_server && zabbix_server --version | head -3
timeout 5 bash -c '</dev/tcp/10.31.38.64/5432' && echo 'pg-01:5432 OK' || echo 'pg-01:5432 FALHA'
timeout 5 bash -c '</dev/tcp/10.31.38.60/10051' && echo 'node1:10051 OK' || echo 'node1:10051 FALHA'
```

> Os nós **não precisam** se comunicar entre si pela porta 10051 para o HA funcionar; o teste serve apenas para confirmar que o NODE 1 está ativo e alcançável pela rede. Se a política de rede bloquear esse fluxo, valide pelo `ha_status` do NODE 1.

## 2. Backup das configurações existentes

```bash
BACKUP="/root/backup-zbx-node2-$(date +%Y%m%d-%H%M%S)"
mkdir -m 700 -p "$BACKUP"
for dir in /etc/zabbix /etc/nginx /etc/apache2 /etc/php; do
  if [ -e "$dir" ]; then cp -a "$dir" "$BACKUP/"; fi
done
printf 'Backup local: %s\n' "$BACKUP"
```

## 3. Repositório e instalação de pacotes

Se o `apt-cache policy` da etapa 1 já mostra candidatos da Zabbix 7.0, **não reinstale** `zabbix-release`. Caso não haja candidato, configure o repositório oficial **exatamente como no NODE 1** (compare `/etc/apt/sources.list.d/zabbix*` entre os dois nós) — as versões de pacote dos dois nós devem ser idênticas.

```bash
apt-get update
apt-mark showhold
apt-get -s install zabbix-server-pgsql zabbix-agent2 \
  nginx php-fpm php-pgsql php-bcmath php-mbstring php-gd php-xml php-ldap php-curl php-intl \
  zabbix-frontend-php zabbix-nginx-conf
```

**Confirme na simulação** que nenhum componente importante será removido e que a versão de `zabbix-server-pgsql` é a mesma do NODE 1 (`dpkg-query -W zabbix-server-pgsql` em ambos). Versões diferentes de servidor no mesmo banco não são suportadas.

```bash
DEBIAN_FRONTEND=noninteractive apt-get install -y zabbix-server-pgsql zabbix-agent2 \
  nginx php-fpm php-pgsql php-bcmath php-mbstring php-gd php-xml php-ldap php-curl php-intl \
  zabbix-frontend-php zabbix-nginx-conf
```

> `zabbix-sql-scripts` **não é necessário** neste nó, pois o schema não será importado aqui.

## 4. Verificar o banco compartilhado (sem importar schema)

```bash
psql -W -h 10.31.38.64 -p 5432 -U zabbix -d zabbix \
  -c "SELECT to_regclass('public.dbversion') AS zabbix_schema;" \
  -c "SELECT name, address, port, status FROM ha_node ORDER BY name;"
```

- `dbversion` presente e `zbx-server-01` listado: prossiga.
- `dbversion` ausente: **PARE**. O NODE 1 não concluiu a importação; não importe a partir deste nó.
- Já existe uma linha `zbx-server-02` com outro endereço: **PARE** e investigue (instalação anterior, IP trocado). Remova registros obsoletos apenas com `zabbix_server -R ha_remove_node=<nome>` a partir do nó ativo, nunca por `DELETE` manual.

Mapa de `status` em `ha_node`: `0` standby, `1` stopped, `2` unavailable, `3` active.

## 5. Configurar Zabbix Server e HA nativo

### 5.1 Verificar parâmetros atuais

```bash
CONF=/etc/zabbix/zabbix_server.conf
test -f "$CONF" || { echo 'ERRO: zabbix_server.conf ausente'; exit 1; }
grep -nE '^[[:space:]]*(DBHost|DBName|DBUser|DBPassword|HANodeName|NodeAddress|ListenPort|CacheSize|HistoryCacheSize|ValueCacheSize)=' "$CONF" \
  | sed -E 's/(DBPassword=).*/\1[OCULTO]/'
```

### 5.2 Atualizar campos pontuais

Mesmo procedimento do NODE 1, mudando **apenas** `HANodeName` e `NodeAddress`. A senha deve ser a mesma configurada no NODE 1.

> ⚠️ **Execute em três colagens separadas.** Se o `read` for colado junto com outras linhas, ele consome a linha seguinte como senha.

**Passo A** — cole e execute **só esta linha**, depois digite a senha e pressione Enter:

```bash
read -r -s -p 'Senha atual do usuário zabbix no PostgreSQL: ' DB_PASS; echo
```

**Passo B** — testar a senha lida **antes** de gravá-la (não altera nada):

```bash
PGPASSWORD="$DB_PASS" psql -w -h 10.31.38.64 -U zabbix -d zabbix -tAc 'SELECT 1' \
  && echo 'SENHA OK' || echo 'SENHA REJEITADA: NAO PROSSIGA'
```

Se retornar `SENHA REJEITADA`, **PARE** e repita o passo A com a senha em uso pelo NODE 1. Requer o cliente `psql` (`postgresql-client`).

**Passo C** — gravar a senha validada:

```bash
export DB_PASS
python3 - <<'PY'
import os, re, pathlib
p = pathlib.Path('/etc/zabbix/zabbix_server.conf')
content = p.read_text()
updates = {
    'DBHost': '10.31.38.64',
    'DBName': 'zabbix',
    'DBUser': 'zabbix',
    'DBPassword': os.environ['DB_PASS'],
    'HANodeName': 'zbx-server-02',
    'NodeAddress': '10.31.38.61:10051',
}
for key, val in updates.items():
    pat = re.compile(r'^\s*#?\s*' + re.escape(key) + r'\s*=.*$', re.M)
    content = pat.sub('', content)
    content = content.rstrip() + '\n' + key + '=' + val + '\n'
p.write_text(content)
PY
unset DB_PASS
chown root:zabbix "$CONF"
chmod 640 "$CONF"
```

> **Não execute este bloco se o IP real do NODE 2 for diferente de `10.31.38.61`**; ajuste `NodeAddress` primeiro.

### 5.3 Paridade com o NODE 1

Os parâmetros de cache e processos devem ser **iguais** nos dois nós, pois qualquer um pode assumir a carga total após failover.

```bash
grep -E '^(DBHost|DBName|DBUser|HANodeName|NodeAddress|CacheSize|HistoryCacheSize|ValueCacheSize|Start[A-Za-z]+|LogFile)=' "$CONF" | sort
grep -nE '^\s*(NodeID|WorkerProcesses)=' "$CONF" || true
```

Compare a saída com a do NODE 1 (`ssh` ou cópia manual): somente `HANodeName` e `NodeAddress` podem diferir. Se `NodeID` ou `WorkerProcesses` aparecerem ativos, remova-os após backup.

### 5.4 Iniciar e validar HA

```bash
systemctl enable --now zabbix-server zabbix-agent2
systemctl restart zabbix-server
systemctl status zabbix-server --no-pager -l
zabbix_server -R ha_status
journalctl -u zabbix-server -n 80 --no-pager
```

**Esperado:** este nó entra em modo **standby**, e `zbx-server-01` permanece **active**. Em standby, o NODE 2 **não abre a porta 10051** para coleta — isso é normal e afeta os health checks do HAProxy (ver etapa 10).

Se o NODE 2 assumir como **active**, PARE: o NODE 1 não está ativo ou não está atualizando `lastaccess` no banco. Verifique o NODE 1 antes de prosseguir.

## 6. Garantir que o Apache não concorra com o Nginx

```bash
systemctl status apache2 nginx --no-pager -l || true
ss -lntp | grep -E ':(80|443|8080)\b' || true
```

Se o Apache estiver instalado e não hospedar outros sites:

```bash
systemctl disable --now apache2 || true
systemctl mask apache2
```

## 7. Configurar PHP-FPM e Nginx do Zabbix

Repita a **etapa 7 do TUTORIAL_04** sem alterações, garantindo que `/etc/zabbix/nginx.conf` e `/etc/zabbix/php-fpm.conf` fiquem equivalentes aos do NODE 1:

- `listen 80;` e `server_name _;` no bloco `server` do Zabbix;
- `fastcgi_pass` apontando para o socket realmente criado pelo pool (confirmar em `/run/php/`);
- timezone `America/Sao_Paulo`, `memory_limit 256M`, `max_execution_time 300`, `max_input_time 300`.

Para comparar com o NODE 1 sem copiar arquivos cegamente:

```bash
sha256sum /etc/zabbix/nginx.conf /etc/zabbix/php-fpm.conf
# Execute o mesmo no NODE 1; diferenças precisam ser justificadas.
```

Ativação:

```bash
PHP_FPM_SERVICE=$(systemctl list-unit-files 'php*-fpm.service' --no-legend | awk '{print $1; exit}')
test -n "$PHP_FPM_SERVICE" || { echo 'ERRO: PHP-FPM não instalado'; exit 1; }
echo "Serviço selecionado: $PHP_FPM_SERVICE"
systemctl enable --now "$PHP_FPM_SERVICE"
systemctl restart "$PHP_FPM_SERVICE"
nginx -t && systemctl enable --now nginx && systemctl restart nginx
```

> **Não continue se `nginx -t` falhar.**

## 8. Frontend e banco compartilhado

Localize o caminho efetivo do arquivo de configuração do frontend, como no NODE 1:

```bash
find /etc/zabbix /usr/share/zabbix -name zabbix.conf.php -o -name zabbix.conf.php.example 2>/dev/null
readlink -f /usr/share/zabbix/ui/conf/zabbix.conf.php 2>/dev/null || true
```

Configure pelo **assistente web** em `http://10.31.38.61/` (ou o caminho efetivo do Nginx) com os mesmos valores do NODE 1:

| Campo | Valor |
|---|---|
| Tipo de banco | PostgreSQL |
| Host | `10.31.38.64` |
| Porta | `5432` |
| Base | `zabbix` |
| Usuário | `zabbix` |
| Senha | Digitar no assistente; não inserir no repositório |
| Nome visível | `Aeroporto HA` (igual ao NODE 1) |

O assistente **não recria** o schema; apenas grava `zabbix.conf.php`. Após salvar:

```bash
F=$(find /etc/zabbix /usr/share/zabbix -name zabbix.conf.php 2>/dev/null | head -1)
echo "$F"; ls -l "$F"
grep -nE 'ZBX_SERVER(_PORT)?\b' "$F" || echo 'OK: ZBX_SERVER/ZBX_SERVER_PORT não definidos'
```

Se `$ZBX_SERVER` ou `$ZBX_SERVER_PORT` estiverem definidos com valor, comente-os: com HA nativo, um valor fixo faz o frontend reportar "Zabbix server is not running" sempre que o nó fixado estiver em standby.

## 9. Verificação completa do NODE 2 e do cluster

No **NODE 2**:

```bash
hostname -f; ip -br addr
systemctl is-active zabbix-server zabbix-agent2 nginx "$PHP_FPM_SERVICE"
systemctl is-active apache2 || true
nginx -t
ss -lntp | grep -E ':(80|10051)\b' || true
curl -i --max-time 10 http://127.0.0.1/ | head -25
zabbix_server -R ha_status
journalctl -u zabbix-server -n 40 --no-pager
tail -n 50 /var/log/nginx/error.log
```

No **NODE 1**, confirme a visão do cluster:

```bash
zabbix_server -R ha_status
```

**Critérios de aceite:**

1. IP do NODE 2 e `NodeAddress` conferem; `HANodeName` único (`zbx-server-02`).
2. `ha_status` em ambos os nós lista `zbx-server-01` **active** e `zbx-server-02` **standby**, sem erros.
3. Versões de `zabbix-server-pgsql` idênticas nos dois nós.
4. Nginx e PHP-FPM ativos, Apache inativo/mascarado.
5. `http://10.31.38.61/` exibe login do **Zabbix** (não a página padrão do Nginx) e **não** mostra o aviso "Zabbix server is not running" — o frontend do NODE 2 deve encontrar o NODE 1 ativo pelo banco.
6. Login com o mesmo usuário em `http://10.31.38.60/` e `http://10.31.38.61/` exibe os mesmos dados.

### 9.1 Teste de failover controlado (somente em janela aprovada)

```bash
# No NODE 1:
systemctl stop zabbix-server
# No NODE 2, aguardar o failover (padrão: até ~1 min, conforme failover delay):
watch -n 5 'zabbix_server -R ha_status'
# Esperado: zbx-server-02 active, zbx-server-01 stopped.
# Retornar o NODE 1 (ele volta como standby; não há failback automático):
systemctl start zabbix-server
```

Registre horários de parada e de assunção para evidência. Não force failback desnecessário; se a política exigir o NODE 1 como ativo, faça-o em nova janela parando o NODE 2 da mesma forma.

## 10. Impacto no HAProxy (TUTORIAL_04d / 04f)

- **Porta 10051 (`backend_zabbix`):** como apenas o nó ativo escuta em 10051, o health check TCP marcará o nó standby como `DOWN`. Esse é o comportamento esperado e faz o HAProxy encaminhar só ao ativo. Ainda assim, prefira configurar agentes e proxies com **os dois endereços** (`Server=10.31.38.60,10.31.38.61` / `ServerActive=10.31.38.60;10.31.38.61`), que é o método suportado pelo Zabbix.
- **Porta 80 (`backend_zabbix_frontend`):** ambos os frontends ficam `UP`. O frontend Nginx serve na raiz `/`, e não mais em `/zabbix/`; os health checks e testes dos tutoriais 04d/04f devem ser ajustados para validar a página de login da aplicação na raiz.

## 11. Rollback do NODE 2

O NODE 2 pode ser retirado sem impacto no NODE 1:

```bash
systemctl disable --now zabbix-server
# No nó ATIVO, remover o registro do nó retirado:
# zabbix_server -R ha_remove_node=zbx-server-02
```

Para a camada web, siga a etapa 10 do TUTORIAL_04 usando o backup da etapa 2 deste tutorial.

## 12. Próxima etapa

➡️ **TUTORIAL_04d** — Backends Zabbix Server no HAProxy, seguido de **TUTORIAL_04f** — Backends do frontend, ambos considerando a etapa 10 acima.

## Fontes de validação

- Tutorial original do projeto: https://github.com/Reisvmr/aeroporto/blob/main/scripts/automated-install/phase-2-ha/TUTORIAL_04c-zabbix-server-node2.md
- Zabbix 7.0 — Alta disponibilidade: https://www.zabbix.com/documentation/7.0/en/manual/concepts/server/ha
- Zabbix 7.0 — Controle em tempo de execução (`ha_status`, `ha_remove_node`): https://www.zabbix.com/documentation/7.0/en/manual/concepts/server#runtime-control
- Zabbix 7.0 — Instalação do frontend: https://www.zabbix.com/documentation/7.0/en/manual/installation/frontend
- Zabbix 7.0 — Parâmetros do servidor: https://www.zabbix.com/documentation/7.0/en/manual/appendix/config/zabbix_server

> **Nota operacional:** este documento revisa a instalação, mas não substitui testes executados no ambiente. Confirme os IPs reais dos dois nós e o estado do PostgreSQL antes de aplicar os comandos.
