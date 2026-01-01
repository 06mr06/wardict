import 'package:flutter/material.dart';

class VsScreen extends StatefulWidget {
  final VoidCallback onAnimationComplete;
  final String userAvatarUrl; // Placeholder for now, could be asset path
  final String botAvatarUrl;
  final String userName;
  final String botName;

  const VsScreen({
    super.key,
    required this.onAnimationComplete,
    this.userAvatarUrl = 'assets/images/avatar_user.png', // Placeholder
    this.botAvatarUrl = 'assets/images/avatar_bot.png',   // Placeholder
    this.userName = 'You',
    this.botName = 'Bot',
  });

  @override
  State<VsScreen> createState() => _VsScreenState();
}

class _VsScreenState extends State<VsScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideInLeft;
  late Animation<double> _slideInRight;
  late Animation<double> _scaleVs;
  late Animation<double> _shakeVs;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // VS Logo Impact - FIRST
    _scaleVs = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
      ),
    );

    // Avatars sliding in - SECOND
    _slideInLeft = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _slideInRight = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward().then((_) {
      // Wait a bit then finish
      Future.delayed(const Duration(seconds: 1), widget.onAnimationComplete);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Assuming full screen overlay
    return Material(
      color: Colors.black, // Fully opaque background
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dynamic Background (Spinning rays or similar could go here)
          
          // Left Player (User)
          AnimatedBuilder(
            animation: _slideInLeft,
            builder: (context, child) {
              final width = MediaQuery.of(context).size.width;
              return Transform.translate(
                offset: Offset(_slideInLeft.value * width / 2, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    heightFactor: 1.0,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF2AA7FF), Colors.blueAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white,
                            child: widget.userAvatarUrl.startsWith('assets')
                                ? ClipOval(child: Image.asset(widget.userAvatarUrl, width: 120, height: 120, fit: BoxFit.cover))
                                : Text(widget.userAvatarUrl, style: const TextStyle(fontSize: 48)),
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  shadows: [Shadow(blurRadius: 10, color: Colors.blue)],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Right Player (Bot)
          AnimatedBuilder(
            animation: _slideInRight,
            builder: (context, child) {
              final width = MediaQuery.of(context).size.width;
              return Transform.translate(
                offset: Offset(_slideInRight.value * width / 2, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    heightFactor: 1.0,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF9800), Colors.deepOrange],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white,
                            child: widget.botAvatarUrl.startsWith('assets')
                                ? ClipOval(child: Image.asset(widget.botAvatarUrl, width: 120, height: 120, fit: BoxFit.cover))
                                : Text(widget.botAvatarUrl, style: const TextStyle(fontSize: 48)),
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.botName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  shadows: [Shadow(blurRadius: 10, color: Colors.orange)],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // VS Text
          Center(
            child: AnimatedBuilder(
              animation: _scaleVs,
              builder: (context, child) {
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Transform.scale(
                    scale: _scaleVs.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.5),
                            blurRadius: 50,
                            spreadRadius: 10,
                          )
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/vs_icon.png', // Needs asset or flutter text
                        errorBuilder: (c, e, s) => Container(
                          decoration: const BoxDecoration(
                             gradient: LinearGradient(colors: [Colors.purple, Colors.red]),
                             shape: BoxShape.circle
                          ),
                          child: const Center(
                            child: Text(
                              "VS",
                              style: TextStyle(
                                fontSize: 60, 
                                fontWeight: FontWeight.w900, 
                                color: Colors.white,
                                fontStyle: FontStyle.italic
                              )
                            )
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
}
