import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'tracking_screen.dart';

// Mock menu items for the restaurant
const _menuItems = [
  _MenuItem('Chicken Biryani',       1299),
  _MenuItem('Lamb Rogan Josh',       1499),
  _MenuItem('Garlic Naan × 2',       399),
  _MenuItem('Mango Lassi',           299),
];

class _MenuItem {
  final String name;
  final int pricePence;
  const _MenuItem(this.name, this.pricePence);
}

const _restaurantAddress = '15 Drummond Street, London, NW1 2QB, GB';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with TickerProviderStateMixin {
  // ── Form fields ───────────────────────────────────────────────────────────
  final _formKey          = GlobalKey<FormState>();
  final _addressCtrl      = TextEditingController(text: '10 Downing Street, London, SW1A 2AA, GB');
  final _nameCtrl         = TextEditingController(text: 'Test Customer');
  final _phoneCtrl        = TextEditingController(text: '+447700900000');
  final _emailCtrl        = TextEditingController(text: 'test@kuppanna.com');

  // ── Quote state ───────────────────────────────────────────────────────────
  DeliveryQuote? _quote;
  bool           _fetchingQuote = false;
  bool           _placingOrder  = false;
  String?        _errorMessage;

  // ── Countdown timer ───────────────────────────────────────────────────────
  Timer?         _countdownTimer;
  int            _secondsLeft = 0;
  late final AnimationController _progressAnimCtrl;

  int get _totalPence =>
      _menuItems.fold(0, (sum, item) => sum + item.pricePence);

  String _formatPrice(int pence) =>
      '£${(pence / 100).toStringAsFixed(2)}';

  @override
  void initState() {
    super.initState();
    _progressAnimCtrl = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _countdownTimer?.cancel();
    _progressAnimCtrl.dispose();
    super.dispose();
  }

  // ── Quote expiry countdown ────────────────────────────────────────────────
  void _startCountdown(int totalSeconds) {
    _countdownTimer?.cancel();
    setState(() => _secondsLeft = totalSeconds);
    _progressAnimCtrl.value = 1.0;
    _progressAnimCtrl.animateTo(
      0.0,
      duration: Duration(seconds: totalSeconds),
      curve: Curves.linear,
    );
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          t.cancel();
          _quote = null;
        }
      });
    });
  }

  String _formatCountdown(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  // ── Fetch quote ───────────────────────────────────────────────────────────
  Future<void> _fetchQuote() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _fetchingQuote = true;
      _errorMessage  = null;
      _quote         = null;
    });
    _countdownTimer?.cancel();

    try {
      final q = await ApiService.fetchQuote(
        pickupAddress:  _restaurantAddress,
        dropoffAddress: _addressCtrl.text.trim(),
      );
      setState(() => _quote = q);
      _startCountdown(15 * 60); // 15-minute expiry
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Network error: $e');
    } finally {
      setState(() => _fetchingQuote = false);
    }
  }

  // ── Place order ───────────────────────────────────────────────────────────
  Future<void> _placeOrder() async {
    if (_quote == null) return;

    setState(() { _placingOrder = true; _errorMessage = null; });

    try {
      final order = await ApiService.createDelivery(
        quoteId:        _quote!.quoteId,
        customerName:   _nameCtrl.text.trim(),
        customerPhone:  _phoneCtrl.text.trim(),
        customerEmail:  _emailCtrl.text.trim().isNotEmpty
            ? _emailCtrl.text.trim() : null,
        pickupAddress:  _restaurantAddress,
        dropoffAddress: _addressCtrl.text.trim(),
        feeAmount:      _quote!.fee,
        feeCurrency:    _quote!.currency,
      );
      _countdownTimer?.cancel();
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrackingScreen(order: order),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Network error: $e');
    } finally {
      if (mounted) setState(() => _placingOrder = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text("Kuppanna's"),
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Order summary card ─────────────────────────────────────────
            _SectionCard(
              title: 'Your Order',
              icon: Icons.restaurant_menu_rounded,
              child: Column(
                children: [
                  ..._menuItems.map((item) => _OrderRow(
                    name:  item.name,
                    price: _formatPrice(item.pricePence),
                  )),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(_formatPrice(_totalPence),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                          )),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Pickup address ─────────────────────────────────────────────
            _SectionCard(
              title: 'Pickup',
              icon: Icons.store_rounded,
              child: Row(
                children: [
                  Icon(Icons.location_on, color: cs.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _restaurantAddress,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Delivery address ───────────────────────────────────────────
            _SectionCard(
              title: 'Delivery Details',
              icon: Icons.delivery_dining_rounded,
              child: Column(
                children: [
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Drop-off Address',
                      hintText:  'e.g. 10 Downing St, London',
                      prefixIcon: Icon(Icons.home_rounded),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Address required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Your Name',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone (E.164)',
                      hintText:  '+447700900000',
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Phone required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                      prefixIcon: Icon(Icons.email_rounded),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Error message ──────────────────────────────────────────────
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: cs.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: cs.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Quote result card ──────────────────────────────────────────
            if (_quote != null) ...[
              _QuoteCard(
                quote:        _quote!,
                secondsLeft:  _secondsLeft,
                formatTimer:  _formatCountdown,
                progressAnim: _progressAnimCtrl,
              ),
              const SizedBox(height: 12),
            ],

            // ── Fetch estimate button ──────────────────────────────────────
            _GradientButton(
              onPressed: _fetchingQuote ? null : _fetchQuote,
              label: _fetchingQuote
                  ? 'Getting Estimate…'
                  : (_quote != null ? '↺ Refresh Estimate' : 'Fetch Delivery Estimate'),
              icon: Icons.local_shipping_rounded,
              loading: _fetchingQuote,
            ),

            const SizedBox(height: 10),

            // ── Place order button ─────────────────────────────────────────
            _GradientButton(
              onPressed: (_quote != null && _secondsLeft > 0 && !_placingOrder)
                  ? _placeOrder
                  : null,
              label: _placingOrder ? 'Placing Order…' : 'Place Delivery Order',
              icon: Icons.check_circle_rounded,
              loading: _placingOrder,
              gradient: LinearGradient(
                colors: [Colors.green.shade700, Colors.teal.shade600],
              ),
            ),

            if (_quote != null && _secondsLeft <= 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Quote expired — please fetch a new estimate.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.error, fontSize: 12),
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

class _SectionCard extends StatelessWidget {
  final String  title;
  final IconData icon;
  final Widget  child;
  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: cs.primary, size: 18),
            const SizedBox(width: 6),
            Text(title,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final String name;
  final String price;
  const _OrderRow({required this.name, required this.price});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: Theme.of(context).textTheme.bodyMedium),
          Text(price,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final DeliveryQuote     quote;
  final int               secondsLeft;
  final String Function(int) formatTimer;
  final AnimationController progressAnim;
  const _QuoteCard({
    required this.quote,
    required this.secondsLeft,
    required this.formatTimer,
    required this.progressAnim,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isExpiring = secondsLeft < 60;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.tertiaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Delivery Estimate',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700, color: cs.onPrimaryContainer)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isExpiring ? Colors.red.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  formatTimer(secondsLeft),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isExpiring ? Colors.red.shade700 : cs.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _QuoteStat(label: 'Fee',  value: quote.formattedFee),
              const SizedBox(width: 24),
              _QuoteStat(label: 'ETA',  value: quote.formattedEta),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: progressAnim,
            builder: (_, _) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressAnim.value,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation(
                    isExpiring ? Colors.red : cs.primary),
                minHeight: 5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteStat extends StatelessWidget {
  final String label;
  final String value;
  const _QuoteStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer.withValues(alpha: 0.7))),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: cs.onPrimaryContainer)),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String        label;
  final IconData      icon;
  final bool          loading;
  final Gradient?     gradient;

  const _GradientButton({
    required this.onPressed,
    required this.label,
    required this.icon,
    this.loading = false,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grad = gradient ??
        LinearGradient(colors: [cs.primary, cs.tertiary]);
    final disabled = onPressed == null;

    return GestureDetector(
      onTap: disabled ? null : onPressed,
      child: AnimatedOpacity(
        opacity: disabled ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: disabled ? null : grad,
            color: disabled ? cs.surfaceContainerHigh : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: disabled
                ? []
                : [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
              else
                Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
