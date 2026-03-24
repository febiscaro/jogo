# Pintor do Muro - Roguelike de Contratos (Godot 4.6)

Jogo 2D com loop roguelike de contratos de pintura, com menu, tutorial, progressao e contratos multi-cor.

## Como abrir

1. Abra Godot 4.6+.
2. Clique em **Import**.
3. Selecione `project.godot`.
4. Rode com `F5`.

## Fluxo de jogo

1. **Menu inicial**:
   - iniciar run
   - iniciar tutorial
   - opcoes (sensibilidade, posFX, cosmetico)
2. **Run**:
   - escolha 1 de 3 contratos
   - cumpra meta de acabamento enquanto a chuva degrada o muro
   - ganhe creditos e selecione upgrades
   - continue ate quebrar a run
3. **Progressao**:
   - perfil persistente com desbloqueios cosmeticos
   - contratos especiais liberados por desempenho

## Controles

- `A/D`: mover personagem
- Mouse: apontar rolo livremente
- `Clique esquerdo` ou `P`: pintar
- `E`: recarregar no balde
- `1-4`: trocar cor
- `ESC`: pausar contrato
- `R` (em telas de fim): repetir tutorial/nova run

## Salvos

- `user://meta_progress.json`: estatisticas globais da run (streak, runs, creditos)
- `user://app_profile.json`: opcoes, cosmeticos e desbloqueios

## Export para Windows/Steam

- Preset base em `export_presets.cfg`
- Checklist de release em `docs/steam_release_checklist.md`
- Notas de publicacao em `docs/publishing_notes.md`

## Estrutura principal

- `scenes/menu.tscn`: menu principal
- `scenes/main.tscn`: gameplay
- `scripts/menu.gd`: logica de menu/opcoes/perfil
- `scripts/app_state.gd`: persistencia de perfil e progresso expandido
- `scripts/game.gd`: loop roguelike + tutorial + eventos + contratos
- `scripts/player.gd`: movimento, rolo, tinta, recarga e cosmeticos
- `scripts/wall.gd`: simulacao de cobertura, padrao de cor e degradacao

## Estado atual

- Sem audio por enquanto (intencional nesta fase).
