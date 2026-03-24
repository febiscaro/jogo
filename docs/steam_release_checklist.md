# Steam Release Checklist (Sem Audio)

## Build

1. Abrir o projeto no Godot 4.6.
2. Validar que a cena inicial eh `res://scenes/menu.tscn`.
3. Exportar preset `Windows Desktop` para `build/PintorDoMuro.exe`.
4. Rodar o executavel exportado localmente.

## Validacao de jogo

1. Tutorial completo sem erros de script.
2. Run normal:
   - contratos aparecem e iniciam
   - pintura so acontece com Clique esquerdo ou `P`
   - rolo e balde drenam/recarregam corretamente com `E`
3. Contratos multi-cor:
   - meta exige cores corretas
   - troca de cor via `1-4` e clique na paleta funciona
4. UI:
   - nenhum texto sobreposto
   - painel lateral legivel em 1280x720

## Requisitos de release

1. Atualizar `README.md` com controles finais.
2. Gerar ao menos 5 screenshots (menu, tutorial, contrato simples, contrato multi-cor, clima intenso).
3. Preencher dados da build no Steamworks:
   - nome da build
   - branch
   - notas de versao
4. Fazer smoke test no cliente Steam em maquina limpa.

## Pos-release imediato

1. Monitorar relatos de tremor de camera excessivo.
2. Coletar taxa de conclusao de tutorial.
3. Priorizar backlog de audio para update 1.
