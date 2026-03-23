# Pintor do Muro - Roguelike de Contratos (Godot 4)

Projeto 2D em Godot 4 com loop roguelike:

- escolha 1 entre 3 contratos,
- cumpra meta de cobertura do muro enquanto gotas destroem a tinta,
- receba pagamento,
- escolha upgrade,
- avance para contratos mais perigosos ate quebrar a run.

## Como abrir

1. Abra a Godot 4.x.
2. Clique em **Import**.
3. Selecione `project.godot` desta pasta.
4. Abra e rode com `F5`.

## Controles

- `W`, `A`, `S`, `D`: mover pintor
- `1`, `2`, `3`: escolher contrato/upgrade
- `R` (ou `Enter`/`Espaco` no fim): iniciar nova run

## Sistemas principais

- Contratos com risco procedural (tempo, meta, chuva, pagamento)
- Eventos dinamicos durante o contrato (temporal, rajada, seca, frente fria)
- Economia da run (creditos por contrato)
- Upgrades de run (movimento, tinta, resistencia, payout, etc.)
- Meta progresso salvo em `user://meta_progress.json` (melhor streak e totais)

## Estrutura

- `scenes/main.tscn`: cena principal
- `scripts/game.gd`: loop roguelike de contratos
- `scripts/player.gd`: movimento, tanque e retoque
- `scripts/wall.gd`: grade de cobertura, pintura e derretimento
