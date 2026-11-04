# Odd or Even - UI/UX Design System & Aesthetics

## 1. Visual Direction & Style Guide
The visual identity follows a **premium competitive sports game** theme:
- Deep midnight and charcoal backgrounds with subtle radial glows.
- Emerald green (`#10B981`) and electric lime (`#84CC16`) for primary actions, legal runs, and active batting states.
- High-carat metallic gold (`#F59E0B` / `#FBBF24`) for wickets, trophies, series points, and milestone animations.
- Player differentiation colors:
  - **Player 1 / Host:** Electric Violet / Cyan (`#8B5CF6` / `#06B6D4`)
  - **Player 2 / Guest:** Coral / Amber (`#F43F5E` / `#FB923C`)
- Soft glassmorphism cards (`rgba(255, 255, 255, 0.05)` to `0.08` with subtle border stroke `#334155`).

## 2. Design Tokens

### 2.1 Colors
- `GameColors.backgroundPrimary`: `0xFF0F172A` (Rich slate/midnight)
- `GameColors.backgroundSecondary`: `0xFF1E293B` (Elevated card slate)
- `GameColors.surfaceGlass`: `0x1A334155` (Subtle translucent glass)
- `GameColors.accentEmerald`: `0xFF10B981` (Run score & success)
- `GameColors.accentLime`: `0xFF84CC16` (Active highlight & Ready indicator)
- `GameColors.accentGold`: `0xFFF59E0B` (Wicket, Series points & Trophy)
- `GameColors.accentWicket`: `0xFFEF4444` (Wicket red / alert)
- `GameColors.player1Primary`: `0xFF8B5CF6` (Violet)
- `GameColors.player2Primary`: `0xFFF43F5E` (Coral)
- `GameColors.textPrimary`: `0xFFF8FAFC`
- `GameColors.textSecondary`: `0xFF94A3B8`
- `GameColors.textMuted`: `0xFF64748B`

### 2.2 Typography
- Headings: Bold/ExtraBold sans-serif (e.g. Outfit / Montserrat / Roboto) with generous tracking.
- Numerals: Tabular, high-impact condensed or monospaced font for scoreboards and countdown timer.
- Body: Inter / Roboto, clean and highly readable under bright mobile ambient lighting.

### 2.3 Spacing & Radii
- Standard Spacing Scale: `xs: 4`, `sm: 8`, `md: 16`, `lg: 24`, `xl: 32`, `xxl: 48`
- Corner Radii:
  - Cards: `16.0`
  - Number Buttons: `14.0`
  - Action Buttons: `28.0` (Pill shape)
  - Dialogs: `24.0`

### 2.4 Interactive Components
- **Number Pad:** 2 rows of 5 numbers (`1..5` and `6..10`), large tap targets (minimum 56x56dp), clear tactile state feedback upon tap.
- **Privacy Handoff Screen:** Full-screen blackout guard with a prominent "Pass Device to Player 2" card and a confirmation swipe or hold-to-unlock mechanism.
- **Ball Outcome Reveal Card:** Centered dual-card flip animation showing Player 1's number and Player 2's number simultaneously with the calculated delta or OUT banner.
