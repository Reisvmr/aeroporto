# 💾 TUTORIAL — Validação de Partições
> **Script:** `00-validar-particoes-padrao.sh`  
> **Objetivo:** Verificar se a estrutura de partições segue o padrão documentado  
> **Executar em:** Cada servidor antes da instalação  
> **Uso:** `sudo ./00-validar-particoes-padrao.sh <tipo_servidor>`

---

## 📋 Estrutura de partições esperada por tipo

| Tipo               | Partição        | Tamanho mínimo |
|--------------------|-----------------|----------------|
| postgresql-primary | /var/lib/pgsql  | 475 GB         |
| postgresql-primary | /pgwal          | 75 GB          |
| postgresql-primary | /pgarchive      | 50 GB          |
| postgresql-primary | /var/log        | 10 GB          |
| zabbix-server      | /var            | 100 GB         |
| grafana            | /var            | 50 GB          |
| awx                | /opt            | 100 GB         |
| vip                | /var            | 20 GB          |

---

## Passo 1 — Verificar partições atuais

```bash
# Ver todas as partições montadas
df -h

# Ver estrutura de discos
lsblk

# Ver detalhes de montagem
mount | grep -v tmpfs | grep -v proc
```

---

## Passo 2 — Verificar partições críticas do PostgreSQL (em pg-01/pg-02)

```bash
# /var/lib/pgsql ou /var/lib/postgresql (dependendo da distro)
df -BG /var/lib/postgresql 2>/dev/null || df -BG /var/lib/pgsql 2>/dev/null

# /pgwal (WAL separado)
df -BG /pgwal 2>/dev/null && echo "Partição /pgwal existe" || echo "⚠️ /pgwal não existe"

# /pgarchive
df -BG /pgarchive 2>/dev/null && echo "Partição /pgarchive existe" || echo "⚠️ /pgarchive não existe"

# /var/log
df -BG /var/log
```

---

## Passo 3 — Verificar espaço livre em cada partição

```bash
# Verificação completa
df -BG | awk 'NR>1 {gsub(/G/,"",$4); if ($4+0 < 5) print "⚠️ ATENÇÃO:", $6, "apenas", $4"GB livres"; else print "✓", $6, $4"GB livres"}'
```

---

## Passo 4 — Verificar permissões dos pontos de montagem

```bash
# Pontos de montagem do PostgreSQL
ls -la /var/lib/postgresql/ 2>/dev/null || echo "/var/lib/postgresql não existe ainda"
ls -la /pgwal 2>/dev/null || echo "/pgwal não montado"
ls -la /pgarchive 2>/dev/null || echo "/pgarchive não montado"
```

---

## Passo 5 — Verificar /etc/fstab (montagens persistentes)

```bash
cat /etc/fstab
```

⚠️ **Atenção:** partições de dados devem estar no fstab para sobreviver reinicializações.

---

## Passo 6 — Executar o script de validação automática

```bash
cd /tmp/phase-2-ha
sudo chmod +x 00-validar-particoes-padrao.sh

# Detecção automática pelo hostname
sudo ./00-validar-particoes-padrao.sh

# Ou especificar manualmente
sudo ./00-validar-particoes-padrao.sh postgresql-primary
```

---

## Passo 7 — Ver log gerado

```bash
cat /tmp/validacao-particoes-*.log | tail -40
```

---

## ⚠️ Situação do pg-01 (baseline conhecida)

```
/var/lib/pgsql/16/data  → 475GB (466G livres)  ✅ OK
/pgwal                  → 75GB  (74G livres)   ✅ OK  
/pgarchive              → 50GB  (49G livres)   ✅ OK
/var/log                → 10GB  (9.7G livres)  ⚠️ CRÍTICO — monitorar mensalmente
```

> 📌 **/var/log cresce ~2-3GB/mês. Saturação estimada em 12-18 meses. Monitoramento obrigatório.**
