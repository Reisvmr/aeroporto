# Projeto Aeroporto - Monitoramento HA & Automação

Repositório para centralizar documentos, cronogramas, scripts, runbooks e artefatos do projeto de implantação da solução de monitoramento e automação para **676 ativos** com **arquitetura em alta disponibilidade (HA)**.

---

## 🎯 Objetivo

Implantar uma plataforma completa de monitoramento e automação baseada em:
- **Zabbix 7.0 LTS** - Server em HA nativo (2 nós) com frontend Nginx em cada nó
- **PostgreSQL 16** - Replicação streaming (Primary/Replica)
- **Grafana** - Visualização em 2 nós
- **Ansible AWX** - Automação em 2 nós com Docker
- **HAProxy + Keepalived** - Publicação das aplicações via VIP com failover automático
- **Sistema operacional:** Ubuntu 26.04 LTS (*resolute*)
- **Retenção de dados:** 180 dias
- **Volume estimado:** ~316 GB úteis

---

## 📦 Estrutura do Repositório

```
aeroporto/
├── README.md                              ← este arquivo
├── PLANO_REFATORACAO_HA.md                ← plano original da Fase 2 HA (histórico, 24/10/2026)
├── README_HA_ANALISE.md                   ← análise técnica original da Fase 2 HA (histórico)
├── SCRIPTS_AWX_GRAFANA_CONCLUIDO.md       ← relatório de entrega dos scripts AWX/Grafana (histórico)
├── SCRIPTS_INSTALACAO_RESUMO.md           ← resumo dos scripts da Fase 1 (histórico)
├── SETUP_PROCEDURES_README.md             ← índice dos procedimentos de setup da Fase 1
│
├── docs/
│   ├── cliente/                           ← checklists, inventário de equipamentos, análise dos 676 ativos
│   ├── cronogramas/                       ← Gantt
│   ├── execucao/                          ← runbooks por fase, controle de evidências, plano por servidor
│   ├── instalacao/                        ← matriz de análise da arquitetura (Fase 1)
│   ├── planejamento/                      ← análise de trabalho remanescente
│   ├── propostas/                         ← proposta de execução
│   ├── validacao/                         ← relatórios de validação dos servidores
│   └── *.md                               ← guias de Grafana, Docker e scripts interativos
│
├── scripts/
│   ├── check-server-*.sh, run-check*.sh   ← validação de servidores (v1.0, v1.1 IMPROVED, v2.0)
│   ├── check-hardware-*.sh                ← validação de hardware AWX/Grafana
│   ├── setup-prerequisites.sh, validate-access.{sh,py}
│   └── automated-install/
│       ├── 01..05-*.sh, validate-*.sh     ← instalação Fase 1 (servidor único)
│       ├── common/, config/, docs/        ← funções, exemplo de ambiente, guias da Fase 1
│       └── phase-2-ha/                    ← ⭐ Fase 2 HA: tutoriais TUTORIAL_*.md e scripts 00..09
│
├── awx_automacoes/
│   ├── inventories/                       ← inventários por tipo de ativo e por cluster HA
│   └── playbooks/                         ← playbooks 01, 03, 04, 06, 07
│
└── zabbix_templates/                      ← templates YAML por tipo de ativo
```

---

## 🏗️ Arquitetura Fase 2 HA

| Camada | Servidores | Endereço de acesso |
|---|---|---|
| Banco | pg-01 `10.31.38.64` (primary), pg-02 `10.31.38.65` (replica) | `10.31.38.64:5432` (VIP-DB `10.31.38.75` proposto — TUTORIAL_02b) |
| Zabbix Server + Frontend | zbx-server-01 `10.31.38.60`, zbx-server-02 `10.31.38.61` | Web: VIP `10.31.38.72` |
| Grafana | grafana-01 `10.31.38.66`, grafana-02 `10.31.38.67` | VIP `10.31.38.73:3000` |
| AWX | awx-01 `10.31.38.68`, awx-02 `10.31.38.69` | VIP `10.31.38.74:8080` |
| Load balancer | vip-01 `10.31.38.70` (master), vip-02 `10.31.38.71` (backup) | HAProxy + Keepalived |

Rede: `10.31.38.0/25`, gateway `10.31.38.1`, VLAN 338.

O Zabbix Server usa o **HA nativo** (`HANodeName`/`NodeAddress`): um nó *active*, outro *standby*, coordenados pelo banco. Os servidores dedicados de frontend (`zbx-fe-01/02`, `10.31.38.62/63`) foram **eliminados**; o frontend roda em cada zbx-server.

---

## 🚀 Como instalar - Fase 2 HA

Siga os tutoriais na ordem indicada em [`scripts/automated-install/phase-2-ha/README.md`](./scripts/automated-install/phase-2-ha/README.md#-roteiro-atual-tutoriais-revisados):

1. `TUTORIAL_00` — pré-requisitos e partições (todos os servidores)
2. `TUTORIAL_01` / `TUTORIAL_02` — PostgreSQL primary e replica (`TUTORIAL_02b` opcional: VIP do banco)
3. `TUTORIAL_03` — HAProxy + Keepalived
4. `TUTORIAL_04` / `TUTORIAL_04c` — Zabbix Server + frontend nos dois nós; `TUTORIAL_04d` / `TUTORIAL_04f` — publicação no HAProxy
5. `TUTORIAL_05` — Grafana; `TUTORIAL_06` — AWX
6. `TUTORIAL_07` e `TUTORIAL_08-09` — validação e testes de failover

> ⚠️ Os tutoriais são a referência. Os scripts `.sh` do Zabbix (`04-zabbix-server-ha.sh`, `04b-zabbix-frontend-ha.sh`) e o `03-vip-haproxy-keepalived.sh` ainda refletem a arquitetura anterior (Apache, frontend em `10.31.38.62/63`) e não devem ser executados sem revisão.

---

## 🔗 Acessos (após instalação)

| Serviço | URL |
|---|---|
| Zabbix Frontend | `http://10.31.38.72/` (via HAProxy, após TUTORIAL_04f) |
| Grafana | `http://10.31.38.73:3000` |
| AWX | `http://10.31.38.74:8080` |
| PostgreSQL | `10.31.38.64:5432` |

Troque as senhas padrão (Zabbix `Admin`, Grafana `admin`, AWX `admin`) no primeiro acesso.

---

## 🔐 Segurança & Credenciais

- Não versione senhas reais. Os tutoriais revisados leem senhas sem eco e testam antes de gravar.
- **Atenção:** alguns scripts e tutoriais antigos ainda trazem valores padrão que precisam ser trocados antes do uso em produção — por exemplo `REPLICATION_PASS:-repl123` (TUTORIAL_01/02), `stats auth admin:haproxy@stats` e `auth_pass aeroporto_ha` (TUTORIAL_03).
- Use um gerenciador de segredos para as credenciais reais.

---

## 📋 Evidências e controle

O padrão de evidências, status report e registro de decisões está em [`docs/execucao/00-controle-evidencias.md`](./docs/execucao/00-controle-evidencias.md); os runbooks por fase estão em [`docs/execucao/`](./docs/execucao/README.md).

---

**Repositório:** https://github.com/Reisvmr/aeroporto.git  
**Última atualização:** 06/11/2026  
**Autor:** Vinicius Reis <reisvmr@gmail.com>

---

## 📝 Licença

Todos os scripts são fornecidos AS-IS para uso interno no Projeto Aeroporto.
