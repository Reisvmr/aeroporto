# 04 - AWX, Git e Automacao

## Objetivo

Implantar e configurar o AWX como plataforma de automacao, governanca e rastreabilidade para execucao de playbooks Ansible no projeto.

## Atividades Cobertas

- Instalacao ou validacao do AWX.
- Integracao com Git.
- Configuracao de inventarios.
- Configuracao de credentials.
- Job templates.
- Workflows.
- Schedules.
- RBAC.
- Evidencias de execucao.

## Pre-Requisitos

- AWX provisionado.
- IP/DNS definidos.
- Certificado TLS definido.
- Acesso administrativo.
- Repositorio Git definido.
- Credenciais do cliente disponiveis por cofre ou metodo seguro.
- Conectividade do AWX com servidores, ativos de rede, Zabbix API e Grafana API.

## Passo a Passo Tecnico

### 1. Validar AWX

1. Acessar interface web via HTTPS.
2. Validar versao.
3. Validar estado dos pods/servicos, se em Kubernetes.
4. Validar storage para projetos, logs e artefatos.
5. Validar usuarios administradores.

### 2. Configurar organizacao e RBAC

1. Criar organizacao do projeto.
2. Criar times:
   - Administradores.
   - Operadores.
   - Auditores.
3. Associar usuarios.
4. Definir permissoes por time.

### 3. Integrar Git

1. Criar projeto AWX apontando para o repositorio Git.
2. Configurar credencial de acesso ao Git.
3. Sincronizar projeto.
4. Validar que playbooks e roles aparecem no AWX.
5. Ativar atualizacao no lancamento do job, se aplicavel.

### 4. Criar inventarios

Inventarios recomendados:

- `inventario_zabbix`
- `inventario_linux`
- `inventario_windows`
- `inventario_rede`
- `inventario_piloto`
- `inventario_producao`

Para cada inventario:

1. Criar grupos por tecnologia.
2. Criar grupos por localidade.
3. Criar variaveis de grupo.
4. Associar hosts.
5. Validar conectividade.

### 5. Configurar credentials

Tipos de credenciais:

- Machine/SSH.
- Windows/WinRM.
- Network device.
- SNMP, preferencialmente via variaveis protegidas.
- Zabbix API.
- Grafana API.
- Banco/backup, se aplicavel.

Regra: nao gravar senhas em arquivos do Git.

### 6. Criar job templates

Templates minimos:

- Validar conectividade.
- Coletar inventario.
- Instalar Zabbix Agent Linux.
- Instalar Zabbix Agent Windows.
- Configurar SNMP.
- Registrar host via Zabbix API.
- Associar templates.
- Validar coleta.
- Backup de configuracao.
- Restore controlado.
- Validacao de VLAN/ACL/QoS.

### 7. Criar workflows

Workflow de onboarding de servidor:

1. Validar acesso.
2. Coletar inventario.
3. Instalar agente.
4. Aplicar configuracao.
5. Registrar no Zabbix.
6. Associar template.
7. Validar coleta.

Workflow de rede:

1. Validar SSH/SNMP.
2. Coletar modelo e versao.
3. Fazer backup pre-mudanca.
4. Configurar SNMP ou validar configuracao.
5. Registrar no Zabbix.
6. Associar template.
7. Validar coleta.

Workflow de mudanca:

1. Backup pre-mudanca.
2. Validacao de pre-requisitos.
3. Aplicacao.
4. Validacao pos-mudanca.
5. Rollback se falhar.

### 8. Definir limites de execucao

1. Nunca executar em todos os 676 ativos sem piloto.
2. Usar lotes pequenos no inicio.
3. Usar serializacao.
4. Monitorar falhas por grupo.
5. Pausar onda se taxa de erro superar limite definido.

## Evidencias Minimas

- Projeto Git sincronizado no AWX.
- Inventarios criados.
- Credentials cadastradas.
- Job templates criados.
- Workflow de piloto executado.
- Logs de execucao.
- Evidencia de host registrado no Zabbix por automacao.

## Rollback

1. Interromper job em execucao, se necessario.
2. Executar playbook de rollback quando existir.
3. Restaurar backup pre-mudanca.
4. Desabilitar host ou template no Zabbix se coleta gerar impacto.
5. Registrar falha e ajustar playbook antes de nova onda.

## Criterios de Aceite

- AWX acessivel via HTTPS.
- Git integrado.
- RBAC aplicado.
- Inventarios e credentials configurados.
- Workflows minimos prontos.
- Piloto executado com evidencia.
