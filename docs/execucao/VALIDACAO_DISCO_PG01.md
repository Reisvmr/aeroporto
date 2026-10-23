# 🔍 VALIDAÇÃO DE DISCOS - SERVIDOR PG-01 (10.31.38.64)

**Data:** 23/10/2024  
**Status:** ⚠️ CRÍTICO - AÇÃO OBRIGATÓRIA ANTES DE PROSSEGUIR  
**Servidor:** pg-01 (PostgreSQL Primary - 10.31.38.64)

---

## 📊 ANÁLISE DO HARDWARE ATUAL

### Saída `lsblk` Fornecida

```
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
loop0                       7:0    0 66.8M  1 loop /snap/core24/1643
loop1                       7:1    0  1.5M  1 loop /snap/hwctl/123
loop2                       7:2    0 50.1M  1 loop /snap/snapd/27710
sda                         8:0    0 1000G  0 disk
├─sda1                      8:1    0    1M  0 part
├─sda2                      8:2    0    2G  0 part /boot
└─sda3                      8:3    0  998G  0 part
  └─ubuntu--vg-ubuntu--lv 252:0    0  100G  0 lvm  /
sr0                        11:0    1  2.7G  1 rom
```

### Saída `df -h` Fornecida

```
Filesystem                         Size  Used Avail Use% Mounted on
tmpfs                               19G  1.1M   19G   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   98G   11G   82G  12% /
tmpfs                               47G     0   47G   0% /dev/shm
...
/dev/sda2                          2.0G   98M  1.7G   6% /boot
tmpfs                              9.3G  8.0K  9.3G   1% /run/user/1000
```

---

## ❌ PROBLEMAS IDENTIFICADOS

### ⭐⭐⭐ CRÍTICO: Disco NVMe Não Detectado

| Item | Esperado (Documentação) | Realidade Atual | Status |
|------|------------------------|-----------------|--------|
| **Disco NVMe** | Obrigatório 800GB-1TB | ❌ Não existe | ❌ FALHA |
| **Montagem** | `/pgdata` com NVMe | ❌ Não montado | ❌ FALHA |
| **Tipo Storage** | NVMe (performance) | SSD/HDD sda apenas | ⚠️ ALERTA |
| **Espaço Disponível** | 800GB-1TB NVMe | 898GB em LVM não usado | ⚠️ ALERTA |
| **Separação SO/Dados** | Discos separados | Mesmo disco (LVM) | ⚠️ ALERTA |

### O Que Existe Atualmente

```
Disco físico: sda (1TB)
├─ sda1: 1M (EFI boot)
├─ sda2: 2G (Linux /boot) → Montado
└─ sda3: 998G (LVM)
   └─ ubuntu--vg-ubuntu--lv: 100G alocado (/) → Montado
      └─ 898G ainda não alocado

⚠️ NEM um disco /dev/nvme0n1 aparece em lsblk
```

### Impacto no Projeto

**PostgreSQL com retenção 180 dias (~316 GB) precisa de:**
- ✅ NVMe para I/O adequado (4K+ IOPS)
- ✅ Throughput WAL para replicação rápida (Standby)
- ✅ Latência baixa (<1ms) para queries

**SSD/HDD regular (sda) resulta em:**
- ❌ I/O lento (~500-1000 IOPS) = gargalo
- ❌ Queries lentas
- ❌ Replicação WAL travada
- ❌ Alerts/reports atrasados

---

## 🎯 AÇÕES OBRIGATÓRIAS (ESCOLHA UMA)

### ✅ OPÇÃO 1: Procurar Disco NVMe Existente (PRIMEIRO)

O disco NVMe **pode estar físicamente conectado mas não aparecendo em lsblk** ou **desapegado**.

#### Passo 1: Verificar se disco NVMe está conectado

**No servidor pg-01 (SSH), execute:**

```bash
# Listar TODOS os discos (incluindo desapegados)
lsblk -a

# Verificar drivers NVMe
lspci | grep -i nvme

# Verificar módulo NVMe carregado
sudo modprobe nvme
lsmod | grep nvme

# Listar todos os block devices
sudo dmidecode | grep -i nvme
```

**Esperado:**
- Se `lsblk -a` mostrar `/dev/nvme0n1`, `/dev/nvme1n1`, etc. → Disco existe!
- Se `lspci | grep nvme` retornar IDs NVMe → Controlador detectado

#### Passo 2: Se disco aparece mas não montado

Se você ver `/dev/nvme0n1` em `lsblk -a` mas **não está em /dev/nvme0n1p1 ou similar**:

```bash
# Verificar se já tem partição
sudo fdisk -l /dev/nvme0n1

# Listar UUIDs
sudo blkid

# Procurar mount points
findmnt
```

#### Passo 3: Se encontrou disco NVMe

Documente:
- Tamanho exato (verificar `lsblk`)
- Partições (se houver)
- Passe para **OPÇÃO 3** abaixo

---

### ⏳ OPÇÃO 2: Solicitar Disco NVMe ao Datacenter (SE NÃO ENCONTRAR)

Se após executar OPÇÃO 1 **nenhum disco NVMe aparecer**, precisa solicitar provisão:

#### Template de Solicitação ao Datacenter/Cloud

```
Solicitação: Adicionar Storage NVMe

Servidor: pg-01 (10.31.38.64)
Projeto: Aeroporto - Zabbix 7.0 LTS + PostgreSQL 16
Caso de uso: Database PostgreSQL com retenção 180 dias

Especificações:
├─ Tamanho: 800GB a 1TB (preferir 1TB para futuro)
├─ Tipo: NVMe (não SSD SATA, não HDD)
├─ Performance: Mínimo 4000+ IOPS, latência <1ms
├─ Replicação: Suportar WAL streaming
└─ Montagem: Será montado em /pgdata

Urgência: CRÍTICA (bloqueia implementação PostgreSQL)

Após provisão: confirmar via lsblk no servidor
```

#### Estimativa de Tempo

- **Solicitação → Aprovação:** 2-4 horas
- **Provisão → Disponível:** 1-24 horas (depende cloud/datacenter)
- **Total:** 4-48 horas

**AÇÃO:** Não prosseguir com setup até disco estar disponível.

---

### ✅ OPÇÃO 3: Usar Espaço LVM Existente (NÃO IDEAL - Último Recurso)

Se **não conseguir adicionar NVMe rapidamente** e **precisa começar setup agora**:

Criar volume lógico (LV) dos 898G não alocados do disco sda.

#### ⚠️ AVISOS

- ❌ **Performance será degradada** (SSD/HDD, não NVMe)
- ❌ **Não atende especificação do projeto**
- ❌ **WAL replication será lenta**
- ✅ **Mas permite testar setup funcionalmente**

#### Procedimento no Servidor pg-01

**Passo 1: Criar novo LV para PostgreSQL**

```bash
# Verificar espaço disponível em VG
sudo vgdisplay ubuntu--vg

# Criar LV de 800GB
sudo lvcreate -L 800G -n postgresql-data ubuntu--vg

# Verificar criação
sudo lvdisplay

# Esperado: /dev/ubuntu--vg/postgresql-data de 800GB
```

**Passo 2: Criar filesystem ext4**

```bash
# Formatar
sudo mkfs.ext4 /dev/ubuntu--vg/postgresql-data

# Confirmação: "done" no final
```

**Passo 3: Criar ponto de montagem e montar**

```bash
# Criar /pgdata
sudo mkdir -p /pgdata

# Montar
sudo mount /dev/ubuntu--vg/postgresql-data /pgdata

# Verificar montagem
df -h /pgdata

# Esperado: ~800G disponível
```

**Passo 4: Configurar persistência em /etc/fstab**

```bash
# Adicionar ao /etc/fstab
sudo nano /etc/fstab

# Adicionar esta linha (ao final):
/dev/ubuntu--vg/postgresql-data /pgdata ext4 defaults 0 2

# Salvar (Ctrl+O → Enter → Ctrl+X)
```

**Passo 5: Ajustar permissões**

```bash
# Mude owner para postgres (depois de instalar)
sudo chown postgres:postgres /pgdata
sudo chmod 700 /pgdata

# Por enquanto, apenas deixe pronto
sudo chmod 755 /pgdata
```

**Passo 6: Validar persistência**

```bash
# Testar reboot (opcional, se puder)
sudo reboot

# Após reboot, verificar
df -h /pgdata

# Deve estar ainda montado
```

**Resultado:**
- ✅ `/pgdata` criado e montado
- ✅ Procedimento SETUP_POSTGRESQL_PRIMARY.md continua
- ❌ Performance não ideal (avisar ao cliente)

---

## 📋 CHECKLIST - ESCOLHA UMA OPÇÃO

### ☐ OPÇÃO 1: Procurar Disco NVMe

```bash
# No servidor pg-01, execute:
lsblk -a
lspci | grep -i nvme
sudo modprobe nvme
lsmod | grep nvme
sudo blkid
findmnt

# Se encontrou /dev/nvme0n1:
lsblk /dev/nvme0n1
sudo fdisk -l /dev/nvme0n1
```

**Resultado esperado:** Disco NVMe apareça em `lsblk`

**Próximo:** OPÇÃO 3 (setup usando disco NVMe)

---

### ☐ OPÇÃO 2: Solicitar Disco NVMe

```
Enviar solicitação ao datacenter/cloud:
├─ Especificação: 800GB-1TB NVMe
├─ Urgência: CRÍTICA
└─ Aguardar: 4-48 horas

Após disponível, executar lsblk para confirmar
```

**Estimativa:** 4-48 horas

**Próximo:** Volta à OPÇÃO 1 ou OPÇÃO 3

---

### ☐ OPÇÃO 3: Usar LVM Existente (Último Recurso)

```bash
# No servidor pg-01, execute:
sudo lvcreate -L 800G -n postgresql-data ubuntu--vg
sudo mkfs.ext4 /dev/ubuntu--vg/postgresql-data
sudo mkdir -p /pgdata
sudo mount /dev/ubuntu--vg/postgresql-data /pgdata
sudo nano /etc/fstab
# Adicionar: /dev/ubuntu--vg/postgresql-data /pgdata ext4 defaults 0 2
df -h /pgdata
```

**Resultado esperado:** `/pgdata` com 800G disponível

**Próximo:** SETUP_POSTGRESQL_PRIMARY.md passo 2 (verificação NVMe)

---

## 🚨 DECISÃO FINAL

**Qual opção você escolhe?**

### ✅ Recomendação em Ordem de Prioridade

1. **OPÇÃO 1 + 3:** Procure disco NVMe (5 min), se encontrar use-o
2. **OPÇÃO 2:** Se não encontrar, solicite NVMe ao datacenter
3. **OPÇÃO 3:** Se urgência crítica e não conseguir NVMe rápido, use LVM (com avisos)

---

## 📝 Próximas Ações Após Resolver Disco

**Quando `/pgdata` estiver montado (NVMe ou LVM):**

1. Confirmar com `df -h /pgdata` que mostra ~800G disponível
2. Voltar ao **SETUP_POSTGRESQL_PRIMARY.md**
3. Continuar do **PASSO 2: PREPARAR STORAGE NVME**
4. Resto do procedimento segue normalmente

---

## 📞 Documentação de Referência

- **SETUP_POSTGRESQL_PRIMARY.md** - Passo 2 (Verificação NVMe)
- **SETUP_PROCEDURES_README.md** - Seção "CRÍTICO: NVMe Obrigatório"

---

**Status:** ⏳ AGUARDANDO SUA DECISÃO

**Qual opção você vai executar?**
