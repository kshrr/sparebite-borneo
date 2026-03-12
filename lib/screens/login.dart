import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_rescue/screens/main_navigation.dart';

import '../app_colors.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool isLogin = true;
  bool isLoading = false;
  bool isPasswordVisible = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;

    // Responsive spacing based on screen height
    final topSpacing = isVerySmallScreen ? 10.0 : (isSmallScreen ? 15.0 : 20.0);
    final logoCardSpacing = isVerySmallScreen
        ? 20.0
        : (isSmallScreen ? 25.0 : 35.0);
    final bottomSpacing = isVerySmallScreen
        ? 15.0
        : (isSmallScreen ? 20.0 : 25.0);

    return Scaffold(
      body: Stack(
        children: [
          // Background with premium gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  appPrimaryGreen,
                  appPrimaryGreenLight,
                  appAccentCyan,
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.network(
                    'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800&q=80',
                    fit: BoxFit.cover,
                    color: Colors.black.withOpacity(0.25),
                    colorBlendMode: BlendMode.darken,
                    errorBuilder: (context, error, stackTrace) {
                      return Container();
                    },
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        appPrimaryGreen.withOpacity(0.88),
                        appPrimaryGreenLight.withOpacity(0.92),
                        appAccentCyan.withOpacity(0.9),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.06,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(height: topSpacing),

                                // Logo/Icon Section with Real Image
                                _buildLogoSection(
                                  isSmallScreen,
                                  isVerySmallScreen,
                                ),

                                SizedBox(height: logoCardSpacing),

                                // Main Card
                                _buildAuthCard(
                                  isSmallScreen,
                                  isVerySmallScreen,
                                ),

                                SizedBox(height: bottomSpacing),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection(bool isSmallScreen, bool isVerySmallScreen) {
    final logoSize = isVerySmallScreen ? 90.0 : (isSmallScreen ? 100.0 : 110.0);
    final titleSize = isVerySmallScreen ? 30.0 : (isSmallScreen ? 32.0 : 36.0);
    final subtitleSize = isVerySmallScreen ? 14.0 : 15.0;
    final spacing = isVerySmallScreen ? 16.0 : (isSmallScreen ? 20.0 : 24.0);

    return Column(
      children: [
        // App Logo with Real Food Image
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 25,
                offset: const Offset(0, 10),
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 3,
                ),
              ),
              child: Image.network(
                'https://images.unsplash.com/photo-1504674900247-0877df9c836a?w=400&q=80',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: appPrimaryGreen,
                    child: Icon(
                      Icons.restaurant_menu_rounded,
                      size: logoSize * 0.5,
                      color: Colors.white,
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: appPrimaryGreen,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        SizedBox(height: spacing),
        Text(
          "SpareBite",
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
            shadows: const [
              Shadow(
                color: Colors.black26,
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        SizedBox(height: isVerySmallScreen ? 4.0 : 8.0),
        Text(
          "Rescue Food, Save Lives",
          style: TextStyle(
            fontSize: subtitleSize,
            color: Colors.white.withOpacity(0.95),
            fontWeight: FontWeight.w400,
            letterSpacing: 0.8,
            shadows: const [
              Shadow(
                color: Colors.black26,
                offset: Offset(0, 1),
                blurRadius: 3,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard(bool isSmallScreen, bool isVerySmallScreen) {
    final cardPadding = isVerySmallScreen
        ? 20.0
        : (isSmallScreen ? 24.0 : 28.0);
    final iconSize = isVerySmallScreen ? 50.0 : 55.0;
    final titleSize = isVerySmallScreen ? 26.0 : (isSmallScreen ? 28.0 : 30.0);
    final subtitleSize = isVerySmallScreen ? 13.0 : 14.0;
    final iconSpacing = isVerySmallScreen
        ? 12.0
        : (isSmallScreen ? 16.0 : 20.0);
    final titleSpacing = isVerySmallScreen ? 6.0 : 8.0;
    final fieldSpacing = isVerySmallScreen
        ? 28.0
        : (isSmallScreen ? 32.0 : 36.0);
    final fieldGap = isVerySmallScreen ? 16.0 : 18.0;
    final buttonSpacing = isVerySmallScreen ? 24.0 : 28.0;
    final dividerSpacing = isVerySmallScreen ? 18.0 : 22.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 40,
            offset: const Offset(0, 20),
            spreadRadius: -5,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Decorative Icon at Top
              Center(
                child: Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: appPrimaryGreenLightBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.fastfood_rounded,
                    color: appPrimaryGreen,
                    size: iconSize * 0.5,
                  ),
                ),
              ),

              SizedBox(height: iconSpacing),

              // Title
              Text(
                isLogin ? "Welcome Back" : "Create Account",
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w800,
                  color: appTextPrimary,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: titleSpacing),

              Text(
                isLogin
                    ? "Sign in to continue your journey"
                    : "Start making a difference today",
                style: TextStyle(
                  fontSize: subtitleSize,
                  color: appTextMuted,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: fieldSpacing),

              // Email Field
              _buildCustomTextField(
                controller: emailController,
                label: "Email",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                isSmallScreen: isSmallScreen,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),

              SizedBox(height: fieldGap),

              // Password Field
              _buildPasswordField(isSmallScreen),

              SizedBox(height: buttonSpacing),

              // Login/Signup Button
              _buildAuthButton(isSmallScreen),

              SizedBox(height: dividerSpacing),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: appPrimaryGreen.withOpacity(0.2))),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isVerySmallScreen ? 12.0 : 16.0,
                    ),
                    child: Text(
                      "OR",
                      style: TextStyle(
                        color: appTextMuted,
                        fontSize: isVerySmallScreen ? 11.0 : 12.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: appPrimaryGreen.withOpacity(0.2))),
                ],
              ),

              SizedBox(height: dividerSpacing),

              // Toggle Login/Signup
              _buildToggleButton(isSmallScreen, isVerySmallScreen),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool isSmallScreen = false,
  }) {
    final fontSize = isSmallScreen ? 15.0 : 16.0;
    final labelSize = isSmallScreen ? 13.0 : 14.0;
    final verticalPadding = isSmallScreen ? 16.0 : 18.0;
    final borderRadius = isSmallScreen ? 14.0 : 16.0;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        color: appTextPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: appTextMuted,
          fontSize: labelSize,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: appPrimaryGreen),
        filled: true,
        fillColor: appSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: appPrimaryGreen.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: appPrimaryGreen.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: appPrimaryGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 18,
          vertical: verticalPadding,
        ),
      ),
    );
  }

  Widget _buildPasswordField(bool isSmallScreen) {
    final fontSize = isSmallScreen ? 15.0 : 16.0;
    final labelSize = isSmallScreen ? 13.0 : 14.0;
    final verticalPadding = isSmallScreen ? 16.0 : 18.0;
    final borderRadius = isSmallScreen ? 14.0 : 16.0;

    return TextFormField(
      controller: passwordController,
      obscureText: !isPasswordVisible,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        if (!isLogin && value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        color: appTextPrimary,
      ),
      decoration: InputDecoration(
        labelText: "Password",
        labelStyle: TextStyle(
          color: appTextMuted,
          fontSize: labelSize,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(Icons.lock_outline_rounded, color: appPrimaryGreen),
        suffixIcon: IconButton(
          icon: Icon(
            isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: appTextMuted,
          ),
          onPressed: () {
            setState(() => isPasswordVisible = !isPasswordVisible);
          },
        ),
        filled: true,
        fillColor: appSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: appPrimaryGreen.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: appPrimaryGreen.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: appPrimaryGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 18,
          vertical: verticalPadding,
        ),
      ),
    );
  }

  Widget _buildAuthButton(bool isSmallScreen) {
    final buttonHeight = isSmallScreen ? 52.0 : 56.0;
    final fontSize = isSmallScreen ? 17.0 : 18.0;
    final borderRadius = isSmallScreen ? 14.0 : 16.0;

    return Container(
      height: buttonHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: appHeroGradient,
        boxShadow: [
          BoxShadow(
            color: appPrimaryGreen.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading
              ? null
              : () {
                  if (_formKey.currentState!.validate()) {
                    authenticate();
                  }
                },
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    isLogin ? "Sign In" : "Sign Up",
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton(bool isSmallScreen, bool isVerySmallScreen) {
    final fontSize = isVerySmallScreen ? 12.0 : (isSmallScreen ? 13.0 : 14.0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            isLogin ? "Don't have an account? " : "Already have an account? ",
            style: TextStyle(color: appTextMuted, fontSize: fontSize),
            textAlign: TextAlign.center,
          ),
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              isLogin = !isLogin;
              _formKey.currentState?.reset();
            });
          },
          child: Text(
            isLogin ? "Sign Up" : "Sign In",
            style: TextStyle(
              color: appPrimaryGreen,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ================= AUTH LOGIC =================

  Future<void> authenticate() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showError("Please fill all fields");
      return;
    }

    setState(() => isLoading = true);

    try {
      UserCredential userCredential;

      if (isLogin) {
        // ---------- LOGIN ----------
        userCredential = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        // ---------- SIGN UP ----------
        userCredential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // create user profile in Firestore
        await firestore.collection("users").doc(userCredential.user!.uid).set({
          "email": email,
          "isNGO": false,
          "ngoStatus": "none", // none | pending | approved
          "createdAt": Timestamp.now(),
        });
      }

      navigateToApp();
    } on FirebaseAuthException catch (e) {
      showError(e.message ?? "Authentication error");
    }

    setState(() => isLoading = false);
  }

  // ================= NAVIGATION =================

  void navigateToApp() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigation()),
    );
  }

  // ================= ERROR =================

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}


