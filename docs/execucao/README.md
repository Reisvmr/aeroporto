# Documentacao de Execucao Tecnica

Este diretorio contem os runbooks operacionais do projeto Aeroporto. Cada arquivo descreve uma fase ou grupo de atividades com pre-requisitos, passo a passo tecnico, evidencias esperadas, rollback e criterios de aceite.

## Ordem Recomendada

1. `00-controle-evidencias.md` - padrao de controle, evidencias e status report.
2. `01-iniciacao-planejamento.md` - kickoff, inventario, acessos e congelamento de baseline.
3. `02-infraestrutura-ha.md` - VMs, rede, VIP, DNS, NTP, storage e HA.
4. `03-zabbix-postgresql.md` - PostgreSQL 16, Zabbix 7.0 LTS, frontend e proxies.
5. `04-awx-automacao.md` - AWX, Git, inventarios, credenciais, job templates e workflows.
6. `05-templates-onboarding.md` - templates, discovery, alertas e onboarding em ondas.
7. `06-grafana-relatorios-topologia.md` - Grafana, dashboards, topologia, relatorios e SLA.
8. `07-backup-restore-rede.md` - backup, restore, VLANs, ACLs, QoS e validacoes de rede.
9. `08-treinamento-handover-operacao.md` - treinamento, handover, operacao assistida e aceite.

## Premissas Fixas

- Escopo: 676 ativos.
- Coleta predominante: SNMP.
- Retencao: 180 dias.
- Zabbix: 7.0 LTS.
- PostgreSQL: 16.x.
- Banco dedicado em Primary/Replica.
- Storage NVMe obrigatorio para PostgreSQL.
- AWX integrado a Git e RBAC.
- Execucao preferencial em ondas, com piloto antes da expansao.

## Regra de Ouro

Nenhuma atividade tecnica deve ser considerada concluida sem evidencia minima: print, export, log, arquivo de configuracao, resultado de teste, registro no AWX, item do checklist atualizado ou aceite formal.
