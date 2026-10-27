# Performance measurements

## Change overview rulers — 27 October 2026

Four alternating ruler-off/on pairs in the same Neovim 0.12.5 process, 180 × 52 embedded RGB UI, 240 wheel events per sample. Three disposable repositories; the combined fixture contains seven files and 168 aligned rows. LSP is disabled for this UI benchmark. CPU is Neovim's user + system time; wall includes RPC/UI draining. No other test ran during these samples; host applications were not controlled. [All samples](benchmarks/2026-10-27-diff-ruler.json).

| Median per 240 wheel events | Ruler off | Ruler on |
|---|---:|---:|
| Neovim CPU | 127.24 ms | 136.10 ms |
| Embedded batch wall | 518.83 ms | 526.63 ms |

The ruler adds about 8.87 ms CPU and 7.81 ms batch wall in these samples. This small fixture does not establish results for large diffs, language servers, terminal FPS or GPU usage. Light mode hides the ruler; the command palette also offers an independent toggle. The diff map and its screen-row buckets are cached; scrolling only updates the ends of the viewport thumb. A separate 160-event combined-view check created zero Git subprocesses and performed zero diff-map rescans.

Ten combined-review open/close cycles left loaded-buffer count at four before and after. Settled Lua memory grew from 6,085.90 to 6,317.08 KiB after GC (about 231 KiB); this is not RSS or a guarantee of zero allocation. Combined review uses two content windows and buffers, caps content at 100 files / 4 MB / 20,000 rows, and does not create one window or parser per file.

## Explorer and navigation samples — 26 October 2026

Local development measurements from 26 October 2026, macOS, Neovim 0.12.5. The baseline already included file icons. These samples preceded the final one-row Explorer/statusline bounds correction; they describe the navigation update during development, not a performance guarantee for every release or project.

## Method

17 disposable sibling Git repos, 4,097 mixed-extension files, 4,149 expanded tree entries and a 160 × 44 embedded RGB UI. Each fresh-process comparison alternated seven before/after pairs and discarded two warmups. One plain-text editor file was open; no LSP attached. Filesystem/code caches were primed, no other test ran concurrently, and other host applications were not controlled.

CPU is Neovim user + system time, excluding Git child processes. RSS is current resident memory after full Lua GC. Each scroll batch sends 240 wheel events, ten rows each. Embedded batch wall time includes fixed UI draining/settling and is not terminal FPS or individual-input latency. Open Editors reduced the visible tree from 36 to 33 rows in these samples, so the whole-UI comparison does not isolate cost per drawn row.

## Normal mode

Each table uses its own baseline medians.

| Metric | Previous config | Updated mode |
|---|---:|---:|
| Startup | 58.19 ms | 60.63 ms |
| First Files opening | 196.38 ms | 195.84 ms |
| RSS after Files | 22.53 MiB | 22.63 MiB |
| Cold scroll CPU / 240 events | 431.44 ms | 354.35 ms |
| Warm scroll CPU / 240 events | 432.27 ms | 352.06 ms |
| Warm scroll batch wall | 735.49 ms | 728.49 ms |
| RSS after scroll | 38.86 MiB | 38.80 MiB |

## Fresh-start Light mode

Each table uses its own baseline medians.

| Metric | Previous config | Updated mode |
|---|---:|---:|
| Startup | 61.35 ms | 70.76 ms |
| First Files opening | 197.30 ms | 178.69 ms |
| RSS after Files | 22.30 MiB | 20.88 MiB |
| Cold scroll CPU / 240 events | 377.21 ms | 457.19 ms |
| Warm scroll CPU / 240 events | 360.03 ms | 359.37 ms |
| Warm scroll batch wall | 714.42 ms | 709.91 ms |
| RSS after scroll | 38.63 MiB | 37.78 MiB |

Normal-mode RSS was about 22.5 → 22.6 MiB; warm-scroll batch time was comparable. Sample ranges overlap, so CPU differences are not proof of a universal speedup.

Fresh-start Light mode reduced median RSS about 1.4 MiB and filesystem watches from 18 to zero. Its cold-scroll run was noisy: CPU median increased about 21% and batch wall time about 20%, with large outliers. Warm-scroll medians were nearly flat. Those samples remain in the raw data; Light is not claimed to be always faster.

## Same-process mode comparison

Eight alternating normal/Light pairs, with the explorer rebuilt and finding settled between modes. Both use 33 tree rows. The icon provider stays loaded after normal mode first uses it.

| Metric / 240 events | Normal | Light |
|---|---:|---:|
| Neovim CPU | 366.61 ms | 348.22 ms |
| Embedded batch wall | 752.00 ms | 761.49 ms |

This run used about 5% less CPU in Light but its median batch wall time was about 1.3% longer; ranges overlapped. Use Light to reduce background watching/decorations, not as a promise of higher frame rate. Toggling cannot unload already-running language servers or immediately reclaim all allocator/plugin memory.

## Buffer retention

An installed-profile regression opened 100 previously unopened files as previews. Listed files changed from six to seven; loaded listed file text grew from 19,976 to 23,304 bytes, one extra fixture file. Open Editors references these buffers rather than copying their contents. Modified buffers, kept tabs and files displayed in another split are preserved. These text-byte counts are not total process RSS or LSP cache sizes.

## Limits and reproduction

- No Warp/WindowServer GPU or native-terminal timing measurement.
- No active Go/Rust/Python/TypeScript LSP workload or subprocess RAM totals; these figures are not a hard memory limit for real projects.
- Short synthetic runs do not establish long-session behavior, Linux/WSL behavior or every repository layout.
- The final statusline correction has separate rendering/bounds regression coverage in [Verification](verification.md).

[Normal raw data](benchmarks/2026-10-26-normal.json) · [Light raw data, including outliers](benchmarks/2026-10-26-light.json) · [Controlled mode samples](benchmarks/2026-10-26-controlled-light.json)

Use [the benchmark commands in Contributing](../CONTRIBUTING.md) with copies of the configs to reproduce a comparison on your own machine.
