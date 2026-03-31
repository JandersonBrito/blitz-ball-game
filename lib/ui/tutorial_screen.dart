import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../models/l10n.dart';

class TutorialScreen extends StatefulWidget {
  final VoidCallback onBack;
  const TutorialScreen({super.key, required this.onBack});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<SettingsService>().l10n;
    final slides = _buildSlides(l);

    return Container(
      color: const Color(0xEE0A0A14),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  // Pular — visível em todos os slides exceto o último
                  if (_currentPage < slides.length - 1)
                    TextButton(
                      onPressed: widget.onBack,
                      child: Text(l.tutorialSkip,
                          style: const TextStyle(
                              color: Colors.white38,
                              fontFamily: 'monospace',
                              fontSize: 13)),
                    )
                  else
                    const SizedBox(width: 56),
                  const Spacer(),
                  Text(l.tutorialTitle,
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          letterSpacing: 2,
                          fontFamily: 'monospace')),
                  const Spacer(),
                  SizedBox(
                    width: 56,
                    child: Text('${_currentPage + 1}/${slides.length}',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 11,
                            fontFamily: 'monospace')),
                  ),
                ],
              ),
            ),

            // Slides
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: slides[i],
                ),
              ),
            ),

            // Dot indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(slides.length, (i) {
                  final active = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: active ? 20 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF1D9E75) : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _goTo(_currentPage - 1),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          foregroundColor: Colors.white54,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(l.tutorialPrev,
                            style: const TextStyle(fontFamily: 'monospace')),
                      ),
                    )
                  else
                    const Expanded(child: SizedBox()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _currentPage < slides.length - 1
                        ? ElevatedButton(
                            onPressed: () => _goTo(_currentPage + 1),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D9E75),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(l.tutorialNext,
                                style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold)),
                          )
                        : ElevatedButton(
                            onPressed: widget.onBack,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D9E75),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(l.tutorialPlay,
                                style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold)),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSlides(L10n l) => [
        _TutorialSlide(
          borderColor: const Color(0xFF1D9E75),
          icon: '🎯',
          title: l.tutSlide1Title,
          subtitle: l.tutSlide1Sub,
          rawItems: l.tutSlide1Items,
        ),
        _TutorialSlide(
          borderColor: const Color(0xFF534AB7),
          icon: '⚡',
          title: l.tutSlide2Title,
          subtitle: l.tutSlide2Sub,
          rawItems: l.tutSlide2Items,
        ),
        _TutorialSlide(
          borderColor: const Color(0xFFE05C5C),
          icon: '🔥',
          title: l.tutSlide3Title,
          subtitle: l.tutSlide3Sub,
          rawItems: l.tutSlide3Items,
        ),
        _TutorialSlide(
          borderColor: const Color(0xFFE24B4A),
          icon: '👹',
          title: l.tutSlide4Title,
          subtitle: l.tutSlide4Sub,
          rawItems: l.tutSlide4Items,
        ),
        _TutorialSlide(
          borderColor: const Color(0xFFEF9F27),
          icon: '⬤',
          title: l.tutSlide5Title,
          subtitle: l.tutSlide5Sub,
          rawItems: l.tutSlide5Items,
        ),
      ];
}

class _TutorialSlide extends StatelessWidget {
  final Color borderColor;
  final String icon;
  final String title;
  final String subtitle;
  /// Each item is [iconEmoji, label, description]
  final List<List<String>> rawItems;

  const _TutorialSlide({
    required this.borderColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.rawItems,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF12121E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon badge
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: borderColor.withOpacity(0.12),
              border:
                  Border.all(color: borderColor.withOpacity(0.5), width: 1),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 34)),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: borderColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 1)),
          const SizedBox(height: 8),

          // Subtitle
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  height: 1.5)),
          const SizedBox(height: 20),

          // Item rows
          ...rawItems.map((item) => _ItemRow(
                iconEmoji: item[0],
                label: item[1],
                desc: item.length > 2 ? item[2] : '',
                accentColor: borderColor,
              )),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final String iconEmoji;
  final String label;
  final String desc;
  final Color accentColor;

  const _ItemRow({
    required this.iconEmoji,
    required this.label,
    required this.desc,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accentColor.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(iconEmoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: accentColor,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold)),
                if (desc.isNotEmpty)
                  Text(desc,
                      style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
