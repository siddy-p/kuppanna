import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

/// The 4 canonical delivery phases shown in the tracker.
enum _Phase { pending, accepted, pickedUp, enRoute, delivered }

extension _PhaseExt on _Phase {
  String get label {
    switch (this) {
      case _Phase.pending:   return 'Order Placed';
      case _Phase.accepted:  return 'Driver Assigned';
      case _Phase.pickedUp:  return 'Food Picked Up';
      case _Phase.enRoute:   return 'On the Way';
      case _Phase.delivered: return 'Delivered!';
    }
  }

  IconData get icon {
    switch (this) {
      case _Phase.pending:   return Icons.receipt_long_rounded;
      case _Phase.accepted:  return Icons.directions_bike_rounded;
      case _Phase.pickedUp:  return Icons.fastfood_rounded;
      case _Phase.enRoute:   return Icons.local_shipping_rounded;
      case _Phase.delivered: return Icons.check_circle_rounded;
    }
  }
}

_Phase _statusToPhase(String status) {
  switch (status.toLowerCase()) {
    case 'accepted':  return _Phase.accepted;
    case 'picked_up': return _Phase.pickedUp;
    case 'en_route':  return _Phase.enRoute;
    case 'delivered': return _Phase.delivered;
    default:          return _Phase.pending;
  }
}

class TrackingScreen extends StatefulWidget {
  final DeliveryOrder order;
  const TrackingScreen({super.key, required this.order});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with SingleTickerProviderStateMixin {
  String  _status     = 'pending';
  String? _trackingUrl;
  bool    _polling    = false;
  String? _pollError;
  Timer?  _pollTimer;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _status      = widget.order.status;
    _trackingUrl = widget.order.trackingUrl;

    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Start polling every 10 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polling) return;
    setState(() { _polling = true; _pollError = null; });

    try {
      final s = await ApiService.getOrderStatus(widget.order.deliveryId);
      if (!mounted) return;
      setState(() {
        _status = s.status;
        if (s.trackingUrl != null) _trackingUrl = s.trackingUrl;
        if (_status == 'delivered') _pollTimer?.cancel();
      });
    } catch (e) {
      if (mounted) setState(() => _pollError = 'Polling error');
    } finally {
      if (mounted) setState(() => _polling = false);
    }
  }

  Future<void> _openTracking() async {
    final url = _trackingUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tracking URL not available yet')),
      );
      return;
    }
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open tracking URL')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final cs      = theme.colorScheme;
    final phase   = _statusToPhase(_status);
    final phases  = _Phase.values;
    final current = phases.indexOf(phase);
    final isDone  = phase == _Phase.delivered;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Order Tracking'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary, cs.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _poll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Header card ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDone
                      ? [Colors.green.shade700, Colors.teal.shade600]
                      : [cs.primary, cs.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, child) => Transform.scale(
                      scale: isDone ? 1.0 : (1.0 + _pulseCtrl.value * 0.08),
                      child: child,
                    ),
                    child: Icon(
                      phase.icon,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    phase.label,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Delivery ID: ${widget.order.deliveryId.substring(0, 8)}…',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                  ),
                  if (_polling)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white.withValues(alpha: 0.7)),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Phase stepper ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delivery Progress',
                      style: theme.textTheme.labelLarge?.copyWith(
                          color: cs.primary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  ...phases.asMap().entries.map((entry) {
                    final i    = entry.key;
                    final p    = entry.value;
                    final done = i <= current;
                    final isCur = i == current;
                    return _PhaseStep(
                      phase:    p,
                      isDone:   done,
                      isCurrent: isCur,
                      isLast:   i == phases.length - 1,
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Order details ────────────────────────────────────────────
            _InfoCard(
              title: 'Order Info',
              rows: [
                ('Order ID',    '${widget.order.orderId.substring(0, 8)}…'),
                ('Delivery ID', '${widget.order.deliveryId.substring(0, 8)}…'),
                ('Status',      _status),
              ],
            ),

            const SizedBox(height: 12),

            if (_pollError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_pollError!,
                    style: TextStyle(color: cs.error, fontSize: 12),
                    textAlign: TextAlign.center),
              ),

            // ── Track live button ────────────────────────────────────────
            GestureDetector(
              onTap: _openTracking,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepOrange.shade600,
                      Colors.orange.shade500,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.open_in_browser_rounded,
                        color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text('Track Live on Uber',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Refresh button ───────────────────────────────────────────
            OutlinedButton.icon(
              onPressed: _poll,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh Status'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────

class _PhaseStep extends StatelessWidget {
  final _Phase  phase;
  final bool    isDone;
  final bool    isCurrent;
  final bool    isLast;
  const _PhaseStep({
    required this.phase,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDone
                    ? (isCurrent ? cs.primary : cs.primaryContainer)
                    : cs.surfaceContainerHigh,
                shape: BoxShape.circle,
                border: Border.all(
                    color: isDone ? cs.primary : cs.outlineVariant, width: 2),
              ),
              child: Icon(
                phase.icon,
                size: 18,
                color: isDone
                    ? (isCurrent ? Colors.white : cs.onPrimaryContainer)
                    : cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: isDone ? cs.primary.withValues(alpha: 0.4) : cs.outlineVariant,
                margin: const EdgeInsets.symmetric(vertical: 2),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                phase.label,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: isDone
                      ? cs.onSurface
                      : cs.onSurface.withValues(alpha: 0.35),
                  fontSize: 14,
                ),
              ),
              if (isCurrent)
                Text('Current status',
                    style: TextStyle(
                        fontSize: 11, color: cs.primary,
                        fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String               title;
  final List<(String, String)> rows;
  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.primary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r.$1,
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 13)),
                    Text(r.$2,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
