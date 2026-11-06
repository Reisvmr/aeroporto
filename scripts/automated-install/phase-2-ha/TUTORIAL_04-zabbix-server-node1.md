# TUTORIAL 04 — Zabbix 7.0 LTS: Server HA + Frontend Nginx — NODE 1

> **Versão revisada:** 2.0 — 05/11/2026  
> **Alvo:** `zbx-server-01` — **IP planejado:** `10.31.38.60` (confirmar com `ip -br addr`, pois uma captura da conexão SSH indicava `10.31.38.61`)  
> **SO:** Ubuntu 26.04 *Resolute*  
> **Banco compartilhado:** PostgreSQL `10.31.38.64:5432`, banco `zabbix`  
> **Segundo nó previsto:** `zbx-server-02` — `10.31.38.61` (confirmar)  
> **Objetivo:** instalar ou corrigir o Zabbix Server já existente e disponibilizar frontend com **Nginx + PHP-FPM**, preparando o HA nativo do servidor Zabbix.  
> **Escopo:** NODE 1. Não configura o nó 2, VIP, HAProxy nem HA do PostgreSQL.

## 0. Alterações importantes em relação ao tutorial original

- **Apache removido da arquitetura-alvo**, mas mantido instalado e desabilitado para facilitar rollback; não se deve misturar `zabbix-apache-conf` com `zabbix-nginx-conf` como configuradores ativos.
- O Zabbix 7.0 **não utiliza `NodeID=1` para definir o HA nativo**: utilizar `HANodeName=zbx-server-01` e `NodeAddress=10.31.38.60:10051`.
- O frontend **não deve fixar** `$ZBX_SERVER` e `$ZBX_SERVER_PORT` quando o HA nativo estiver habilitado: ele consulta o banco compartilhado para descobrir o nó ativo.
- O `zabbix_server.conf` existente **não deve ser sobrescrito**. Modificações pontuais e backup antes de aplicar.
- O schema do Zabbix só pode ser importado em banco **vazio e preparado**, nunca repetidamente.
- A senha **não aparece em comandos ou no Markdown**. Ela é solicitada interativamente quando necessária. Substitua a senha fraca utilizada anteriormente e revise eventual exposição no histórico/logs.
- Evitar `apt-get upgrade -y` e remoção cega de arquivos de repositório: isso amplia o escopo e pode atualizar componentes inesperadamente.
- O health check web deve validar a **aplicação**; `HTTP 200` da página padrão Nginx não comprova sucesso.

## 1. Pré-requisitos e pontos de parada

Execute como `root` no **zbx-server-01**. Deve existir conectividade com `10.31.38.64:5432` e com `10.31.38.61:10051` conforme a política de rede. Confirme que o repositório oficial Zabbix 7.0 para `resolute` já está configurado. A instalação anterior mostrou o pacote `zabbix-frontend-php` disponível.

**PARE** e corrija a documentação/topologia se `hostname -I` não confirmar o IP atribuído ao NODE 1. Não copie um endereço errado para `NodeAddress`.

```bash
set -o pipefail
hostnamectl --static
ip -br addr
cat /etc/os-release | grep -E '^(PRETTY_NAME|VERSION_CODENAME)='
ss -lntp | grep -E ':(80|443|8080|10051)\b' || true
systemctl is-active zabbix-server apache2 nginx || true
apt-cache policy zabbix-server-pgsql zabbix-frontend-php zabbix-nginx-conf
command -v zabbix_server && zabbix_server --version | head -3
nc -vz -w 5 10.31.38.64 5432
```

Se `nc` não existir, instale `netcat-openbsd`, ou use:

```bash
timeout 5 bash -c '</dev/tcp/10.31.38.64/5432'
```

## 2. Backup completo das configurações existentes

```bash
BACKUP="/root/backup-zbx-node1-$(date +%Y%m%d-%H%M%S)"
mkdir -m 700 -p "$BACKUP"
for dir in /etc/zabbix /etc/nginx /etc/apache2 /etc/php; do
  if [ -e "$dir" ]; then cp -a "$dir" "$BACKUP/"; fi
done
printf 'Backup local: %s\n' "$BACKUP"
```

> Esse backup contempla **configuração**, não um backup consistente do banco. Em produção, confirme a existência de backup recuperável do PostgreSQL antes de qualquer importação ou atualização de schema.

## 3. Repositório e instalação de pacotes

Se o `apt-cache policy` da etapa 1 apresentar candidatos da Zabbix 7.0, **não reinstale** `zabbix-release` nem edite `noble`/`resolute` indiscriminadamente. Caso não haja candidato, interrompa o procedimento e configure o repositório oficial apropriado à distribuição.

```bash
apt-get update
apt-mark showhold
apt-get -s install nginx php-fpm php-pgsql php-bcmath php-mbstring php-gd php-xml php-ldap php-curl php-intl zabbix-frontend-php zabbix-nginx-conf
```

**Confirme que a simulação não removerá componentes importantes nem atualizará inesperadamente o Zabbix Server.** Em instalações pré-existentes, avalie o `apt-mark hold zabbix-server-pgsql` temporário se o APT quiser atualizar seu pacote.

```bash
DEBIAN_FRONTEND=noninteractive apt-get install -y nginx php-fpm php-pgsql php-bcmath php-mbstring php-gd php-xml php-ldap php-curl php-intl zabbix-frontend-php zabbix-nginx-conf
```

Se `zabbix-server-pgsql` ou `zabbix-agent2` ainda não estiverem instalados, simule e instale-os **separadamente**; não reinstale um componente já funcional por padrão:

```bash
dpkg-query -W zabbix-server-pgsql zabbix-agent2 2>/dev/null || true
# Apenas se faltar, após revisar a simulação:
# apt-get -s install zabbix-server-pgsql zabbix-agent2 zabbix-sql-scripts
# apt-get install -y zabbix-server-pgsql zabbix-agent2 zabbix-sql-scripts
```

## 4. Preservar banco de dados e verificar schema

O banco `zabbix` e seu usuário podem já ter sido criados em `pg-01`. **Não execute `CREATE DATABASE`, `CREATE USER` ou `server.sql.gz` sem confirmar a situação.** Para testar sem incluir segredo na linha de comando, use `psql` e digite a senha quando solicitado:

```bash
psql -W -h 10.31.38.64 -p 5432 -U zabbix -d zabbix \
  -c "SELECT to_regclass('public.dbversion') AS zabbix_schema;"
```

- Retorno `dbversion`: schema principal presente. **Não importar novamente**.
- Retorno vazio: investigar antes de importar; o banco pode ter schema diferente de `public` ou instalação incompleta.
- Falha de login/conexão: corrigir rede, `pg_hba.conf`, usuário ou senha no PostgreSQL.

**Apenas para uma instalação nova, com banco comprovadamente vazio, backup disponível e pacote `zabbix-sql-scripts` instalado:**

```bash
# Exemplo de procedimento manual, NÃO executar em banco já populado:
# zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | \
#   psql -W -v ON_ERROR_STOP=1 -h 10.31.38.64 -U zabbix -d zabbix
```

> `PGPASSWORD=... zcat ... | psql ...` do tutorial anterior está incorreto: a variável ficaria no processo `zcat`, não necessariamente no `psql`. A opção acima usa prompt interativo. A importação deve ser realizada uma única vez e sem interrupções, por procedimento de banco controlado.

## 5. Configurar Zabbix Server e HA nativo

### 5.1 Verificar parâmetros já ativos

```bash
CONF=/etc/zabbix/zabbix_server.conf
test -f "$CONF" || { echo 'ERRO: zabbix_server.conf ausente'; exit 1; }
grep -nE '^[[:space:]]*(DBHost|DBName|DBUser|DBPassword|HANodeName|NodeAddress|ListenPort|CacheSize|HistoryCacheSize|ValueCacheSize)=' "$CONF" \
  | sed -E 's/(DBPassword=).*/\1[OCULTO]/'
```

### 5.2 Atualizar campos pontuais com segurança

O comando abaixo atualiza entradas existentes comentadas ou não, evitando duplicar parâmetros. A senha é lida sem eco. **Não use a senha exposta anteriormente como credencial definitiva.**

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

Se retornar `SENHA REJEITADA` (`password authentication failed`), **PARE**: repita o passo A ou redefina a senha no pg-01 com `sudo -u postgres psql -c '\password zabbix'` (prompt sem eco) e volte ao passo A. Gravar uma senha não testada deixa o serviço `active` no systemd, porém preso em `database is down: reconnecting`, sem abrir a porta 10051.

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
    'HANodeName': 'zbx-server-01',
    'NodeAddress': '10.31.38.60:10051',
}
for key, val in updates.items():
    pat = re.compile(r'^\s*#?\s*' + re.escape(key) + r'\s*=.*$', re.M)
    lines = pat.findall(content)
    if lines:
        content = pat.sub('', content)
        content = content.rstrip() + '\n' + key + '=' + val + '\n'
    else:
        content = content.rstrip() + '\n' + key + '=' + val + '\n'
p.write_text(content)
PY
unset DB_PASS
chown root:zabbix "$CONF"
chmod 640 "$CONF"
```

> O comando usa o IP planejado `10.31.38.60`. **Não execute este bloco se o IP real do NODE 1 for diferente**; ajuste `NodeAddress` primeiro.

### 5.3 Performance e logging

Não atribua valores de cache ou de workers arbitrários sem medição. O parâmetro `WorkerProcesses=8` do tutorial anterior não é um parâmetro padrão válido para configurar os processos do Zabbix Server 7.0; não o utilize. Mantenha `CacheSize`, `HistoryCacheSize`, `ValueCacheSize` existentes inicialmente e ajuste após coletar indicadores de cache e carga.

```bash
# Revisão sem revelar a senha:
grep -E '^(DBHost|DBName|DBUser|HANodeName|NodeAddress|CacheSize|HistoryCacheSize|ValueCacheSize|LogFile)=' "$CONF"
# Confirmar ausência de parâmetros antigos/inválidos:
grep -nE '^\s*(NodeID|WorkerProcesses)=' "$CONF" || true
```

Caso `NodeID` ou `WorkerProcesses` estejam ativos, faça backup e remova-os **somente após identificar seu contexto**, pois o parser pode rejeitá-los.

### 5.4 Reiniciar e validar HA

```bash
systemctl enable --now zabbix-server
systemctl restart zabbix-server
systemctl status zabbix-server --no-pager -l
zabbix_server -R ha_status
journalctl -u zabbix-server -n 80 --no-pager
```

No NODE 1, antes de iniciar o NODE 2, o esperado é que o serviço entre em modo **active**, desde que o banco esteja funcional e nenhum outro nó já esteja ativo. O comando `ha_status` também registra o resultado nos logs. Nunca execute dois servidores sem seus nomes de HA exclusivos.

## 6. Migrar Apache para Nginx com rollback simples

Primeiro confirme os serviços e portas. Uma falha do Apache pode decorrer de conflito com Nginx, mas isso precisa ser verificado, não presumido:

```bash
systemctl status apache2 nginx --no-pager -l || true
ss -lntp | grep -E ':(80|443|8080)\b' || true
```

Se o plano aprovado é substituir o Apache e não houver outros sites hospedados nele:

```bash
systemctl disable --now apache2 || true
systemctl mask apache2
```

**Não desinstale o Apache nesta etapa.** Se ele hospedar outros aplicativos, faça antes um plano de migração específico.

## 7. Configurar PHP-FPM e Nginx do Zabbix

### 7.1 Verificar os arquivos e o socket instalados

```bash
php -v
systemctl list-unit-files 'php*-fpm.service'
ls -la /etc/zabbix/nginx.conf /etc/zabbix/php-fpm.conf 2>/dev/null || true
find /run/php -maxdepth 1 -type s -print 2>/dev/null || true
nginx -T 2>&1 | grep -E 'include.*zabbix|listen|server_name|fastcgi_pass' || true
```

A distribuição e versão do pacote podem instalar um pool dedicado do Zabbix e socket específico; **não presuma que o caminho é `/run/php/php8.5-fpm.sock`**. Confirme `listen` no pool e `fastcgi_pass` no Nginx.

### 7.2 Configurar frontend Nginx

```bash
nano /etc/zabbix/nginx.conf
```

No bloco `server` distribuído pelo pacote, ajuste o endpoint para porta 80 caso o backend web esteja planejado em `:80`:

```nginx
listen 80;
server_name _;
```

Preserve as demais diretivas fornecidas pelo pacote (`root`, `index`, restrições de arquivos e `location` PHP), e confira o `fastcgi_pass`. O arquivo `/etc/zabbix/nginx.conf` precisa estar incluído no Nginx, normalmente via `conf.d` ou um include explícito: valide com `nginx -T` antes de adicionar symlinks, para evitar blocos duplicados.

Se o site padrão estiver habilitado via symlink e estiver conflitando, desabilite apenas esse site:

```bash
if [ -L /etc/nginx/sites-enabled/default ]; then
  unlink /etc/nginx/sites-enabled/default
fi
```

> Para instalações com outro site web ou TLS preexistente, não altere `listen` nem desabilite o site padrão sem revisão da configuração final.

### 7.3 PHP-FPM

Se o pacote disponibilizar `/etc/zabbix/php-fpm.conf`, ajuste o pool Zabbix:

```bash
nano /etc/zabbix/php-fpm.conf
```

Garanta que o timezone esteja configurado (sem duplicar diretivas) e que o pool esteja de fato carregado pelo serviço PHP-FPM:

```ini
php_value[date.timezone] = America/Sao_Paulo
php_value[memory_limit] = 256M
php_value[max_execution_time] = 300
php_value[max_input_time] = 300
```

Verifique a versão efetiva antes de reiniciar (exemplo para PHP 8.5):

```bash
PHP_FPM_SERVICE=$(systemctl list-unit-files 'php*-fpm.service' --no-legend | awk '{print $1; exit}')
test -n "$PHP_FPM_SERVICE" || { echo 'ERRO: PHP-FPM não instalado'; exit 1; }
echo "Serviço selecionado: $PHP_FPM_SERVICE"
PHP_FPM_BIN="php-fpm${PHP_FPM_SERVICE#php}"
PHP_FPM_BIN="${PHP_FPM_BIN%-fpm.service}"
command -v "$PHP_FPM_BIN" && "$PHP_FPM_BIN" -t
systemctl enable --now "$PHP_FPM_SERVICE"
systemctl restart "$PHP_FPM_SERVICE"
nginx -t && systemctl enable --now nginx && systemctl restart nginx
```

> Se o comando de teste do PHP-FPM não resolver o binário esperado, use `command -v php-fpm8.5` e `php-fpm8.5 -t` manualmente conforme a versão instalada. **Não continue se `nginx -t` falhar.**

## 8. Frontend e banco compartilhado

O antigo caminho `/etc/zabbix/zabbix.conf.php` **não deve ser presumido**. Inspecione o caminho efetivo do pacote:

```bash
ls -ld /etc/zabbix/web /usr/share/zabbix/ui/conf /usr/share/zabbix/conf 2>/dev/null || true
find /etc/zabbix /usr/share/zabbix -name zabbix.conf.php -o -name zabbix.conf.php.example 2>/dev/null
readlink -f /usr/share/zabbix/ui/conf/zabbix.conf.php 2>/dev/null || true
```

Se o frontend já estiver configurado, **não sobrescreva** `zabbix.conf.php`. Se não estiver, acesse o assistente web do Zabbix na porta e caminho efetivos definidos em Nginx; configure:

| Campo | Valor |
|---|---|
| Tipo de banco | PostgreSQL |
| Host | `10.31.38.64` |
| Porta | `5432` |
| Base | `zabbix` |
| Usuário | `zabbix` |
| Senha | Digitar no assistente; não inserir no repositório |
| Nome visível | `Aeroporto HA` |

Se o instalador solicitar salvar manualmente o arquivo, use **o caminho que a instalação de pacotes realmente expõe** e permissões restritas ao usuário/grupo do serviço web.

**Para HA nativo:** não especifique `$ZBX_SERVER` nem `$ZBX_SERVER_PORT` no arquivo `zabbix.conf.php`; ambos devem permanecer indefinidos, para o frontend descobrir o servidor ativo na base `ha_node`.

## 9. Verificação completa do NODE 1

```bash
hostname -f; ip -br addr
systemctl is-active zabbix-server nginx "$PHP_FPM_SERVICE"
systemctl is-active apache2 || true
nginx -t
ss -lntp | grep -E ':(80|10051)\b' || true
curl -i --max-time 10 http://127.0.0.1/ | head -25
zabbix_server -R ha_status
journalctl -u zabbix-server -n 40 --no-pager
tail -n 50 /var/log/nginx/error.log
```

**Critérios de aceite:**

1. IP do NODE 1 e `NodeAddress` conferem.
2. Zabbix Server operacional e HA habilitado com `HANodeName=zbx-server-01`; o `ha_status` não aponta erros.
3. Nginx e PHP-FPM ativos, Apache inativo.
4. Porta 80 responde com **Zabbix frontend** (não a página padrão Nginx); se houver redirecionamento, siga-o e confira a página de login/assistente.
5. Banco acessível pelo processo Zabbix Server e pelo frontend; sem erros de autenticação em logs.
6. O navegador apresenta login ou assistente Zabbix; após instalação, faça o primeiro acesso e altere imediatamente credenciais padrão.
7. A configuração do frontend não fixa o endereço do servidor e, quando o NODE 2 estiver pronto, deve funcionar após failover nativo.

## 10. Rollback do componente web (se necessário)

> ⛔ **NÃO execute esta etapa como parte da instalação.** Ela desfaz as etapas 6 e 7 e derruba o frontend. Use-a somente se a validação da etapa 9 falhar na camada web e a decisão for voltar ao Apache.

Os passos abaixo restauram **somente a camada web**. Não revertem o banco nem o estado do HA:

```bash
systemctl disable --now nginx || true
# Inspecione o backup criado na etapa 2 antes de restaurar os arquivos.
systemctl unmask apache2
# Se a configuração anterior do Apache era funcional:
# systemctl enable --now apache2
```

**Atenção:** reinstalar o Apache não é necessário. Se ele já falhava antes, reabilitá-lo pode reproduzir o mesmo erro. Para restaurar configurações web, copie do backup somente os arquivos pertinentes, após comparar diferenças.

## 11. Próxima etapa

Concluída a validação do NODE 1, preparar o tutorial do `zbx-server-02` com `HANodeName=zbx-server-02` e `NodeAddress=<IP_REAL_NODE2>:10051`, usando o mesmo banco **sem importar novamente** o schema. Depois, ajustar a configuração HAProxy/Keepalived para encaminhar o **frontend** a ambos os nós, com health check que valide a aplicação e avaliação de persistência de sessão. O balanceamento HTTP não substitui o HA nativo do processo `zabbix_server`.

## Fontes de validação

- Tutorial original do projeto: https://github.com/Reisvmr/aeroporto/blob/main/scripts/automated-install/phase-2-ha/TUTORIAL_04-zabbix-server-node1.md
- Zabbix 7.0 — Alta disponibilidade: https://www.zabbix.com/documentation/7.0/en/manual/concepts/server/ha
- Zabbix 7.0 — Instalação por pacotes: https://www.zabbix.com/documentation/7.0/en/manual/installation/install_from_packages
- Zabbix 7.0 — Instalação do frontend: https://www.zabbix.com/documentation/7.0/en/manual/installation/frontend
- Zabbix 7.0 — Parâmetros do servidor: https://www.zabbix.com/documentation/7.0/en/manual/appendix/config/zabbix_server

> **Nota operacional:** este documento revisa a instalação, mas não substitui testes executados no ambiente. A configuração do PostgreSQL HA e os IPs reais dos nós precisam ser conferidos antes de aplicar os comandos.
