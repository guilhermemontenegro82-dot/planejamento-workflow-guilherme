# Skill — Limpeza semanal de e-mail e boletos

Backup e **fonte da verdade** da rotina semanal de organização da caixa de e-mail +
download de boletos. Trazida do Cowork em 30/08/2026.

## Arquivos

| Arquivo | O que é |
|---|---|
| `limpeza-semanal-inbox-boletos.md` | A skill em si — Parte 1: limpeza/arquivamento da inbox por categoria. Parte 2: identificar boletos, aplicar label, baixar e renomear o PDF. Parte 3: relatório final |

Conta usada: Gmail (o Yahoo encaminha automaticamente para lá, então organizar o Gmail
cobre os dois).

## ⚠️ Duas pastas ligadas a esta skill não podem ser movidas

| Pasta | Por quê |
|---|---|
| `D:\12- Claude - works\E-Mails - G-Mail e Yahoo\Boletos` | Destino dos PDFs de boleto — caminho escrito dentro da skill |
| `D:\12- Claude - works\Scheduled\limpeza-semanal-inbox-boletos\` | Onde o agendador procura a skill para a execução automática semanal |

As duas ficam fora do Git (boletos têm CPF/CNPJ e valores). O que está versionado aqui
é só a **definição** da skill.

**Atenção**: a cópia em `Scheduled/` é a que o agendador executa. Se esta aqui for
alterada, o texto precisa ser atualizado nos dois lugares — aqui (fonte da verdade,
versionada) e lá (o que roda toda semana).

## Como alterar

Edita o `.md` aqui → atualiza no Cowork **e** na cópia de `Scheduled/`. Nunca editar
direto no Cowork (ver `CLAUDE.md`, seção "Regra crítica: nunca editar direto no
Cowork").
