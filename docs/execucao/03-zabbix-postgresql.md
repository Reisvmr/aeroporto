# 03 - PostgreSQL, Zabbix Server, Frontend e Proxies

## Objetivo

Instalar e validar a base de monitoramento com PostgreSQL 16, Zabbix 7.0 LTS, frontend web, proxies e configuracoes iniciais de alta disponibilidade.

## Atividades Cobertas

- Instalacao PostgreSQL Primary/Replica.
- Configuracao de retencao.
- Instalacao Zabbix Server.
- Instalacao Zabbix Frontend.
- Instalacao de proxies.
- Configuracao inicial de usuarios e RBAC.
- Validacao de health check.

## Pre-Requisitos

- Infraestrutura validada.
- IPs, DNS e NTP configurados.
- Storage NVMe disponivel.
- Portas liberadas entre aplicacao e banco.
- Credenciais administrativas.
- Repositorios de pacotes acessiveis ou midia offline disponivel.

## Passo a Passo Tecnico

### 1. Preparar PostgreSQL Primary

1. Instalar PostgreSQL 16.x.
2. Definir diretorio de dados em storage NVMe.
3. Configurar parametros iniciais de memoria conforme sizing.
4. Criar usuario e banco do Zabbix.
5. Configurar acesso somente a partir dos componentes autorizados.
6. Habilitar logs necessarios para troubleshooting.
7. Configurar politica de backup.

### 2. Preparar PostgreSQL Replica

1. Instalar mesma versao do PostgreSQL.
2. Configurar replicacao a partir do Primary.
3. Validar sincronismo.
4. Validar atraso de replica.
5. Documentar procedimento de promocao da Replica.

### 3. Configurar retencao

1. Confirmar politica de 180 dias.
2. Ajustar parametros de historico e trends no Zabbix.
3. Confirmar impacto esperado no banco.
4. Registrar decisao.

### 4. Instalar Zabbix Server

1. Instalar pacotes do Zabbix 7.0 LTS.
2. Importar schema no banco.
3. Configurar arquivo do Zabbix Server.
4. Apontar para PostgreSQL Primary.
5. Configurar caches conforme volumetria.
6. Habilitar servico.
7. Validar logs de inicializacao.

### 5. Instalar Zabbix Frontend

1. Instalar frontend web.
2. Configurar PHP-FPM/Nginx ou Apache conforme padrao.
3. Apontar para banco Zabbix.
4. Configurar timezone.
5. Publicar via VIP/Proxy.
6. Validar login administrativo.

### 6. Configurar RBAC

1. Criar grupos de usuarios.
2. Definir perfis:
   - Administrador.
   - Operacao.
   - Visualizacao.
   - Auditoria.
3. Validar permissoes por grupo.
4. Documentar usuarios iniciais.

### 7. Instalar e registrar proxies

1. Definir segmentos ou localidades dos proxies.
2. Instalar Zabbix Proxy.
3. Configurar conexao com Zabbix Server.
4. Validar registro no frontend.
5. Validar coleta de teste via proxy.

### 8. Testar alta disponibilidade do Zabbix

1. Validar estado normal.
2. Simular parada controlada do no ativo, em janela aprovada.
3. Confirmar comportamento do standby/VIP.
4. Validar coleta apos failover.
5. Retornar ambiente ao estado normal.

## Validacoes

- Zabbix Server sem erros criticos em log.
- Frontend acessivel via HTTPS.
- Banco aceitando conexoes somente de origens autorizadas.
- Replica PostgreSQL sincronizada.
- Proxies conectados.
- Primeiro host de teste coletando.

## Evidencias Minimas

- Versoes instaladas.
- Health check do Zabbix.
- Tela de proxies conectados.
- Evidencia de replicacao PostgreSQL.
- Evidencia de acesso via VIP.
- Evidencia de login frontend.
- Export das configuracoes iniciais.

## Rollback

1. Parar servicos Zabbix.
2. Restaurar configuracao anterior.
3. Reverter alteracoes de proxy/VIP, se necessario.
4. Restaurar backup do banco, se houver alteracao destrutiva.
5. Registrar causa e acao corretiva.

## Criterios de Aceite

- PostgreSQL Primary/Replica operacional.
- Zabbix Server 7.0 LTS operacional.
- Frontend publicado via HTTPS.
- Proxies conectados.
- Retencao de 180 dias aplicada.
- HA validado ou excecao formalmente aceita.
