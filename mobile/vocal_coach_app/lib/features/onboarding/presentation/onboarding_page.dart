import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/widgets/contained_hero_image.dart';

class _OnboardingContent {
  const _OnboardingContent({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onComplete});

  final VoidCallback onComplete;
  static const onboardingCompleteKey = 'onboarding_complete';

  static Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(onboardingCompleteKey) ?? false;
  }

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = <_OnboardingContent>[
    _OnboardingContent(
      title: 'Welcome to Cockatiel',
      subtitle: 'Build confidence with short, guided vocal practice.',
    ),
    _OnboardingContent(
      title: 'See your voice as you sing',
      subtitle:
          'Get simple live guidance for pitch, timing, and microphone input.',
    ),
    _OnboardingContent(
      title: 'Practice at your pace',
      subtitle:
          'Choose exercises or karaoke, review your progress, and know what to try next.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingPage.onboardingCompleteKey, true);
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(
              flex: 45,
              child: ContainedHeroImage(
                assetPath: 'assets/images/onboarding_collage.jpg',
                semanticLabel: 'Singers practicing with microphones',
              ),
            ),
            Expanded(
              flex: 55,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) =>
                            setState(() => _currentPage = index),
                        itemCount: _pages.length,
                        itemBuilder: (context, index) {
                          final page = _pages[index];
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                page.title,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                page.subtitle,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => Semantics(
                          label:
                              'Onboarding page ${index + 1} of ${_pages.length}',
                          selected: _currentPage == index,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          if (isLastPage) {
                            _completeOnboarding();
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                        child: Text(isLastPage ? 'Get started' : 'Next'),
                      ),
                    ),
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: const Text('I already have an account'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
