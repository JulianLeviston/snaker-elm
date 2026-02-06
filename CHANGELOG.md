# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

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
