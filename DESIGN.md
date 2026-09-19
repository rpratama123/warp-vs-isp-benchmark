---
name: Route Dispatch
description: An evidence-first route comparison system modeled on operational dispatch records.
colors:
  direct-blue: "#285c88"
  direct-blue-soft: "#dce8f0"
  warp-orange: "#b84b23"
  warp-orange-soft: "#f2dfd3"
  dispatch-paper: "#dfe5e3"
  dispatch-sheet: "#f6f8f5"
  carbon-ink: "#18201f"
  graphite-muted: "#5a6460"
  rule: "#a8aaa2"
  rule-dark: "#747b77"
  cleared: "#256947"
  caution: "#8a5a0a"
  hold: "#9d302c"
  focus: "#6c3cc4"
typography:
  display:
    fontFamily: "Aptos, Segoe UI, Helvetica, Arial, sans-serif"
    fontSize: "clamp(2.2rem, 5.3vw, 5.1rem)"
    fontWeight: 700
    lineHeight: 0.96
    letterSpacing: "-0.038em"
  headline:
    fontFamily: "Aptos, Segoe UI, Helvetica, Arial, sans-serif"
    fontSize: "clamp(1.75rem, 3vw, 2.8rem)"
    fontWeight: 700
    lineHeight: 1.1
    letterSpacing: "-0.025em"
  body:
    fontFamily: "Aptos, Segoe UI, Helvetica, Arial, sans-serif"
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: 1.58
  label:
    fontFamily: "Aptos, Segoe UI, Helvetica, Arial, sans-serif"
    fontSize: "0.76rem"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "0.05em"
rounded:
  dispatch: "3px"
spacing:
  compact: "8px"
  control: "12px"
  field: "18px"
  section: "34px"
components:
  button-primary:
    backgroundColor: "{colors.carbon-ink}"
    textColor: "{colors.dispatch-sheet}"
    rounded: "{rounded.dispatch}"
    padding: "0 22px"
    height: "48px"
  button-secondary:
    backgroundColor: "transparent"
    textColor: "{colors.carbon-ink}"
    rounded: "{rounded.dispatch}"
    padding: "0 13px"
    height: "36px"
---

# Design System: Route Dispatch

## Overview

**Creative North Star: "The Route Dispatch Board"**

Route Dispatch treats measurement evidence like an operational release: routes are not declared fit until verification and compatibility checks clear them. The visual language is compact, physical, and procedural without imitating a terminal. Broad sheets establish hierarchy; destination strips carry aligned route records; stamps communicate consequential states.

The system is information-dense but not compressed. Its personality comes from ruled structure, paired route inks, clipped geometry, tabular numerals, and decisive state language. It rejects interchangeable dashboard cards in favor of records whose shape explains their relationship.

**Key Characteristics:**
- Cool low-glare paper and dark carbon ink.
- Direct blue and WARP orange always retain stable route meaning.
- Square, ruled structures with minimal corner rounding.
- Evidence validity is visually stronger than performance outcome.
- Motion advances records into inspection rather than decorating the page.

## Colors

The palette resembles cool dispatch stock marked with route inks and restrained safety stamps.

### Primary
- **Direct Blue:** Identifies the direct ISP route in text, rules, legends, and charts.
- **WARP Orange:** Identifies the Cloudflare WARP route in the same paired contexts.

### Secondary
- **Cleared Green:** Reserved for evidence that is valid and for measurements favoring WARP.
- **Caution Ochre:** Marks restricted, incomplete, or mixed evidence.
- **Hold Red:** Marks blocked verdicts, invalid imports, and measurements favoring Direct.
- **Focus Violet:** Appears only as the keyboard focus ring so focus remains distinct from route and result states.

### Neutral
- **Dispatch Paper:** The cool outer work surface.
- **Dispatch Sheet:** The primary reading and control surface.
- **Carbon Ink:** Primary text, strong rules, and selected controls.
- **Graphite Muted:** Supporting copy and labels.
- **Rule / Rule Dark:** Structural separators and field boundaries.

### Named Rules
**The Stable Route Ink Rule.** Blue always means Direct and orange always means WARP; neither color is reused to mean better or worse.

**The Clearance Before Outcome Rule.** A verdict state must remain visually and semantically separate from which route performs better.

## Typography

**Display Font:** Aptos with Segoe UI, Helvetica, and Arial fallbacks
**Body Font:** Aptos with Segoe UI, Helvetica, and Arial fallbacks

**Character:** One durable UI family handles both expressive decisions and dense records. Compression comes from scale, close display tracking, uppercase labels, and tabular numerals rather than a decorative technical font.

### Hierarchy
- **Display** (700, responsive up to 5.1rem, 0.96): Qualified route decisions and import thesis.
- **Headline** (700, responsive up to 2.8rem, approximately 1.1): Destination and section headings.
- **Body** (400, 1rem, 1.58): Explanations and methodology caveats, normally kept below 75 characters per line.
- **Label** (700, 0.76rem, 0.05em, uppercase): Statuses, route names, field labels, and record metadata.

### Named Rules
**The Numerals Are Evidence Rule.** Measurement values use tabular numerals; route labels and units never compete with the number's weight.

## Layout

Surfaces use a centered fluid shell capped at 1500px with 20px desktop gutters and 12px mobile gutters. The first result sheet divides decision evidence from the run record at roughly 70/30, collapsing to one column below 950px. Destination strips align identity, Direct, WARP, and outcome in one row; below 950px outcome becomes a full-width footer, and below 640px destination identity occupies its own row.

Spacing follows contextual intervals rather than a universal card gap: 8px for tight control relationships, 12–18px inside fields, 24–34px inside records, and at least 42px between major sections.

## Elevation & Depth

The system is ruled and layered rather than floaty. Primary sheets use a restrained ambient lift; strips are flat at rest and rise slightly only on hover or selection.

### Shadow Vocabulary
- **Sheet lift** (`0 10px 24px rgba(31, 38, 36, .11), 0 2px 6px rgba(31, 38, 36, .07)`): Import, clearance, and evidence sheets only.
- **Active strip** (`0 8px 20px rgba(24, 32, 31, .12)`): The destination advanced into the evidence bay.

### Named Rules
**The Working Surface Rule.** Elevation indicates a sheet being handled or a record being selected, never a decorative card collection.

## Shapes

Corners are nearly square with a 3px operational radius. Thin graphite rules establish records; dashed perforations divide fields inside a strip. Circular geometry is reserved for route nodes and the product mark. Status stamps use stronger outlined rectangles and a slight physical rotation.

## Components

### Buttons
- **Shape:** Compact dispatch controls with a 3px radius.
- **Primary:** Carbon ink on dispatch sheet, 48px high, used for the local-file action.
- **Hover / Focus:** Primary controls lighten slightly on hover; all controls receive a 3px violet external focus ring.
- **Secondary:** Transparent with a graphite border, 36px high, used for changing the imported file.

### Chips
- **Style:** Status stamps and movement labels use semantic pale fields with matching dark ink and outlined edges.
- **State:** Cleared, caution, hold, better, worse, mixed, and unavailable labels always include text; color is supporting evidence only.

### Cards / Containers
- **Corner Style:** Nearly square (3px).
- **Background:** Dispatch sheet or a slightly darker neutral log field.
- **Shadow Strategy:** Only primary handled sheets are lifted.
- **Border:** One-pixel graphite rules, strengthened where a sheet boundary matters.
- **Internal Padding:** Fluid 24–68px for major sheets; 18–20px for route-strip cells.

### Inputs / Fields
- **Style:** Native file input is visually represented by the primary button; selects use a graphite stroke, sheet background, and 3px radius.
- **Focus:** Violet ring with a 3px offset.
- **Error / Disabled:** Errors use hold red on a pale red field with a recovery message; unavailable evidence uses an em dash and explicit text rather than disabled-looking zeroes.

### Navigation
- Metric views form a horizontal ruled register. The selected tab inverts to carbon ink with sheet text; unselected tabs remain transparent and use a neutral hover field. On narrow screens the register scrolls horizontally without shrinking labels.

### Destination Strip

The signature component aligns destination identity with Direct and WARP values. Route color appears as a top registration rule, not as a generic card accent. Selection advances the strip toward the evidence bay and preserves all fleet context around it.

## Do's and Don'ts

### Do:
- **Do** disclose evidence validity before stating a performance lean.
- **Do** keep Direct and WARP in stable blue/orange positions and pair measurements spatially.
- **Do** use ruled records, tabular numerals, and explicit status language for dense evidence.
- **Do** collapse grids into readable record sequences rather than miniaturizing them on mobile.

### Don't:
- **Don't** use route colors as better/worse colors or rely on color without text.
- **Don't** summarize missing, failed, interrupted, or incompatible evidence as zero.
- **Don't** replace aligned records with interchangeable metric-card grids at page level.
- **Don't** add decorative gradients, glass effects, neon glows, or terminal styling to signal technical credibility.
