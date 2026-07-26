# Projeto Aeroporto - Zabbix, Ansible AWX e Grafana

Repositório para centralizar os documentos, cronogramas e artefatos do projeto de implantação da solução de monitoramento e automação para 676 ativos.

## Objetivo

Implantar uma plataforma de monitoramento baseada em Zabbix 7.0 LTS, PostgreSQL 16, Grafana e Ansible AWX, com arquitetura em alta disponibilidade, retenção de dados de 180 dias e automação de onboarding, validação, backup, restore e mudanças de rede.

## Escopo Atual

- 676 dispositivos no escopo.
- Coleta majoritariamente via SNMP.
- Ativos contemplados: rede, câmeras, controladoras, storages e servidores.
- Retenção adotada: 180 dias.
- Volume histórico estimado: aproximadamente 316 GB úteis.
- PostgreSQL dedicado em arquitetura Primary/Replica.
- Storage NVMe obrigatório para o banco.
- Zabbix, Frontend, Grafana, AWX e VIP organizados em camadas com HA ativo/standby.

## Estrutura do Repositório

```text
docs/
  propostas/      Documentos de proposta e plano executivo.
  cronogramas/    Planilhas de cronograma, Gantt, WBS, RACI e riscos.
  referencias/    Anexos, materiais base e referências técnicas.
planejamento/     Materiais auxiliares de execução do projeto.
```

## Entregáveis Iniciais

- `docs/propostas/Proposta_Execucao_Monitoramento_676_Ativos_AWX_V3_Disponibilidade.docx`
- `docs/cronogramas/Cronograma_Gantt_Monitoramento_676_Ativos_AWX_V3_Disponibilidade.xlsx`

## Restrições de Disponibilidade

O planejamento considera a disponibilidade real do executor:

- Segunda-feira: home office, ideal para blocos técnicos profundos.
- Terça a quinta-feira: presencial, com aproximadamente 4 horas de deslocamento por dia.
- Sexta-feira: home office, ideal para execução concentrada, fechamento de pendências e status report.

Atividades críticas de arquitetura, automação, análise de erros, documentação e ajustes de templates devem ser priorizadas às segundas e sextas-feiras. Terça a quinta devem ser usadas preferencialmente para alinhamentos, validações presenciais, remoção de bloqueios e aprovações.

## Cronograma Executivo

O plano atual propõe execução comprimida em 6 semanas a partir de 15/08/2026, condicionada à disponibilidade de:

- inventário validado dos 676 ativos;
- VPN e conectividade;
- credenciais SNMP, SSH/Telnet, sistema operacional e banco;
- liberação de portas;
- VMs provisionadas conforme sizing aprovado;
- janelas para mudanças de rede;
- aprovações rápidas de arquitetura, piloto e ondas.

## Próximos Passos

1. Validar o plano V3 com a gerência.
2. Confirmar se o cronograma de 6 semanas será apresentado como meta condicionada.
3. Consolidar anexos técnicos finais na pasta `docs/referencias/`.
4. Definir branch e estratégia de versionamento dos documentos.
5. Confirmar se os arquivos devem ser commitados e enviados para o GitLab.
