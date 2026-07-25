import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  final List<Map<String, dynamic>> _pages = [
    {
      'title': const TextSpan(
        children: [
          TextSpan(text: 'Welcome to '),
          TextSpan(text: 'Cockatiel,\n', style: TextStyle(color: Color(0xFF00FF7F))),
          TextSpan(text: 'your Gateway to\n'),
          TextSpan(text: 'Vocal Mastery!'),
        ],
      ),
      'subtitle': const TextSpan(
        children: [
          TextSpan(text: 'Unlock exclusive vocal exercises and '),
          TextSpan(text: 'gain confidence\nwith every practice.', style: TextStyle(color: Color(0xFF00FF7F), fontWeight: FontWeight.bold)),
          TextSpan(text: ' Let\'s turn your\nsinging into mastery!'),
        ],
      ),
    },
    {
      'title': const TextSpan(
        children: [
          TextSpan(text: 'Real-time\n'),
          TextSpan(text: 'Feedback', style: TextStyle(color: Color(0xFF00FF7F))),
        ],
      ),
      'subtitle': const TextSpan(
        children: [
          TextSpan(text: 'See your pitch accuracy live as you sing.\nOur advanced engine helps you hit the right notes every time.'),
        ],
      ),
    },
    {
      'title': const TextSpan(
        children: [
          TextSpan(text: 'Tailored\n'),
          TextSpan(text: 'Vocal Workouts', style: TextStyle(color: Color(0xFF00FF7F))),
        ],
      ),
      'subtitle': const TextSpan(
        children: [
          TextSpan(text: 'Practice with exercises designed specifically for your vocal range and goals. Start singing better today.'),
        ],
      ),
    },
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingPage.onboardingCompleteKey, true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090F),
      body: Stack(
        children: [
          // Background Collage covers the ENTIRE screen
          Positioned.fill(
            child: Image.asset(
              'assets/images/onboarding_collage.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          
          // Dark Gradient Overlay (matching Login screen aesthetic exactly)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.30, 0.50, 1.0],
                  colors: [
                    const Color(0xFF09090F).withValues(alpha: 0.15),
                    const Color(0xFF09090F).withValues(alpha: 0.55),
                    const Color(0xFF09090F).withValues(alpha: 0.92),
                    const Color(0xFF09090F),
                  ],
                ),
              ),
            ),
          ),

          // Content Layer
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                                children: _pages[index]['title'].children,
                              ),
                            ),
                            const SizedBox(height: 16),
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  height: 1.5,
                                ),
                                children: _pages[index]['subtitle'].children,
                              ),
                            ),
                            const SizedBox(height: 48),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Dot Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 24 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _currentPage == index ? const Color(0xFF00FF7F) : Colors.white30,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),

                // Vibrant Action Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage == _pages.length - 1) {
                          _completeOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF7F),
                        foregroundColor: const Color(0xFF09090F),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1 ? "Let's Get Started!" : "Next",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),

                // Login Text
                TextButton(
                  onPressed: _completeOnboarding,
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 14, color: Colors.white60),
                      children: [
                        TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Log In',
                          style: TextStyle(color: Color(0xFF00FF7F), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
