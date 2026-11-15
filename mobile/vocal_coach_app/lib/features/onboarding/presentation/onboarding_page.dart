import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/widgets/voice_studio.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onComplete});
  final VoidCallback onComplete;
  static const onboardingCompleteKey = 'onboarding_complete';
  static Future<bool> hasCompletedOnboarding() async =>
      (await SharedPreferences.getInstance()).getBool(onboardingCompleteKey) ??
      false;
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  var _index = 0;
  var _completing = false;
  static const _titles = [
    'Find your voice.\nMake it yours.',
    'One note.\nOne clear next step.',
    'Bring your practice\nto a song.'
  ];
  static const _descriptions = [
    'A personal space to warm up, build your technique and sing with confidence.',
    'Choose your voice range, warm up gently, then follow a live pitch guide. Review your take at your own pace.',
    'Practice church songs with backing tracks and synchronized lyrics when available. Finish with a clear coaching review.',
  ];
  Future<void> _complete() async {
    if (_completing) return;
    setState(() => _completing = true);
    try {
      await (await SharedPreferences.getInstance())
          .setBool(OnboardingPage.onboardingCompleteKey, true);
    } catch (_) {
      // Local storage must not block entry to authentication.
    }
    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
        body: VoiceStageBackground(
            child: SafeArea(
                child: Column(children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Expanded(
                child: Text('COCKATIEL',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(letterSpacing: 3))),
            TextButton(
                onPressed: _completing ? null : _complete,
                child: const Text('Skip')),
          ])),
      Expanded(
          child: PageView.builder(
        controller: _controller,
        itemCount: _titles.length,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (context, index) =>
            LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        VoiceHero(
                            size: math.min(
                                320, MediaQuery.sizeOf(context).width * .78)),
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Column(children: [
                              Text(_titles[index],
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineLarge
                                      ?.copyWith(height: 1.12)),
                              const SizedBox(height: 16),
                              Text(_descriptions[index],
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant)),
                            ])),
                      ])));
        }),
      )),
      Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
              3,
              (index) => Semantics(
                    label: 'Onboarding page ${index + 1} of 3',
                    selected: index == _index,
                    child: Container(
                        margin: const EdgeInsets.all(4),
                        width: index == _index ? 26 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                            color: index == _index
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                            borderRadius: BorderRadius.circular(8))),
                  ))),
      Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: FilledButton(
            key: const ValueKey('onboarding-primary-action'),
            onPressed: _completing
                ? null
                : () {
                    if (_index == 2) {
                      _complete();
                    } else {
                      _controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut);
                    }
                  },
            child: Text(_index == 2 ? 'Start my journey' : 'Next'),
          )),
      TextButton(
          key: const ValueKey('onboarding-login-action'),
          onPressed: _completing ? null : _complete,
          child: const Text('Already have an account? Log in')),
    ]))));
  }
}
