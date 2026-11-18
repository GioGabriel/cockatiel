import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/widgets/entry_identity.dart';

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
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 16, 8),
              child: Row(children: [
                const Expanded(child: EntryWordmark()),
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
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight: math.max(0, constraints.maxHeight - 32)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        EntryArtwork(
                            height: math.min(340, constraints.maxWidth * .76),
                            variant: index),
                        const SizedBox(height: 32),
                        Text(
                            [
                              'YOUR VOICE STARTS HERE',
                              'PRACTICE WITH PURPOSE',
                              'SING SOMETHING YOU LOVE'
                            ][index],
                            style: theme.textTheme.labelSmall?.copyWith(
                                letterSpacing: 1.8,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary)),
                        const SizedBox(height: 14),
                        Text(_titles[index],
                            style: theme.textTheme.headlineLarge?.copyWith(
                                fontSize: 36,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -1.2,
                                height: 1.08)),
                        const SizedBox(height: 16),
                        Text(_descriptions[index],
                            style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.6,
                                color: theme.colorScheme.onSurfaceVariant)),
                      ]),
                ),
              );
            }),
          )),
          Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Row(children: [
                ...List.generate(
                    3,
                    (index) => Semantics(
                        label: 'Onboarding page ${index + 1} of 3',
                        selected: index == _index,
                        child: Container(
                            width: index == _index ? 28 : 8,
                            height: 5,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                                color: index == _index
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outlineVariant,
                                borderRadius: BorderRadius.circular(8))))),
                const Spacer(),
                Text('0${_index + 1} / 03',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 1.5)),
              ])),
          Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
              child: FilledButton(
                key: const ValueKey('onboarding-primary-action'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                onPressed: _completing
                    ? null
                    : () {
                        if (_index == 2) {
                          _complete();
                        } else if (MediaQuery.disableAnimationsOf(context)) {
                          _controller.jumpToPage(_index + 1);
                        } else {
                          _controller.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut);
                        }
                      },
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Flexible(
                      child: Text(_index == 2 ? 'Start my journey' : 'Next')),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ]),
              )),
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextButton(
                  key: const ValueKey('onboarding-login-action'),
                  onPressed: _completing ? null : _complete,
                  child: const Text('Already have an account? Log in',
                      textAlign: TextAlign.center))),
        ]),
      ))),
    );
  }
}
