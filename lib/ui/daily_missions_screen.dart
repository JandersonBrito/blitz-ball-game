import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/managers/game_state.dart';
import '../models/daily_mission.dart';
import '../services/daily_mission_service.dart';
import '../services/haptic_service.dart';
import '../services/settings_service.dart';

const _gold = Color(0xFFEF9F27);
const _green = Color(0xFF1D9E75);

Color _difficultyColor(MissionDifficulty d) => switch (d) {
      MissionDifficulty.easy => const Color(0xFF97C459),
      MissionDifficulty.medium => const Color(0xFF85B7EB),
      MissionDifficulty.hard => const Color(0xFFE24B4A),
    };

class DailyMissionsScreen extends StatefulWidget {
  final VoidCallback onBack;
  const DailyMissionsScreen({super.key, required this.onBack});

  @override
  State<DailyMissionsScreen> createState() => _DailyMissionsScreenState();
}

class _DailyMissionsScreenState extends State<DailyMissionsScreen> {
  // Atualiza a contagem regressiva e vira as missões se passar da meia-noite.
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  void _claimed(int amount) {
    if (amount == 0) return;
    HapticService.instance.blockBreak();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DailyMissionService>();
    final state = context.watch<GameState>();
    final l = context.watch<SettingsService>().l10n;
    final missions = service.missions;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.missionsTitle,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace')),
              Text('⬤ ${state.gold}',
                  style: const TextStyle(
                      color: _gold,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(l.missionsReset(service.timeUntilReset),
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontFamily: 'monospace')),
          ),
          const SizedBox(height: 12),
          for (final m in missions) ...[
            _MissionCard(
                mission: m, onClaim: () => _claimed(service.claim(m))),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 4),
          _BonusCard(
            reward: service.bonusReward,
            claimable: service.bonusClaimable,
            claimed: service.bonusClaimed,
            onClaim: () => _claimed(service.claimBonus()),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: widget.onBack,
            child: Text(l.back,
                style: const TextStyle(
                    color: Colors.white54, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final DailyMission mission;
  final VoidCallback onClaim;
  const _MissionCard({required this.mission, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    final l = context.watch<SettingsService>().l10n;
    final color = _difficultyColor(mission.difficulty);
    final m = mission;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: m.claimed
              ? Colors.white12
              : m.claimable
                  ? _green
                  : color.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.missionDifficulty(m.difficulty),
                    style: TextStyle(
                        color: m.claimed ? Colors.white24 : color,
                        fontSize: 8,
                        letterSpacing: 1,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace')),
                const SizedBox(height: 2),
                Text(l.missionDesc(m.type, m.target),
                    style: TextStyle(
                        color: m.claimed ? Colors.white38 : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace')),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: m.ratio,
                          minHeight: 5,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation(
                              m.completed ? _green : color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${m.progress}/${m.target}',
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
                            fontFamily: 'monospace')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _RewardButton(
            reward: m.reward,
            claimable: m.claimable,
            claimed: m.claimed,
            label: l.missionClaim,
            claimedLabel: l.missionClaimed,
            onTap: onClaim,
          ),
        ],
      ),
    );
  }
}

class _BonusCard extends StatelessWidget {
  final int reward;
  final bool claimable;
  final bool claimed;
  final VoidCallback onClaim;
  const _BonusCard(
      {required this.reward,
      required this.claimable,
      required this.claimed,
      required this.onClaim});

  @override
  Widget build(BuildContext context) {
    final l = context.watch<SettingsService>().l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: claimable ? 0.14 : 0.05),
        border: Border.all(
            color: claimed ? Colors.white12 : _gold.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: claimable
            ? [BoxShadow(color: _gold.withValues(alpha: 0.3), blurRadius: 12)]
            : null,
      ),
      child: Row(
        children: [
          Text(claimed ? '📭' : '🎁', style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.missionBonusTitle,
                    style: TextStyle(
                        color: claimed ? Colors.white38 : _gold,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace')),
                Text(l.missionBonusDesc,
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                        fontFamily: 'monospace')),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _RewardButton(
            reward: reward,
            claimable: claimable,
            claimed: claimed,
            label: l.missionBonusOpen,
            claimedLabel: l.missionClaimed,
            onTap: onClaim,
          ),
        ],
      ),
    );
  }
}

class _RewardButton extends StatelessWidget {
  final int reward;
  final bool claimable;
  final bool claimed;
  final String label;
  final String claimedLabel;
  final VoidCallback onTap;
  const _RewardButton({
    required this.reward,
    required this.claimable,
    required this.claimed,
    required this.label,
    required this.claimedLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (claimed) {
      return Text(claimedLabel,
          style: const TextStyle(
              color: Colors.white38, fontSize: 9, fontFamily: 'monospace'));
    }
    return GestureDetector(
      onTap: claimable ? onTap : null,
      child: Container(
        width: 74,
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: claimable ? _green : Colors.transparent,
          border: Border.all(color: claimable ? _green : Colors.white24),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text('⬤ $reward',
                style: TextStyle(
                    color: claimable ? Colors.white : _gold,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace')),
            if (claimable)
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }
}
