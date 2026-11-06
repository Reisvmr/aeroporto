# TUTORIAL 04f — Frontend web Zabbix (porta 80) no HAProxy

> **Versão revisada:** 2.0 — 05/11/2026  
> **Alvo:** `vip-01` (`10.31.38.70`) e `vip-02` (`10.31.38.71`); VIP flutuante planejado `10.31.38.72` (confirmar com `ip -br addr` no MASTER)  
> **Backends:** frontend Nginx em `zbx-server-01` (`10.31.38.60:80`) e `zbx-server-02` (`10.31.38.61:80`)  
> **Pré-requisito:** TUTORIAL_04 e 04c v2.0 concluídos, com o assistente web finalizado nos **dois** nós  
> **Objetivo:** publicar o frontend web pelo VIP com health check que valide a aplicação.

## 0. Alterações importantes em relação ao tutorial original

- O frontend agora é servido pelo Nginx **na raiz `/`**, não em `/zabbix/`. O health check antigo (`GET /zabbix/`) retornaria 404 e marcaria os dois nós como `DOWN`.
- Existem **duas versões** do `haproxy.cfg` no projeto: o TUTORIAL_03 cria `backend_zabbix` com `zabbix_01/02` em `.60/.61:80`; o script `03-vip-haproxy-keepalived.sh` cria `backend_zabbix_frontend` com `zbx_fe_01/02` em `.62/.63:80` (servidores dedicados já eliminados). Os `sed` do tutorial anterior só funcionavam em uma combinação que não existia. Esta versão inspeciona o arquivo real e substitui o bloco inteiro.
- O health check exige **HTTP 200 em `/index.php`**: um nó com assistente não concluído (302 para `setup.php`) ou com erro PHP fica `DOWN`.
- As sessões do Zabbix 7.0 ficam no banco; o balanceamento não exige afinidade de sessão. A afinidade por cookie é mantida apenas para reduzir trocas de nó durante a navegação.
- Removidos os comandos com a credencial do stats web e as referências a logs do Apache.

## 1. Pré-requisitos e pontos de parada

Em **cada nó Zabbix**, a página precisa responder 200 com o Zabbix (não a página padrão do Nginx):

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1/index.php
curl -s http://127.0.0.1/index.php | grep -o '<title>[^<]*</title>'
```

**PARE** se algum nó retornar `302` (assistente não concluído), `404`/`502` (Nginx/PHP-FPM) ou um título que não seja do Zabbix.

A partir de **cada VIP**, confirme o alcance aos dois nós:

```bash
for ip in 10.31.38.60 10.31.38.61; do
  printf '%s: ' "$ip"; curl -s -o /dev/null -w '%{http_code}\n' --max-time 5 "http://$ip/index.php"
done
```

## 2. Inspecionar o `haproxy.cfg` real (vip-01 e vip-02)

```bash
hostname; ip -br addr | grep -E '10\.31\.38\.7[0-4]' || true
haproxy -v | head -1
grep -nE '^\s*(frontend|backend|listen)\b|zabbix|zbx_|httpchk' /etc/haproxy/haproxy.cfg
sha256sum /etc/haproxy/haproxy.cfg
```

Anote o **nome do backend** usado pelo `frontend zabbix_front` (`default_backend ...`): `backend_zabbix` ou `backend_zabbix_frontend`. Se os dois VIPs tiverem `sha256sum` diferentes, alinhe-os antes de continuar.

## 3. Backup

```bash
cp -a /etc/haproxy/haproxy.cfg "/etc/haproxy/haproxy.cfg.bak-04f-$(date +%Y%m%d-%H%M%S)"
```

## 4. Substituir o bloco do backend web

Edite o arquivo:

```bash
nano /etc/haproxy/haproxy.cfg
```

Substitua **o bloco inteiro** do backend identificado na etapa 2 (da linha `backend ...` até a última linha `server ...` dele) por este, **mantendo o nome encontrado** (exemplo com `backend_zabbix`):

```haproxy
backend backend_zabbix
    balance roundrobin
    cookie ZBXNODE insert indirect nocache httponly
    option httpchk
    http-check send meth GET uri /index.php ver HTTP/1.1 hdr Host zabbix.aeroporto.local
    http-check expect status 200
    default-server check inter 5s fall 3 rise 2
    server zabbix_01 10.31.38.60:80 cookie n1
    server zabbix_02 10.31.38.61:80 cookie n2
```

Não altere o `frontend zabbix_front` nem os blocos de Grafana/AWX. Se o frontend tiver `acl is_zabbix path_beg /zabbix` com `use_backend`, ele pode permanecer: o `default_backend` continua enviando `/` ao mesmo backend.

Valide e recarregue, **primeiro no BACKUP (vip-02) e depois no MASTER (vip-01)**:

```bash
haproxy -c -f /etc/haproxy/haproxy.cfg && systemctl reload haproxy
systemctl status haproxy --no-pager -l | head -15
```

Se `haproxy -c` falhar, **não recarregue**: restaure o backup da etapa 3.

## 5. Validação

Nos VIPs (troque o nome do backend se for `backend_zabbix_frontend`):

```bash
echo 'show servers state backend_zabbix' | socat /run/haproxy/admin.sock stdio
echo 'show stat' | socat /run/haproxy/admin.sock stdio | awk -F, '$1=="backend_zabbix"{print $2, $18, $37}'
```

De uma estação na rede:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://10.31.38.72/index.php
for i in 1 2 3 4; do curl -s -D - -o /dev/null http://10.31.38.72/index.php | grep -i '^set-cookie: ZBXNODE'; done
```

**Critérios de aceite:**

1. Os dois servidores `UP` (`L7OK/200`) em vip-01 **e** vip-02.
2. `http://10.31.38.72/` abre a tela de login do Zabbix, sem o aviso "Zabbix server is not running".
3. Requisições sem cookie alternam entre `ZBXNODE=n1` e `n2`.
4. Teste de nó: `systemctl stop nginx` em um zbx-server → o backend dele fica `DOWN` em ≈15 s e o acesso pelo VIP continua; `systemctl start nginx` → volta a `UP`. Faça em janela aprovada.
5. Failover do HAProxy (TUTORIAL_03): parar o `keepalived` no MASTER move o VIP para o BACKUP e o login continua acessível.

## 6. Primeiro acesso

1. Acesse `http://10.31.38.72/`.
2. Se ainda for o primeiro login, **troque imediatamente** a senha padrão do usuário `Admin` (*User settings → Profile → Change password*).
3. Configure o fuso em *Administration → General → GUI* se necessário.

## 7. Monitoramento contínuo

```bash
# Nos VIPs
journalctl -u haproxy -f
watch -n 10 "echo 'show servers state backend_zabbix' | socat /run/haproxy/admin.sock stdio"
# Nos nós Zabbix
tail -f /var/log/nginx/access.log /var/log/nginx/error.log
```

## 8. Rollback

```bash
cp -a /etc/haproxy/haproxy.cfg.bak-04f-<timestamp> /etc/haproxy/haproxy.cfg
haproxy -c -f /etc/haproxy/haproxy.cfg && systemctl reload haproxy
```

## 9. Próximos passos

1. ➡️ **TUTORIAL_05** — Grafana HA. O data source Zabbix deve usar `http://10.31.38.72/api_jsonrpc.php` (raiz, sem `/zabbix/`).
2. Atualizar o TUTORIAL_03 e o script `03-vip-haproxy-keepalived.sh` para gerar este bloco diretamente, eliminando a divergência descrita na etapa 0.

## Fontes de validação

- Tutorial original do projeto: https://github.com/Reisvmr/aeroporto/blob/main/scripts/automated-install/phase-2-ha/TUTORIAL_04f-haproxy-zabbix-frontend-backends.md
- Zabbix 7.0 — Instalação do frontend: https://www.zabbix.com/documentation/7.0/en/manual/installation/frontend
- HAProxy — Configuration Manual (`http-check send`, `http-check expect`, `cookie`): https://docs.haproxy.org/

> **Nota operacional:** este documento revisa o procedimento, mas não substitui testes executados no ambiente.
