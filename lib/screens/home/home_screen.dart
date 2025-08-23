import 'dart:io' show Platform;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_pass_qr/config/routes.dart';
import 'package:gym_pass_qr/config/theme.dart';
import 'package:gym_pass_qr/models/auth_model.dart';
import 'package:gym_pass_qr/models/user_model.dart';
import 'package:gym_pass_qr/providers/auth_provider.dart';
import 'package:gym_pass_qr/providers/user_provider.dart';
import 'package:gym_pass_qr/utils/validators.dart';
import 'package:gym_pass_qr/widgets/common/loading_overlay.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_protector/screen_protector.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _qrAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500))
    ..forward();
  late final Animation<double> _qrScale =
      CurvedAnimation(parent: _qrAnim, curve: Curves.elasticOut);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final a = context.read<AuthProvider>();
      if (a.user != null) context.read<UserProvider>().setUser(a.user!);
    });
  }

  @override
  void dispose() {
    _qrAnim.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() => context.read<UserProvider>().refreshData();

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // ignore: use_build_context_synchronously
    final auth = context.read<AuthProvider>();
    // ignore: use_build_context_synchronously
    context.read<UserProvider>().clearData();
    await auth.logout();
    if (!mounted) return;
    context.go(AppRouter.phoneInput);
  }

  @override
  Widget build(BuildContext context) {
    final up = context.watch<UserProvider>();
    final user = up.user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final w = MediaQuery.of(context).size.width;
    final compact = w < 360;

    return LoadingOverlay(
      isLoading: up.isLoadingQr,
      child: Scaffold(
        key: const ValueKey('home_scaffold'),
        backgroundColor: AppTheme.backgroundColor,
        body: RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: _refreshAll,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _Header(user: user, onLogout: _logout, compact: compact),
              SliverToBoxAdapter(
                child: Padding(
                  // içeriği güvenli aralıkla tut
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MembershipCard(user: user, compact: compact),
                      const SizedBox(height: 16),
                      const NoScreenshot(child: _QrSectionWrapper()),
                      const SizedBox(height: 16),
                      const _Instructions(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrSectionWrapper extends StatelessWidget {
  const _QrSectionWrapper();

  @override
  Widget build(BuildContext context) {
    final up = context.watch<UserProvider>();
    final state = context.findAncestorStateOfType<_HomeScreenState>();
    final scale = state?._qrScale ?? kAlwaysCompleteAnimation;

    return _QrSection(
      scale: scale,
      qrData: up.qrCodeData,
      isRefreshing: up.isRefreshing,
      error: up.errorMessage,
      onRefresh: () => context.read<UserProvider>().refreshData(),
    );
  }
}

/// ============== HEADER (Overflow-safe) ==============
class _Header extends StatelessWidget {
  const _Header(
      {required this.user, required this.onLogout, required this.compact});
  final User user;
  final VoidCallback onLogout;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // daha kompakt boyutlar
    final avatarSize = compact ? 56.0 : 64.0;
    final titleSize = compact ? 20.0 : 22.0;

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: AppTheme.primaryColor,
      automaticallyImplyLeading: false,
      // esnek alan yüksekliği — küçük farkla fazla tuttuk
      expandedHeight: compact ? 132 : 152,
      toolbarHeight: 56,
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: onLogout,
          tooltip: 'Logout',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
          child: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, c) {
                // Bu yapı taşmaları kesin olarak engeller:
                // Tüm içerik alanı içine sığmazsa FittedBox küçültür.
                return SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Avatar(url: user.profilePhotoUrl, size: avatarSize),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Text(
                              user.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppTheme.heading2.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: titleSize,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Text(
                              Validators.formatPhoneForDisplay(
                                  user.phoneNumber),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppTheme.bodySmall
                                  .copyWith(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url, this.size = 64});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipOval(
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    const CircularProgressIndicator(color: Colors.white),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.person, size: 36, color: Colors.white),
              )
            : const ColoredBox(
                color: Colors.white24,
                child: Center(
                    child: Icon(Icons.person, size: 36, color: Colors.white)),
              ),
      ),
    );
  }
}

/// ============== MEMBERSHIP CARD (dinamik & güvenli) ==============
class _MembershipCard extends StatelessWidget {
  const _MembershipCard({required this.user, required this.compact});
  final User user;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = user.membershipStart;
    final end = user.membershipEnd;

    final totalDays =
        end.isAfter(start) ? end.difference(start).inDays.clamp(1, 36500) : 1;
    final remainingDays = end.isAfter(now) ? end.difference(now).inDays : 0;

    // Çubuğu “kalan/total” olarak gösteriyoruz: üyelik başında dolu,
    // sona yaklaştıkça azalır.
    final progress = (remainingDays / totalDays).clamp(0.0, 1.0);

    final isValid = end.isAfter(now) && user.isActive;
    final isSoon = remainingDays > 0 && remainingDays <= 7;

    final (color, icon, text) = !isValid
        ? (AppTheme.errorColor, Icons.cancel, 'Expired')
        : isSoon
            ? (AppTheme.warningColor, Icons.warning, 'Expiring Soon')
            : (AppTheme.successColor, Icons.check_circle, 'Active');

    return _Card(
      child: Column(
        key: const ValueKey('home_membership_card'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Membership Status',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTheme.heading3.copyWith(fontSize: compact ? 18 : null),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _Chip(color: color, icon: icon, text: text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.star,
            label: 'Plan',
            value: user.membershipType,
            color: AppTheme.accentColor,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.calendar_today,
            label: 'Started',
            value: _d(start),
            color: AppTheme.successColor,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.event,
            label: 'Expires',
            value: _d(end),
            color: isSoon ? AppTheme.warningColor : AppTheme.infoColor,
          ),
          if (isValid) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text('Days Remaining',
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.textSecondary)),
                ),
                Text(
                  '$remainingDays days',
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color:
                        isSoon ? AppTheme.warningColor : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.dividerColor,
              valueColor: AlwaysStoppedAnimation(
                  isSoon ? AppTheme.warningColor : AppTheme.successColor),
              minHeight: 6,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: color.withOpacity(.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.textSecondary)),
              const SizedBox(height: 2),
              Text(
                value,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style:
                    AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        ],
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.color, required this.icon, required this.text});
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          // ignore: deprecated_member_use
          color: color.withOpacity(.1),
          borderRadius: BorderRadius.circular(20),
          // ignore: deprecated_member_use
          border: Border.all(color: color.withOpacity(.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(text,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySmall
                  .copyWith(color: color, fontWeight: FontWeight.bold)),
        ]),
      );
}

/// ============== QR SECTION ==============
class _QrSection extends StatelessWidget {
  const _QrSection({
    required this.scale,
    required this.qrData,
    required this.isRefreshing,
    required this.error,
    required this.onRefresh,
  });

  final Animation<double> scale;
  final QrCodeData? qrData;
  final bool isRefreshing;
  final String? error;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        key: const ValueKey('home_qr_card'),
        children: [
          const Text('Entry QR Code', style: AppTheme.heading3),
          const SizedBox(height: 6),
          Text('Scan at the turnstile',
              overflow: TextOverflow.ellipsis,
              style:
                  AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              // Ekstra güvenlik: yüksekliği de clamp’le
              final double qrSize =
                  (c.maxWidth - 48).clamp(120.0, 220.0).toDouble();

              Widget body;
              if (qrData != null && qrData!.isValid) {
                body = Column(
                  children: [
                    ScaleTransition(
                      scale: scale,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              // ignore: deprecated_member_use
                              color: AppTheme.primaryColor.withOpacity(.2),
                              width: 2),
                        ),
                        child: SizedBox(
                          width: qrSize,
                          height: qrSize,
                          child: QrImageView(
                            data: qrData!.qrContent,
                            version: QrVersions.auto,
                            size: qrSize,
                            backgroundColor: Colors.white,
                            errorCorrectionLevel: QrErrorCorrectLevel.H,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ValidityBadge(
                        text: 'Valid until ${_t(qrData!.validUntil)}'),
                  ],
                );
              } else if (error != null) {
                body = SizedBox(
                  height: qrSize,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppTheme.errorColor),
                      const SizedBox(height: 8),
                      Text('Failed to generate QR code',
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodyMedium
                              .copyWith(color: AppTheme.errorColor)),
                      TextButton(
                          onPressed: onRefresh, child: const Text('Retry')),
                    ],
                  ),
                );
              } else {
                body = SizedBox(
                    height: qrSize,
                    child: const Center(child: CircularProgressIndicator()));
              }

              return body;
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isRefreshing ? null : onRefresh,
            icon: Icon(Icons.refresh,
                color: isRefreshing
                    ? AppTheme.textSecondary
                    : AppTheme.primaryColor),
            label: Text(
              isRefreshing ? 'Refreshing...' : 'Refresh QR',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: isRefreshing
                      ? AppTheme.textSecondary
                      : AppTheme.primaryColor),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidityBadge extends StatelessWidget {
  const _ValidityBadge({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: AppTheme.successColor.withOpacity(.1),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.access_time, size: 16, color: AppTheme.successColor),
          const SizedBox(width: 4),
          Text(text,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.successColor, fontWeight: FontWeight.w500)),
        ]),
      );
}

/// ============== INFO CARD WRAPPER ==============
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
        ),
        child: child,
      );
}

/// ============== INSTRUCTIONS ==============
class _Instructions extends StatelessWidget {
  const _Instructions();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // ignore: deprecated_member_use
          color: AppTheme.infoColor.withOpacity(.1),
          borderRadius: BorderRadius.circular(12),
          // ignore: deprecated_member_use
          border: Border.all(color: AppTheme.infoColor.withOpacity(.3)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TitleRow(),
            SizedBox(height: 8),
            _Step(numLabel: '1', text: 'Open this screen at the gym entrance'),
            _Step(numLabel: '2', text: 'Hold your phone near the scanner'),
            _Step(numLabel: '3', text: 'Wait for the green light'),
            _Step(numLabel: '4', text: 'Push the turnstile to enter'),
          ],
        ),
      );
}

class _TitleRow extends StatelessWidget {
  const _TitleRow();
  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.info_outline, size: 20, color: AppTheme.infoColor),
          const SizedBox(width: 8),
          Text('How to use',
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold, color: AppTheme.infoColor)),
        ],
      );
}

class _Step extends StatelessWidget {
  const _Step({required this.numLabel, required this.text});
  final String numLabel;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: AppTheme.infoColor.withOpacity(.2),
                shape: BoxShape.circle),
            child: Center(
              child: Text(numLabel,
                  style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.infoColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.textSecondary))),
        ]),
      );
}

/// ============== HELPERS ==============
String _d(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String _t(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// ============== SCREENSHOT BLOCKER ==============
class NoScreenshot extends StatefulWidget {
  const NoScreenshot({super.key, required this.child});
  final Widget child;
  @override
  State<NoScreenshot> createState() => _NoScreenshotState();
}

class _NoScreenshotState extends State<NoScreenshot> {
  @override
  void initState() {
    super.initState();
    _enableProtection();
  }

  Future<void> _enableProtection() async {
    try {
      await ScreenProtector.preventScreenshotOn();
      await ScreenProtector.protectDataLeakageOn();
      if (kDebugMode) {
        debugPrint(
            '[NoScreenshot] protection ON (Platform: ${Platform.operatingSystem})');
      }
    } catch (e) {
      debugPrint('[NoScreenshot] enable failed: $e');
    }
  }

  Future<void> _disableProtection() async {
    try {
      await ScreenProtector.preventScreenshotOff();
      await ScreenProtector.protectDataLeakageOff();
      if (kDebugMode) {
        debugPrint('[NoScreenshot] protection OFF');
      }
    } catch (e) {
      debugPrint('[NoScreenshot] disable failed: $e');
    }
  }

  @override
  void dispose() {
    _disableProtection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
