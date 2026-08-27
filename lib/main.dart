import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

void main() => runApp(const BrickBreakerApp());

class BrickBreakerApp extends StatelessWidget {
  const BrickBreakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Brick Breaker',
      theme: ThemeData.dark(useMaterial3: true),
      home: const BrickBreakerPage(),
    );
  }
}

class BrickBreakerPage extends StatefulWidget {
  const BrickBreakerPage({super.key});

  @override
  State<BrickBreakerPage> createState() => _BrickBreakerPageState();
}

enum GameStatus { ready, playing, won, lost }

class Brick {
  Brick(this.rect, this.color);

  final Rect rect;
  final Color color;
  bool active = true;
}

class _BrickBreakerPageState extends State<BrickBreakerPage> {
  static const double worldWidth = 400;
  static const double worldHeight = 700;
  static const double paddleWidth = 92;
  static const double paddleHeight = 14;
  static const double ballRadius = 8;

  final Stopwatch _clock = Stopwatch();
  Timer? _timer;
  late List<Brick> _bricks;
  Offset _ball = const Offset(worldWidth / 2, 610);
  Offset _velocity = const Offset(175, -260);
  double _paddleX = (worldWidth - paddleWidth) / 2;
  Duration _lastFrame = Duration.zero;
  GameStatus _status = GameStatus.ready;
  int _score = 0;
  int _lives = 3;

  @override
  void initState() {
    super.initState();
    _bricks = _makeBricks();
    _clock.start();
    _timer = Timer.periodic(const Duration(milliseconds: 16), _tick);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clock.stop();
    super.dispose();
  }

  List<Brick> _makeBricks() {
    const columns = 7;
    const rows = 6;
    const gap = 6.0;
    const side = 18.0;
    const top = 95.0;
    final width = (worldWidth - side * 2 - gap * (columns - 1)) / columns;
    const colors = [
      Color(0xFFFF5C7A),
      Color(0xFFFF8A5B),
      Color(0xFFFFC857),
      Color(0xFF63D2A1),
      Color(0xFF52B7FF),
      Color(0xFF9A7BFF),
    ];

    return [
      for (var row = 0; row < rows; row++)
        for (var column = 0; column < columns; column++)
          Brick(
            Rect.fromLTWH(
              side + column * (width + gap),
              top + row * 29,
              width,
              21,
            ),
            colors[row],
          ),
    ];
  }

  void _tick(Timer _) {
    final now = _clock.elapsed;
    final rawDt = (now - _lastFrame).inMicroseconds / 1000000;
    _lastFrame = now;
    if (!mounted || _status != GameStatus.playing) return;

    final dt = rawDt.clamp(0.0, 0.032).toDouble();
    setState(() => _update(dt));
  }

  void _update(double dt) {
    var next = _ball + _velocity * dt;

    if (next.dx - ballRadius <= 0 || next.dx + ballRadius >= worldWidth) {
      _velocity = Offset(-_velocity.dx, _velocity.dy);
      next = Offset(
        next.dx.clamp(ballRadius, worldWidth - ballRadius).toDouble(),
        next.dy,
      );
    }
    if (next.dy - ballRadius <= 0) {
      _velocity = Offset(_velocity.dx, _velocity.dy.abs());
      next = Offset(next.dx, ballRadius);
    }

    final paddle = Rect.fromLTWH(_paddleX, 630, paddleWidth, paddleHeight);
    if (_velocity.dy > 0 && _circleHitsRect(next, ballRadius, paddle)) {
      final hit = ((next.dx - paddle.center.dx) / (paddleWidth / 2))
          .clamp(-1.0, 1.0)
          .toDouble();
      final speed = math.max(315.0, _velocity.distance).toDouble();
      _velocity = Offset(speed * hit * 0.78, -speed * (1 - hit.abs() * 0.2));
      next = Offset(next.dx, paddle.top - ballRadius);
    }

    for (final brick in _bricks) {
      if (!brick.active || !_circleHitsRect(next, ballRadius, brick.rect)) continue;
      brick.active = false;
      _score += 100;
      final previous = _ball;
      final crossedTopOrBottom = previous.dy + ballRadius <= brick.rect.top ||
          previous.dy - ballRadius >= brick.rect.bottom;
      _velocity = crossedTopOrBottom
          ? Offset(_velocity.dx, -_velocity.dy)
          : Offset(-_velocity.dx, _velocity.dy);
      break;
    }

    _ball = next;
    if (_bricks.every((brick) => !brick.active)) {
      _status = GameStatus.won;
    } else if (_ball.dy - ballRadius > worldHeight) {
      _lives--;
      if (_lives <= 0) {
        _status = GameStatus.lost;
      } else {
        _resetBall();
      }
    }
  }

  bool _circleHitsRect(Offset center, double radius, Rect rect) {
    final nearestX = center.dx.clamp(rect.left, rect.right);
    final nearestY = center.dy.clamp(rect.top, rect.bottom);
    final dx = center.dx - nearestX;
    final dy = center.dy - nearestY;
    return dx * dx + dy * dy <= radius * radius;
  }

  void _resetBall() {
    _status = GameStatus.ready;
    _ball = Offset(_paddleX + paddleWidth / 2, 610);
    _velocity = const Offset(175, -260);
  }

  void _restart() {
    setState(() {
      _score = 0;
      _lives = 3;
      _paddleX = (worldWidth - paddleWidth) / 2;
      _bricks = _makeBricks();
      _resetBall();
    });
  }

  void _tap() {
    if (_status == GameStatus.ready) {
      setState(() => _status = GameStatus.playing);
    } else if (_status == GameStatus.won || _status == GameStatus.lost) {
      _restart();
    }
  }

  void _movePaddle(double localX, double renderedWidth) {
    final worldX = localX / renderedWidth * worldWidth;
    setState(() {
      _paddleX = (worldX - paddleWidth / 2)
          .clamp(0, worldWidth - paddleWidth)
          .toDouble();
      if (_status == GameStatus.ready) {
        _ball = Offset(_paddleX + paddleWidth / 2, 610);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B16),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AspectRatio(
              aspectRatio: worldWidth / worldHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _tap,
                    onPanDown: (details) =>
                        _movePaddle(details.localPosition.dx, constraints.maxWidth),
                    onPanUpdate: (details) =>
                        _movePaddle(details.localPosition.dx, constraints.maxWidth),
                    child: CustomPaint(
                      painter: GamePainter(
                        bricks: _bricks,
                        ball: _ball,
                        paddleX: _paddleX,
                        score: _score,
                        lives: _lives,
                        status: _status,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GamePainter extends CustomPainter {
  GamePainter({
    required this.bricks,
    required this.ball,
    required this.paddleX,
    required this.score,
    required this.lives,
    required this.status,
  });

  final List<Brick> bricks;
  final Offset ball;
  final double paddleX;
  final int score;
  final int lives;
  final GameStatus status;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / _BrickBreakerPageState.worldWidth;
    final scaleY = size.height / _BrickBreakerPageState.worldHeight;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    final board = Rect.fromLTWH(0, 0, _BrickBreakerPageState.worldWidth,
        _BrickBreakerPageState.worldHeight);
    canvas.drawRRect(
      RRect.fromRectAndRadius(board, const Radius.circular(24)),
      Paint()..color = const Color(0xFF10162A),
    );

    _text(canvas, 'BRICK BREAKER', const Offset(18, 18), 18, Colors.white,
        FontWeight.w800);
    _text(canvas, 'SCORE  $score', const Offset(18, 51), 13,
        const Color(0xFF9BA7C7), FontWeight.w600);
    _text(canvas, 'LIVES  $lives', const Offset(307, 51), 13,
        const Color(0xFF9BA7C7), FontWeight.w600);

    for (final brick in bricks.where((brick) => brick.active)) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(brick.rect, const Radius.circular(5)),
        Paint()..color = brick.color,
      );
    }

    final paddle = Rect.fromLTWH(paddleX, 630,
        _BrickBreakerPageState.paddleWidth, _BrickBreakerPageState.paddleHeight);
    canvas.drawRRect(
      RRect.fromRectAndRadius(paddle, const Radius.circular(8)),
      Paint()..color = const Color(0xFFEAF0FF),
    );
    canvas.drawCircle(
      ball,
      _BrickBreakerPageState.ballRadius,
      Paint()..color = const Color(0xFF8DEBFF),
    );

    if (status != GameStatus.playing) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(54, 300, 292, 125),
          const Radius.circular(18),
        ),
        Paint()..color = const Color(0xE6192038),
      );
      final title = switch (status) {
        GameStatus.ready => 'READY?',
        GameStatus.won => 'YOU WIN!',
        GameStatus.lost => 'GAME OVER',
        GameStatus.playing => '',
      };
      final subtitle = status == GameStatus.ready
          ? 'Tap to launch • Drag to move'
          : 'Tap to play again';
      _centeredText(canvas, title, 329, 28, Colors.white, FontWeight.w900);
      _centeredText(canvas, subtitle, 377, 14, const Color(0xFFB7C3E3),
          FontWeight.w500);
    }
    canvas.restore();
  }

  void _text(Canvas canvas, String text, Offset position, double size,
      Color color, FontWeight weight) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size, color: color, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, position);
  }

  void _centeredText(Canvas canvas, String text, double y, double size,
      Color color, FontWeight weight) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size, color: color, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset((_BrickBreakerPageState.worldWidth - painter.width) / 2, y),
    );
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
