# Website direction

This records the owner's instructions: a simple site, direct wording, no promotional copy, and installation instructions for someone starting with an empty Mac. The existing workbench uses TokyoNight Moon. The owner selected VimDesk as the project name.

- Purpose: help a new user install and open the configuration.
- Audience: a macOS, Ubuntu/Debian, or Windows WSL 2 user who may not have used Terminal or Neovim. The owner requested beginner guides for Linux and Windows as well as macOS.
- Voice: plain instructions in Indonesian and English. Name the tool, command, expected result, and recovery action.
- Layout: documentation with a contents list and one reading column. Installation precedes optional language servers and screenshots.
- Palette: TokyoNight surfaces and text, with blue for links and keyboard focus. This connects the documentation to the configured editor.
- Typography: system sans for reading, system monospace only for commands and file paths. No external fonts.
- Spacing: separate steps by reading task. Keep the first instructions visible without a promotional section above them.
- Components: plain sections, code blocks with copy, disclosure sections for optional material. No feature cards, decorative status dots, badges, CTA footer, new illustrations, or invented metrics.
- Assets: reuse existing screenshots of disposable repositories. The header uses the product name as text; no new logo is created.
- Interaction: native links, disclosure controls, a language selector, and copy buttons. Controls have visible keyboard focus and minimum 44px hit areas.
- Responsive behavior: desktop contents are always expanded beside the document, with no collapse control. Following the owner's mobile follow-up, narrow screens keep the three OS links visible and place only the numbered installation steps in a disclosure. Other section links wrap compactly. Selecting an OS never hides the OS links; selecting a numbered step closes only its mobile disclosure.
- ENERGY 1 / RHYTHM 1 / MOTION 1: quiet documentation, regular step structure, and no scripted animation or smooth scrolling.
- Identity motif: consistent Terminal / Inside Neovim labels tie each instruction to the place where it is run.
- Platform guidance: the owner requested visible macOS, Linux, and Windows links in the table of contents instead of a dropdown. The three links appear before the current guide's numbered steps and mark the active guide. Each changes the guide, references, and Markdown destination. Native URLs allow sharing, opening a new tab, and browser Back/Forward. PowerShell blocks are labelled before the Windows guide switches to Ubuntu. Linux and WSL remain documented paths without runtime verification.

Anti-slop core, UI, copywriting, and mobile-layout rules are applied in DURING mode, selected by the owner for this session. The skill is read from its supplied source without installing global settings or changing agent entry files.
