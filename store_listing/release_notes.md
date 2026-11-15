# Notas da versão (Play Console > "O que há de novo", máx. 500 caracteres por idioma)

## 1.1.0 (versionCode 14) — versão atual

### Português (pt-BR)
<pt-BR>
🔥 Nova era elemental! 5 elementos: Fogo, Água, Vento, Raio e Terra.

• Atravesse blocos elementais e dispare 25 combos: a ordem importa!
• Botão de especial: cada acerto enche o anel; escolha o poder e solte
• Especiais animados: Linha de Fogo, Maré, Rajada, Descarga e Impacto
• Transmutação: escolha o elemento das bolas e troque 1× por turno
• Novos power-ups, status nos blocos e Codex de combos
• Missões diárias novas e ícone novo
</pt-BR>

### English (en-US)
<en-US>
🔥 A new elemental era! 5 elements: Fire, Water, Wind, Lightning and Earth.

• Pass through elemental blocks and trigger 25 combos: order matters!
• Special button: every hit fills the ring; pick your power and unleash it
• Animated specials: Fire Line, Tide, Gust, Discharge and Impact
• Transmutation: choose your balls' element and swap it once per turn
• New power-ups, block status effects and a combo Codex
• New daily missions and a new icon
</en-US>

### Español (es-419)
<es-419>
🔥 ¡Una nueva era elemental! 5 elementos: Fuego, Agua, Viento, Rayo y Tierra.

• Atraviesa bloques elementales y dispara 25 combos: ¡el orden importa!
• Botón de especial: cada golpe llena el anillo; elige el poder y suéltalo
• Especiales animados: Línea de Fuego, Marea, Ráfaga, Descarga e Impacto
• Transmutación: elige el elemento de las bolas y cámbialo 1× por turno
• Nuevos power-ups, estados en bloques y Códice de combos
• Misiones diarias nuevas e ícono nuevo
</es-419>

### Français (fr-FR)
<fr-FR>
🔥 Une nouvelle ère élémentaire ! 5 éléments : Feu, Eau, Vent, Foudre et Terre.

• Traversez les blocs élémentaires et déclenchez 25 combos : l'ordre compte !
• Bouton spécial : chaque coup remplit l'anneau ; choisissez et lâchez
• Spéciaux animés : Ligne de feu, Marée, Rafale, Décharge et Impact
• Transmutation : choisissez l'élément des balles et changez-le 1× par tour
• Nouveaux power-ups, statuts sur les blocs et Codex des combos
• Nouvelles missions quotidiennes et nouvelle icône
</fr-FR>

---

## 1.1.0 (versionCode 13) — build anterior, não publicado com estas novidades

### Português (pt-BR)
<pt-BR>
🔥 Nova era elemental! Agora são 5 elementos: Fogo, Água, Vento, Raio e Terra.

• Atravesse blocos elementais para absorver o elemento da bola
• 25 combinações: a ordem importa! Fogo×Água é Ácido, Água×Fogo é Vapor
• Codex para descobrir todos os combos
• Especiais para evoluir: Linha de Fogo, Maré, Rajada, Descarga e Impacto
• Novos power-ups: portais, buraco negro, muralha, ímã e mais
• Status nos blocos: chamas, gelo, lama e vapor
</pt-BR>

### English (en-US)
<en-US>
🔥 A new elemental era! Now with 5 elements: Fire, Water, Wind, Lightning and Earth.

• Pass through elemental blocks to absorb their element
• 25 combos: order matters! Fire×Water is Acid, Water×Fire is Steam
• Codex to discover every combo
• Upgradeable specials: Fire Line, Tide, Gust, Discharge and Impact
• New power-ups: portals, black hole, wall, magnet and more
• Block status effects: burning, frozen, mud and steam
</en-US>

### Español (es-419)
<es-419>
🔥 ¡Una nueva era elemental! Ahora con 5 elementos: Fuego, Agua, Viento, Rayo y Tierra.

• Atraviesa bloques elementales para absorber su elemento
• 25 combinaciones: ¡el orden importa! Fuego×Agua es Ácido, Agua×Fuego es Vapor
• Códice para descubrir todos los combos
• Especiales mejorables: Línea de Fuego, Marea, Ráfaga, Descarga e Impacto
• Nuevos power-ups: portales, agujero negro, muralla, imán y más
• Estados en bloques: llamas, hielo, lodo y vapor
</es-419>

### Français (fr-FR)
<fr-FR>
🔥 Une nouvelle ère élémentaire ! 5 éléments : Feu, Eau, Vent, Foudre et Terre.

• Traversez les blocs élémentaires pour absorber leur élément
• 25 combos : l'ordre compte ! Feu×Eau donne Acide, Eau×Feu donne Vapeur
• Codex pour découvrir tous les combos
• Spéciaux évolutifs : Ligne de feu, Marée, Rafale, Décharge et Impact
• Nouveaux power-ups : portails, trou noir, muraille, aimant et plus
• Statuts sur les blocs : feu, gel, boue et vapeur
</fr-FR>

## Alterações técnicas (internas, não vão para a loja)

- Sistema de elementos reescrito: o triângulo de vantagem e o seletor de elemento saíram; Fogo+/Água+/Vento+ viram níveis dos especiais automaticamente no primeiro load (ninguém perde ouro).
- Novos rewarded: "Especial agora" e "Escolher elemento" (1× por partida cada) e "Dobrar moedas" no game over.
- Tutorial com 7 slides (combos, status e especiais).
- Ícone oficial novo (`assets/icons/icon.png`, adaptativo) e `store_listing/icon_512.png` para a ficha da loja.
- Toolchain Android: Gradle 9.5.0, AGP 9.1.1 e `compilerOptions` no `app/build.gradle.kts` (exigência do Flutter 3.50).
