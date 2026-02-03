---
phase: 07-migration-polish
plan: 02
title: "Room Sharing UI"
subsystem: ui
tags: [qr-code, clipboard, sharing, elm, typescript]

dependency-graph:
  requires: [05-01, 06-01]  # P2P connection layer, host game setup
  provides:
    - "QR code generation for room URLs"
    - "Copy room code functionality"
    - "Copy room URL functionality"
    - "ShareUI component"
  affects: []  # Final plan in roadmap

tech-stack:
  added: ["qrcode@1.5.4"]
  patterns: ["Elm ports for QR generation", "Flags for base URL injection"]

files:
  created:
    - assets/js/qr-generator.ts
    - assets/src/View/ShareUI.elm
  modified:
    - assets/package.json
    - assets/js/app.ts
    - assets/src/Ports.elm
    - assets/src/Main.elm
    - assets/css/app.css

decisions: []

metrics:
  duration: "5 min"
  completed: "2026-02-03"
---

# Phase 07 Plan 02: Room Sharing UI Summary

Room sharing with copy buttons and QR code via qrcode npm library

## What Was Built

### QR Code Generation Port
- Installed `qrcode@1.5.4` npm package
- Created `qr-generator.ts` with `setupQRPorts` function
- Added `generateQRCode` (outgoing) and `qrCodeGenerated` (incoming) ports
- QR code generates at 256x256 pixels with medium error correction

### ShareUI Component
- New `View/ShareUI.elm` module with `CopyState` and `CopyTarget` types
- "Copy Code" button copies room code (e.g., "ABCD")
- "Copy Link" button copies full URL (e.g., "http://localhost:4000?room=ABCD")
- Buttons show "Copied!" feedback with green styling for 2 seconds
- QR code image displays when data URL is available
- Loading state shown while QR generates

### Main.elm Integration
- Added `baseUrl` to Flags for URL construction
- Added `qrCodeDataUrl`, `copyCodeState`, `copyUrlState` to Model
- QR code generates automatically when room is created
- ShareUI appears below ConnectionUI when connected as host
- Separate feedback timers for code and URL copy buttons

## Commits

| Hash | Description |
|------|-------------|
| 2016e66 | feat(07-02): add QR code generation port |
| f71263b | feat(07-02): create ShareUI component with copy buttons and QR display |
| 7af5f4d | feat(07-02): wire ShareUI into Main.elm with copy URL and QR code |

## Deviations from Plan

### Version Adjustment
- **Found during:** Task 1 (npm install)
- **Issue:** qrcode@1.5.5 does not exist (plan specified non-existent version)
- **Fix:** Installed latest available version qrcode@1.5.4
- **Impact:** None, same functionality

No other deviations.

## Verification Results

- [x] qrcode npm package installed (1.5.4)
- [x] QR code generates when room is created
- [x] QR code displays at medium size (256x256)
- [x] "Copy Code" copies room code with "Copied!" feedback
- [x] "Copy Link" copies full room URL with "Copied!" feedback
- [x] Feedback returns to normal state after 2 seconds
- [x] TypeScript and Elm compile without errors

## Key Files

**QR Generation Port:**
```typescript
// assets/js/qr-generator.ts
export function setupQRPorts(app: ElmAppWithQR): void {
  app.ports.generateQRCode.subscribe(async (url: string) => {
    const dataUrl = await QRCode.toDataURL(url, {
      width: 256,
      margin: 2,
      errorCorrectionLevel: 'M'
    });
    app.ports.qrCodeGenerated.send({ success: true, dataUrl });
  });
}
```

**ShareUI View:**
```elm
-- assets/src/View/ShareUI.elm
view : Config msg -> Html msg
view config =
    div [ class "share-ui" ]
        [ div [ class "share-buttons" ]
            [ viewCopyButton "Copy Code" config.copyCodeState config.onCopyCode
            , viewCopyButton "Copy Link" config.copyUrlState config.onCopyUrl
            ]
        , viewQRCode config.roomCode config.qrCodeDataUrl
        ]
```

## Next Phase Readiness

Phase 07 (Migration & Polish) is now complete.

**Blockers:** None
**Concerns:** None
**Ready for:** Production deployment
