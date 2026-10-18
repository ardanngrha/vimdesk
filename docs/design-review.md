# Website review

Result: PASS. Scope: the documentation website and its installation copy, reviewed on 18 October 2026.

Rules: [anti-slop core](https://github.com/miqdadbadjuber/anti-slop/blob/main/skills/antislop/SKILL.md), plus its UI, copywriting, and mobile-layout skills. The owner selected DURING mode. [DESIGN.md](../DESIGN.md) records the owner's request for simple documentation, direct language, and the existing TokyoNight identity.

## Hard Gate

- R-02 PASS: the HTML, JavaScript labels and shared guide JSON contain no em dashes; headings name their subject or action.
- R-03 PASS: browser layout checks at 320, 760 and 1280 pixels returned page widths equal to viewport widths, with no undersized controls in the measured set.
- R-17 PASS: version requirements match the config; the nine steps are the actual guide entries. There are no usage or performance statistics.
- R-18 PASS: the page has no testimonials, customer names or avatars.
- R-23 PASS: no new visual asset was created for this revision. The header is text; the earlier generated favicon was removed. Existing screenshots remain labelled as practice repositories.
- R-24 PASS: all nine step links and four section links were clicked and reached their matching hash. Fourteen unique external documentation/source URLs returned HTTP 200.
- R-25 PASS: measured text/background pairs range from 5.26:1 to 11.21:1. The control border is 4.08:1 against the background. These measurements cover website text and controls, not the text embedded in Neovim screenshots.
- R-26 PASS: both language options, all 16 copy controls, contents, optional sections, troubleshooting disclosures and screenshot tabs produced their expected state changes.
- R-27 PASS: the normal guide rendered nine steps. A paused fetch showed loading text; an empty-guide fixture showed its empty message; a missing-file fixture showed an alert and retained the Markdown fallback link. The original guide was restored afterward.
- R-28 PASS: troubleshooting covers existing-config preservation, accounts, PATH failures, editing/quit modes, platform support and an existing checkout directory.
- R-32 PASS: Tab reached the header link with a 2px solid focus outline; Enter followed the skip link to main; Enter opened/closed disclosures; Home selected the first screenshot tab.
- R-33 PASS: UI changes were written directly in HTML, CSS and JavaScript. The Markdown generator consumes shared guide data; it does not patch UI source. State-test fixtures were separate copies.
- R-34 PASS: the page has one fixed TokyoNight theme and no theme toggle promising another mode.
- R-35 PASS: the site ran on a local HTTP server and was exercised in the browser. Click-through evidence is recorded below. The normal page reported no console errors.
- R-36 PASS: no security, compliance, customer or performance claims were added.
- R-37 PASS: the owner's documentation-first direction was recorded before the revision. ENERGY 1 / RHYTHM 1 / MOTION 1 follows the request for a simple page.
- R-38 PASS: commands come from this project or the linked official instructions. Screenshot repositories are explicitly labelled as practice data.

## Purpose-Gate

- R-01 PASS: flat TokyoNight surfaces connect the docs with the configured editor; blue identifies links, selected tabs and focus.
- R-04 PASS: the page uses text labels and native disclosure markers, without decorative feature icons.
- R-06 PASS: system sans is used for reading; monospace is restricted to commands and step indices.
- R-07 PASS: the background has no decorative pattern.
- R-08 PASS: the page has no repeated arrow decoration on links or buttons.
- R-09 PASS: no eyebrow badges, status dots or capsule claims remain.
- R-10 PASS: no glass or backdrop blur is used.
- R-12 PASS: no elevation shadows are used.
- R-13 PASS: no glow is used; focus uses an outline.
- R-14 PASS: the feature-card section was removed; instructions use one reading column.
- R-19 PASS: no entry animation, smooth scrolling or looping motion is used. Copy feedback is temporary text.
- R-22 PASS: the only content images are the actual Neovim screenshots, opened on request.

## Design consistency

- ENERGY PASS: small headings and plain prose match the quiet documentation direction.
- RHYTHM PASS: regular step spacing supports sequential installation; optional material uses disclosures.
- MOTION PASS: no decorative animation is present.
- Focus PASS: the title identifies the config; the current numbered step identifies the next instruction.
- Spacing PASS: section and step spacing separate tasks; the promotional opening and closing sections are gone.
- Accent PASS: blue marks links, focus and the selected screenshot tab.
- Identity PASS: Terminal / Inside Neovim labels consistently distinguish command contexts.
- Design Read PASS: the audience, palette, typography, layout, interaction and reason for each are recorded in DESIGN.md.

## Craftsmanship and Quality Locks

- C-1 PASS: major choices have one-line reasons in DESIGN.md.
- C-2 PASS: controls have real behavior; external anchors have verified destinations.
- C-3 PASS: the document contains installation, optional setup, screenshots and troubleshooting. No section exists to fill a marketing template.
- C-4 PASS: narrow, intermediate and wide layouts, both languages, keyboard controls, normal/loading/empty/error states were checked.
- C-5 PASS: claims are bounded to actual config behavior and the recorded verification.
- R-05 PASS: installation appears before screenshots, with a contents list alongside it when space permits.
- R-11 PASS: small consistent radii are used on command blocks and controls; there are no pill components.
- R-15 PASS: actions say Copy, Markdown guide, Show screenshots or the section they open.
- R-16 PASS: promotional headlines, generic benefits and repeated invitations were removed.
- R-20 PASS: the visual identity follows the editor's TokyoNight palette and command-context labels.
- R-21 PASS: the fixed dark theme matches the owner's existing developer-tool theme.
- R-29 PASS: surfaces and text use neutral TokyoNight tones, with one blue accent.
- R-30 PASS: the page follows its installation content; it does not copy a commercial product layout.
- R-31 PASS: purpose is documented for color, typography, spacing, structure and image use.

## Browser evidence

- Nine numbered contents links: each click reached its corresponding step hash.
- Install, Additional setup, Screenshots and Troubleshooting links: each reached its section hash.
- Brand link: reached overview. Skip link: Enter reached main.
- Fifteen guide copy buttons and one optional LSP copy button: each displayed copied feedback. This checks browser feedback, not OS-level clipboard integration in every terminal/browser.
- Language selector: switched the heading and all nine guide steps between Indonesian and English.
- Three optional disclosures and six troubleshooting disclosures: click opened each; Enter closed each.
- Screenshot disclosure: opened. Git diff, Conflicts and Search/replace: each selected the corresponding real image. Home returned selection to Git diff.
- Mobile contents: opened on tap, and closed after selecting a step.
- Responsive checks: 320/320, 760/760 and 1280/1280 page/viewport widths; all measured actionable targets were at least 44 by 44 pixels.
- Website color pairs: body 10.26:1, muted 7.92:1, links/focus 6.66:1, code 11.21:1, selected tab 7.27:1, hovered copy 5.26:1, control boundary 4.08:1.
- Source checks: JavaScript parses; both static languages cover every translated HTML label; generated Markdown matches shared guide JSON; eleven automated installer, AI-adapter and onboarding tests passed, including managing a legacy profile and its backup after the VimDesk rename.

The renamed `vimdesk` launcher/profile also passed the native Neovim runtime test with three temporary repositories, cached locked plugins, real LazyGit startup, AI draft routing through the new config path, three-pane conflict resolution, local Fetch All, search and selected replacement. Existing user configs were not modified.

External sites were checked by HTTP response, not exhaustively tested as applications. The guide's Homebrew/Apple instructions were checked against their sources; no factory-reset Mac was used for this revision. This review does not claim full Linux, Windows, or provider-CLI compatibility.

## Header control correction

The owner reported the language arrow sitting against the right border. The native select remains in use, with its browser decoration replaced by a CSS chevron inset 15px from the edge. Reserved right padding separates the label from the arrow. The language control and GitHub link now share a 14.4px font size and 44px minimum height.

Browser verification passed for Indonesian and English selection, visible keyboard focus, and 320px and 1280px viewport widths without horizontal overflow. This is a scoped header correction; the installation guide and Neovim configuration are unchanged.

## Linux and Windows installation guides

The owner requested beginner installation tutorials for Linux and Windows. A native operating-system selector now changes the existing numbered guide, contents, references, and Markdown destination. Linux covers Ubuntu/Debian with Bash and Homebrew. Windows uses Ubuntu in WSL 2, with Windows PowerShell explicitly labelled before switching to Ubuntu. The page and guides state that these are documented paths without end-to-end VimDesk runtime validation. Native Windows remains unsupported.

The existing item-by-item gate above applies to the retained components and visual system. The following evidence covers the extension:

- Hard gate PASS, scoped: no identity asset or statistic was invented; official Homebrew and Microsoft documentation supports the new platform instructions. No native-Windows or Linux-runtime compatibility claim was added.
- R-03 PASS: 320px and 1280px page widths matched their viewport widths. The new select is 44px high and stays within the narrow reading column.
- R-23 / R-37 PASS: the owner explicitly requested both platform tutorials. The selector reuses the existing native select and chevron treatment; its role and URL behavior are recorded in DESIGN.md.
- R-24 / R-26 / R-35 PASS: 9 macOS, 9 Linux, and 10 Windows contents links each reached their step hash. All 15 macOS, 16 Linux, and 18 Windows guide copy buttons displayed Copied feedback. This is browser-feedback verification, not verification of every OS clipboard transport.
- R-25 / R-29 PASS, scoped: the selector uses the same previously measured TokyoNight text, background, border, and focus colors; no new color pair was introduced.
- R-27 PASS: separate local fixtures returned an empty guide and an unavailable platform file. The page displayed its empty/error message and retained the correct Linux/Windows Markdown fallback. Normal steps were restored afterwards. These fixtures did not alter published source files.
- R-32 PASS: Tab from the OS select reached the first copy control, with the existing visible 2px focus outline.
- R-33 PASS: HTML, CSS, JavaScript, shared JSON, and generator changes were edited directly. Only the established Markdown generator and formatter produced derived output.
- R-34 / R-38 PASS, scoped: the retained fixed theme and real content remain in use. Neither Linux nor WSL installation was executed on this Mac; no such execution is claimed.
- Purpose gate PASS: one selector prevents mixing commands across operating systems. The same reading column, step structure, source list, and copy controls serve all platforms without adding decorative components.
- Liveliness PASS: ENERGY 1 / RHYTHM 1 / MOTION 1 is retained. Terminal / Windows PowerShell / Inside Neovim labels identify the context for each instruction.
- Craftsmanship and copy checklist PASS, scoped: all six OS/language combinations rendered the expected localized heading, matching contents count, and Markdown link. No macOS xcode-select command appeared in Linux or Windows steps. Native Windows limits, WSL file locations, provider environment, and clipboard boundaries are explicit.
- Source checks PASS: all eleven automated tests passed, including extended guide synchronization, shared step references, shell syntax checks, and WSL command-context checks. Six Markdown files match the shared data; JavaScript parses; git diff whitespace check passed.
- Reload PASS: the selected Linux OS and Indonesian language survived reloading the shareable URL.

Sources checked: [Homebrew on Linux](https://docs.brew.sh/Homebrew-on-Linux), [Homebrew support tiers](https://docs.brew.sh/Support-Tiers), [current Neovim formula](https://formulae.brew.sh/formula/neovim), [Microsoft WSL installation](https://learn.microsoft.com/en-us/windows/wsl/install), [WSL file storage](https://learn.microsoft.com/en-us/windows/wsl/filesystems), and [WSL troubleshooting](https://learn.microsoft.com/en-us/windows/wsl/troubleshooting). The new guides link directly to their relevant references.

## Visible platform links in the contents

The owner requested that macOS, Linux, and Windows appear in the left table of contents instead of an OS dropdown. All three native links now appear before the current guide's numbered steps. The language selector remains unchanged.

- Hard gate PASS, scoped: the OS dropdown was removed; all three native links have real, shareable destinations and preserve the current language. No new content claims or visual assets were introduced.
- R-03 PASS: the 320px page matched the viewport width, and each OS link measured 44px high. The existing mobile contents disclosure opens, and choosing a guide closes it and navigates to the instructions.
- R-24 / R-26 / R-35 PASS: clicking macOS, Linux, and Windows rendered their 9, 9, and 10 steps with the correct title, URL, and active link. Browser Back returned from Windows to Linux; Forward restored Windows.
- R-25 / R-32 PASS, scoped: links inherit the established text palette; Enter activated the Linux link, preserving a visible 2px keyboard outline.
- R-23 / R-37 PASS: the owner explicitly chose table-of-contents navigation. DESIGN.md records this direction.
- R-33 PASS: the HTML, CSS, and JavaScript were edited directly; the formatter only reformatted those source files.
- Purpose gate PASS: the selected link uses the existing accent and a left border to identify the active guide. This is a navigation state, not decoration. All three choices remain together above the numbered steps.
- Liveliness PASS: ENERGY 1 / RHYTHM 1 / MOTION 1 is unchanged; the existing reading column, typography, and command-context labels remain.
- Craftsmanship PASS, scoped: no guide data, installation command, fallback, or editor configuration changed. The previously recorded item-by-item gate applies to the retained components. English destinations were checked, the mobile selection worked, and the normal-page browser error log was empty.

## Desktop contents and compact mobile navigation

The owner requested non-collapsible desktop contents, then asked for the most usable mobile treatment. The overall contents now use a plain heading and navigation. Desktop always displays the numbered steps with no collapse control. Mobile always shows all three OS links; only the numbered installation steps use a native disclosure. Section links wrap to keep the mobile navigation compact.

- Hard gate PASS, scoped: no new assets, claims, or destinations were added. Existing OS links and guide commands are retained.
- R-03 PASS: at 320px all three OS links occupy the same row, each is 44px high, and page width equals viewport width. The guide overview remains visible below the compact navigation.
- R-24 / R-26 / R-35 PASS: the mobile step disclosure opened; choosing its first numbered link reached the correct step hash and closed only that disclosure. All OS links remained rendered. Enter activated the Linux OS link on desktop.
- R-25 / R-32 PASS, scoped: retained colors and focus styles are unchanged; the disclosure is native keyboard-operable HTML.
- R-23 / R-37 PASS: the desktop behavior follows the owner's explicit instruction; the mobile refinement follows the owner's request for the most usable narrow-screen approach. DESIGN.md records both.
- R-33 PASS: the implementation is directly in HTML, CSS, and JavaScript; no rewriting script implements the feature.
- R-34 / R-38 PASS, scoped: the fixed theme, real content, and existing OS support limits are unchanged.
- Purpose gate PASS: the mobile disclosure contains only the long numbered list, keeping OS choices visible while reducing the distance to the guide. Desktop hides that disclosure control and expands its content.
- Liveliness PASS: ENERGY 1 / RHYTHM 1 / MOTION 1 remains; no new animation or decorative treatment was added.
- Craftsmanship PASS, scoped: desktop breakpoint verification waited for the steps to become visible, then confirmed the details element was open and its summary hidden. Both languages render the step label. Existing guide synchronization and JavaScript syntax checks pass. This extends the retained item-by-item gate above.
