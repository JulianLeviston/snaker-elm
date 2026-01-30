# Stack Research: Elm + Phoenix Real-Time Application (2025/2026)

**Research Date:** 2026-01-30
**Project:** Snaker Elm Multiplayer Game Upgrade
**Current Stack:** Elm 0.18, Phoenix 1.3, Elixir 1.4, Brunch
**Target:** Modern Elm 0.19.1 + Phoenix + Elixir stack

---

## Executive Summary

The modern Elm + Phoenix stack for 2025/2026 has evolved significantly from the 2017-era setup. Key changes:
- **Elm:** 0.19.1 is the stable version (breaking changes from 0.18)
- **Phoenix:** 1.7.x series is current (moved to esbuild, removed Brunch)
- **Elixir:** 1.14+ with Erlang/OTP 25+
- **Build Tools:** esbuild replaced Brunch, Mix tasks handle assets
- **Phoenix Channels:** WebSocket library changed for Elm 0.19

---

## 1. Language & Framework Versions

### Elm
**Recommended:** `0.19.1`
**Confidence:** HIGH (this is the latest stable Elm release)

**Rationale:**
- Elm 0.19.1 is the current stable release and has been since 2019
- Breaking changes from 0.18:
  - `elm-package.json` → `elm.json` format change
  - Core library reorganization (Html.App → Browser, etc.)
  - No more Native modules support
  - Changed package namespace from `user/package` to package-based
  - Kernel code is compiler-internal only

**What NOT to use:**
- ❌ Elm 0.18.x - deprecated, incompatible package ecosystem
- ❌ Elm 0.19.0 - had bugs, use 0.19.1 instead

**Migration Impact:** MAJOR - this is the most breaking change in the upgrade path.

---

### Phoenix Framework
**Recommended:** `~> 1.7.14` (latest 1.7.x series)
**Confidence:** MEDIUM-HIGH (1.7.x was stable as of my knowledge cutoff)

**Rationale:**
- Phoenix 1.7 is the mature, stable release
- Major improvements over 1.3:
  - Verified routes for compile-time safety
  - Improved LiveView integration
  - Better WebSocket performance
  - Streamlined directory structure
  - Asset pipeline moved from Brunch to esbuild by default

**What NOT to use:**
- ❌ Phoenix 1.3.x - deprecated, missing security patches
- ❌ Phoenix 1.4-1.6 - skip to 1.7 for cleanest modern patterns
- ⚠️ Phoenix 1.8+ (if exists) - wait for community adoption on major versions

**Migration Impact:** MODERATE-HIGH - directory restructuring, config changes, new patterns

---

### Elixir
**Recommended:** `~> 1.14` or `~> 1.15`
**Confidence:** MEDIUM-HIGH

**Rationale:**
- Elixir 1.14+ provides modern language features
- Good compatibility with Phoenix 1.7.x
- Includes improvements to compilation, debugging, and core libraries
- Version 1.15 adds even more polish

**Minimum:** `1.14.0` (for Phoenix 1.7 compatibility)
**What NOT to use:**
- ❌ Elixir 1.4.x - ancient, missing critical features
- ❌ Elixir 1.5-1.12 - skip the intermediate versions

**Migration Impact:** LOW - mostly backward compatible, config format may change

---

### Erlang/OTP
**Recommended:** `OTP 25.x` or `OTP 26.x`
**Confidence:** MEDIUM

**Rationale:**
- OTP 25+ required for modern Elixir versions
- Provides performance improvements and security patches
- OTP 26 is likely the current stable version as of 2025/2026

**Minimum:** OTP 25.0
**What NOT to use:**
- ❌ OTP 24 or older - compatibility issues with modern Elixir

**Migration Impact:** LOW - transparent to application code

---

## 2. Version Management

### mise (formerly rtx)
**Recommended:** Latest stable mise
**Confidence:** HIGH (specified in project requirements)

**Rationale:**
- Replacement for asdf with better performance
- Unified tool version management
- Project requires mise specifically (not asdf)

**Configuration:**
Create `.mise.toml` in project root:
```toml
[tools]
elixir = "1.15.7"
erlang = "26.2.1"
nodejs = "20.11.0"  # For asset compilation
```

Or use `.tool-versions` (asdf-compatible format):
```
elixir 1.15.7
erlang 26.2.1
nodejs 20.11.0
```

**What NOT to use:**
- ❌ asdf - project specifies mise
- ❌ kerl/kiex/nvm separately - mise handles all
- ❌ System package managers (apt/brew) - version conflicts

**Migration Path:**
1. Install mise: `curl https://mise.run | sh`
2. Create `.mise.toml` or `.tool-versions`
3. Run `mise install` in project directory
4. Verify with `mise current`

---

## 3. Build Tools & Asset Pipeline

### JavaScript Build Tool
**Recommended:** `esbuild`
**Confidence:** HIGH (Phoenix 1.7 default)

**Rationale:**
- Phoenix 1.7 replaced Brunch with esbuild
- Much faster than Brunch or Webpack
- Simpler configuration
- Better tree-shaking and modern JS support

**Configuration:**
Phoenix 1.7 uses Mix tasks to invoke esbuild:
- `mix assets.deploy` - production build
- `mix assets.build` - development build
- Configured in `config/config.exs`

**What NOT to use:**
- ❌ Brunch - deprecated in Phoenix ecosystem
- ❌ Webpack - overkill for Phoenix, slower than esbuild
- ⚠️ Vite - possible but not Phoenix default, less documented

**Migration Impact:** MODERATE
- Remove `brunch-config.js`
- Remove Brunch npm dependencies
- Add esbuild config in Phoenix config files
- Update npm scripts

---

### Elm Build Integration
**Recommended:** Custom Mix task or npm script calling `elm make`
**Confidence:** MEDIUM-HIGH

**Rationale:**
- `elm-brunch` is obsolete (Brunch is deprecated)
- Modern approach: invoke `elm make` directly
- Options:
  1. npm script that runs `elm make`, then esbuild imports output
  2. Custom Mix task to compile Elm before assets
  3. Use esbuild plugin for Elm

**Example npm script approach:**
```json
{
  "scripts": {
    "build:elm": "elm make src/Main.elm --output=../priv/static/assets/elm.js",
    "build": "npm run build:elm && esbuild js/app.js --bundle --outdir=../priv/static/assets"
  }
}
```

**What NOT to use:**
- ❌ elm-brunch - incompatible with esbuild pipeline
- ❌ elm-webpack-loader - if not using Webpack

---

## 4. WebSocket / Phoenix Channels for Elm 0.19

### Critical Issue: fbonetti/elm-phoenix-socket
**Status:** NOT COMPATIBLE with Elm 0.19
**Confidence:** HIGH

The `fbonetti/elm-phoenix-socket` package you're currently using (v2.2.0) only supports Elm 0.18. This is the BIGGEST migration blocker.

---

### Recommended Solutions (in order of preference)

#### Option 1: saschatimme/elm-phoenix (RECOMMENDED)
**Package:** `saschatimme/elm-phoenix`
**Confidence:** MEDIUM-HIGH

**Rationale:**
- Port of elm-phoenix-socket to Elm 0.19
- Maintained community fork
- Similar API to fbonetti's original
- Well-documented

**Installation:**
```bash
elm install saschatimme/elm-phoenix
```

**Migration Notes:**
- API is similar to fbonetti/elm-phoenix-socket
- Some function signature changes for Elm 0.19
- Will need to update Socket/Channel setup code

---

#### Option 2: Custom Port-based WebSocket Implementation
**Approach:** JavaScript Ports + Phoenix JavaScript client
**Confidence:** HIGH (always works, more control)

**Rationale:**
- Maximum flexibility
- Use official Phoenix JavaScript client
- Elm Ports are the standard interop mechanism
- More boilerplate but well-understood pattern

**Architecture:**
```
Elm App <-- Ports --> JavaScript <-- phoenix.js --> Phoenix Channels
```

**Files needed:**
1. Elm ports definitions
2. JavaScript port handlers using `phoenix.js`
3. Message encoders/decoders

**Advantages:**
- Uses official Phoenix client (most up-to-date)
- Complete control over connection logic
- No dependency on third-party Elm packages

**Disadvantages:**
- More code to write and maintain
- Requires JavaScript knowledge
- Type safety boundary at port interface

**Example Elm Port:**
```elm
port module Ports exposing (sendToChannel, receiveFromChannel)

-- Outgoing
port sendToChannel : { topic : String, event : String, payload : Value } -> Cmd msg

-- Incoming
port receiveFromChannel : ({ topic : String, event : String, payload : Value } -> msg) -> Sub msg
```

---

#### Option 3: Build Direct WebSocket Connection
**Approach:** Elm's `WebSocket` module (if still available in 0.19)
**Confidence:** LOW-MEDIUM (WebSocket module may be deprecated)

**Rationale:**
- Bypass Phoenix Channels abstraction
- Direct WebSocket connection
- Handle Phoenix protocol manually

**What NOT to use:**
- ❌ elm-lang/websocket - deprecated in Elm 0.19
- ❌ Any Elm 0.18 package - incompatible

**Issues:**
- Elm 0.19 removed the WebSocket module
- Would need ports anyway
- Lose Phoenix Channels features (presence, etc.)

---

### Recommendation for Snaker-Elm

**Primary:** Try `saschatimme/elm-phoenix` first
**Fallback:** Implement custom Ports + phoenix.js

**Reasoning:**
- Your app already uses Phoenix Channels patterns
- Minimal refactoring with saschatimme/elm-phoenix
- Ports approach gives you escape hatch if package issues arise

**Migration Complexity:** MODERATE to HIGH
- Must rewrite all Socket/Channel code
- Encoder/decoder changes for Elm 0.19
- Test thoroughly - this is critical for multiplayer sync

---

## 5. Supporting Libraries

### Phoenix JavaScript Client
**Package:** `phoenix` (npm)
**Version:** `~> 1.7.0` (match Phoenix version)
**Confidence:** HIGH

**Usage:** If using Ports approach for Elm ↔ Phoenix communication

```bash
npm install phoenix
```

---

### Elm Core Libraries (Elm 0.19)
**Confidence:** HIGH

Elm 0.19 reorganized standard libraries:

**Install via elm.json:**
```json
{
  "dependencies": {
    "direct": {
      "elm/core": "1.0.5",
      "elm/html": "1.0.0",
      "elm/browser": "1.0.2",
      "elm/json": "1.1.3",
      "elm/time": "1.0.0",
      "elm/http": "2.0.0"
    }
  }
}
```

**Migration Notes:**
- `elm-lang/core` → `elm/core`
- `elm-lang/html` → `elm/html`
- `elm-lang/keyboard` → REMOVED in 0.19 (use Browser.Events.onKeyDown)
- All `elm-lang/*` packages renamed to `elm/*`

---

### Keyboard Input (Elm 0.19)
**Approach:** `Browser.Events` module
**Confidence:** HIGH

**Rationale:**
- `elm-lang/keyboard` was removed in Elm 0.19
- Use `Browser.Events.onKeyDown` / `onKeyUp` subscriptions
- More flexible but requires JSON decoders

**Example:**
```elm
import Browser.Events exposing (onKeyDown)
import Json.Decode as Decode

subscriptions : Model -> Sub Msg
subscriptions model =
    onKeyDown (Decode.map KeyPressed keyDecoder)

keyDecoder : Decode.Decoder String
keyDecoder =
    Decode.field "key" Decode.string
```

**Migration Impact:** MODERATE - rewrite keyboard handling

---

## 6. Dependencies Summary Table

| Category | Current | Target | Package/Tool | Confidence |
|----------|---------|--------|--------------|------------|
| Elm | 0.18.0 | 0.19.1 | elm binary | HIGH |
| Phoenix | 1.3.0 | 1.7.14 | phoenix (hex) | MEDIUM-HIGH |
| Elixir | 1.4.x | 1.15.7 | elixir | MEDIUM-HIGH |
| Erlang | (old) | OTP 26.2 | erlang | MEDIUM |
| Build Tool | Brunch | esbuild | esbuild (npm) | HIGH |
| Version Mgmt | (none) | mise | mise | HIGH |
| Elm-Phoenix | fbonetti 2.2.0 | saschatimme/elm-phoenix OR Ports | elm package | MEDIUM |
| Keyboard | elm-lang/keyboard | Browser.Events | elm/browser | HIGH |
| Node.js | unknown | 20.x LTS | nodejs | HIGH |

---

## 7. What NOT to Use (Anti-Patterns)

### Avoid These:
1. ❌ **Elm 0.18 packages** - Incompatible, deprecated ecosystem
2. ❌ **Brunch** - Deprecated, removed from Phoenix 1.7
3. ❌ **elm-brunch** - Obsolete build plugin
4. ❌ **asdf** - Project specifies mise instead
5. ❌ **fbonetti/elm-phoenix-socket** - Only works with Elm 0.18
6. ❌ **Native modules in Elm** - Removed in 0.19
7. ❌ **Phoenix 1.3-1.6** - Skip to 1.7 for modern patterns
8. ❌ **Cowboy 1.x** - Phoenix 1.7 uses Cowboy 2.x (handled automatically)
9. ❌ **System-installed Elixir/Erlang** - Use mise for version control
10. ❌ **elm-lang/* packages** - Renamed to elm/* in 0.19

---

## 8. Recommended Migration Path

### Phase 1: Environment Setup
1. Install mise
2. Create `.mise.toml` with Elixir 1.15, Erlang 26, Node 20
3. Run `mise install`
4. Verify versions with `mise current`

**Risk:** LOW
**Confidence:** HIGH

---

### Phase 2: Phoenix Upgrade
1. Update `mix.exs` to Phoenix 1.7.x
2. Run `mix deps.get`
3. Run `mix phx.gen.release --docker` to see new structure
4. Migrate config files (config/runtime.exs pattern)
5. Update directory structure if needed
6. Remove Brunch, add esbuild config

**Risk:** MODERATE
**Confidence:** MEDIUM-HIGH
**Note:** Phoenix has good upgrade guides; follow official docs

---

### Phase 3: Asset Pipeline
1. Remove `brunch-config.js`
2. Remove Brunch from `package.json`
3. Add esbuild configuration
4. Test asset compilation
5. Update deployment scripts

**Risk:** MODERATE
**Confidence:** HIGH

---

### Phase 4: Elm Upgrade (CRITICAL)
1. Install Elm 0.19.1
2. Run `elm init` in new elm directory
3. Manually port code file-by-file:
   - Update imports (elm-lang → elm)
   - Fix Browser.* API changes
   - Rewrite keyboard handling
   - Update JSON decoders
4. Fix all compiler errors (Elm compiler is helpful)

**Risk:** HIGH
**Confidence:** MEDIUM-HIGH
**Time Estimate:** SIGNIFICANT - Elm 0.18 → 0.19 is major

---

### Phase 5: Phoenix Channels Integration
1. Choose: saschatimme/elm-phoenix OR Ports
2. If Ports: Write JavaScript channel handlers
3. If Package: Install and configure elm-phoenix
4. Rewrite Socket/Channel code
5. Test WebSocket connection thoroughly

**Risk:** HIGH
**Confidence:** MEDIUM
**Critical:** This is where multiplayer sync happens

---

### Phase 6: Fix Multiplayer Sync Bug
1. Add state broadcast on player join
2. Send full game state to new connections
3. Test multi-client scenarios

**Risk:** MODERATE
**Confidence:** HIGH
**Note:** Easier to fix after upgrade complete

---

## 9. Confidence Levels Explanation

**HIGH:** Information confirmed from official sources or widely known as of Jan 2025
**MEDIUM-HIGH:** Strong likelihood based on ecosystem trends
**MEDIUM:** Reasonable assumption, but verify with live docs
**LOW-MEDIUM:** Speculative, needs verification

**Verification Needed (no live access):**
- Exact Phoenix 1.7.x patch version
- Exact Elixir 1.15.x patch version
- Current saschatimme/elm-phoenix status and API
- Erlang OTP 26 vs 27 recommendation for 2026

---

## 10. Open Questions for Verification

When you have web access, verify:

1. **Latest Phoenix version** - Check hexdocs.pm/phoenix
2. **Latest Elixir version** - Check elixir-lang.org
3. **Erlang OTP current** - Check erlang.org
4. **saschatimme/elm-phoenix status** - Check package.elm-lang.org
5. **Alternative Elm-Phoenix packages** - Search Elm package repository
6. **Phoenix 1.7 asset pipeline** - Confirm esbuild is still default
7. **mise vs asdf 2026** - Confirm mise is stable and recommended

---

## 11. Additional Resources

**Official Documentation** (verify these URLs):
- Phoenix: https://hexdocs.pm/phoenix
- Elm: https://guide.elm-lang.org/
- Elixir: https://elixir-lang.org/
- mise: https://mise.jdx.dev/

**Elm 0.18 → 0.19 Migration:**
- Official upgrade guide: https://github.com/elm/compiler/blob/master/upgrade-docs/0.19.md

**Phoenix 1.3 → 1.7 Migration:**
- Check Phoenix CHANGELOG and upgrade guides on hexdocs

---

## 12. Risk Assessment

| Component | Migration Risk | Complexity | Impact if Wrong |
|-----------|---------------|------------|-----------------|
| Elm 0.18→0.19 | HIGH | HIGH | App won't compile |
| Phoenix Channels | HIGH | MODERATE | Multiplayer broken |
| Phoenix 1.3→1.7 | MODERATE | MODERATE | Deploy issues |
| Brunch→esbuild | MODERATE | LOW | Assets won't build |
| Keyboard handling | MODERATE | LOW | Controls broken |
| mise setup | LOW | LOW | Version mismatch |
| Elixir upgrade | LOW | LOW | Minor compatibility |

---

## 13. Success Criteria

You'll know the stack is correct when:

✅ `elm make` compiles Elm 0.19.1 code without errors
✅ `mix phx.server` starts Phoenix without warnings
✅ `mise current` shows correct Elixir/Erlang/Node versions
✅ Asset pipeline builds JS and CSS correctly
✅ WebSocket connects to Phoenix Channels
✅ Multiplayer sync works (after bug fix)
✅ No deprecated dependency warnings
✅ Modern browser testing passes

---

## 14. Next Steps for Roadmap

Based on this research:

1. **Set up mise** - Quick win, low risk
2. **Upgrade Phoenix first** - Easier without Elm changes
3. **Replace Brunch with esbuild** - While Phoenix works
4. **Tackle Elm 0.19 migration** - Biggest effort
5. **Fix WebSocket/Channels** - After Elm works
6. **Fix multiplayer sync bug** - Final goal

**Estimated Total Effort:** 3-5 weeks for experienced developer
**Biggest Unknowns:** Elm-Phoenix WebSocket integration, state sync fix

---

**Document Status:** DRAFT - Needs verification with live documentation
**Confidence Overall:** MEDIUM-HIGH for general direction, specific versions need confirmation
**Last Updated:** 2026-01-30
**Researched By:** Claude (Sonnet 4.5) - Knowledge cutoff January 2025
