# Skill — DARF MEI Equipe

Backup e **fonte da verdade** da skill de pagamento mensal do DARF MEI dos 9
funcionários contratados como MEI. Trazida do Cowork em 30/08/2026.

## Arquivos

| Arquivo | O que é |
|---|---|
| `darf-mei-equipe.md` | A skill em si — 4 fases: gerar DAS no PGMEI, organizar PDFs, organizar comprovantes PIX, sincronizar backup no OneDrive |
| `references/employees.md` | Lista dos 9 funcionários (CNPJs, apelidos, pastas) |
| `references/technical-notes.md` | Detalhes de hCaptcha, sessão e extração de PDF |
| `_pacotes-originais-cowork/` | O `.skill` original exportado do Cowork (ZIP) |

## ⚠️ A pasta de dados é separada e não pode ser movida

Os PDFs, guias e comprovantes ficam em `D:\12- Claude - works\Darf MEI Equipe\` — esse
caminho está **escrito dentro da skill**, então a pasta não pode ser movida nem
renomeada. Ela fica fora do Git de propósito (49 MB de comprovantes e guias).

O que está versionado aqui é só a **definição** da skill, não os documentos.

## Como alterar

Edita o `.md` aqui → Guilherme leva o texto para o Cowork. Nunca editar direto lá
(ver `CLAUDE.md`, seção "Regra crítica: nunca editar direto no Cowork").
