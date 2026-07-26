# 06 - Grafana, Dashboards, Topologia, Relatorios e SLA

## Objetivo

Entregar visibilidade executiva e operacional por meio de dashboards Grafana, topologia funcional, relatorios em CSV/Excel e indicadores de disponibilidade/SLA.

## Atividades Cobertas

- Integracao Grafana com Zabbix API.
- Dashboards executivos.
- Dashboards operacionais.
- Topologia funcional.
- Relatorios.
- Indicadores de SLA.

## Pre-Requisitos

- Zabbix operacional.
- Hosts e grupos padronizados.
- Tags e criticidades aplicadas.
- API do Zabbix acessivel.
- Grafana instalado.
- Usuarios e permissoes definidos.

## Passo a Passo Tecnico

### 1. Configurar datasource Zabbix

1. Instalar plugin Zabbix, se necessario.
2. Criar datasource apontando para Zabbix API.
3. Configurar credencial de leitura.
4. Testar conexao.
5. Validar retorno de grupos, hosts e itens.

### 2. Definir padrao de dashboards

Separar dashboards por publico:

- Executivo.
- Operacao.
- Rede.
- Servidores.
- Cameras/controladoras.
- Storage.
- SLA/disponibilidade.

### 3. Criar dashboard executivo

Indicadores recomendados:

- Total de ativos monitorados.
- Ativos indisponiveis.
- Eventos por severidade.
- Top 10 ativos com mais eventos.
- Disponibilidade por localidade.
- Status das ondas.
- Excecoes pendentes.

### 4. Criar dashboards operacionais

Indicadores recomendados:

- CPU.
- Memoria.
- Trafego de interfaces.
- Status de portas.
- Disponibilidade ICMP.
- Sensores.
- Latencia.
- Eventos recentes.

### 5. Criar topologia funcional

1. Identificar localidades.
2. Identificar grupos de ativos.
3. Associar links ou dependencias conhecidas.
4. Montar mapa no Zabbix ou ferramenta acordada.
5. Validar com equipe de rede.

### 6. Criar relatorios

Relatorios minimos:

- Relatorio de ativos monitorados.
- Relatorio de excecoes.
- Relatorio de disponibilidade.
- Relatorio de eventos por severidade.
- Relatorio de progresso de onboarding.

Formatos:

- CSV.
- Excel.
- PDF, se solicitado.

### 7. Validar SLA

1. Confirmar formula de disponibilidade.
2. Confirmar janela de medicao.
3. Confirmar excecoes planejadas.
4. Confirmar horario comercial ou 24x7.
5. Validar com cliente.

## Evidencias Minimas

- Print do datasource conectado.
- Prints dos dashboards.
- Export JSON dos dashboards.
- Relatorio de exemplo.
- Topologia validada.
- Registro da regra de SLA.

## Rollback

1. Reverter versao anterior do dashboard.
2. Desabilitar painel com consulta pesada.
3. Ajustar intervalo de refresh.
4. Corrigir datasource ou credencial.

## Criterios de Aceite

- Grafana acessivel.
- Datasource Zabbix conectado.
- Dashboards publicados.
- Relatorios gerados.
- Topologia funcional validada.
- SLA definido e documentado.
