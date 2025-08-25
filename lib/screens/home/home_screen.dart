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
        title: const Text('Çıkış Yap'),
        content: const Text('Uygulamadan çıkmak istediğinize emin misiniz?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çıkış yap'),
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
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Üyelik kartı
                      _MembershipCardWrapper(),
                      SizedBox(height: 16),
                      // Ekran görüntüsü engelli QR alanı
                      NoScreenshot(child: _QrSectionWrapper()),
                      SizedBox(height: 16),
                      _Instructions(),
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

class _MembershipCardWrapper extends StatelessWidget {
  const _MembershipCardWrapper();

  @override
  Widget build(BuildContext context) {
    final up = context.watch<UserProvider>();
    final user = up.user!;
    final w = MediaQuery.of(context).size.width;
    final compact = w < 360;
    return _MembershipCard(user: user, compact: compact);
  }
}

class _QrSectionWrapper extends StatelessWidget {
  const _QrSectionWrapper();

  @override
  Widget build(BuildContext context) {
    final up = context.watch<UserProvider>();
    final state = context.findAncestorStateOfType<_HomeScreenState>();
    final scale = state?._qrScale ?? kAlwaysCompleteAnimation;

    // Üyelik aktif mi?
    final u = up.user!;
    final membershipActive =
        u.isActive && u.membershipEnd.isAfter(DateTime.now());

    return _QrSection(
      scale: scale,
      qrData: up.qrCodeData,
      isRefreshing: up.isRefreshing,
      error: up.errorMessage,
      membershipActive: membershipActive, // ⬅️ eklendi
      onRefresh: () => context.read<UserProvider>().refreshData(),
    );
  }
}

/// ============== HEADER ==============
class _Header extends StatelessWidget {
  const _Header({
    required this.user,
    required this.onLogout,
    required this.compact,
  });
  final User user;
  final VoidCallback onLogout;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final avatarSize = compact ? 56.0 : 64.0;
    final titleSize = compact ? 20.0 : 22.0;

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: AppTheme.primaryColor,
      automaticallyImplyLeading: false,
      expandedHeight: compact ? 132 : 152,
      toolbarHeight: 56,
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: onLogout,
          tooltip: 'Çıkış',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
          child: SafeArea(
            bottom: false,
            child: SizedBox.expand(
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
                          Validators.formatPhoneForDisplay(user.phoneNumber),
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
                  child: Icon(Icons.person, size: 36, color: Colors.white),
                ),
              ),
      ),
    );
  }
}

/// ============== ÜYELİK KARTI ==============
class _MembershipCard extends StatelessWidget {
  const _MembershipCard({required this.user, required this.compact});
  final User user;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = user.membershipStart;
    final end = user.membershipEnd;

    final totalDays = end.difference(start).inDays.abs().clamp(1, 1000000);
    final elapsedDays = now.difference(start).inDays;
    final remainingDays = end.difference(now).inDays;

    double progress = 0.0; // kalan/total (kalan arttıkça bar dolu)
    if (totalDays > 0 && remainingDays > 0) {
      progress = (remainingDays / totalDays).clamp(0.0, 1.0);
    }

    final isValid = remainingDays > 0 && user.isActive;
    final isSoon = remainingDays > 0 && remainingDays <= 7;

    final (color, icon, text) = !isValid
        ? (AppTheme.errorColor, Icons.cancel, 'Süresi Doldu')
        : isSoon
            ? (AppTheme.warningColor, Icons.warning, 'Yakında Sona Eriyor')
            : (AppTheme.successColor, Icons.check_circle, 'Aktif');

    return _Card(
      child: Column(
        key: const ValueKey('home_membership_card'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Üyelik Durumu',
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
            label: 'Başlangıç',
            value: _formatDate(start),
            color: AppTheme.successColor,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.event,
            label: 'Bitiş',
            value: _formatDate(end),
            color: isSoon ? AppTheme.warningColor : AppTheme.infoColor,
          ),
          if (isValid) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Kalan Gün',
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.textSecondary),
                  ),
                ),
                Text(
                  remainingDays == 1 ? '1 gün' : '$remainingDays gün',
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
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.dividerColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isSoon ? AppTheme.warningColor : AppTheme.successColor,
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '%${(progress * 100).toStringAsFixed(0)} kaldı',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '$totalDays günün ${elapsedDays.clamp(0, totalDays)} günü kullanıldı',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ] else if (remainingDays < 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                // ignore: deprecated_member_use
                border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 16, color: AppTheme.errorColor),
                  const SizedBox(width: 8),
                  Text(
                    '${remainingDays.abs()} gün önce doldu',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.errorColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
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
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style:
                      AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
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
          Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.bodySmall
                .copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ]),
      );
}

/// ============== QR BÖLÜMÜ ==============
class _QrSection extends StatelessWidget {
  const _QrSection({
    required this.scale,
    required this.qrData,
    required this.isRefreshing,
    required this.error,
    required this.membershipActive,
    required this.onRefresh,
  });

  final Animation<double> scale;
  final QrCodeData? qrData;
  final bool isRefreshing;
  final String? error;
  final bool membershipActive;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        key: const ValueKey('home_qr_card'),
        children: [
          const Text('Giriş QR Kodu', style: AppTheme.heading3),
          const SizedBox(height: 6),
          Text(
            'Turnikede okutun',
            overflow: TextOverflow.ellipsis,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final double qrSize =
                  (c.maxWidth - 48).clamp(120.0, 220.0).toDouble();

              Widget body;

              // 🔒 Üyelik aktif değilse QR göstermeyiz
              if (!membershipActive) {
                body = SizedBox(
                  height: qrSize,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline,
                          size: 48, color: AppTheme.errorColor),
                      const SizedBox(height: 8),
                      Text(
                        'Üyeliğiniz aktif değil veya süresi dolmuş.\nQR kod oluşturulamaz.',
                        textAlign: TextAlign.center,
                        style: AppTheme.bodyMedium
                            .copyWith(color: AppTheme.errorColor),
                      ),
                    ],
                  ),
                );
              } else if (qrData != null && qrData!.isValid) {
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
                            width: 2,
                          ),
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
                      text: '${_t(qrData!.validUntil)} saatine kadar geçerli',
                    ),
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
                      Text(
                        'QR kodu oluşturulamadı',
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.bodyMedium
                            .copyWith(color: AppTheme.errorColor),
                      ),
                      TextButton(
                        onPressed: onRefresh,
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                );
              } else {
                body = SizedBox(
                  height: qrSize,
                  child: const Center(child: CircularProgressIndicator()),
                );
              }

              return body;
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: (!membershipActive || isRefreshing) ? null : onRefresh,
            icon: Icon(
              Icons.refresh,
              color: (!membershipActive || isRefreshing)
                  ? AppTheme.textSecondary
                  : AppTheme.primaryColor,
            ),
            label: Text(
              !membershipActive
                  ? 'Üyelik Gerekli'
                  : (isRefreshing ? 'Yenileniyor…' : 'QR’yi Yenile'),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: (!membershipActive || isRefreshing)
                    ? AppTheme.textSecondary
                    : AppTheme.primaryColor,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.access_time, size: 16, color: AppTheme.successColor),
          const SizedBox(width: 4),
          Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.successColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ]),
      );
}

/// ============== KART SARMALAYICI ==============
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

/// ============== KULLANIM TALİMATI ==============
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
            _Step(numLabel: '1', text: 'Girişte bu ekranı açın'),
            _Step(numLabel: '2', text: 'Telefonunuzu okuyucuya yaklaştırın'),
            _Step(numLabel: '3', text: 'Yeşil ışığı bekleyin'),
            _Step(numLabel: '4', text: 'Turnikeyi iterek içeri girin'),
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
          Text(
            'Nasıl Kullanılır',
            overflow: TextOverflow.ellipsis,
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.infoColor,
            ),
          ),
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
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                numLabel,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.infoColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
            ),
          ),
        ]),
      );
}

String _t(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// ============== EKRAN GÖRÜNTÜSÜ ÖNLEME ==============
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
            '[NoScreenshot] koruma AÇIK (Platform: ${Platform.operatingSystem})');
      }
    } catch (e) {
      debugPrint('[NoScreenshot] etkinleştirme başarısız: $e');
    }
  }

  Future<void> _disableProtection() async {
    try {
      await ScreenProtector.preventScreenshotOff();
      await ScreenProtector.protectDataLeakageOff();
      if (kDebugMode) {
        debugPrint('[NoScreenshot] koruma KAPALI');
      }
    } catch (e) {
      debugPrint('[NoScreenshot] kapatma başarısız: $e');
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
