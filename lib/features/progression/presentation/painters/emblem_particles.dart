import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/models/rank_tier.dart';

/// Lightweight particle model for ambient rank emblem animations.
class EmblemParticle {
  double x; // Normalized 0.0 .. 1.0 within emblem bounds
  double y; // Normalized 0.0 .. 1.0 within emblem bounds
  double radius;
  double opacity;
  double speed;
  double angle;
  Color color;

  EmblemParticle({
    required this.x,
    required this.y,
    required this.radius,
    required this.opacity,
    required this.speed,
    required this.angle,
    required this.color,
  });
}

/// Particle emitter and updater tailored for each of the 10 rank tiers.
class EmblemParticleSystem {
  final List<EmblemParticle> particles = [];
  final RankTier tier;
  final int maxParticles;
  final Random _rng;

  EmblemParticleSystem({
    required this.tier,
    this.maxParticles = 16,
    int? seed,
  }) : _rng = Random(seed ?? 42) {
    _initParticles();
  }

  void _initParticles() {
    particles.clear();
    for (int i = 0; i < maxParticles; i++) {
      particles.add(_createParticle(initial: true));
    }
  }

  EmblemParticle _createParticle({bool initial = false}) {
    final t = initial ? _rng.nextDouble() : 0.0;
    switch (tier) {
      case RankTier.bronze:
        // Warm floating ember sparks drifting upwards
        return EmblemParticle(
          x: 0.2 + _rng.nextDouble() * 0.6,
          y: initial ? _rng.nextDouble() : 0.95,
          radius: 1.5 + _rng.nextDouble() * 2.0,
          opacity: 0.3 + _rng.nextDouble() * 0.5,
          speed: 0.15 + _rng.nextDouble() * 0.25,
          angle: -pi / 2 + (_rng.nextDouble() - 0.5) * 0.5,
          color: const Color(0xFFFFA07A),
        );

      case RankTier.silver:
        // Blue-white metallic sparkle burst
        return EmblemParticle(
          x: 0.15 + _rng.nextDouble() * 0.7,
          y: initial ? _rng.nextDouble() : 0.5 + (_rng.nextDouble() - 0.5) * 0.4,
          radius: 1.2 + _rng.nextDouble() * 1.8,
          opacity: 0.2 + _rng.nextDouble() * 0.6,
          speed: 0.2 + _rng.nextDouble() * 0.3,
          angle: _rng.nextDouble() * 2 * pi,
          color: const Color(0xFFE2E8F0),
        );

      case RankTier.gold:
        // Golden diamond sparkles
        return EmblemParticle(
          x: 0.1 + _rng.nextDouble() * 0.8,
          y: initial ? _rng.nextDouble() : 0.8,
          radius: 1.8 + _rng.nextDouble() * 2.5,
          opacity: 0.4 + _rng.nextDouble() * 0.5,
          speed: 0.1 + _rng.nextDouble() * 0.2,
          angle: -pi / 2 + (_rng.nextDouble() - 0.5) * 0.4,
          color: const Color(0xFFFFD700),
        );

      case RankTier.platinum:
        // Icy cyan energy glints
        return EmblemParticle(
          x: 0.1 + _rng.nextDouble() * 0.8,
          y: initial ? _rng.nextDouble() : _rng.nextDouble(),
          radius: 1.5 + _rng.nextDouble() * 2.2,
          opacity: 0.3 + _rng.nextDouble() * 0.6,
          speed: 0.18 + _rng.nextDouble() * 0.25,
          angle: -pi / 4 + (_rng.nextDouble() - 0.5) * 0.6,
          color: const Color(0xFFA5F3FC),
        );

      case RankTier.diamond:
        // Cyan prism refraction reflections
        return EmblemParticle(
          x: 0.15 + _rng.nextDouble() * 0.7,
          y: initial ? _rng.nextDouble() : _rng.nextDouble(),
          radius: 2.0 + _rng.nextDouble() * 2.5,
          opacity: 0.4 + _rng.nextDouble() * 0.5,
          speed: 0.12 + _rng.nextDouble() * 0.2,
          angle: _rng.nextDouble() * 2 * pi,
          color: const Color(0xFF38BDF8),
        );

      case RankTier.elite:
        // Floating purple plasma runes
        return EmblemParticle(
          x: 0.2 + _rng.nextDouble() * 0.6,
          y: initial ? _rng.nextDouble() : 0.9,
          radius: 1.8 + _rng.nextDouble() * 2.5,
          opacity: 0.35 + _rng.nextDouble() * 0.5,
          speed: 0.14 + _rng.nextDouble() * 0.2,
          angle: -pi / 2 + (_rng.nextDouble() - 0.5) * 0.3,
          color: const Color(0xFFA855F7),
        );

      case RankTier.proElite:
        // Red-gold fire corona embers
        return EmblemParticle(
          x: 0.1 + _rng.nextDouble() * 0.8,
          y: initial ? _rng.nextDouble() : 0.95,
          radius: 2.0 + _rng.nextDouble() * 3.0,
          opacity: 0.4 + _rng.nextDouble() * 0.5,
          speed: 0.25 + _rng.nextDouble() * 0.35,
          angle: -pi / 2 + (_rng.nextDouble() - 0.5) * 0.6,
          color: _rng.nextBool() ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
        );

      case RankTier.legend:
        // Royal purple and golden phoenix energy trail
        return EmblemParticle(
          x: 0.15 + _rng.nextDouble() * 0.7,
          y: initial ? _rng.nextDouble() : 0.85,
          radius: 2.2 + _rng.nextDouble() * 3.0,
          opacity: 0.45 + _rng.nextDouble() * 0.5,
          speed: 0.2 + _rng.nextDouble() * 0.3,
          angle: -pi / 2 + (_rng.nextDouble() - 0.5) * 0.7,
          color: _rng.nextBool() ? const Color(0xFFFBBF24) : const Color(0xFFC084FC),
        );

      case RankTier.master:
        // Orbiting golden crown stars
        final orbitRadius = 0.38 + _rng.nextDouble() * 0.08;
        final orbitAngle = t * 2 * pi + _rng.nextDouble() * 2 * pi;
        return EmblemParticle(
          x: 0.5 + cos(orbitAngle) * orbitRadius,
          y: 0.5 + sin(orbitAngle) * orbitRadius,
          radius: 2.0 + _rng.nextDouble() * 2.5,
          opacity: 0.5 + _rng.nextDouble() * 0.4,
          speed: 0.2 + _rng.nextDouble() * 0.2,
          angle: orbitAngle,
          color: const Color(0xFFFFD700),
        );

      case RankTier.grandMaster:
        // Mythic gold-white celestial god-ray shower
        return EmblemParticle(
          x: 0.05 + _rng.nextDouble() * 0.9,
          y: initial ? _rng.nextDouble() : 0.05,
          radius: 2.2 + _rng.nextDouble() * 3.2,
          opacity: 0.5 + _rng.nextDouble() * 0.5,
          speed: 0.3 + _rng.nextDouble() * 0.35,
          angle: pi / 2 + (_rng.nextDouble() - 0.5) * 0.3,
          color: _rng.nextBool() ? Colors.white : const Color(0xFFFFD700),
        );
    }
  }

  /// Updates particle positions based on delta time [dt] (seconds).
  void update(double dt) {
    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];
      if (tier == RankTier.master) {
        // Master stars orbit around center (0.5, 0.5)
        p.angle += p.speed * dt * 2.0;
        const double r = 0.42;
        p.x = 0.5 + cos(p.angle) * r;
        p.y = 0.5 + sin(p.angle) * r;
      } else {
        p.x += cos(p.angle) * p.speed * dt;
        p.y += sin(p.angle) * p.speed * dt;

        // Reset if drifted outside emblem bounds
        if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0) {
          particles[i] = _createParticle();
        }
      }
    }
  }
}
