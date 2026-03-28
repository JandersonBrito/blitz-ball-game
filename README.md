# Ballz Flutter

Brick-breaker com elementos, upgrades e boss fights — convertido de React/Canvas para Flutter + Flame.

## Setup

```bash
# 1. Instalar dependências
flutter pub get

# 2. Rodar no emulador/dispositivo
flutter run

# 3. Build APK (Android)
flutter build apk --release

# 4. Build IPA (iOS — requer Mac + Xcode)
flutter build ios --release
```

## Estrutura

```
lib/
├── main.dart                        # Entry point
├── models/
│   ├── element.dart                 # Elementos (fogo/água/vento/neutro) + tabela de mult.
│   └── upgrade.dart                 # Definições de upgrades e custos
├── game/
│   ├── ballz_flame_game.dart        # Game principal (Flame FlameGame)
│   ├── components/
│   │   ├── block_component.dart     # Blocos (normal, bonus, gold, boss, etc.)
│   │   └── ball_component.dart      # Bola
│   └── managers/
│       ├── game_state.dart          # Estado global (ChangeNotifier)
│       └── block_factory.dart       # Geração de rows, initBlocks, initBossStage
└── ui/
    ├── game_screen.dart             # Tela principal (Stack: Flame + overlays)
    ├── hud_overlay.dart             # HUD superior
    ├── menu_overlay.dart            # Menu entre fases (elemento + upgrades)
    ├── upgrade_screen.dart          # Tela de upgrades
    └── game_over_overlay.dart       # Game over
```

## Dependências principais

- **flame** ^1.18.0 — game loop, canvas, colisões
- **provider** ^6.1.2 — estado reativo entre Flutter widgets e Flame
- **shared_preferences** ^2.2.2 — persistência futura de save

## Mecânicas implementadas

- Sistema de elementos: Fogo 🔥 Água 💧 Vento 🌪 Neutro
- Tabela de vantagem/desvantagem elemental
- Power-ups: +1 bola (roxo), troca de elemento, triplicar (branco), ouro
- Upgrades: mira, bolas iniciais, força, crítico, Fogo+, Água+, Vento+, ricochete
- Boss a cada 5 fases (bloco 2×2 com barra de HP)
- Sistema de fases/waves com progressão
- Retorno animado das bolas em arco (Bézier quadrática)
- Linha de mira com ricochetes (upgrade)
