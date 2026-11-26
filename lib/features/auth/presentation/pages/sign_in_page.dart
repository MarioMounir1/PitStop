import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pitstop/core/theme/app_colors.dart';
import 'package:pitstop/core/widgets/pitstop_logo_widget.dart';
import 'package:pitstop/features/auth/cubit/auth_cubit.dart';
import 'package:pitstop/features/auth/cubit/auth_state.dart';

enum _AuthMode { signIn, signUp }

/// Dark Automotive Material 3 Sign-In & Sign-Up page with Email/Password,
/// Google Sign-In, Password Reset, and Guest (Offline) options.
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<AuthCubit>();

    final bool ok;
    if (_mode == _AuthMode.signIn) {
      ok = await cubit.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      ok = await cubit.signUpWithEmail(
        displayName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }

    if (ok && context.mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/dashboard');
      }
    }
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    final ok = await context.read<AuthCubit>().signInWithGoogle();
    if (ok && context.mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/dashboard');
      }
    }
  }

  Future<void> _continueAsGuest(BuildContext context) async {
    await context.read<AuthCubit>().continueAsGuest();
    if (context.mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/dashboard');
      }
    }
  }

  Future<void> _showForgotPasswordDialog(BuildContext context) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final resetController = TextEditingController(
      text: _emailController.text.trim(),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isArabic ? 'استعادة كلمة المرور' : 'Reset Password'),
        content: TextField(
          controller: resetController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: isArabic ? 'البريد الإلكتروني' : 'Email Address',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(isArabic ? 'إرسال' : 'Send Link'),
          ),
        ],
      ),
    );

    final email = resetController.text.trim();
    resetController.dispose();

    if (confirmed == true && email.isNotEmpty && context.mounted) {
      await context.read<AuthCubit>().sendPasswordReset(email);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final colors = context.appColors;

    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (prev, curr) =>
          (curr.error != null && curr.error != prev.error) ||
          (curr.statusMessage != null &&
              curr.statusMessage != prev.statusMessage),
      listener: (context, state) {
        final msg = state.error ?? state.statusMessage;
        if (msg != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
          context.read<AuthCubit>().clearMessages();
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _mode == _AuthMode.signIn
                  ? (isArabic ? 'تسجيل الدخول' : 'Sign In')
                  : (isArabic ? 'إنشاء حساب' : 'Create Account'),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Header
                    const Center(child: PitStopIconBadge(size: 84)),
                    const SizedBox(height: 14),
                    Center(
                      child: PitStopWordmark(
                        fontSize: 28,
                        tagline: isArabic
                            ? 'الصيانة والوقود والمصاريف'
                            : 'Maintenance, fuel and costs',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isArabic
                          ? 'سجّل الدخول لمزامنة سياراتك وصياناتك بأمان على السحابة'
                          : 'Sign in to sync your garage, maintenance & fuel logs to the cloud',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 22),

                    // Sign In / Create Account toggle
                    SegmentedButton<_AuthMode>(
                      segments: [
                        ButtonSegment(
                          value: _AuthMode.signIn,
                          label: Text(isArabic ? 'تسجيل الدخول' : 'Sign In'),
                        ),
                        ButtonSegment(
                          value: _AuthMode.signUp,
                          label: Text(isArabic ? 'حساب جديد' : 'Create Account'),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (selection) {
                        setState(() => _mode = selection.first);
                      },
                    ),
                    const SizedBox(height: 18),

                    if (_mode == _AuthMode.signUp) ...[
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: isArabic ? 'الاسم الكامل' : 'Full Name',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? (isArabic ? 'أدخل اسمك' : 'Enter your name')
                            : null,
                      ),
                      const SizedBox(height: 14),
                    ],

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText:
                            isArabic ? 'البريد الإلكتروني' : 'Email Address',
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        final text = v?.trim() ?? '';
                        if (text.isEmpty || !text.contains('@')) {
                          return isArabic
                              ? 'أدخل بريداً إلكترونياً صالحاً'
                              : 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'كلمة المرور' : 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.length < 6) {
                          return isArabic
                              ? '6 أحرف على الأقل'
                              : 'At least 6 characters';
                        }
                        return null;
                      },
                    ),

                    if (_mode == _AuthMode.signIn)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: state.isLoading
                              ? null
                              : () => _showForgotPasswordDialog(context),
                          child: Text(
                            isArabic ? 'نسيت كلمة المرور؟' : 'Forgot Password?',
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 18),

                    // Primary Submit Button
                    FilledButton(
                      onPressed: state.isLoading
                          ? null
                          : () => _submitEmail(context),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: state.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _mode == _AuthMode.signIn
                                  ? (isArabic ? 'تسجيل الدخول' : 'Sign In')
                                  : (isArabic
                                      ? 'إنشاء الحساب'
                                      : 'Create Account'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: colors.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            isArabic ? 'أو' : 'OR',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: colors.textMuted),
                          ),
                        ),
                        Expanded(child: Divider(color: colors.border)),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Continue with Google
                    OutlinedButton.icon(
                      onPressed: state.isLoading
                          ? null
                          : () => _signInWithGoogle(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                      label: Text(
                        isArabic
                            ? 'المتابعة باستخدام Google'
                            : 'Continue with Google',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Continue as Guest (Anonymous / Offline)
                    TextButton.icon(
                      onPressed: state.isLoading
                          ? null
                          : () => _continueAsGuest(context),
                      icon: const Icon(Icons.person_off_outlined, size: 19),
                      label: Text(
                        isArabic
                            ? 'المتابعة كضيف (بدون حساب)'
                            : 'Continue as Guest (Offline)',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
