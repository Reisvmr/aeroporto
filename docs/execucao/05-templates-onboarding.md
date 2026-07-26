# 05 - Templates, Discovery, Alertas e Onboarding

## Objetivo

Padronizar o monitoramento dos 676 ativos por meio de templates, discovery, triggers, tags, macros e onboarding em ondas controladas.

## Atividades Cobertas

- Classificacao dos ativos.
- Selecao ou criacao de templates.
- LLD.
- Triggers.
- Severidades.
- Tags.
- Macros.
- Piloto.
- Ondas de onboarding.

## Pre-Requisitos

- Inventario validado.
- Zabbix operacional.
- AWX operacional.
- Credenciais SNMP/agente/API disponiveis.
- Portas liberadas.
- Piloto definido.

## Passo a Passo Tecnico

### 1. Classificar ativos

1. Separar por tipo:
   - Switch.
   - Roteador.
   - Firewall.
   - Camera.
   - Controladora.
   - Storage.
   - Servidor Linux.
   - Servidor Windows.
2. Separar por fabricante/modelo.
3. Separar por criticidade.
4. Separar por metodo de coleta.
5. Identificar excecoes.

### 2. Definir padrao de nomenclatura

Padronizar:

- Nome do host.
- Grupo do host.
- Tags.
- Macros.
- Nome de templates.
- Nome de triggers.
- Severidades.

Exemplo de tags:

```text
site=<localidade>
tipo=<rede|camera|storage|servidor>
criticidade=<critico|alto|medio|baixo>
ambiente=<producao|homologacao>
```

### 3. Selecionar templates

1. Usar templates nativos do Zabbix quando atenderem.
2. Avaliar templates de fabricante quando necessario.
3. Evitar duplicidade de itens.
4. Padronizar intervalos:
   - Itens criticos: 1 minuto.
   - Itens informativos: 5 minutos.
5. Ajustar retencao conforme politica de 180 dias.

### 4. Configurar discovery

1. Definir regras LLD por tecnologia.
2. Validar discovery de interfaces.
3. Validar discovery de discos/volumes.
4. Validar discovery de sensores.
5. Ajustar filtros para reduzir ruido.
6. Definir override por criticidade quando aplicavel.

### 5. Configurar triggers

1. Definir severidades.
2. Evitar triggers duplicadas.
3. Criar dependencias de trigger.
4. Ajustar thresholds por criticidade.
5. Evitar alarmes em interfaces administrativas/desativadas.
6. Definir janelas de manutencao.

### 6. Executar piloto

1. Selecionar 20 a 30 ativos.
2. Cadastrar via AWX/Zabbix API.
3. Associar templates.
4. Validar coleta.
5. Monitorar por periodo acordado.
6. Ajustar triggers.
7. Validar dashboards basicos.
8. Registrar aceite do piloto.

### 7. Executar ondas

Onda 1:

- Ativos mais padronizados.
- Baixa complexidade.
- Acessos ja validados.

Onda 2:

- Ativos por localidade ou criticidade.
- Tecnologias ja ajustadas no piloto.

Onda 3:

- Saldo do escopo.
- Excecoes tratadas ou formalizadas.

### 8. Tratar excecoes

Excecao deve registrar:

- Ativo.
- Motivo.
- Impacto.
- Responsavel.
- Acao necessaria.
- Prazo.
- Se bloqueia ou nao o aceite.

## Evidencias Minimas

- Export dos templates.
- Lista de hosts cadastrados.
- Print de coleta recente.
- Print de latest data.
- Print de triggers calibradas.
- Log AWX de onboarding.
- Lista de excecoes.

## Rollback

1. Desabilitar host ou template.
2. Remover template recem-aplicado, se gerou ruido.
3. Reverter macro/threshold.
4. Retornar host para estado anterior.
5. Registrar causa do rollback.

## Criterios de Aceite

- Piloto aprovado.
- Templates padronizados.
- Hosts cadastrados por onda.
- Coleta validada.
- Ruido critico tratado.
- Excecoes formalizadas.
