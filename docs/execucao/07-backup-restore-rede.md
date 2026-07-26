# 07 - Backup, Restore, VLANs, ACLs e QoS

## Objetivo

Implementar rotinas de backup e restore da plataforma e executar automacoes de rede com validacao, evidencia e rollback.

## Atividades Cobertas

- Backup PostgreSQL.
- Backup Zabbix.
- Backup Grafana.
- Backup AWX.
- Backup de configuracoes de rede.
- Teste de restore.
- VLANs.
- ACLs.
- QoS.
- Validacoes pre e pos-mudanca.

## Pre-Requisitos

- Plataforma instalada.
- AWX operacional.
- Credenciais seguras disponiveis.
- Repositorio ou destino de backup definido.
- Janelas de mudanca aprovadas.
- Aprovadores de rede definidos.
- Plano de rollback aprovado.

## Passo a Passo Tecnico

### 1. Definir politica de backup

1. Definir o que sera salvo.
2. Definir periodicidade.
3. Definir retencao.
4. Definir destino.
5. Definir responsavel.
6. Definir teste periodico de restore.

Itens minimos:

- Banco PostgreSQL.
- Arquivos de configuracao Zabbix.
- Exports de templates.
- Dashboards Grafana.
- Configuracao AWX.
- Playbooks Git.
- Configuracoes de rede, quando permitido.

### 2. Implementar backup PostgreSQL

1. Criar rotina de backup logico.
2. Validar permissao do usuario.
3. Executar backup manual inicial.
4. Validar tamanho do arquivo.
5. Validar integridade.
6. Agendar rotina.

### 3. Implementar backup Zabbix

1. Exportar templates.
2. Exportar configuracoes relevantes.
3. Salvar arquivos de configuracao.
4. Documentar versoes.

### 4. Implementar backup Grafana

1. Exportar dashboards JSON.
2. Salvar configuracao de datasource.
3. Salvar plugins instalados.
4. Registrar versao.

### 5. Implementar backup AWX

1. Salvar projetos no Git.
2. Exportar inventarios, quando aplicavel.
3. Registrar credentials sem expor segredos.
4. Salvar definicoes de job templates e workflows.

### 6. Testar restore

1. Definir ambiente de teste.
2. Restaurar backup do banco.
3. Restaurar configuracoes.
4. Validar acesso.
5. Validar dados.
6. Registrar evidencia.
7. Atualizar runbook com tempo de recuperacao.

### 7. Automacoes de rede

Antes de qualquer mudanca:

1. Confirmar janela.
2. Confirmar aprovador.
3. Confirmar lista de ativos.
4. Fazer backup pre-mudanca.
5. Validar conectividade.
6. Executar mudanca em lote pequeno.
7. Validar pos-mudanca.
8. Expandir ou reverter.

### 8. VLANs

1. Confirmar VLAN ID.
2. Confirmar nome.
3. Confirmar switches afetados.
4. Confirmar trunk/access.
5. Aplicar em piloto.
6. Validar estado.

### 9. ACLs

1. Confirmar origem.
2. Confirmar destino.
3. Confirmar porta/protocolo.
4. Confirmar sentido.
5. Aplicar com comentario padronizado.
6. Validar trafego.
7. Registrar antes/depois.

### 10. QoS

1. Confirmar politica.
2. Confirmar classes.
3. Confirmar interfaces.
4. Aplicar em piloto.
5. Validar counters.
6. Documentar impacto.

## Evidencias Minimas

- Log de backup executado.
- Arquivo de backup gerado.
- Evidencia de restore.
- Logs AWX.
- Backup pre-mudanca de rede.
- Configuracao antes/depois.
- Resultado de validacao pos-mudanca.

## Rollback

Rollback de plataforma:

1. Parar servicos afetados.
2. Restaurar backup.
3. Validar integridade.
4. Subir servicos.
5. Validar aplicacao.

Rollback de rede:

1. Aplicar configuracao anterior.
2. Validar conectividade.
3. Confirmar retorno do servico.
4. Registrar evidencias.

## Criterios de Aceite

- Backups agendados.
- Restore testado.
- Runbook atualizado.
- Automacoes de rede com rollback.
- Evidencias registradas.
