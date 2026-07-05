import 'package:flutter/material.dart';

import 'package:vocal_coach_app/shared/animations/page_transitions.dart';

import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/user_models.dart';
import '../../analytics_dashboard/presentation/analytics_dashboard_page.dart';
import 'vocal_preferences_page.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({
    super.key,
    required this.appState,
    required this.apiClient,
  });

  final AppState appState;
  final ApiClient apiClient;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  bool _isSigningOut = false;
  bool _isLoading = true;
  bool _isUpgrading = false;
  String? _error;
  UserProfileFull? _profile;

  @override
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFB),
        title: const Text('Account Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(theme)
              : _buildContent(theme),
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
        ),
        _SettingsItem(
          icon: Icons.mail_outline_rounded,
          label: 'Email',
          value: profile.email,
        ),
        _SettingsItem(
          icon: Icons.badge_outlined,
          label: 'User ID',
          value: profile.uid.length > 12
              ? '${profile.uid.substring(0, 12)}...'
              : profile.uid,
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
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
            child: Center(
              child: Text(
                _getInitials(profile.name),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profile.email,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAction = onTap != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (iconColor ?? theme.colorScheme.primary)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor ?? theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: labelColor,
                      ),
                    ),
                    if (value != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        value!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier});

  final AccessTier tier;

  @override
  Widget build(BuildContext context) {
    final isPremium = tier == AccessTier.premium;
    final label = isPremium ? 'Premium' : 'Free';
    final bgColor =
        isPremium ? const Color(0xFFFDF3E0) : const Color(0xFFE8F5E9);
    final textColor =
        isPremium ? const Color(0xFFB8860B) : const Color(0xFF2E7D32);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

/// Enterprise-style sign out confirmation dialog.
/// Centered icon, bold title, body text, full-width action buttons.
class _SignOutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.error.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.logout_rounded,
                color: theme.colorScheme.error,
                size: 28,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sign Out',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to sign out? You can sign back in anytime with your credentials.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sign Out'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
