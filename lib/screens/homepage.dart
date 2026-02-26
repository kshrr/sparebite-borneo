import 'package:flutter/material.dart';

import '../app_colors.dart';
import 'login.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final PageController controller = PageController();
  int currentPage = 0;

  final List<_IntroPageData> pages = const [
    _IntroPageData(
      imageAsset: 'assets/images/onboarding_1.png',
      title: 'Rescue Premium Surplus',
      subtitle:
          'Turn extra meals into impact with a donor flow designed for speed and trust.',
      badge: 'Donor First',
    ),
    _IntroPageData(
      imageAsset: 'assets/images/onboarding_2.png',
      title: 'AI + Geo Matching',
      subtitle:
          'Smart pairing prioritizes NGO capacity and real map distance for faster pickups.',
      badge: 'Gemini + Maps',
    ),
    _IntroPageData(
      imageAsset: 'assets/images/onboarding_3.png',
      title: 'Track Real Outcomes',
      subtitle:
          'Monitor rescued meals, pickup success, and community support in one premium dashboard.',
      badge: 'Live Impact',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7EFE5), Color(0xFFEEDDC7)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              left: -60,
              child: _blurCircle(const Color(0x33A67C52), 220),
            ),
            Positioned(
              bottom: -90,
              right: -70,
              child: _blurCircle(const Color(0x338B5E34), 240),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: appPrimaryGreen,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.restaurant_menu_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'SpareBite',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2D3436),
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: _goToLogin,
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              color: Color(0xFF5F5F5F),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: controller,
                      itemCount: pages.length,
                      onPageChanged: (index) => setState(() => currentPage = index),
                      itemBuilder: (context, index) {
                        final page = pages[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: _IntroCard(data: page, height: size.height),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(pages.length, (index) {
                      final isActive = currentPage == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 26 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? appPrimaryGreen : Colors.black12,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 26),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (currentPage == pages.length - 1) {
                            _goToLogin();
                          } else {
                            controller.nextPage(
                              duration: const Duration(milliseconds: 450),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appPrimaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          currentPage == pages.length - 1
                              ? 'Enter SpareBite'
                              : 'Continue',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blurCircle(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthPage()),
    );
  }
}

class _IntroPageData {
  const _IntroPageData({
    required this.imageAsset,
    required this.title,
    required this.subtitle,
    required this.badge,
  });

  final String imageAsset;
  final String title;
  final String subtitle;
  final String badge;
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.data, required this.height});

  final _IntroPageData data;
  final double height;

  @override
  Widget build(BuildContext context) {
    final imageHeight = height < 700 ? 210.0 : 260.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.white.withValues(alpha: 0.92),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: appPrimaryGreenLightBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              data.badge,
              style: TextStyle(
                color: appPrimaryGreen,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: imageHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Image.asset(
                data.imageAsset,
                fit: BoxFit.contain,
                errorBuilder: (_, error, stackTrace) => Icon(
                  Icons.delivery_dining_rounded,
                  size: imageHeight * 0.6,
                  color: appPrimaryGreen,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Text(
              data.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2D3436),
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              data.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                color: Color(0xFF666666),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}
