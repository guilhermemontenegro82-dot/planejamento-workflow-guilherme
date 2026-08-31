# Dados dos Funcionários MEI

**Pasta raiz:** `D:\12- Claude - works\Darf MEI Equipe\`  
**Bash mount:** `/sessions/zealous-kind-goodall/mnt/Darf MEI Equipe/`

---

## Tabela de funcionários

| Apelido | Nome completo (pasta) | CNPJ | Pasta DARF | Caminho completo do DARF |
|---------|----------------------|------|------------|--------------------------|
| Anderson | Anderson Reis | 35.504.685/0001-98 | `Darf - MEI` | `Anderson Reis/Darf - MEI/` |
| Cabelo | Carlos César | 46.526.151/0001-89 | `Darf - MEI` | `Carlos César/Darf - MEI/` |
| Grande | Cleilson Borges | 49.478.898/0001-05 | `Darf - MEI` | `Cleilson Borges/Darf - MEI/` |
| Gaguinho | Fransueli Albuquerque | 59.977.647/0001-10 | `DARF MEI` | `Fransueli Albuquerque/DARF MEI/` |
| Jonathan | Jonathan Catroffe | 58.142.203/0001-00 | `Darf - MEI` | `Jonathan Catroffe/Darf - MEI/` |
| Leandro | Leandro Gonçalves | 59.366.804/0001-51 | `Darf - Mei` | `Leandro Gonçalves/Darf - Mei/` |
| Matheus | Matheus Lyrio | 65.994.654/0001-23 | `DARF - MEI` | `Matheus Lyrio/DARF - MEI/` |
| Mauricio | Maurício Tiburcio | 14.246.137/0001-35 | `DARF - MEI` | `Maurício Tiburcio/DARF - MEI/` |
| Rogerio | Rogério José da Silva | 59.381.040/0001-73 | `Darf- Mei` | `Rogério José da Silva/Darf- Mei/` |

> ⚠️ **Atenção:** Os nomes das subpastas DARF variam (maiúsculas, espaços, hífens). Use exatamente como indicado acima.

---

## Arrays bash prontos para uso

```bash
# CNPJs sem formatação (para login no PGMEI)
declare -A CNPJ=(
  [Anderson]="35504685000198"
  [Cabelo]="46526151000189"
  [Grande]="49478898000105"
  [Gaguinho]="59977647000110"
  [Jonathan]="58142203000100"
  [Leandro]="59366804000151"
  [Matheus]="65994654000123"
  [Mauricio]="14246137000135"
  [Rogerio]="59381040000173"
)

# Caminhos relativos das pastas DARF (a partir da pasta raiz)
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

# Apelidos em minúsculas (para nomes de arquivo)
declare -A APELIDO=(
  [Anderson]="anderson"
  [Cabelo]="cabelo"
  [Grande]="grande"
  [Gaguinho]="gaguinho"
  [Jonathan]="jonathan"
  [Leandro]="leandro"
  [Matheus]="matheus"
  [Mauricio]="mauricio"
  [Rogerio]="rogerio"
)
```

---

## Convenção de nomes de arquivo

| Tipo | Padrão | Exemplo |
|------|--------|---------|
| DAS PDF | `Darf [Apelido].pdf` | `Darf Anderson.pdf` |
| Comprovante | `comprovante mei - [apelido].[ext]` | `comprovante mei - anderson.jpg` |

---

## Convenção de pasta mensal

Formato: `YY-MM - MêsPortuguês`

| Mês | Pasta |
|-----|-------|
| Janeiro | `26-01 - Janeiro` |
| Fevereiro | `26-02 - Fevereiro` |
| Março | `26-03 - Março` |
| Abril | `26-04 - Abril` |
| Maio | `26-05 - Maio` |
| Junho | `26-06 - Junho` |
| Julho | `26-07 - Julho` |
| Agosto | `26-08 - Agosto` |
| Setembro | `26-09 - Setembro` |
| Outubro | `26-10 - Outubro` |
| Novembro | `26-11 - Novembro` |
| Dezembro | `26-12 - Dezembro` |

> O ano (`YY`) deve ser ajustado conforme o ano em vigor.
