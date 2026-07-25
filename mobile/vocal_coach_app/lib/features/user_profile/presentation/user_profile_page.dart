import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:vocal_coach_app/shared/animations/page_transitions.dart';

import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/user_models.dart';
import '../../analytics_dashboard/presentation/analytics_dashboard_page.dart';
import '../../history/presentation/practice_history_page.dart';
import 'vocal_preferences_page.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({
    super.key,
    required this.appState,
    required this.apiClient,
  });

  final AppState appState;
  final ApiClient apiClient;

  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  bool _isSigningOut = false;
  bool _isLoading = true;
  bool _isUpgrading = false;
  String? _error;
  UserProfileFull? _profile;

  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profile = await widget.apiClient.fetchFullProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load profile (${e.statusCode})';
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _upgradeToPremium() async {
    setState(() => _isUpgrading = true);
    try {
      final updated = await widget.apiClient.upgradeToPremium();
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _isUpgrading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUpgrading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upgrade failed. Please try again.')),
      );
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _SignOutDialog(),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSigningOut = true);
    await widget.appState.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _navigateToPreferences() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VocalPreferencesPage(
          apiClient: widget.apiClient,
          currentPreferences: _profile?.vocalPreferences,
        ),
      ),
    ).then((_) => _loadProfile());
  }

  void _navigateToAnalytics() {
    Navigator.of(context).push(
      slideForwardRoute(
        builder: (_) => AnalyticsDashboardPage(
          apiClient: widget.apiClient,
        ),
      ),
    );
  }

  void _navigateToHistory() {
    Navigator.of(context).push(
      slideForwardRoute(
        builder: (_) => PracticeHistoryPage(
          apiClient: widget.apiClient,
          appState: widget.appState,
        ),
      ),
    );
  }

  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Account Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: const Color(0xFF0A0A0F),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
              : _error != null
                  ? _buildError(theme)
                  : _buildContent(theme),
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48,
                color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _loadProfile,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final profile = _profile;
    if (profile == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        // ─── PROFILE HEADER ──────────────────────────────────────
        _buildProfileHeader(theme, profile),
        const SizedBox(height: 32),

        // ─── PROFILE INFORMATION ─────────────────────────────────
        _SectionHeader(title: 'Profile Information'),
        const SizedBox(height: 8),
        _SettingsItem(
          icon: Icons.person_outline_rounded,
          label: 'Full Name',
          value: profile.name,
          onTap: () {
            Clipboard.setData(ClipboardData(text: profile.name));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Name copied to clipboard')),
            );
          },
        ),
        _SettingsItem(
          icon: Icons.mail_outline_rounded,
          label: 'Email',
          value: profile.email,
          onTap: () {
            Clipboard.setData(ClipboardData(text: profile.email));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Email copied to clipboard')),
            );
          },
        ),
        _SettingsItem(
          icon: Icons.badge_outlined,
          label: 'User ID',
          value: profile.uid.length > 12
              ? '${profile.uid.substring(0, 12)}...'
              : profile.uid,
          onTap: () {
            Clipboard.setData(ClipboardData(text: profile.uid));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User ID copied to clipboard')),
            );
          },
        ),
        const SizedBox(height: 28),

        // ─── MANAGE ACCOUNT ──────────────────────────────────────
        _SectionHeader(title: 'Manage Account'),
        const SizedBox(height: 8),
        _SettingsItem(
          icon: Icons.music_note_outlined,
          label: 'Vocal Preferences',
          value: profile.vocalPreferences != null
              ? _formatVocalRange(profile.vocalPreferences!.vocalRange)
              : 'Not configured',
          onTap: _navigateToPreferences,
        ),
        _SettingsItem(
          icon: Icons.bar_chart_rounded,
          label: 'Analytics & Progress',
          value: 'View stats and trends',
          onTap: _navigateToAnalytics,
        ),
        _SettingsItem(
          icon: Icons.history_rounded,
          label: 'Practice History & Logs',
          value: 'Review takes & AI feedback',
          onTap: _navigateToHistory,
        ),
        _SettingsItem(
          icon: Icons.star_outline_rounded,
          label: 'Subscription',
          trailing: _TierBadge(tier: profile.accessTier),
          onTap: profile.accessTier == AccessTier.registered
              ? (_isUpgrading ? null : _upgradeToPremium)
              : null,
        ),
        if (profile.accessTier == AccessTier.premium &&
            profile.premiumExpiresAt != null)
          _SettingsItem(
            icon: Icons.schedule_rounded,
            label: 'Premium Until',
            value: _formatDate(profile.premiumExpiresAt!),
          ),
        const SizedBox(height: 28),

        // ─── DANGER ZONE ─────────────────────────────────────────
        _SectionHeader(title: 'Session'),
        const SizedBox(height: 8),
        _SettingsItem(
          icon: Icons.logout_rounded,
          label: 'Sign Out',
          value: 'You can sign back in anytime',
          onTap: _isSigningOut ? null : _confirmSignOut,
          iconColor: theme.colorScheme.error,
          labelColor: theme.colorScheme.error,
        ),
      ],
    );
  }

  Widget _buildProfileHeader(ThemeData theme, UserProfileFull profile) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1DB954),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF181818),
                ),
                child: Center(
                  child: Text(
                    _getInitials(profile.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            profile.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profile.email,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatVocalRange(VocalRange range) {
    switch (range) {
      case VocalRange.soprano: return 'Soprano';
      case VocalRange.mezzoSoprano: return 'Mezzo-Soprano';
      case VocalRange.alto: return 'Alto';
      case VocalRange.tenor: return 'Tenor';
      case VocalRange.baritone: return 'Baritone';
      case VocalRange.bass: return 'Bass';
    }
  }

  String _formatDate(int timestampMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ─── SUPPORTING WIDGETS ──────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.cyanAccent,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? labelColor;

  Widget build(BuildContext context) {
    final hasAction = onTap != null;
    final itemIconColor = iconColor ?? Colors.cyanAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF282828),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          highlightColor: Colors.white.withOpacity(0.05),
          splashColor: itemIconColor.withOpacity(0.15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: itemIconColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: itemIconColor.withOpacity(0.3),
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: itemIconColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: labelColor ?? Colors.white,
                          ),
                        ),
                        if (value != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            value!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                  if (hasAction && trailing == null)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Colors.white.withOpacity(0.5),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier});

  final AccessTier tier;

  Widget build(BuildContext context) {
    final isPremium = tier == AccessTier.premium;
    final label = isPremium ? 'PREMIUM' : 'FREE';
    final glowColor = isPremium ? Colors.purpleAccent : Colors.greenAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: glowColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glowColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: -2,
          )
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: glowColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Enterprise-style sign out confirmation dialog.
/// Centered icon, bold title, body text, full-width action buttons.
class _SignOutDialog extends StatelessWidget {
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF282828)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withOpacity(0.15),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                  ),
                  child: const Icon(
                    Icons.power_settings_new_rounded,
                    color: Colors.redAccent,
                    size: 32,
                  ),
                ),
                  const SizedBox(height: 20),
                  const Text(
                    'SYSTEM OFFLINE?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Are you sure you want to sign out? Your vocal data is safely stored in the cloud.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'SIGN OUT',
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withOpacity(0.8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                      ),
                      child: const Text('CANCEL'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
