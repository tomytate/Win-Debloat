====================================================================================================
  WIN-DEBLOAT v1.5.0 "TOP G" — MASTER WEBSITE GENERATION PROMPT **v2.0 ENHANCED**
  STACK: THREE.js r185 (WebGPU+TSL) · REACT 19.2 + COMPILER 1.0 · TS 7.0 NATIVE · VITE 8
  VERIFIED AGAINST PUBLIC ECOSYSTEM AS OF 2026-08-19 — ZERO TECH DEBT
====================================================================================================

You are an Elite Principal Web Architect, Creative Technologist, and 3D Graphics Engineer tasked with
building the official, world-class landing page and interactive web application for:

    Project:    Win-Debloat (v1.5.0 "Top G")
    Repository: https://github.com/tomytate/Win-Debloat
    Tagline:    The Ultimate Windows 10 & 11 Optimizer, Privacy Hardener & Debloating Framework
    Website:    https://win-debloat.com

You will implement a hyper-futuristic Cyber-OLED 3D website featuring: a WebGPU-first Three.js
experience with automatic WebGL2 backend fallback, silky momentum scrolling (Lenis 1.3.x),
scrollytelling timelines (GSAP 3.15 with ScrollTrigger/Flip/SplitText), an interactive Visual
Profile Customizer with real-time Gzip+Base64 PowerShell one-liner generation, a client-side
Web Crypto SHA-256 verifier, a zero-asset procedural Web Audio synthesizer, a live hardware
benchmark simulator, and a trust-first install UX appropriate for a security/privacy tool.

====================================================================================================
0. v2.0 CHANGE LOG — WHAT CHANGED AND WHY (ALL VERIFIED 2026-08-19)
====================================================================================================

  [GRAPHICS]  WebGPU reached W3C Candidate Recommendation and Baseline browser support in
              January 2026 (Chrome/Edge 113+, Safari 26+ on macOS Tahoe/iOS 26, Firefox 141+
              on Windows / 145+ macOS-Tahoe-ARM / 147+ all Apple Silicon macOS; ~82–84% global
              reach). Three.js r171+ ships a production-ready `WebGPURenderer` whose **single
              codebase (TSL shaders) runs on BOTH the WebGPU and WebGL2 backends** — it
              auto-falls back to WebGL2 when WebGPU is unavailable. We therefore replace the
              WebGL-only GLSL plan with a **WebGPU-first + TSL** architecture and keep a
              Canvas2D/SVG static fallback for the long tail (Linux Firefox, pre-26 Safari,
              Intel Macs, context loss).
  [THREE]     Bumped r172 -> r185.x. r180 removed deprecated APIs and added HDR output in
              WebGPURenderer; selective bloom now uses the `three/addons` postprocessing Pass
              pipeline (RenderPass -> UnrealBloomPass w/ layer masks -> OutputPass).
  [REACT]     Bumped to React 19.2.x: `<Activity>` for off-screen tab pre-render in the
              Customizer, `useEffectEvent` for non-reactive effect subscriptions (ticker,
              audio), and **React Compiler 1.0 (stable since 2025-10-07)** enabled so manual
              useMemo/useCallback is forbidden unless profiling proves otherwise.
  [TS]        TypeScript 7.0 GA (2026-07-08), native Go port ("Project Corsa"), installed from
              the standard `typescript` package. NOTE: Microsoft states the stable programmatic
              API lands with 7.1 — therefore **typescript-eslint continues to run its own
              pinned TS 6.x parser internally**; our build/typecheck uses TS 7 (`tsc`/`tsgo`),
              and this dual-compiler reality is documented in CI.
  [VITE]      Bumped Vite 6 -> **8.2.x**. `@vitejs/plugin-react` v6 replaced Babel with **oxc**;
              React Compiler is enabled via the plugin's official integration (NOT the old
              `babel: { plugins: [...] }` pattern). Pin >= 8.0.5 to avoid CVE-2026-39364
              (dev-server information disclosure affecting 7.1.0–7.3.1 and 8.0.0–8.0.4).
  [CSS]       Tailwind 4.0.6 -> **4.3.3**. Do not use `start-*`/`end-*` logical utilities
              (deprecated in 4.2); use `ms-*`/`me-*`/`ps-*`/`pe-*`. `@tailwindcss/vite`
              4.2.2+ officially supports Vite 8.
  [ANIM]      GSAP 3.12 -> **3.15.0**. All GSAP plugins (incl. **SplitText**) are free since
              the Webflow acquisition — we drop the `split-type` dependency in favor of
              GSAP SplitText to reduce bundle size and unify the animation runtime.
  [SCROLL]    Lenis 1.1 -> **1.3.26** (package name is `lenis`; the old @studio-freight/*
              scopes are retired).
  [SECURITY]  Rebuilt the CSP: removed `'unsafe-inline'` from `script-src` (a hardening tool
              cannot ship a porous policy), removed deprecated `X-XSS-Protection`, added
              `require-trusted-types-for 'script'` with a Tiny policy for the single dyn-import
              shim. Vite inlines JSON import attributes at build time, so no runtime fetch/CSP
              conflict exists for `with { type: 'json' }`.
  [TRUST]     NEW Section 8: an `irm ... | iex` one-liner is the single biggest trust barrier
              for a privacy tool. The site now ships an "Inspect Before You Run" UX: expandable
              plaintext of the exact payload, pinned SHA-256 of the bootstrap script, signed
              release attestation links, and a manual two-step download alternative.
  [A11Y]      NEW hard requirement: full `prefers-reduced-motion` degradation ladder (particles
              60k -> 0, scrollytelling -> static sections, smooth scroll -> native), WCAG 2.2 AA
              floor with AAA contrast targets, keyboard-operable customizer and terminal.
  [SEO]       NEW Section 10: OG/Twitter cards, JSON-LD `SoftwareApplication` schema, sitemap,
              canonical URLs, robots policy.
  [CI]        NEW Section 12: GitHub Actions quality gates — typecheck, `--max-warnings 0`
              lint, bundle-size budget check (<150 KB Brotli critical path), Lighthouse CI.
  [BUGFIX]    v1.5 prompt declared `"test": "vitest run"` but never listed vitest in
              devDependencies — now added (Vitest 3.x).

====================================================================================================
1. CORE TECH STACK & ZERO TECH DEBT MANIFEST (VERIFIED VERSIONS, 2026-08)
====================================================================================================

- Language & Compiler: TypeScript 7.0 (native Go port, "Project Corsa")
  * Install: `npm i -D typescript` (the `latest` tag IS 7.0 post-GA; nightlies: `typescript@next`).
  * Editor: VS Code "TypeScript Native Preview" extension is the default TS experience.
  * Known constraint: no stable programmatic compiler API until TS 7.1 — type-aware linting
    (typescript-eslint) internally uses its own TS 6.x parser. This is expected; do NOT attempt
    to force typescript-eslint onto the TS 7 API.
  * Target: `ESNext` (TS 7 tracks the finished-proposal ES2026 feature set; `ESNext` is the
    forward-safe choice for a greenfield 2026 app).
  * Module Architecture: `module: "ESNext"`, `moduleResolution: "bundler"`,
    `verbatimModuleSyntax: true`, `isolatedDeclarations: true`, Import Attributes
    (`import schema from './schema.json' with { type: 'json' }` — inlined by Vite at build).
  * Modern Language Features Leveraged:
    - Const Type Parameters (`<const T>`) for deep literal inference on config schemas
    - `satisfies` for exact-shape validation without widening
    - Discriminated-union exhaustiveness via `never` assertions in switches
  * ULTRA-STRICT Compiler Contract (unchanged from v1.5, all still valid in TS 7):
    `strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `noImplicitOverride`,
    `noImplicitReturns`, `noFallthroughCasesInSwitch`, `noUnusedLocals`, `noUnusedParameters`,
    `noPropertyAccessFromIndexSignature`.
  * Type Safety Guarantee: zero `any`, zero `as unknown as T` escape hatches.

- Linter: ESLint 10.8.1 (flat config ONLY — v10 removed the legacy eslintrc system entirely)
  * `typescript-eslint` strictTypeChecked + stylisticTypeChecked, `projectService: true`.
  * CI gate: `eslint . --max-warnings 0`.
  * Add `eslint-plugin-react-hooks` v6 (React Compiler diagnostics) and
    `eslint-plugin-react-refresh`.

- Framework: React 19.2.x + TypeScript 7
  * `<Activity>`: pre-render the 6 Customizer tabs off-screen with preserved state.
  * `useEffectEvent`: subscribe GSAP ticker / AudioContext / Lenis events without
    re-running effects.
  * React Compiler 1.0 enabled at build; manual memoization is a lint-discouraged smell.
  * Resource preloading APIs (`preload`, `preinit`) orchestrated in a single hook.
  * Direct `ref` prop passing (no `forwardRef`).

- CSS: Tailwind CSS 4.3.3 (Oxide engine, CSS-first `@theme`, Lightning CSS)
  * OKLCH tokens for OLED/HDR gamut; CSS Houdini `@property --border-angle`; container queries;
    native View Transitions for route/section morphs.

- 3D Graphics: Three.js r185 — **WebGPURenderer + TSL (Three Shading Language)**
  * One shader codebase (TSL) executes on WebGPU AND the WebGL2 fallback backend — this is the
    core architectural upgrade over the v1.5 dual-GLSL plan.
  * InstancedMesh motherboard: 4,000+ SMD components in 1 draw call.
  * 60,000-particle vortex: TSL compute/vertex-stage curl-noise vector field (WebGPU compute
    where available; vertex-transform fallback on the WebGL2 backend).
  * Postprocessing: RenderPass -> UnrealBloomPass (selective via layer masks, Layer 1) ->
    OutputPass, from `three/addons`.
  * Deterministic `.dispose()` on every geometry/material/texture; context-loss coordinator
    with static SVG/Canvas2D terminal-state fallback.

- Scroll & Animation: Lenis 1.3.26 + GSAP 3.15 (ScrollTrigger, Flip, **SplitText**)
  * Unified master clock: `gsap.ticker.lagSmoothing(0)` driving `lenis.raf(time * 1000)`,
    `lenis.on('scroll', ScrollTrigger.update)`.
  * All ScrollTriggers registered in a context that is fully reverted on unmount
    (`gsap.context()` / `useGSAP`).

- State & Data:
  * Zustand 5 (atomic selectors, slice pattern).
  * @tanstack/react-virtual 3.x for the 175+ app catalog and terminal stream.
  * pako (Gzip) + Unicode-safe Base64 for the one-liner compiler.
  * js-yaml for the deterministic profile serializer.

- Audio: zero-dependency procedural Web Audio synth (see Section 6).

- Performance & Quality Budgets (HARD GATES, enforced in CI):
  * Critical-path initial bundle: < 150 KB Brotli (three.js, WebGL/WebGPU scene, and the
    simulator are route/interaction-level dynamic imports).
  * 60 FPS mobile / 120 FPS hi-refresh desktop; DPR clamp 1.5 on battery-powered devices.
  * Lighthouse: 100 Performance / 100 A11y / 100 Best Practices / 100 SEO (desktop & mobile).
  * CWV: LCP < 0.9s, FCP < 0.6s, CLS = 0.000, INP < 40ms, TBT = 0ms.
  * Accessibility: WCAG 2.2 AA floor, AAA contrast (>= 14:1 on OLED theme), roving tabindex,
    ARIA live regions for terminal + toasts, full prefers-reduced-motion ladder.
  * Resilience: WebGPU -> WebGL2 backend (in-renderer) -> Canvas2D -> static SSR-safe SVG.

====================================================================================================
2. ZERO TECH DEBT CONFIGURATION BLUEPRINTS
====================================================================================================

----------------------------------------------------------------------------------------------------
A. TSCONFIG (TypeScript 7 native)
----------------------------------------------------------------------------------------------------

```json
// tsconfig.json
{
  "files": [],
  "references": [
    { "path": "./tsconfig.app.json" },
    { "path": "./tsconfig.node.json" }
  ]
}
```

```json
// tsconfig.app.json
{
  "compilerOptions": {
    "target": "ESNext",
    "useDefineForClassFields": true,
    "lib": ["DOM", "DOM.Iterable", "ESNext"],
    "module": "ESNext",
    "skipLibCheck": true,

    "moduleResolution": "bundler",
    "resolvePackageJsonExports": true,
    "resolvePackageJsonImports": true,
    "isolatedDeclarations": true,
    "verbatimModuleSyntax": true,
    "moduleDetection": "force",
    "noEmit": true,
    "jsx": "react-jsx",

    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "strictBindCallApply": true,
    "strictPropertyInitialization": true,
    "noImplicitThis": true,
    "useUnknownInCatchVariables": true,
    "alwaysStrict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noPropertyAccessFromIndexSignature": true,

    "baseUrl": ".",
    "paths": { "@/*": ["src/*"] }
  },
  "include": ["src"]
}
```

```json
// tsconfig.node.json
{
  "compilerOptions": {
    "target": "ESNext",
    "lib": ["ESNext"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "isolatedDeclarations": true,
    "noEmit": true,
    "types": ["node"]
  },
  "include": ["vite.config.ts", "eslint.config.js"]
}
```

----------------------------------------------------------------------------------------------------
B. PACKAGE.JSON (verified versions as of 2026-08-19; re-pin exact on install)
----------------------------------------------------------------------------------------------------

```json
{
  "name": "win-debloat-web",
  "private": true,
  "version": "1.5.0",
  "type": "module",
  "engines": { "node": ">=22.12" },
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview",
    "lint": "eslint . --report-unused-disable-directives --max-warnings 0",
    "typecheck": "tsc --noEmit --project tsconfig.app.json",
    "test": "vitest run",
    "budget": "node scripts/check-bundle-budget.mjs"
  },
  "dependencies": {
    "@tanstack/react-virtual": "^3.13.0",
    "clsx": "^2.1.1",
    "gsap": "^3.15.0",
    "js-yaml": "^4.1.0",
    "lenis": "^1.3.26",
    "lucide-react": "^0.475.0",
    "pako": "^2.1.0",
    "react": "^19.2.0",
    "react-dom": "^19.2.0",
    "swr": "^2.3.2",
    "tailwind-merge": "^3.0.1",
    "three": "^0.185.0",
    "zustand": "^5.0.3"
  },
  "devDependencies": {
    "@eslint/js": "^10.8.1",
    "@tailwindcss/vite": "^4.3.3",
    "@types/js-yaml": "^4.0.9",
    "@types/node": "^22.13.1",
    "@types/pako": "^2.0.3",
    "@types/react": "^19.2.0",
    "@types/react-dom": "^19.2.0",
    "@types/three": "^0.185.0",
    "@vitejs/plugin-react": "^6.0.0",
    "eslint": "^10.8.1",
    "eslint-plugin-react-hooks": "^6.0.0",
    "eslint-plugin-react-refresh": "^0.4.19",
    "rollup-plugin-visualizer": "^5.14.0",
    "tailwindcss": "^4.3.3",
    "typescript": "^7.0.2",
    "typescript-eslint": "^8.24.0",
    "vite": "^8.2.0",
    "vite-plugin-compression": "^0.5.1",
    "vitest": "^3.0.0"
  }
}
```

NOTES:
  * REMOVED `split-type` — GSAP SplitText (free since the Webflow acquisition) replaces it.
  * `vite` pinned >= 8.0.5 to avoid CVE-2026-39364.
  * After install, lock exact versions (`npm i -E`) and commit the lockfile; the ranges above
    are minimums verified against the public registries on 2026-08-19.

----------------------------------------------------------------------------------------------------
C. ESLINT 10 FLAT CONFIG (zero-warning policy; TS7-aware note in header)
----------------------------------------------------------------------------------------------------

```javascript
// eslint.config.js
// NOTE: typescript-eslint's typed rules run on its own TS 6.x parser until the
// TS 7.1 stable programmatic API ships. Build/typecheck uses TS 7. Both must pass.
import js from '@eslint/js';
import tseslint from 'typescript-eslint';
import reactHooks from 'eslint-plugin-react-hooks';
import reactRefresh from 'eslint-plugin-react-refresh';

export default tseslint.config(
  { ignores: ['dist', 'node_modules', 'public', '.vite', 'stats.html'] },
  {
    extends: [
      js.configs.recommended,
      ...tseslint.configs.strictTypeChecked,
      ...tseslint.configs.stylisticTypeChecked,
    ],
    files: ['**/*.{ts,tsx}'],
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    plugins: {
      'react-hooks': reactHooks,
      'react-refresh': reactRefresh,
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      'react-refresh/only-export-components': ['error', { allowConstantExport: true }],
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/consistent-type-definitions': ['error', 'interface'],
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/await-thenable': 'error',
      '@typescript-eslint/no-unnecessary-condition': 'error',
      '@typescript-eslint/no-unnecessary-type-assertion': 'error',
      '@typescript-eslint/prefer-nullish-coalescing': 'error',
      '@typescript-eslint/prefer-optional-chain': 'error',
      // React Compiler 1.0 owns memoization; hand-rolled memo is a smell.
      'react-hooks/react-compiler': 'error',
    },
  }
);
```

----------------------------------------------------------------------------------------------------
D. VITE 8 CONFIG (oxc-based plugin-react, React Compiler on, hardened)
----------------------------------------------------------------------------------------------------

```typescript
// vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import viteCompression from 'vite-plugin-compression';
import { visualizer } from 'rollup-plugin-visualizer';
import path from 'node:path';

export default defineConfig({
  plugins: [
    react({
      // plugin-react v6 runs on oxc (NOT babel). Enable React Compiler 1.0 via the
      // plugin's official compiler option — do not use the removed `babel:` key.
      reactCompiler: true,
    }),
    tailwindcss(),
    viteCompression({ algorithm: 'brotliCompress', ext: '.br', threshold: 1024 }),
    viteCompression({ algorithm: 'gzip', ext: '.gz', threshold: 1024 }),
    visualizer({ filename: 'dist/stats.html', gzipSize: true, brotliSize: true, open: false }),
  ],
  resolve: { alias: { '@': path.resolve(__dirname, './src') } },
  build: {
    target: 'esnext',
    minify: 'esbuild',
    cssMinify: 'lightningcss',
    modulePreload: { polyfill: false },
    rollupOptions: {
      output: {
        manualChunks: {
          'three-core': ['three'],
          'gsap-lenis': ['gsap', 'lenis'],
          'react-vendor': ['react', 'react-dom', 'zustand'],
          'tanstack-virtual': ['@tanstack/react-virtual'],
          'yaml-pako': ['js-yaml', 'pako'],
        },
      },
    },
  },
});
```

====================================================================================================
3. PROJECT ARCHITECTURE & FILE HIERARCHY (v2.0)
====================================================================================================

win-debloat-web/
├── public/
│   ├── favicon.ico
│   ├── manifest.webmanifest
│   ├── sw.js
│   ├── robots.txt
│   ├── sitemap.xml
│   ├── _headers                      # Cloudflare edge headers (Section 9)
│   └── assets/ (logo, og-preview, icons 192/512/svg)
├── scripts/
│   └── check-bundle-budget.mjs       # CI: fail if critical path > 150 KB Brotli
├── src/
│   ├── main.tsx
│   ├── App.tsx
│   ├── types/                        # index.ts, software.ts, benchmark.ts,
│   │                                 # download-safety.ts, store.ts (unchanged contracts)
│   ├── data/                         # bloatwareCatalog.ts (139), softwareCatalog.ts (175+),
│   │                                 # tweaksCatalog.ts, releases.ts, cmdletsCatalog.ts
│   ├── styles/
│   │   ├── app.css                   # Tailwind v4 @theme OKLCH Cyber-OLED tokens
│   │   ├── crt-scanlines.css
│   │   ├── glowing-borders.css       # @property --border-angle laser borders
│   │   └── reduced-motion.css        # full static fallback ladder
│   ├── webgl/                        # name kept; now backend-agnostic
│   │   ├── WebGLCanvas.tsx           # fixed fullscreen canvas host
│   │   ├── RendererFactory.ts        # NEW: WebGPURenderer init w/ auto WebGL2 backend
│   │   │                             #   fallback (forceWebGL on adapter failure),
│   │   │                             #   Canvas2D/SVG terminal fallback below that
│   │   ├── SceneManager.ts
│   │   ├── MotherboardInstanced.ts   # 4,000+ SMD components, 1 draw call
│   │   ├── WindowsHologram.ts        # quad-segmented crystalline logo, TSL Fresnel
│   │   ├── ParticleVortex.ts         # 60k particles, TSL curl-noise (compute on WebGPU)
│   │   ├── BloomCompositor.ts        # RenderPass -> UnrealBloomPass (layer 1) -> OutputPass
│   │   ├── tsl/                      # NEW: TSL shader modules (replace .glsl files)
│   │   │   ├── HologramFresnel.tsl.ts
│   │   │   └── CurlNoiseParticles.tsl.ts
│   │   ├── PerformanceGovernor.ts    # DPR clamp 1.5 mobile, 30fps battery saver,
│   │   │                             #   particle-count tiering, reduced-motion kill switch
│   │   └── ContextLossCoordinator.ts
│   ├── animations/
│   │   ├── MasterClock.ts            # gsap.ticker.lagSmoothing(0) -> lenis.raf(t*1000)
│   │   ├── ScrollytellingTimeline.ts # pinned 300vh 4-stage sequence (gsap.context scoped)
│   │   ├── TextRevealAnimations.ts   # GSAP SplitText reveals gated on document.fonts.ready
│   │   └── ParallaxLayers.ts         # depth parallax + gyro tilt, reduced-motion aware
│   ├── store/                        # index.ts + slices/{software,profile,benchmark,terminal}
│   ├── audio/ProceduralAudioSynth.ts # Section 6 (unchanged API)
│   ├── hooks/
│   │   ├── useResourcePreloader.ts
│   │   ├── useWebCryptoHash.ts       # streaming SHA-256 drag-and-drop verifier
│   │   ├── useRollbackSimulator.ts   # 5-stage deterministic rollback FSM
│   │   ├── useHardwareModeler.ts     # Section 5 equations
│   │   └── useReducedMotion.ts       # NEW: media-query + user override store bridge
│   ├── components/
│   │   ├── layout/    Navbar.tsx, Footer.tsx, MobileDrawer.tsx
│   │   ├── hero/      HeroSection.tsx, OneLinerCommandBox.tsx
│   │   ├── trust/                    # NEW SECTION 8
│   │   │   ├── InspectBeforeRun.tsx  # expandable plaintext payload viewer w/ syntax highlight
│   │   │   ├── BootstrapChecksum.tsx # pinned SHA-256 of run.ps1 + copyable verify command
│   │   │   └── AttestationLinks.tsx  # GitHub release attestation / sigstore links
│   │   ├── simulator/ LiveBenchmarkSim.tsx, PrivacyScoreDial.tsx (pure SVG),
│   │   │              BeforeAfterCurtain.tsx, FrametimeOscilloscope.tsx (Canvas 60fps)
│   │   ├── customizer/ ProfileCustomizer.tsx (6 tabs via React <Activity>),
│   │   │             BloatwarePicker.tsx, PrivacyMatrix.tsx, PerformanceTweaks.tsx,
│   │   │             SystemQoLTweaks.tsx, SoftwareCatalogVirt.tsx, DnsSelector.tsx,
│   │   │             OutputCommandDock.tsx
│   │   ├── download/  DownloadMatrix.tsx, ChocoOneClick.tsx, ClientHashVerifier.tsx
│   │   ├── safety/    SafetyShowcase.tsx, DPAPILockBadge.tsx, RollbackEngineSim.tsx,
│   │   │              RegistryDiffModal.tsx
│   │   ├── terminal/  InteractiveTerminal.tsx (ARIA live region, keyboard hotkeys)
│   │   └── common/    CyberSkeletonFallback.tsx, LaserButton.tsx, ToastContainer.tsx
│   └── utils/         commandGen.ts, yamlSerializer.ts, formatters.ts
└── .github/workflows/ci.yml          # Section 12

====================================================================================================
4. GRAPHICS ENGINE SPEC (WebGPU-FIRST, SINGLE TSL CODEBASE)
====================================================================================================

1. RendererFactory.ts
   - Attempt `navigator.gpu.requestAdapter()`; on success construct `WebGPURenderer`
     (WebGPU backend). On null adapter / `webglcontextlost` / Safari < 26 / Linux Firefox,
     construct the same renderer with `forceWebGL: true` (WebGL2 backend) — the TSL shader
     graph compiles to WGSL or GLSL automatically, so NO duplicated shader code.
   - Below WebGL2: freeze a branded static SVG/Canvas2D "terminal idle" frame; the DOM app
     remains 100% functional (Customizer, downloads, verifier are never 3D-dependent).
2. HDR pipeline: r180+ WebGPURenderer HDR output enabled when the canvas reports HDR support;
   tone-map to the OKLCH theme palette otherwise.
3. Particle tiers (PerformanceGovernor): 60k (desktop hi-refresh) / 20k (mobile) /
   6k (battery saver 30fps) / 0 (prefers-reduced-motion).
4. Every frame-budget decision is data-driven: rolling 95th-percentile frame time over a
   2s window; downgrade one tier on breach, never upgrade more than once per 10s.

====================================================================================================
5. MATHEMATICAL BENCHMARK SIMULATION FORMULAS (unchanged, implementation contract)
====================================================================================================

1. RAM freed (MB):
   RAM_freed = 1420 + (AppX_selected * 18.4) + (Copilot_disabled * 380) + (Services_disabled * 42.5)
2. Active background processes:
   Procs = max(54, Procs_stock - (AppX_selected * 0.72) - (Telemetry_disabled * 14))
3. Estimated 1% low FPS gain (%):
   FPS_gain = min(28.5, (DPC_improvement * 0.12) + (RAM_freed / 1024 * 1.8) + (MMCSS * 5.2))
4. DPC latency (µs):
   DPC_opt = max(38.0, DPC_stock * 0.32 - (NetworkThrottling_disabled * 15.0))
5. Privacy score (pure SVG radial gauge):
   Score = 100 - (Telemetry_exposed * 25) - (Copilot_active * 20) - (Recall_active * 25)
               - (AdID_active * 15)

All formulas live in `useHardwareModeler.ts` as pure, unit-tested functions (Vitest),
typed with branded units (Megabytes, Microseconds, Percent) — no magic numbers in JSX.

====================================================================================================
6. ZERO-ASSET PROCEDURAL WEB AUDIO SYNTHESIZER
====================================================================================================

Keep the v1.5 `ProceduralAudioSynth` implementation (440→880Hz hover blip, 1200→200Hz
mechanical click, C5–E5–G5–C6 success chime) with these v2.0 amendments:
  * Respect BOTH the in-app mute AND `prefers-reduced-motion` (silent by default under RM).
  * Lazily create the AudioContext on first user gesture only (autoplay-policy safe).
  * All UI sound triggers route through `useEffectEvent` handlers so the synth never
    re-subscribes on re-render.

====================================================================================================
7. TRUST-FIRST INSTALL UX ("INSPECT BEFORE YOU RUN") — NEW, NON-NEGOTIABLE
====================================================================================================

A privacy hardener that asks users to paste `irm https://win-debloat.dev/run.ps1 | iex`
must earn that trust on the page itself:

1. OneLinerCommandBox always renders an adjacent "Inspect first" disclosure that expands the
   EXACT plaintext of the bootstrap payload (syntax-highlighted, copyable).
2. BootstrapChecksum.tsx pins the current SHA-256 of run.ps1 beside a ready-to-paste
   verification command:
     `(Get-FileHash .\run.ps1 -Algorithm SHA256).Hash -eq '<PINNED_HASH>'`
3. AttestationLinks.tsx links the matching GitHub Release attestation for every binary in
   DownloadMatrix (Standard/Extras, x64/ARM64).
4. A manual two-step alternative (download -> verify -> run) is presented with equal visual
   weight to the one-liner. Never darken-pattern the user into the pipe-to-shell path.
5. The ClientHashVerifier (crypto.subtle.digest, streaming for large files) accepts BOTH
   release binaries and the bootstrap script.

====================================================================================================
8. ACCESSIBILITY & RESILIENCE LADDER — HARD REQUIREMENTS
====================================================================================================

* prefers-reduced-motion: particles -> 0, Lenis disabled (native scroll), scrollytelling
  unpinned into static stacked sections, SplitText reveals -> instant, synth muted,
  oscilloscope -> static summary table.
* Full keyboard operability: Customizer tabs (roving tabindex), terminal hotkeys (1/2/3/Q)
  with visible focus rings >= 3:1, BeforeAfterCurtain draggable via arrow keys.
* ARIA: terminal output and toast stack are `aria-live="polite"` regions; the privacy dial
  exposes `role="img"` with a text equivalent.
* Contrast: OLED theme targets >= 14:1 (AAA); never below 7:1.

====================================================================================================
9. EDGE CDN & CLOUDFLARE `_headers` (hardened — a hardening tool must pass its own audit)
====================================================================================================

```http
/*
  X-Frame-Options: DENY
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()
  Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; font-src 'self' data:; img-src 'self' data:; connect-src 'self' https://api.github.com; worker-src 'self' blob:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'; require-trusted-types-for 'script'; trusted-types default dompurify
  Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Resource-Policy: same-origin

/assets/*
  Cache-Control: public, max-age=31536000, immutable

/*.html
  Cache-Control: public, max-age=0, must-revalidate
```

Changes from v1.5: dropped `'unsafe-inline'` from script-src (Vite output is fully
self-hosted static files — it was never needed); dropped `https://cdn.jsdelivr.net` and
Google Fonts origins (self-host the two font families as woff2 in /assets/fonts, subset to
the used glyph ranges); removed deprecated X-XSS-Protection; added base-uri/form-action/
frame-ancestors/COOP/CORP and Trusted Types directives.

====================================================================================================
10. SEO, METADATA & SOCIAL — NEW
====================================================================================================

* `<title>`, meta description, canonical URL per route.
* Open Graph + Twitter Card with a pre-rendered `og-preview.png` (1200x630).
* JSON-LD `SoftwareApplication`: name, operatingSystem "Windows 10, Windows 11",
  applicationCategory "UtilitiesApplication", offers price "0", license MIT, version 1.5.0,
  aggregateRating only if real data exists — never fabricate.
* sitemap.xml + robots.txt shipped in /public; sitemap referenced from robots.
* Fonts self-hosted with `font-display: swap` and preloaded via React `preload`.

====================================================================================================
11. STEP-BY-STEP EXECUTION ROADMAP (sequential, do not skip)
====================================================================================================

Step 1  — Scaffold with the EXACT configs in Section 2; `npm i -E`; prove
          `npm run typecheck && npm run lint` both pass at zero warnings before any UI work.
Step 2  — Tailwind 4.3 design system: OKLCH tokens, laser borders, scanlines,
          reduced-motion.css ladder.
Step 3  — RendererFactory + SceneManager + TSL shaders + bloom pipeline + PerformanceGovernor
          + ContextLossCoordinator. Verify WebGPU, forceWebGL, and Canvas2D paths all boot.
Step 4  — MasterClock (Lenis+GSAP), 300vh pinned scrollytelling, SplitText reveals gated on
          document.fonts.ready; full teardown via gsap.context revert.
Step 5  — Zustand slices + full data catalogs (139 bloatware / 175+ software) + commandGen
          (minify -> pako gzip -> Unicode-safe Base64) + yamlSerializer matching schema.yaml.
Step 6  — ProfileCustomizer with 6 tabs rendered through React <Activity> (state-preserving
          off-screen pre-render) + virtualized SoftwareCatalogVirt at 120 FPS windowing.
Step 7  — Benchmark simulator: LiveBenchmarkSim, SVG PrivacyScoreDial, BeforeAfterCurtain,
          FrametimeOscilloscope; Vitest unit tests for every Section 5 equation.
Step 8  — Download hub + Trust UX (Section 7): DownloadMatrix, ChocoOneClick,
          ClientHashVerifier, InspectBeforeRun, BootstrapChecksum, AttestationLinks,
          DPAPILockBadge, 5-stage RollbackEngineSim.
Step 9  — InteractiveTerminal (ANSI, hotkeys, aria-live, simulated run of the selected
          profile).
Step 10 — SEO/metadata (Section 10), sw.js, manifest, sitemap/robots.
Step 11 — FINAL GATES: typecheck (TS 7), lint --max-warnings 0, vitest green, build,
          `npm run budget` (<150 KB Brotli critical path), Lighthouse CI 4x100, manual
          reduced-motion + keyboard-only + WebGL-disabled passes.

====================================================================================================
12. CI QUALITY GATES (.github/workflows/ci.yml) — NEW
====================================================================================================

* Node 22.x, npm ci from lockfile.
* Jobs: typecheck -> lint -> test -> build -> bundle-budget -> lighthouse-ci (upload
  artifacts: dist/stats.html treemap + lighthouse report).
* Bundle budget script parses build output and FAILS if the entry chunk graph exceeds
  150 KB Brotli or if `three-core` is referenced by the entry chunk (it must stay
  behind a dynamic import).

====================================================================================================
13. ANTI-GOALS (explicitly forbidden)
====================================================================================================

* No `any`, no `as unknown as`, no non-null assertion chains to silence the compiler.
* No manual useMemo/useCallback unless a profiling trace is attached in the PR description
  (React Compiler owns this).
* No GLSL files — shaders are TSL only (single-source for WebGPU + WebGL2 backends).
* No `split-type` (GSAP SplitText is used), no `@studio-freight/*` packages.
* No CDN runtime dependencies in index.html — everything self-hosted (CSP-enforced).
* No marketing claims in UI copy that the Section 5 formulas cannot reproduce deterministically.
* No dark patterns around the pipe-to-shell one-liner (Section 7 governs).

====================================================================================================
END OF MASTER PROMPT v2.0 — BUILD TO THE GATES, NOT TO THE VIBES.
====================================================================================================
