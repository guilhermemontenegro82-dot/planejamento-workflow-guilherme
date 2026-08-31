# Notas Técnicas – DARF MEI Equipe

Problemas encontrados em produção e como resolvê-los.

---

## 1. hCaptcha no PGMEI (crítico)

O site PGMEI usa **hCaptcha invisível**. A validação do captcha depende de como o campo CNPJ é preenchido.

### ✅ Método correto
Use a ferramenta `form_input` do Chrome MCP para preencher o campo CNPJ:

```
tool: form_input
selector: input (ou o seletor CSS do campo)
value: "35504685000198"
```

Depois, clique no botão submit via JavaScript:
```javascript
document.querySelector('button[type="submit"]').click()
```

### ❌ Método incorreto (hCaptcha falha)
```javascript
// Isso bypassa a detecção do hCaptcha e o login não funciona:
document.querySelector('input').value = '35504685000198';
document.querySelector('form').submit();
```

### Por que funciona?
O `form_input` dispara eventos nativos do DOM (input, change, keypress) que o hCaptcha usa para detectar interação humana. Setar `value` diretamente via JS não dispara esses eventos.

---

## 2. Gerenciamento de sessão

Ao fazer login sequencial de vários funcionários, a sessão anterior precisa ser encerrada corretamente.

### Procedimento entre logins
1. Após baixar o DAS do funcionário atual, acesse:
   ```
   https://www8.receita.fazenda.gov.br/SimplesNacional/Aplicacoes/ATSPO/pgmei.app/home/sair
   ```
2. Aguarde a confirmação de logout.
3. Só então inicie o login do próximo funcionário na URL de Identificação.

Pular esse passo pode causar redirecionamentos ou manter dados do funcionário anterior em cache.

---

## 3. Race condition no carregamento de página

Após o submit do login, a sessão leva alguns milissegundos para ser estabelecida. Se navegar para `/emissao` antes da página Home carregar, o site redireciona de volta para `/Identificacao`.

### Solução
Após o submit do login, **confirme que a página inicial carregou** antes de navegar para emissão:

```
1. Chamar get_page_text
2. Verificar se o texto contém "Início" ou "Home" ou botão de emissão
3. Só então navegar para /emissao
```

Nunca use `window.location.href = '/emissao'` no mesmo batch da submissão do formulário.

---

## 4. Limitação de rate do Chrome MCP

A ferramenta `find` do Chrome MCP pode retornar erro de rate limit em sessões longas (processamento de vários funcionários em sequência).

### Solução
Substitua chamadas à ferramenta `find` por JavaScript direto:
```javascript
// Em vez de usar find para localizar um input:
document.querySelector('input').value  // para ler
// ou form_input para preencher
```

---

## 5. Extração do código de barras dos PDFs

Os DAS baixados são PDFs que contêm o código de barras no formato `07.08.26180.XXXXXXX-X`.

### Extração via bash
```bash
pdftotext "caminho/Darf Anderson.pdf" - | grep "07\.08\."
```

Isso retorna linhas como:
```
07.08.26180.8794381-3
07.08.26180.8794381-3
```
(aparece duas vezes no PDF – é normal)

### Conversão para comparar com o Identificador PIX

Remova pontos e traço: `07.08.26180.8794381-3` → `07082618087943813`

O **Identificador** do comprovante PIX começa com esses mesmos 17 dígitos.

---

## 6. Correspondência comprovante ↔ funcionário

O campo **Identificador** no comprovante Inter Empresas contém o código de barras do DAS como prefixo.

### Processo de matching
1. Extrair Identificador de cada imagem de comprovante (via `Read` da imagem)
2. Extrair código de barras de cada DAS PDF (via `pdftotext`)
3. Converter ambos para string numérica sem separadores
4. Verificar se o Identificador **começa com** o código do DAS

### Exemplo real (Julho/2026)
```
Anderson DAS:    07.08.26180.8794381-3  →  07082618087943813
Identificador:   07082618087943813098954180  →  começa com 07082618087943813 ✅
```

---

## 7. Verificação de competência "Liquidado"

Antes de gerar o DAS, verifique se o período selecionado mostra **"A Vencer"**.

- **"A Vencer"** → gerar normalmente
- **"Liquidado"** → o pagamento deste período já foi feito. Selecione o **próximo mês** e alerte o usuário:
  > "⚠️ O período [mês] já está liquidado para [funcionário]. Gerei o DAS para [próximo mês] em seu lugar."

---

## 8. URL base do PGMEI

```
Identificação:  https://www8.receita.fazenda.gov.br/SimplesNacional/Aplicacoes/ATSPO/pgmei.app/Identificacao
Home:           https://www8.receita.fazenda.gov.br/SimplesNacional/Aplicacoes/ATSPO/pgmei.app/home
Emissão:        https://www8.receita.fazenda.gov.br/SimplesNacional/Aplicacoes/ATSPO/pgmei.app/emissao
Sair:           https://www8.receita.fazenda.gov.br/SimplesNacional/Aplicacoes/ATSPO/pgmei.app/home/sair
```
