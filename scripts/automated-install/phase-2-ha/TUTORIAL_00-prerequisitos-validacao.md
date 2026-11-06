# Tutorial 00 — Pré-requisitos

**Escopo:** Todos os hosts antes de qualquer instalação  
**Origem:** [TUTORIAL_00-prerequisitos-validacao.md](https://github.com/Reisvmr/aeroporto/blob/main/scripts/automated-install/phase-2-ha/TUTORIAL_00-prerequisitos-validacao.md)

> **Revisão documental — 05/11/2026.** O arquivo original permanece inalterado. Esta versão é um roteiro de revisão operacional, **não uma confirmação de que o cluster foi instalado ou testado**. Antes de alterar serviços, valide endereços, distribuição, pacotes, interfaces e arquivos ativos. Os scripts `.sh` da pasta original **não foram corrigidos** e não devem ser executados automaticamente apenas porque este documento foi revisado.

## Regras de segurança

- Não copie senhas para o histórico do Bash, URL, terminal de prints ou repositório.
- Faça backup de configurações antes de qualquer alteração; em PostgreSQL, confirme recuperação por backup.
- Não execute `rm -rf` em diretórios de dados, promoção de standby, reinício de VIP ou testes disruptivos fora de janela aprovada.
- Diferencie **validação de configuração** de **evidência de funcionamento real**.
- Faça alterações em um nó por vez e registre o estado inicial e final.

## Validação (sem mudanças)

```bash
hostname -f; hostname -I; cat /etc/os-release
df -hT; free -h; nproc; ip -br address; ip route
for host in 10.31.38.64 10.31.38.65 10.31.38.60 10.31.38.61 10.31.38.70 10.31.38.71; do timeout 2 bash -c "</dev/tcp/$host/22" 2>/dev/null && echo "$host SSH OK" || echo "$host SSH INDISPONIVEL"; done
curl --head --max-time 8 https://repo.zabbix.com/ || true
curl --head --max-time 8 https://apt.postgresql.org/ || true
```

`curl` não prova disponibilidade de todos os pacotes nem conectividade funcional do aplicativo. Execute `apt-cache policy <pacote>` após confirmar que os repositórios estão configurados. Não execute `apt upgrade -y` durante simples preflight; atualização requer janela e plano de rollback. Documente divergências entre IP esperado e IP real.
