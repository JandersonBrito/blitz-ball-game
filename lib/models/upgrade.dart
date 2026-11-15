import 'package:flutter/material.dart';

class UpgradeLevel {
  final int cost;
  final double value;
  final String desc;
  const UpgradeLevel({required this.cost, required this.value, required this.desc});
}

class UpgradeDef {
  final String id;
  final String label;
  final String icon;
  final Color color;
  final String desc;
  final List<UpgradeLevel> levels;
  const UpgradeDef({
    required this.id, required this.label, required this.icon,
    required this.color, required this.desc, required this.levels,
  });
}

const List<UpgradeDef> upgradeDefs = [
  UpgradeDef(id:'aim',   label:'Mira',          icon:'◎', color:Color(0xFF378ADD), desc:'Alcance da mira',
    levels:[UpgradeLevel(cost:50,value:80,desc:'+80'),UpgradeLevel(cost:120,value:160,desc:'+160'),UpgradeLevel(cost:250,value:260,desc:'+260'),UpgradeLevel(cost:450,value:400,desc:'+400'),UpgradeLevel(cost:700,value:600,desc:'Máximo')]),
  UpgradeDef(id:'balls', label:'Bolas iniciais', icon:'●', color:Color(0xFF7F77DD), desc:'Bolas ao iniciar fase',
    levels:[UpgradeLevel(cost:80,value:2,desc:'2 bolas'),UpgradeLevel(cost:200,value:3,desc:'3 bolas'),UpgradeLevel(cost:400,value:5,desc:'5 bolas'),UpgradeLevel(cost:750,value:8,desc:'8 bolas'),UpgradeLevel(cost:1200,value:12,desc:'12 bolas')]),
  UpgradeDef(id:'power', label:'Força',          icon:'⚡', color:Color(0xFF1D9E75), desc:'Dano base por hit',
    levels:[UpgradeLevel(cost:60,value:2,desc:'2 dano'),UpgradeLevel(cost:150,value:3,desc:'3 dano'),UpgradeLevel(cost:300,value:4,desc:'4 dano'),UpgradeLevel(cost:600,value:6,desc:'6 dano'),UpgradeLevel(cost:1000,value:8,desc:'8 dano')]),
  UpgradeDef(id:'crit',  label:'Crítico',        icon:'✦', color:Color(0xFFE24B4A), desc:'Chance de dano x2',
    levels:[UpgradeLevel(cost:100,value:0.08,desc:'8%'),UpgradeLevel(cost:250,value:0.15,desc:'15%'),UpgradeLevel(cost:500,value:0.25,desc:'25%'),UpgradeLevel(cost:900,value:0.35,desc:'35%'),UpgradeLevel(cost:1500,value:0.50,desc:'50%')]),
  // Os antigos Fogo+/Água+/Vento+ (triângulo de vantagem) saíram: os níveis
  // comprados ficam guardados em GameState.legacyElemUpgrades e serão
  // convertidos nos especiais de elemento (Fase 4).
  UpgradeDef(id:'bounce', label:'Ricochete', icon:'↗', color:Color(0xFFAFA9EC), desc:'Ricochetes na mira',
    levels:[UpgradeLevel(cost:150,value:1,desc:'1 ricochete'),UpgradeLevel(cost:400,value:2,desc:'2 ricochetes'),UpgradeLevel(cost:800,value:3,desc:'3 ricochetes')]),
  UpgradeDef(id:'speed', label:'Acelerar', icon:'⏩', color:Color(0xFFEF9F27), desc:'Desbloqueia o botão 2x',
    levels:[UpgradeLevel(cost:10000,value:2,desc:'2x')]),
];
