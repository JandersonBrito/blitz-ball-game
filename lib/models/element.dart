import 'package:flutter/material.dart';

// ─── Elements ─────────────────────────────────────────────────────────────────
enum ElementType { neutral, fire, water, wind }

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

const Map<ElementType, ElementData> elementDataMap = {
  ElementType.neutral: ElementData(
    label: 'Neutro', icon: '○',
    ballColor: Color(0xFFFFFFFF),
    blockBg: Color(0xFF5F5E5A), blockBorder: Color(0xFF444441), textColor: Color(0xFFF1EFE8),
  ),
  ElementType.fire: ElementData(
    label: 'Fogo', icon: '🔥',
    ballColor: Color(0xFFEF9F27),
    blockBg: Color(0xFFD85A30), blockBorder: Color(0xFF993C1D), textColor: Color(0xFFFAECE7),
  ),
  ElementType.water: ElementData(
    label: 'Água', icon: '💧',
    ballColor: Color(0xFF85B7EB),
    blockBg: Color(0xFF378ADD), blockBorder: Color(0xFF185FA5), textColor: Color(0xFFE6F1FB),
  ),
  ElementType.wind: ElementData(
    label: 'Vento', icon: '🌪',
    ballColor: Color(0xFF97C459),
    blockBg: Color(0xFF639922), blockBorder: Color(0xFF3B6D11), textColor: Color(0xFFEAF3DE),
  ),
};

// advantage table: attacker -> defender -> multiplier
const Map<ElementType, Map<ElementType, double>> elementMultTable = {
  ElementType.fire:    {ElementType.fire:1.0, ElementType.water:0.5, ElementType.wind:1.5, ElementType.neutral:1.0},
  ElementType.water:   {ElementType.fire:1.5, ElementType.water:1.0, ElementType.wind:0.5, ElementType.neutral:1.0},
  ElementType.wind:    {ElementType.fire:0.5, ElementType.water:1.5, ElementType.wind:1.0, ElementType.neutral:1.0},
  ElementType.neutral: {ElementType.fire:1.0, ElementType.water:1.0, ElementType.wind:1.0, ElementType.neutral:1.0},
};

double getElementMult(ElementType atk, ElementType def) {
  return elementMultTable[atk]?[def] ?? 1.0;
}
