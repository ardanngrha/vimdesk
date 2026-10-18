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
