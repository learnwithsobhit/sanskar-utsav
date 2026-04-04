import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';

/// Reads `?t=` from the current URL on web (invite deep link).
String? joinInviteTokenFromPlatformUri() {
  try {
    final u = Uri.base;
    if (!u.path.contains('join')) return null;
    final t = u.queryParameters['t'];
    if (t == null || t.isEmpty) return null;
    return t;
  } catch (_) {
    return null;
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialInviteToken});

  /// Opaque token from `/join?t=...` deep link.
  final String? initialInviteToken;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _tokenController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _error;
  bool _useInviteLink = false;
  bool _otpStep = false;
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    final fromUri = joinInviteTokenFromPlatformUri();
    if (widget.initialInviteToken != null && widget.initialInviteToken!.isNotEmpty) {
      _tokenController.text = widget.initialInviteToken!;
      _useInviteLink = true;
    } else if (fromUri != null) {
      _tokenController.text = fromUri;
      _useInviteLink = true;
    }
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _tokenController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handlePrimarySubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);

    final auth = context.read<AuthService>();

    if (_otpStep) {
      final err = await auth.verifyOtp(
        phoneE164: _phoneController.text.trim(),
        otp: _otpController.text.trim(),
        inviteToken: _useInviteLink ? _tokenController.text.trim() : null,
        inviteCode: _useInviteLink ? null : _codeController.text.trim(),
      );
      if (!mounted) return;
      if (err == null) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() => _error = err);
      }
      return;
    }

    if (_useInviteLink) {
      final token = _tokenController.text.trim();
      if (token.isEmpty) {
        setState(() => _error = 'Paste your invite link token or open the invite link again.');
        return;
      }
      final (outcome, err) = await auth.redeemInviteToken(token);
      if (!mounted) return;
      if (outcome == AuthLoginOutcome.success) {
        Navigator.pushReplacementNamed(context, '/home');
        return;
      }
      if (outcome == AuthLoginOutcome.otpRequired) {
        setState(() {
          _otpStep = true;
          _error = null;
        });
        return;
      }
      setState(() => _error = err ?? 'Could not sign in');
      return;
    }

    final (outcome, err) = await auth.loginWithInviteCode(_codeController.text.trim());
    if (!mounted) return;
    if (outcome == AuthLoginOutcome.success) {
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }
    if (outcome == AuthLoginOutcome.otpRequired) {
      setState(() {
        _otpStep = true;
        _error = null;
      });
      return;
    }
    setState(() => _error = err ?? 'Login failed');
  }

  Future<void> _requestOtp() async {
    setState(() => _error = null);
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || !phone.startsWith('+')) {
      setState(() => _error = 'Enter phone in E.164 format (e.g. +9198xxxxxxx)');
      return;
    }
    final auth = context.read<AuthService>();
    final err = await auth.requestOtp(
      phoneE164: phone,
      inviteToken: _useInviteLink ? _tokenController.text.trim() : null,
      inviteCode: _useInviteLink ? null : _codeController.text.trim(),
    );
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('If SMS is enabled, check your phone for the code.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: SanskarTheme.sacredGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: SanskarTheme.gold.withAlpha(120),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Text('🪔', style: TextStyle(fontSize: 36)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: SanskarTheme.gold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _otpStep
                          ? 'Enter the phone number your host registered and the SMS code.'
                          : 'Use your invite link, or enter the invite code you received.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withAlpha(200),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!_otpStep) ...[
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Invite code'), icon: Icon(Icons.pin_outlined)),
                          ButtonSegment(value: true, label: Text('Invite link'), icon: Icon(Icons.link)),
                        ],
                        selected: {_useInviteLink},
                        onSelectionChanged: (s) {
                          setState(() {
                            _useInviteLink = s.first;
                            _error = null;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: SanskarTheme.radiusLg,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(40),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_otpStep) ...[
                              Text(
                                'Phone (E.164)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: SanskarTheme.darkCharcoal.withAlpha(180),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  hintText: '+9198xxxxxxx',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  if (!v.trim().startsWith('+')) return 'Include country code with +';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: auth.isLoading ? null : _requestOtp,
                                icon: const Icon(Icons.sms_outlined),
                                label: const Text('Send SMS code'),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '6-digit code',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: SanskarTheme.darkCharcoal.withAlpha(180),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                decoration: const InputDecoration(
                                  hintText: '______',
                                  counterText: '',
                                  prefixIcon: Icon(Icons.password_outlined),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().length < 6) return 'Enter the 6-digit code';
                                  return null;
                                },
                              ),
                            ] else if (_useInviteLink) ...[
                              Text(
                                'Invite token',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: SanskarTheme.darkCharcoal.withAlpha(180),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _tokenController,
                                maxLines: 2,
                                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                                decoration: const InputDecoration(
                                  hintText: 'Pasted from invite link …',
                                  prefixIcon: Icon(Icons.link),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Open your invite link or paste the token';
                                  }
                                  return null;
                                },
                              ),
                            ] else ...[
                              Text(
                                'Invite Code',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: SanskarTheme.darkCharcoal.withAlpha(180),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _codeController,
                                textCapitalization: TextCapitalization.characters,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'e.g. SHRI1234',
                                  prefixIcon: Icon(
                                    Icons.vpn_key_rounded,
                                    color: SanskarTheme.saffron.withAlpha(180),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Please enter your invite code';
                                  }
                                  return null;
                                },
                              ),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: SanskarTheme.vermillion.withAlpha(20),
                                  borderRadius: SanskarTheme.radiusSm,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        size: 18, color: SanskarTheme.vermillion),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: SanskarTheme.vermillion,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: auth.isLoading ? null : _handlePrimarySubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: SanskarTheme.saffron,
                                ),
                                child: auth.isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation(Colors.white),
                                        ),
                                      )
                                    : Text(
                                        _otpStep ? 'Verify & enter' : 'Enter Celebration 🙏',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            if (_otpStep) ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _otpStep = false;
                                    _error = null;
                                  });
                                },
                                child: const Text('Back'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '🙏 शुभम् भवतु 🙏',
                      style: TextStyle(
                        fontSize: 14,
                        color: SanskarTheme.gold.withAlpha(180),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
