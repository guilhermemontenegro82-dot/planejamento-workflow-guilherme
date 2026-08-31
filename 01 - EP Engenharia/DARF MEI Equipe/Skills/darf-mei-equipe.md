---
name: darf-mei-equipe
description: >
  Skill para automatizar o pagamento mensal do DARF MEI da equipe de funcionários MEI de Guilherme.
  Cobre quatro fases: (1) acesso ao PGMEI via Chrome, geração dos guias DAS e download dos PDFs;
  (2) organização e renomeação dos PDFs baixados nas pastas corretas de cada funcionário;
  (3) identificação, renomeação e organização dos comprovantes PIX após o pagamento;
  (4) sincronização do backup para a pasta OneDrive Profissionais.
  
  Use esta skill SEMPRE que o usuário mencionar DARF MEI da equipe, pagar DARF, gerar DAS,
  guia de pagamento MEI, organizar comprovantes, atualizar backup, ou qualquer variação — mesmo sem mencionar "skill".
  
  Triggers típicos: "vamos pagar o DARF", "me ajuda com o DARF", "gerar os DAS de [mês]",
  "organizar comprovantes", "pronto, paguei", "fiz minha parte", "finalizei os pagamentos",
  "temos DARF para pagar", "preciso gerar as guias do mês", "atualizar backup", "sincronizar pasta".
---

# DARF MEI Equipe

Automação do pagamento mensal do DARF MEI dos 9 funcionários contratados como MEI.

**Pasta de trabalho:** `D:\12- Claude - works\Darf MEI Equipe\`  
**Bash mount:** `/sessions/zealous-kind-goodall/mnt/Darf MEI Equipe/`

Leia sempre `references/employees.md` para a lista completa de funcionários (CNPJs, apelidos, pastas).  
Leia `references/technical-notes.md` para detalhes críticos sobre hCaptcha, sessão e extração de PDF.

---

## Como identificar a fase atual

Ao ser acionado, determine em qual fase o usuário está:

| Situação | Fase |
|----------|------|
| Início do mês, nenhum DAS gerado ainda | **Fase A** – Gerar DAS no PGMEI |
| DAS gerados, usuário moveu os PDFs para a pasta raiz | **Fase B** – Organizar PDFs |
| Usuário pagou e jogou os comprovantes na pasta | **Fase C** – Organizar comprovantes |
| Comprovantes organizados, usuário quer atualizar backup | **Fase D** – Sincronizar backup OneDrive |

Se não estiver claro, pergunte: "Os PDFs já foram baixados? Já fizeram os pagamentos?"

---

## Fase A – Gerar os DAS no PGMEI

### 1. Determinar mês/ano alvo

Determine o mês de referência (normalmente o mês atual). O nome da pasta a criar segue o formato:  
`YY-MM - MêsPortuguês`  
Exemplo: `26-07 - Julho`

Meses em português: Janeiro, Fevereiro, Março, Abril, Maio, Junho, Julho, Agosto, Setembro, Outubro, Novembro, Dezembro.

### 2. Para cada funcionário (em sequência)

Repita os passos abaixo para todos os 9 funcionários listados em `references/employees.md`:

#### a) Login no PGMEI

```
URL: https://www8.receita.fazenda.gov.br/SimplesNacional/Aplicacoes/ATSPO/pgmei.app/Identificacao
```

Use `form_input` para preencher o campo CNPJ — **nunca** use JavaScript puro para setar o valor.  
Isso é essencial para que o hCaptcha invisível seja validado corretamente.

```javascript
// NÃO FAZER:
document.querySelector('input').value = '00000000000000';

// FAZER: usar a ferramenta form_input com o seletor e valor
// Depois clicar no botão submit via JS:
document.querySelector('button[type="submit"]').click()
```

Aguarde o carregamento da página Home/Início antes de continuar.  
**Nunca navegue para /emissao sem confirmar que a página inicial carregou** (use `get_page_text` para verificar).

#### b) Verificar competência

Na página inicial do PGMEI, clique em **"Emitir Guia de Pagamento (DAS)"**.

Na tela de emissão, verifique o período do mês alvo:
- Se aparecer **"A Vencer"** → pode gerar normalmente.
- Se aparecer **"Liquidado"** → informe o usuário e gere o mês seguinte.

#### c) Gerar e baixar o DAS

Selecione o período correto e clique em **"Apurar/Gerar DAS"**. O PDF abrirá ou será baixado automaticamente.

**Registre o número do DAS** (formato `07.08.26180.XXXXXXX-X`) — ele será necessário para cruzar com os comprovantes na Fase C.

#### d) Encerrar sessão

Acesse `/home/sair` para encerrar a sessão antes de logar o próximo funcionário. Isso evita conflitos de sessão.

### 3. Após gerar todos os DAS

Informe ao usuário: "Todos os DAS foram gerados. Mova os PDFs da pasta Downloads para a pasta raiz `Darf MEI Equipe` e me avise."

---

## Fase B – Organizar PDFs na pasta

O usuário moveu todos os PDFs baixados para a pasta raiz `D:\12- Claude - works\Darf MEI Equipe\`.

### 1. Identificar os PDFs

Liste os arquivos `.pdf` na pasta raiz. Para cada PDF, identifique a qual funcionário pertence (pelo conteúdo ou pelo nome gerado pelo PGMEI — ele geralmente contém o CNPJ).

Use `pdftotext` via bash para extrair texto se necessário:
```bash
pdftotext "arquivo.pdf" -
```

### 2. Criar pastas e mover

Para cada funcionário:
1. Crie a pasta do mês dentro do diretório DARF do funcionário (veja `references/employees.md` para o caminho exato):
   ```
   [Pasta do funcionário]/[Pasta DARF]/26-07 - Julho/
   ```
2. Renomeie o PDF para: `Darf [Apelido].pdf`
3. Mova para a pasta criada.

**Exemplo de script bash:**
```bash
BASE="/sessions/zealous-kind-goodall/mnt/Darf MEI Equipe"
MES="26-07 - Julho"

# Exemplo para Anderson:
DEST="$BASE/Anderson Reis/Darf - MEI/$MES"
mkdir -p "$DEST"
mv "$BASE/arquivo-anderson.pdf" "$DEST/Darf Anderson.pdf"
```

Use um loop com as declarações de array de `references/employees.md` para processar todos de uma vez.

---

## Fase C – Organizar comprovantes PIX

O usuário terminou os pagamentos e jogou as imagens dos comprovantes na pasta raiz.

### 1. Listar comprovantes

Liste os arquivos `.jpg` (ou `.png`) na pasta raiz.

### 2. Ler cada imagem

Para cada imagem de comprovante, leia-a com a ferramenta `Read` para visualizar o conteúdo.  
Extraia o **Identificador** do PIX (campo visível no comprovante Inter Empresas).

### 3. Cruzar com código de barras do DAS

O **Identificador PIX começa com os mesmos dígitos do código de barras do DAS** (sem pontos e traços).

**Conversão do código DAS:**  
`07.08.26180.8794381-3` → remova pontos e traço → `07082618087943813`  
O Identificador do comprovante começará com `07082618087943813...`

**Como obter os códigos DAS:**
- Se foram registrados durante a Fase A → use os valores anotados.
- Se não foram registrados → use `pdftotext` para extrair dos PDFs já organizados:
  ```bash
  pdftotext "[caminho do Darf funcionário.pdf]" - | grep "07\.08\."
  ```

Veja `references/employees.md` para os caminhos exatos dos PDFs.

### 4. Renomear e mover

Para cada comprovante identificado:
1. Renomeie para: `comprovante mei - [apelido].[ext]`  
   (apelido em minúsculas, ex: `comprovante mei - anderson.jpg`)
2. Mova para a pasta do mês do funcionário correspondente:
   ```
   [Pasta do funcionário]/[Pasta DARF]/26-07 - Julho/comprovante mei - [apelido].jpg
   ```

**Script bash de referência:**
```bash
BASE="/sessions/zealous-kind-goodall/mnt/Darf MEI Equipe"
MES="26-07 - Julho"

mv "$BASE/1783120908219.jpg" "$BASE/Anderson Reis/Darf - MEI/$MES/comprovante mei - anderson.jpg"
# ... repetir para todos
```

Monte o script completo com os resultados do cruzamento e execute de uma vez.

### 5. Verificação final

Após mover tudo, confirme que cada pasta `26-07 - Julho` contém exatamente:
- `Darf [Apelido].pdf`
- `comprovante mei - [apelido].jpg`

```bash
BASE="/sessions/zealous-kind-goodall/mnt/Darf MEI Equipe"
MES="26-07 - Julho"
find "$BASE" -path "*/$MES/*" | sort
```

Informe o usuário com um resumo de ✅ / ❌.

---

## Fase D – Sincronizar backup OneDrive

O usuário quer copiar os meses novos para a pasta de backup no OneDrive.

**Pasta de backup (destino):**  
`C:\Users\gamon\OneDrive\EP Engenharia\EP - Documentos\Contratos Efetivo\Profissionais`  
**Bash mount:** `/sessions/zealous-kind-goodall/mnt/Profissionais/`

### 1. Solicitar acesso à pasta

A pasta `Profissionais` precisa estar conectada no Cowork. Se ainda não estiver:
> "Para sincronizar o backup, preciso que você conecte a pasta `Profissionais` no Cowork (botão de pasta). Ela fica em: `C:\Users\gamon\OneDrive\EP Engenharia\EP - Documentos\Contratos Efetivo\Profissionais`."

Confirme que o mount `/sessions/zealous-kind-goodall/mnt/Profissionais/` existe antes de prosseguir:
```bash
ls "/sessions/zealous-kind-goodall/mnt/" | grep Profissionais
```

### 2. Identificar o que está faltando

Compare as pastas mensais na origem vs. destino para cada funcionário. O backup costuma estar alguns meses atrasado — copie apenas o que ainda não existe no destino.

### 3. Copiar via bash

Use o script abaixo, ajustando `MES` para os meses que faltam:

```bash
SRC="/sessions/zealous-kind-goodall/mnt/Darf MEI Equipe"
DST="/sessions/zealous-kind-goodall/mnt/Profissionais"

declare -A PASTA=(
  [Anderson]="Anderson Reis/Darf - MEI"
  [Cabelo]="Carlos César/Darf - MEI"
  [Grande]="Cleilson Borges/Darf - MEI"
  [Gaguinho]="Fransueli Albuquerque/DARF MEI"
  [Jonathan]="Jonathan Catroffe/Darf - MEI"
  [Leandro]="Leandro Gonçalves/Darf - Mei"
  [Matheus]="Matheus Lyrio/DARF - MEI"
  [Mauricio]="Maurício Tiburcio/DARF - MEI"
  [Rogerio]="Rogério José da Silva/Darf- Mei"
)

for apelido in "${!PASTA[@]}"; do
  for mes in "26-07 - Julho" "26-08 - Agosto"; do  # ajuste os meses conforme necessário
    src_path="$SRC/${PASTA[$apelido]}/$mes"
    dst_path="$DST/${PASTA[$apelido]}/$mes"
    if [ -d "$src_path" ]; then
      mkdir -p "$dst_path"
      cp -rn "$src_path/." "$dst_path/"
      echo "✅ $apelido / $mes"
    else
      echo "⚠️  $apelido / $mes — não encontrado na origem"
    fi
  done
done
```

O flag `-rn` copia recursivamente sem sobrescrever arquivos que já existam no destino.

### 4. Confirmar

Reporte ao usuário quais meses foram copiados para cada funcionário (✅ / ⚠️).

---

## Notas de comunicação

- Informe o usuário a cada conclusão de fase.
- Ao final, apresente um resumo tabular com funcionário, DAS gerado, valor, pasta organizada e comprovante arquivado.
- Se encontrar algum comprovante que não consegue identificar pelo Identificador, leia o PDF do DAS correspondente para confirmar, e se ainda assim não encontrar, avise o usuário.
