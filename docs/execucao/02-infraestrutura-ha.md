# 02 - Infraestrutura, Rede Base e Alta Disponibilidade

## Objetivo

Provisionar e validar a infraestrutura base da solucao em arquitetura de alta disponibilidade, com VMs, IPs, DNS, NTP, storage, rede, VIP e conectividade entre camadas.

## Atividades Cobertas

- Provisionamento das VMs.
- Validacao de sizing.
- Configuracao de rede.
- DNS e NTP.
- VIP flutuante.
- Keepalived/Proxy.
- Validacao de latencia.
- Preparacao para instalacao dos componentes.

## Pre-Requisitos

- Enderecamento IP definido.
- VMs provisionadas.
- VLAN/sub-rede definida.
- Gateway e rotas liberados.
- DNS e NTP disponiveis.
- Storage NVMe para PostgreSQL.
- Credenciais de administracao das VMs.

## Sizing de Referencia

| VM | Funcao | Minimo |
|---|---|---|
| zbx-server-01 | Zabbix Server ativo | 8 vCPU / 24 GB RAM / 120 GB SSD |
| zbx-server-02 | Zabbix Server standby | 8 vCPU / 24 GB RAM / 120 GB SSD |
| zbx-fe-01 | Frontend ativo | 2 vCPU / 8 GB RAM / 40 GB SSD |
| zbx-fe-02 | Frontend standby | 2 vCPU / 8 GB RAM / 40 GB SSD |
| pg-01 | PostgreSQL Primary | 20 vCPU / 96 GB RAM / 800 GB-1 TB NVMe |
| pg-02 | PostgreSQL Replica | 20 vCPU / 96 GB RAM / 800 GB-1 TB NVMe |
| grafana-01 | Grafana ativo | 2 vCPU / 8 GB RAM / 50 GB SSD |
| grafana-02 | Grafana standby | 2 vCPU / 8 GB RAM / 50 GB SSD |
| awx-01 | AWX ativo | 4 vCPU / 16 GB RAM / 150 GB SSD |
| awx-02 | AWX standby opcional | 4 vCPU / 16 GB RAM / 150 GB SSD |
| vip-01 | Keepalived + Proxy ativo | 2 vCPU / 4 GB RAM / 30 GB SSD |
| vip-02 | Keepalived + Proxy standby | 2 vCPU / 4 GB RAM / 30 GB SSD |

## Passo a Passo Tecnico

### 1. Validar VMs

Para cada VM:

1. Confirmar hostname.
2. Confirmar IP.
3. Confirmar mascara/CIDR.
4. Confirmar gateway.
5. Confirmar DNS.
6. Confirmar NTP.
7. Confirmar CPU.
8. Confirmar RAM.
9. Confirmar disco.
10. Confirmar tipo de storage.

### 2. Validar conectividade basica

Em cada VM:

1. Testar ping para gateway.
2. Testar resolucao DNS.
3. Testar sincronismo NTP.
4. Testar conectividade com demais VMs.
5. Testar conectividade com redes dos ativos monitorados.
6. Testar saida para repositorios, se permitido.

### 3. Validar storage do PostgreSQL

1. Confirmar que `pg-01` e `pg-02` usam NVMe.
2. Confirmar capacidade util de 800 GB a 1 TB.
3. Confirmar disco separado para dados, se definido.
4. Confirmar que o disco nao e compartilhado indevidamente entre Primary e Replica.
5. Registrar evidencia de capacidade e tipo de disco.

### 4. Preparar VIP

1. Confirmar IPs dos VIPs.
2. Confirmar se os VIPs ficam na mesma sub-rede das interfaces.
3. Confirmar permissao de ARP/VRRP na rede.
4. Configurar Keepalived nos pares `vip-01` e `vip-02`.
5. Configurar prioridade ativo/standby.
6. Validar failover manual.
7. Validar retorno controlado.

### 5. Preparar proxy HTTP/HTTPS

1. Definir se sera HAProxy, Nginx ou outro padrao do cliente.
2. Criar backends para:
   - Zabbix Frontend.
   - Grafana.
   - AWX.
3. Configurar certificados TLS.
4. Validar acesso via URL/FQDN.
5. Registrar evidencias.

### 6. Validar latencia entre aplicacao e banco

1. Testar latencia de `zbx-server-01` para `pg-01`.
2. Testar latencia de `zbx-server-02` para `pg-02`.
3. Testar latencia de frontend para banco.
4. Confirmar latencia inferior a 5 ms.

## Evidencias Minimas

- Lista de VMs provisionadas.
- Prints ou exports de CPU/RAM/disco.
- Evidencia de storage NVMe.
- Planilha de enderecamento IP preenchida.
- Teste de DNS.
- Teste de NTP.
- Teste de conectividade entre VMs.
- Teste de failover do VIP.

## Rollback

Rollback de infraestrutura normalmente significa:

1. Reverter alteracoes de VIP.
2. Remover rotas ou regras adicionadas incorretamente.
3. Restaurar configuracao anterior de proxy.
4. Desligar servico com falha.
5. Retornar o VIP para o no ativo original.

## Criterios de Aceite

- Todas as VMs acessiveis.
- Sizing validado.
- PostgreSQL com NVMe.
- DNS e NTP funcionando.
- VIP configurado.
- Failover validado.
- Latencia aplicacao/banco dentro do limite.

## Riscos e Mitigacoes

| Risco | Mitigacao |
|---|---|
| VMs com recursos abaixo do sizing | Bloquear instalacao produtiva ate ajuste ou aceite formal de excecao |
| PostgreSQL sem NVMe | Nao aceitar ambiente produtivo |
| VIP bloqueado pela rede | Envolver equipe de rede para liberar VRRP/ARP |
| DNS indefinido | Usar temporariamente hosts local apenas para teste, nao para aceite |
