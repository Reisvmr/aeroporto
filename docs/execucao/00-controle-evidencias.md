# 00 - Controle, Evidencias e Status Report

## Objetivo

Padronizar como a execucao tecnica sera controlada, evidenciada e comunicada durante o projeto.

## Pre-Requisitos

- Repositorio Git do projeto disponivel.
- Planilha `docs/cliente/Checklist_Cliente_Pre_Requisitos_Projeto_Aeroporto.xlsx` atualizada.
- Responsaveis do cliente definidos.
- Canal oficial de comunicacao definido.
- Periodicidade de status report acordada.

## Passo a Passo

### 1. Criar estrutura de evidencias

1. Criar uma pasta por semana de projeto.
2. Dentro de cada semana, separar evidencias por frente:
   - `inventario`
   - `infraestrutura`
   - `zabbix`
   - `postgresql`
   - `awx`
   - `grafana`
   - `rede`
   - `treinamento`
3. Nomear evidencias com data, frente e descricao curta.

Padrao sugerido:

```text
YYYY-MM-DD_fase_atividade_descricao.ext
2026-08-24_zabbix_instalacao_server_healthcheck.png
2026-09-08_restore_teste_postgresql_evidencia.pdf
```

### 2. Controlar status das atividades

1. Atualizar status em uma das opcoes:
   - `Pendente`
   - `Em andamento`
   - `Concluido`
   - `Nao aplicavel`
2. Registrar responsavel.
3. Registrar data alvo.
4. Registrar bloqueios e dependencia do cliente.
5. Nunca marcar como concluido sem evidencia.

### 3. Criar status report semanal

O status report deve conter:

- Atividades concluidas na semana.
- Atividades em andamento.
- Pendencias do cliente.
- Riscos novos ou agravados.
- Decisoes necessarias.
- Plano da proxima semana.
- Impacto no cronograma de 6 semanas.

### 4. Controlar decisoes

Toda decisao tecnica deve registrar:

- Tema.
- Opcao escolhida.
- Aprovador.
- Data.
- Impacto.
- Evidencia da aprovacao.

Exemplos de decisoes:

- Confirmacao da retencao de 180 dias.
- Obrigatoriedade ou nao do AWX standby.
- Padrao SNMPv2c ou SNMPv3.
- Criacao de VLAN dedicada de monitoramento.
- Uso de Telnet em ativos legados.

## Evidencias Minimas

- Planilha de checklist atualizada.
- Ata ou e-mail de decisao.
- Prints de configuracao.
- Logs de execucao AWX.
- Exports do Zabbix/Grafana.
- Arquivos versionados no Git.

## Criterios de Aceite

- Existe trilha de evidencia por fase.
- Status report semanal emitido.
- Pendencias do cliente registradas.
- Decisoes tecnicas rastreaveis.
- Backlog de excecoes atualizado.

## Riscos

| Risco | Mitigacao |
|---|---|
| Evidencias espalhadas | Centralizar no repositorio ou pasta oficial do projeto |
| Decisoes verbais sem registro | Formalizar por e-mail, ata ou status report |
| Atividade marcada como concluida sem validacao | Exigir evidencia antes do aceite |
| Pendencias do cliente sem dono | Registrar responsavel e prazo |
