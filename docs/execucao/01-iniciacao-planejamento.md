# 01 - Iniciacao, Planejamento e Baseline

## Objetivo

Preparar o projeto para execucao tecnica, validando escopo, inventario, acessos, arquitetura inicial, responsaveis e dependencias do cliente.

## Atividades Cobertas

- Kickoff.
- Governanca do projeto.
- Inventario baseline dos 676 ativos.
- Matriz de acessos.
- Confirmacao de premissas.
- Validacao do cronograma comprimido.
- Definicao do piloto.

## Pre-Requisitos

- Proposta tecnica aprovada.
- Anexo tecnico de infraestrutura validado.
- Cliente ciente dos pre-requisitos.
- Planilha de checklist enviada ao cliente.
- Responsaveis por rede, infraestrutura, seguranca, banco e operacao nomeados.

## Passo a Passo Tecnico

### 1. Realizar kickoff

1. Apresentar objetivo do projeto.
2. Confirmar escopo dos 676 ativos.
3. Confirmar ferramentas:
   - Zabbix 7.0 LTS.
   - PostgreSQL 16.x.
   - Grafana.
   - Ansible AWX.
4. Confirmar execucao remota via VPN.
5. Confirmar cadencia de reunioes e status report.
6. Confirmar janela de trabalho e restricoes de disponibilidade.

### 2. Validar inventario

O cliente deve entregar uma planilha contendo:

- ID do ativo.
- Hostname.
- IP.
- Tipo.
- Fabricante.
- Modelo.
- Localidade.
- Segmento ou VLAN.
- Criticidade.
- Metodo de monitoramento.
- Responsavel tecnico.

Validacoes:

1. Remover duplicidades de IP e hostname.
2. Separar ativos sem IP definido.
3. Separar ativos sem fabricante/modelo.
4. Classificar ativos por metodo de coleta:
   - SNMP.
   - Zabbix Agent.
   - API.
   - ICMP.
   - Outro.
5. Identificar tecnologias que exigem template especifico.
6. Marcar excecoes.

### 3. Validar enderecamento IP das VMs

O cliente deve definir ou disponibilizar:

- IP de cada VM.
- Mascara/CIDR.
- Gateway.
- VLAN/sub-rede.
- DNS/FQDN.
- VIPs da solucao.
- Regras de NAT/publicacao, se aplicavel.

Componentes minimos:

- `zbx-server-01`
- `zbx-server-02`
- `zbx-fe-01`
- `zbx-fe-02`
- `pg-01`
- `pg-02`
- `grafana-01`
- `grafana-02`
- `awx-01`
- `awx-02`, se aprovado
- `vip-01`
- `vip-02`
- VIP Zabbix Web
- VIP Grafana
- VIP AWX

### 4. Validar matriz de acessos

Confirmar:

- VPN.
- SNMPv2c ou SNMPv3.
- SSH para ativos de rede.
- Telnet somente se houver legado sem SSH.
- Acesso aos servidores Linux/Windows.
- Acesso administrativo ao Zabbix.
- Acesso administrativo ao Grafana.
- Acesso administrativo ao AWX.
- Acesso ao PostgreSQL.

Importante: senhas nao devem ser registradas em planilha. Usar cofre, canal seguro ou procedimento formal do cliente.

### 5. Definir piloto

Selecionar 20 a 30 ativos representativos:

- Pelo menos 1 ativo por tecnologia principal.
- Pelo menos 1 ativo por localidade critica.
- Pelo menos 1 ativo de alta criticidade.
- Pelo menos 1 ativo de rede com SNMP.
- Pelo menos 1 servidor com agente, se aplicavel.

### 6. Congelar baseline

1. Definir versao do inventario.
2. Registrar data de congelamento.
3. Separar excecoes.
4. Definir que novos ativos entram em backlog ou onda posterior.

## Evidencias Minimas

- Ata de kickoff.
- Checklist do cliente preenchido.
- Inventario baseline versionado.
- Lista do piloto.
- Matriz de acessos.
- Matriz de enderecamento IP.
- Registro das premissas aceitas.

## Criterios de Aceite

- Inventario inicial validado.
- Acessos principais encaminhados.
- IPs das VMs e VIPs definidos.
- Piloto definido.
- Cronograma de 6 semanas aceito como meta condicionada.

## Riscos e Mitigacoes

| Risco | Mitigacao |
|---|---|
| Inventario incompleto | Tratar ausentes como excecao e nao bloquear arquitetura |
| IPs das VMs nao definidos | Bloquear provisionamento e escalar como pendencia critica |
| Acesso VPN indisponivel | Executar somente planejamento ate liberacao |
| Sem credenciais SNMP | Nao iniciar piloto de coleta |
| Cliente alterar escopo apos baseline | Registrar mudanca como backlog ou aditivo |
