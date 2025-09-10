// widgets/animated_logo.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedPaySwapLogo extends StatefulWidget {
  final double size;
  final Color primaryColor;
  final Color secondaryColor;
  final bool enableTapAnimation;
  final VoidCallback? onTap;

  const AnimatedPaySwapLogo({
    Key? key,
    this.size = 40.0,
    this.primaryColor = Colors.blue,
    this.secondaryColor = Colors.white,
    this.enableTapAnimation = true,
    this.onTap,
  }) : super(key: key);

  @override
  _AnimatedPaySwapLogoState createState() => _AnimatedPaySwapLogoState();
}

class _AnimatedPaySwapLogoState extends State<AnimatedPaySwapLogo>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late AnimationController _shimmerController;
  late AnimationController _tapController;
  
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _tapScaleAnimation;
  late Animation<Color?> _tapColorAnimation;

  @override
  void initState() {
    super.initState();
    
    // Continuous rotation animation
    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    
    // Gentle scaling animation
    _scaleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    // Shimmer effect animation
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
    
    // Tap animation controller
    _tapController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
    
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOutSine,
    ));
    
    _tapScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(
      parent: _tapController,
      curve: Curves.elasticOut,
    ));
    
    _tapColorAnimation = ColorTween(
      begin: widget.primaryColor,
      end: widget.primaryColor.withOpacity(0.7),
    ).animate(CurvedAnimation(
      parent: _tapController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scaleController.dispose();
    _shimmerController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.enableTapAnimation) {
      _tapController.forward().then((_) {
        _tapController.reverse();
      });
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _rotationController,
          _scaleController,
          _shimmerController,
          _tapController,
        ]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value * _tapScaleAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: PaySwapLogoPainter(
                  rotationAngle: _rotationAnimation.value,
                  shimmerProgress: _shimmerAnimation.value,
                  primaryColor: _tapColorAnimation.value ?? widget.primaryColor,
                  secondaryColor: widget.secondaryColor,
                ),
                child: Container(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class PaySwapLogoPainter extends CustomPainter {
  final double rotationAngle;
  final double shimmerProgress;
  final Color primaryColor;
  final Color secondaryColor;

  PaySwapLogoPainter({
    required this.rotationAngle,
    required this.shimmerProgress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    
    // Save the canvas state
    canvas.save();
    
    // Draw background circle with gradient
    final backgroundPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withOpacity(0.2),
          primaryColor.withOpacity(0.1),
        ],
        stops: [0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Draw main circle border
    final borderPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    canvas.drawCircle(center, radius - 2, borderPaint);
    
    // Translate to center for easier drawing
    canvas.translate(center.dx, center.dy);
    
    // Rotate the entire logo
    canvas.rotate(rotationAngle);
    
    // Draw the swap arrows
    _drawSwapArrows(canvas, radius * 0.7);
    
    // Draw dollar signs
    _drawDollarSigns(canvas, radius * 0.4);
    
    // Draw connecting lines
    _drawConnectingLines(canvas, radius * 0.5);
    
    // Restore canvas state
    canvas.restore();
    
    // Draw shimmer effect
    _drawShimmerEffect(canvas, size);
  }
  
  void _drawSwapArrows(Canvas canvas, double radius) {
    final paint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    
    // Right arrow (clockwise)
    final rightArrowPath = Path();
    rightArrowPath.addArc(
      Rect.fromCircle(center: Offset.zero, radius: radius),
      -math.pi / 4,
      math.pi / 2,
    );
    canvas.drawPath(rightArrowPath, paint);
    
    // Right arrow head
    final rightArrowHead = Path();
    final rightEndPoint = Offset(
      radius * math.cos(math.pi / 4),
      radius * math.sin(math.pi / 4),
    );
    rightArrowHead.moveTo(rightEndPoint.dx - 8, rightEndPoint.dy - 8);
    rightArrowHead.lineTo(rightEndPoint.dx, rightEndPoint.dy);
    rightArrowHead.lineTo(rightEndPoint.dx - 8, rightEndPoint.dy + 8);
    canvas.drawPath(rightArrowHead, paint);
    
    // Left arrow (counter-clockwise)
    final leftArrowPath = Path();
    leftArrowPath.addArc(
      Rect.fromCircle(center: Offset.zero, radius: radius),
      3 * math.pi / 4,
      math.pi / 2,
    );
    canvas.drawPath(leftArrowPath, paint);
    
    // Left arrow head
    final leftArrowHead = Path();
    final leftEndPoint = Offset(
      radius * math.cos(-3 * math.pi / 4),
      radius * math.sin(-3 * math.pi / 4),
    );
    leftArrowHead.moveTo(leftEndPoint.dx + 8, leftEndPoint.dy - 8);
    leftArrowHead.lineTo(leftEndPoint.dx, leftEndPoint.dy);
    leftArrowHead.lineTo(leftEndPoint.dx + 8, leftEndPoint.dy + 8);
    canvas.drawPath(leftArrowHead, paint);
  }
  
  void _drawDollarSigns(Canvas canvas, double radius) {
    final paint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.fill;
    
    // Left dollar sign
    _drawDollarSign(canvas, Offset(-radius, 0), radius * 0.3, paint);
    
    // Right dollar sign
    _drawDollarSign(canvas, Offset(radius, 0), radius * 0.3, paint);
  }
  
  void _drawDollarSign(Canvas canvas, Offset center, double size, Paint paint) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '\$',
        style: TextStyle(
          color: paint.color,
          fontSize: size,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }
  
  void _drawConnectingLines(Canvas canvas, double radius) {
    final paint = Paint()
      ..color = primaryColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    // Draw connecting lines between dollar signs
    final leftPoint = Offset(-radius * 0.8, 0);
    final rightPoint = Offset(radius * 0.8, 0);
    
    // Upper connecting line
    final upperPath = Path();
    upperPath.moveTo(leftPoint.dx, leftPoint.dy - 5);
    upperPath.quadraticBezierTo(0, -radius * 0.3, rightPoint.dx, rightPoint.dy - 5);
    canvas.drawPath(upperPath, paint);
    
    // Lower connecting line
    final lowerPath = Path();
    lowerPath.moveTo(leftPoint.dx, leftPoint.dy + 5);
    lowerPath.quadraticBezierTo(0, radius * 0.3, rightPoint.dx, rightPoint.dy + 5);
    canvas.drawPath(lowerPath, paint);
  }
  
  void _drawShimmerEffect(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    
    if (shimmerProgress >= 0.0 && shimmerProgress <= 1.0) {
      final shimmerPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1.0, -1.0),
          end: Alignment(1.0, 1.0),
          colors: [
            Colors.transparent,
            Colors.white.withOpacity(0.3),
            Colors.transparent,
          ],
          stops: [0.0, shimmerProgress, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..blendMode = BlendMode.overlay;
      
      canvas.drawCircle(center, radius - 2, shimmerPaint);
    }
  }

  @override
  bool shouldRepaint(PaySwapLogoPainter oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle ||
           oldDelegate.shimmerProgress != shimmerProgress ||
           oldDelegate.primaryColor != primaryColor ||
           oldDelegate.secondaryColor != secondaryColor;
  }
}