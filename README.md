# Projeto Aeroporto - Zabbix, Ansible AWX e Grafana

Repositorio para centralizar documentos, cronogramas, checklists, runbooks e artefatos do projeto de implantacao da solucao de monitoramento e automacao para 676 ativos.

## Objetivo

Implantar uma plataforma de monitoramento baseada em Zabbix 7.0 LTS, PostgreSQL 16, Grafana e Ansible AWX, com arquitetura em alta disponibilidade, retencao de dados de 180 dias e automacao de onboarding, validacao, backup, restore e mudancas de rede.

## Escopo Atual

- 676 dispositivos no escopo.
- Coleta majoritariamente via SNMP.
- Ativos contemplados: rede, cameras, controladoras, storages e servidores.
- Retencao adotada: 180 dias.
- Volume historico estimado: aproximadamente 316 GB uteis.
- PostgreSQL dedicado em arquitetura Primary/Replica.
- Storage NVMe obrigatorio para o banco.
- Zabbix, Frontend, Grafana, AWX e VIP organizados em camadas com HA ativo/standby.

## Estrutura do Repositorio

```text
docs/
  cliente/        Checklists e informacoes a serem preenchidas pelo cliente.
  cronogramas/    Planilhas de cronograma, Gantt, WBS, RACI e riscos.
  execucao/       Runbooks tecnicos passo a passo por fase/atividade.
  propostas/      Documentos de proposta e plano executivo.
  referencias/    Anexos, materiais base e referencias tecnicas.
planejamento/     Materiais auxiliares de execucao do projeto.
```

## Entregaveis Iniciais

- `docs/propostas/Proposta_Execucao_Monitoramento_676_Ativos_AWX_V3_Disponibilidade.docx`
- `docs/cronogramas/Cronograma_Gantt_Monitoramento_676_Ativos_AWX_V3_Disponibilidade.xlsx`
- `docs/cliente/Checklist_Cliente_Pre_Requisitos_Projeto_Aeroporto.xlsx`
- `docs/execucao/README.md`

## Documentacao de Execucao

Os procedimentos tecnicos detalhados estao em `docs/execucao/`:

- Controle, evidencias e status report.
- Iniciacao, planejamento e baseline.
- Infraestrutura, rede base e alta disponibilidade.
- PostgreSQL, Zabbix Server, Frontend e Proxies.
- AWX, Git e automacao.
- Templates, discovery, alertas e onboarding.
- Grafana, dashboards, topologia, relatorios e SLA.
- Backup, restore, VLANs, ACLs e QoS.
- Treinamento, handover, operacao assistida e aceite.

## Restricoes de Disponibilidade

O planejamento considera a disponibilidade real do executor:

- Segunda-feira: home office, ideal para blocos tecnicos profundos.
- Terca a quinta-feira: presencial, com aproximadamente 4 horas de deslocamento por dia.
- Sexta-feira: home office, ideal para execucao concentrada, fechamento de pendencias e status report.

Atividades criticas de arquitetura, automacao, analise de erros, documentacao e ajustes de templates devem ser priorizadas as segundas e sextas-feiras. Terca a quinta devem ser usadas preferencialmente para alinhamentos, validacoes presenciais, remocao de bloqueios e aprovacoes.

## Cronograma Executivo

O plano atual propoe execucao comprimida em 6 semanas a partir de 15/08/2026, condicionada a disponibilidade de:

- inventario validado dos 676 ativos;
- IPs das VMs e VIPs definidos;
- VPN e conectividade;
- credenciais SNMP, SSH/Telnet, sistema operacional e banco;
- liberacao de portas;
- VMs provisionadas conforme sizing aprovado;
- janelas para mudancas de rede;
- aprovacoes rapidas de arquitetura, piloto e ondas.

## Proximos Passos

1. Validar o plano V3 com a gerencia.
2. Confirmar se o cronograma de 6 semanas sera apresentado como meta condicionada.
3. Consolidar anexos tecnicos finais na pasta `docs/referencias/`.
4. Validar a planilha de pre-requisitos com o cliente.
5. Atualizar os runbooks conforme decisoes tecnicas do kickoff.
