# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]
### Added
- Venom power-up drops: V (purple, straight venom) and B (blue, ball venom) appear on the board, grant venom type + 1 segment growth when eaten
- Ball venom mode with diagonal bouncing: starts cardinal, gains diagonal velocity on first wall bounce, reflects naturally off walls/corners
- Local mode venom: venom shooting now works in offline/local mode
- 39 elm-test tests covering projectile creation, movement, wall reflection, corner bouncing, bounds safety, expiration, and game integration

### Changed
- Ball venom lifetime increased from 30 ticks (3s) to 50 ticks (5s) for longer bouncing gameplay
- Ball venom wall bounces now have a 25% chance to randomize the parallel velocity component, making trajectories less predictable
- Shoot key changed from spacebar to Shift (prevents page scroll)

### Fixed
- Ball projectile visibility: CSS `transform: scale()` animation was overriding SVG `translate()` positioning, causing ball projectiles to render at (0,0). Fixed to opacity-only animation
- Spawn wrapping: `Projectile.create` now wraps spawn position with `Grid.wrapPosition`

## [v2.1] - 2026-02-06
### Fixed
- Apple sync bug: prevent apple count growth from expired apple double-counting
- Derive maxApples from grid dimensions instead of magic number

### Added
- Mobile fullscreen layout with QR watermark
- Auto-join room when URL contains `?room=` parameter
- Apple aging lifecycle with skull penalty
- Changelog and about page with version history and credits

## [v2.0] - 2026-02-03
### Added
- Direct peer-to-peer multiplayer via WebRTC (no server needed)
- Room codes for easy game sharing
- QR code support for mobile joining
- Host migration when host leaves
- Touch controls for mobile devices
- Static build for P2P-only deployment
- Kill notifications and death point transfer
- Distinct player colors

## [v1.0] - 2017-08-15
### Added
- Phoenix server-based multiplayer
- Real-time game synchronization
- Player collision and death animations
- Live scoreboard

## [v0.1] - 2017-08-14
### Added
- Original single-player snake game
- Grid-based movement with arrow key controls
- Apple spawning and score tracking
