# Notas da versão (Play Console > "O que há de novo", máx. 500 caracteres por idioma)

## 1.1.0 (versionCode 13)

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
- Novos rewarded: "Especial agora" (1× por partida) e "Dobrar moedas" no game over.
- Tutorial com 7 slides (combos, status e especiais).
- Toolchain Android: Gradle 9.5.0, AGP 9.1.1 e `compilerOptions` no `app/build.gradle.kts` (exigência do Flutter 3.50).
