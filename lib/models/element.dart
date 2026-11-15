import 'package:flutter/material.dart';

// ─── Elements ─────────────────────────────────────────────────────────────────
/// A ordem é salva em disco (índice): só adicione elementos no final.
enum ElementType { neutral, fire, water, wind, lightning, earth }

/// Elementos de combate (todos menos o neutro), na ordem do enum.
const List<ElementType> kCombatElements = [
  ElementType.fire,
  ElementType.water,
  ElementType.wind,
  ElementType.lightning,
  ElementType.earth,
];

class ElementData {
  final String label;
  final String icon;
  final Color ballColor;
  final Color blockBg;
  final Color blockBorder;
  final Color textColor;

  const ElementData({
    required this.label,
    required this.icon,
    required this.ballColor,
    required this.blockBg,
    required this.blockBorder,
    required this.textColor,
  });
}

/// Cores pensadas para 5 elementos distinguíveis à distância, mesmo em bolas
/// de 10 px: laranja-fogo, azul-água, verde-vento, violeta-raio e ocre-terra.
const Map<ElementType, ElementData> elementDataMap = {
  ElementType.neutral: ElementData(
    label: 'Neutro', icon: '○',
    ballColor: Color(0xFFFFFFFF),
    blockBg: Color(0xFF5F5E5A), blockBorder: Color(0xFF444441), textColor: Color(0xFFF1EFE8),
  ),
  ElementType.fire: ElementData(
    label: 'Fogo', icon: '🔥',
    ballColor: Color(0xFFFF7043),
    blockBg: Color(0xFFD85A30), blockBorder: Color(0xFF993C1D), textColor: Color(0xFFFAECE7),
  ),
  ElementType.water: ElementData(
    label: 'Água', icon: '💧',
    ballColor: Color(0xFF4FC3F7),
    blockBg: Color(0xFF378ADD), blockBorder: Color(0xFF185FA5), textColor: Color(0xFFE6F1FB),
  ),
  ElementType.wind: ElementData(
    label: 'Vento', icon: '🌪',
    ballColor: Color(0xFF97C459),
    blockBg: Color(0xFF639922), blockBorder: Color(0xFF3B6D11), textColor: Color(0xFFEAF3DE),
  ),
  ElementType.lightning: ElementData(
    label: 'Raio', icon: '⚡',
    ballColor: Color(0xFFCE93D8),
    blockBg: Color(0xFF7E57C2), blockBorder: Color(0xFF4D2E8F), textColor: Color(0xFFF0E7FF),
  ),
  ElementType.earth: ElementData(
    label: 'Terra', icon: '⛰',
    ballColor: Color(0xFFD4A24C),
    blockBg: Color(0xFF8D6E2F), blockBorder: Color(0xFF5D4717), textColor: Color(0xFFF3EAD3),
  ),
};
