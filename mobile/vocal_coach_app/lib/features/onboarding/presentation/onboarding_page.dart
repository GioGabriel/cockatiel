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
          // Background Collage
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.7,
            child: Image.asset(
              'assets/images/onboarding_collage.jpg',
              fit: BoxFit.cover,
            ),
          ),
          
          // Dark Gradient Overlay to blend the image into the bottom text area
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF09090F).withOpacity(0.2),
                    const Color(0xFF09090F).withOpacity(0.8),
                    const Color(0xFF09090F),
                    const Color(0xFF09090F),
                  ],
                  stops: const [0.0, 0.4, 0.6, 0.75, 1.0],
                ),
              ),
            ),
          ),

          // Content Layer
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Spacer(),
                
                // Welcome Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      children: [
                        TextSpan(text: 'Welcome to '),
                        TextSpan(
                          text: 'Cockatiel,\n',
                          style: TextStyle(color: Color(0xFF00FF7F)), // Vibrant Green from reference
                        ),
                        TextSpan(text: 'your Gateway to\n'),
                        TextSpan(text: 'Vocal Mastery!'),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Subtitle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                        height: 1.5,
                      ),
                      children: const [
                        TextSpan(text: 'Unlock exclusive vocal exercises and '),
                        TextSpan(
                          text: 'gain confidence\nwith every practice.',
                          style: TextStyle(color: Color(0xFF00FF7F), fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: ' Let\'s turn your\nsinging into mastery!'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Dot Indicators (just for aesthetic mimicry of the reference image)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 24, height: 6, decoration: BoxDecoration(color: const Color(0xFF00FF7F), borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 6),
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.white30, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.white30, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.white30, shape: BoxShape.circle)),
                  ],
                ),

                const SizedBox(height: 32),

                // Vibrant Action Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _completeOnboarding,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF7F), // Vibrant Green
                        foregroundColor: const Color(0xFF09090F),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Let's Get Started!",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),

                // Login Text (If they already have an account)
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
