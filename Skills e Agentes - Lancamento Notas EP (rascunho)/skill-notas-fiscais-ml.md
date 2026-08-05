---
name: "notas-fiscais-ml"
description: "Busca, baixa e organiza as notas fiscais oficiais (NF-e) de compras do Mercado Livre marcadas como 'Pendente' na aba LANÇAMENTO da planilha de controle financeiro da EP. Roda depois de qualquer lançamento (pipeline modular ou fluxo antigo) que tenha deixado itens de ML sem número de nota. Extraída do documento 'Fluxo Completo de Notas Fiscais de Obra' (Etapas 2 e 3) em 04/08/2026 — sem alteração de lógica, só isolada como skill própria."
---

# Skill — Notas Fiscais Mercado Livre

## Papel

Skill independente, chamada depois de qualquer lançamento (pelo `supervisor-lancamento-ep` ou
pelo fluxo antigo) que tenha deixado itens com Nota = "Pendente" por serem compras do Mercado
Livre sem NF-e ainda identificada. Busca o número oficial da nota no site do ML, atualiza a
planilha e baixa o PDF para arquivo.

**Trabalha uma planilha (uma obra) por vez** — se houver itens "Pendente" em mais de uma obra,
rodar esta skill uma vez por obra, cada vez apontando pra planilha certa (mesmo motivo do
`ep-lancador-notas`: uma leitura do WhatsApp normalmente cobre várias obras).

## Pré-requisito

A extensão **Claude in Chrome** deve estar instalada e conectada. Confirme com o usuário antes
de prosseguir.

## Passo a passo

### 1. Ler pendências da planilha

```python
import openpyxl

wb = openpyxl.load_workbook("caminho/planilha.xlsx")
ws = wb["LANÇAMENTO"]

pendentes_ml = []
for row in ws.iter_rows():
    item   = row[1].value  # Col B
    descr  = row[2].value  # Col C
    fornec = row[3].value  # Col D
    nota   = row[4].value  # Col E

    if nota is None:
        continue
    if str(nota).strip().lower() == "pendente":
        fornec_str = str(fornec).lower() if fornec else ""
        if "mercado livre" in fornec_str or "ml " in fornec_str:
            pendentes_ml.append({"item": int(item), "descricao": str(descr), "row_index": row[0].row})
```

### 2. Navegar no ML e extrair orderIds

URL base: `https://myaccount.mercadolivre.com.br/my_purchases/list?page=1&filterDate=Y`

JavaScript para extrair orderIds por página:
```javascript
const articles = document.querySelectorAll('article');
const orders = [];
for (const art of articles) {
  const heading = art.querySelector('h2, h3');
  const date = heading ? heading.textContent.trim() : '';
  const links = Array.from(art.querySelectorAll('a'))
    .filter(a => a.href.includes('/my_purchases/') && a.href.includes('/status'));
  const imgEl = art.querySelector('img[alt]');
  const product = imgEl ? imgEl.getAttribute('alt') : '';
  links.forEach(l => {
    const m = l.href.match(/orderId=(\d+)/);
    if (m) orders.push({date, product: product.substring(0,60), orderId: m[1]});
  });
}
orders.map(r => r.orderId + '|' + r.date + '|' + r.product).join('\n');
```

Compare as datas dos itens pendentes com as datas das páginas para saber quais páginas verificar.

### 3. Coletar número de NF via API

```javascript
async function getNF(orderId) {
  const url = `https://www.mercadolivre.com.br/emissor/omni/api/invoices-download/sale/${orderId}/xml`;
  const r = await fetch(url, {credentials: 'include'});
  if (!r.ok) return {orderId, nNF: 'N/A', status: r.status};
  const text = await r.text();
  const match = text.match(/<nNF>(\d+)<\/nNF>/);
  return {orderId, nNF: match ? match[1] : 'N/A'};
}
```

- `nNF` = número curto (4-7 dígitos), não a chave de 44 dígitos.
- Retornou N/A com status 200 → vendedor não emitiu NF-e → gravar `S/NF` na planilha.
- Salve os resultados localmente antes de navegar para outra página (`window.__nfResults` é
  perdido ao navegar).

### 4. Match entre pedidos ML e itens da planilha

Use: data (mais confiável), descrição aproximada, valor, ordem sequencial. Ambiguidade →
pergunte ao usuário antes de gravar.

### 5. Atualizar planilha

```python
for row in ws.iter_rows():
    col_b = row[1].value
    col_e = row[4].value
    try:
        item_num = int(col_b)
    except (ValueError, TypeError):
        continue
    if item_num in nf_mapping and str(col_e).strip().lower() == "pendente":
        row[4].value = nf_mapping[item_num]

wb.save("caminho/planilha.xlsx")
```

### 6. Baixar PDFs

URL do PDF: `https://www.mercadolivre.com.br/emissor/omni/api/invoices-download/sale/{ORDER_ID}/pdf`

Navegar diretamente no Chrome, um de cada vez, aguardando 2 segundos entre cada. **Não usar
fetch+blob+click** — o Chrome bloqueia múltiplos downloads automáticos.

Arquivo salvo como: `invoice-{ORDER_ID}.pdf`

### 7. Renomear e organizar os PDFs

```python
import os, shutil

DOWNLOADS = "C:/Users/{usuario}/Downloads"
NOTAS = "caminho/para/Notas Fiscais/Notas"

os.makedirs(NOTAS, exist_ok=True)

for item, order_id in sorted(item_order_map.items()):
    src = os.path.join(DOWNLOADS, f"invoice-{order_id}.pdf")
    dst = os.path.join(NOTAS, f"{item}.pdf")

    if os.path.exists(dst):
        print(f"Item {item}: já existe, pulando")
        continue
    if os.path.exists(src):
        shutil.copy2(src, dst)  # copy2, não move (evita cross-device error)
        print(f"Item {item}: copiado → {item}.pdf")
    else:
        print(f"Item {item}: não encontrado em Downloads")
```

## Confirmação final

1. Liste os arquivos na pasta Notas e mostre ao usuário.
2. Informe quais itens foram marcados como `S/NF`.
3. Lembre o usuário: após conferir os PDFs em `Notas`, mover manualmente para `Numeradas`.

## Troubleshooting

| Problema | Solução |
|---|---|
| Chrome bloqueou downloads | Use navegação direta (passo 6), não fetch+blob |
| `shutil.move` falha | Use `shutil.copy2` |
| PDF retorna 404 | Vendedor não emitiu NF-e → marcar `S/NF` |
| Planilha com `~$*.xlsx` | Está aberta no Excel — pedir para fechar antes |
| mtime drift no commit | Reenvie com o mtime atual informado na rejeição |

## Referências técnicas

- Lista ML: `https://myaccount.mercadolivre.com.br/my_purchases/list?page=N&filterDate=Y`
- XML da NF: `https://www.mercadolivre.com.br/emissor/omni/api/invoices-download/sale/{ORDER_ID}/xml`
- PDF da NF: `https://www.mercadolivre.com.br/emissor/omni/api/invoices-download/sale/{ORDER_ID}/pdf`
- Regex nNF: `/<nNF>(\d+)<\/nNF>/`
- Filename do download: `invoice-{ORDER_ID}.pdf`

## O que ainda falta decidir

- Confirmar se o passo 7 (organizar PDF em pasta `Notas`/`Numeradas`) continua necessário do
  jeito que está, ou se cabe revisão — é a única parte do fluxo de lançamento que ainda
  baixa/arquiva arquivo físico, diferente da decisão tomada no `ep-leitor-notas` de não
  baixar nada das notas do WhatsApp. Pode ser intencional (NF-e do ML é documento fiscal
  oficial, diferente de foto de comprovante) — vale confirmar com o Guilherme antes de mexer.
