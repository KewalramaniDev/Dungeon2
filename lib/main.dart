import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'game.dart';
import 'background_painter.dart';
import 'constants.dart';

void main() {
  runApp(const DarknessDungeonApp());
}

class DarknessDungeonApp extends StatelessWidget {
  const DarknessDungeonApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = DungeonTheme.darkTheme;

    return MaterialApp(
      title: 'Darkness Dungeon',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        textTheme: TextTheme(
          displayLarge: GoogleFonts.pressStart2p(
            fontSize: 32,
            color: DungeonColors.textPrimary,
            shadows: [
              Shadow(
                blurRadius: 8.0,
                color: DungeonColors.primary,
                offset: const Offset(2.0, 2.0),
              ),
            ],
          ),
          bodyLarge: GoogleFonts.pressStart2p(
            fontSize: 16,
            color: DungeonColors.textSecondary,
          ),
          labelLarge: GoogleFonts.pressStart2p(
            fontSize: 18,
            color: DungeonColors.textSecondary,
          ),
        ),
      ),
      home: const StartPage(),
    );
  }
}

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomPaint(
        painter: DungeonBackgroundPainter(),
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [
                Colors.indigo.shade800.withOpacity(0.6),
                Colors.black.withOpacity(0.9),
              ],
              stops: const [0.4, 1.0],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                _buildAnimatedTitle('DARKNESS', 300),
                _buildAnimatedTitle('DUNGEON', 600),
                const SizedBox(height: 60),
                _buildMenuButton(context, 'START GAME', () {
                  // Navigate to game page
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GamePage(),
                    ),
                  );
                }),
                const SizedBox(height: 20),
                _buildMenuButton(context, 'SETTINGS', () {
                  // Open settings
                }),
                const SizedBox(height: 20),
                _buildMenuButton(context, 'EXIT', () {
                  // Exit game
                }),
                const SizedBox(height: 60),
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Text(
                        'PRESS START TO ENTER THE DARKNESS',
                        style: GoogleFonts.pressStart2p(
                          fontSize: 10,
                          color: DungeonColors.textPrimary,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedTitle(String text, int delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * -20),
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.displayLarge?.copyWith(letterSpacing: 2.0),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuButton(
      BuildContext context,
      String text,
      VoidCallback onPressed,
      ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        builder: (context, value, child) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 250,
            height: 50,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: DungeonColors.surface,
                minimumSize: const Size(250, 50),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(
                    color: DungeonColors.secondary,
                    width: 2 * value, // Animation for border thickness
                  ),
                ),
                elevation: 8 * value, // Animation for elevation
                shadowColor: DungeonColors.primary.withOpacity(0.5),
              ),
              child: Text(
                text,
                style: GoogleFonts.pressStart2p(
                  fontSize: 14,
                  color: DungeonColors.textPrimary,
                  shadows: [
                    Shadow(
                      color: DungeonColors.primary.withOpacity(value),
                      blurRadius: 8 * value,
                      offset: Offset(2 * value, 2 * value),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}