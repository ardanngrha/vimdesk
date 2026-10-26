"use strict";

const strings = {
  id: {
    skip: "Langsung ke konten",
    contents: "Daftar isi",
    stepContents: "Langkah instalasi",
    description:
      "Konfigurasi Neovim untuk bekerja dengan beberapa repo Git. Termasuk sidebar Git, LazyGit, diff, dan search/replace.",
    requirements:
      "Membutuhkan Neovim 0.12+ dan Python 3.9+. Config dipasang sebagai profil vimdesk, terpisah dari ~/.config/nvim. Pilih panduan sesuai sistem operasi; Windows memakai WSL 2.",
    markdownGuide: "Panduan Markdown",
    installTitle: "Install",
    installIntro:
      "Ikuti langkah berurutan. Jika suatu alat sudah terpasang, cek versinya lalu lanjutkan.",
    loading: "Memuat langkah instalasi…",
    guideError:
      "Langkah instalasi gagal dimuat. Buka Panduan Markdown di atas untuk melanjutkan.",
    guideEmpty:
      "Langkah instalasi belum tersedia di halaman ini. Buka Panduan Markdown di atas.",
    sources: "Referensi resmi",
    terminal: "Terminal",
    powershell: "PowerShell Windows",
    neovim: "Di dalam Neovim",
    copy: "Salin",
    copied: "Tersalin",
    copyError: "Perintah belum tersalin. Pilih teks dan salin secara manual.",
    success: "Tanda berhasil:",
    extrasTitle: "Pengaturan tambahan",
    lspTitle: "Language server (opsional)",
    lspText:
      "Language server menyediakan completion, diagnostik, dan formatting. Jalankan dari folder sumber untuk memasang server Go, Rust, JS/TS/React, dan Python. Proyek tetap membutuhkan runtime dan dependensinya sendiri.",
    lspMore: "Detail server dan runtime",
    aiTitle: "AI commit message (opsional)",
    aiText:
      "Pasang dan login Codex CLI atau Claude Code mengikuti panduan resminya. Simpan file, stage perubahan, klik Generate di sidebar Git, pilih agent, lalu review pesannya sebelum Commit. Staged diff dikirim ke provider memakai akunmu; biaya penggunaan normal berlaku.",
    filesTitle: "Files, preview, dan mode ringan",
    filesText: "Sekali klik untuk preview; double-click, Enter, atau mulai edit untuk menyimpan tab. Open Editors dan tombol file/folder berada di atas tree.",
    fontText: "Icon file membutuhkan Nerd Font yang dipilih di terminal. Space ui mematikan icon jika memakai font biasa. Untuk WSL, font dipasang di Windows Terminal.",
    lightText: "Space up men-toggle Light mode. Watcher dan dekorasi explorer dimatikan; refresh dengan u di Files atau r di Git. Language server tetap berjalan.",
    filesMore: "Panduan Files dan pengaturan",
    workflowTitle: "Pemakaian, update, dan backup",
    workflow: "Editing, Git, konflik, dan search/replace",
    maintenance: "Update, restore, dan uninstall",
    previewTitle: "Tampilan",
    previewOpen: "Lihat screenshot",
    realUI: "Screenshot dari Neovim dengan repo latihan lokal.",
    tabReview: "Git diff",
    tabConflicts: "Konflik",
    tabSearch: "Search/replace",
    tabExplorer: "Files",
    faqTitle: "Masalah umum",
    faqQ1: "Config Neovim lama akan tertimpa?",
    faqA1:
      "Install default memakai profil vimdesk, terpisah dari ~/.config/nvim. Upgrade profil VimDesk membuat backup. Mengganti config default membutuhkan flag khusus di dokumentasi.",
    faqQ2: "Perlu akun AI atau GitHub?",
    faqA2:
      "Download repo publik dan latihan lokal tidak membutuhkan login. AI opsional. Push ke proyek sungguhan membutuhkan remote, identitas commit, dan autentikasi Git. Repo latihan tidak memiliki remote.",
    faqQ3: "brew atau vimdesk tidak ditemukan",
    faqA3:
      "Untuk brew, jalankan Next steps dari installer Homebrew. Untuk VimDesk, pakai ~/.local/bin/vimdesk atau ikuti langkah PATH. Buka ulang Terminal setelah mengubah konfigurasi shell.",
    faqQ4: "Tidak bisa mengetik atau keluar dari Neovim",
    faqA4:
      "Tekan i untuk mengetik, lalu Esc untuk kembali ke Normal mode. Ketik :w lalu Enter untuk menyimpan, atau :qa lalu Enter untuk keluar. Space q q membuka konfirmasi jika ada perubahan belum tersimpan.",
    faqQ5: "Dukungan Linux dan Windows",
    faqA5:
      "Pilih Linux untuk panduan Ubuntu/Debian, atau Windows untuk WSL 2 + Ubuntu. Instalasi Windows native belum didukung. Linux dan WSL belum diuji menyeluruh; pengujian runtime VimDesk saat ini dilakukan di macOS.",
    faqQ6: "Folder sudah ada saat git clone",
    faqA6:
      "Buka folder vimdesk yang sudah diunduh, simpan perubahan lokal, lalu jalankan git pull --ff-only dan ./install.sh. Jangan hapus folder yang berisi pekerjaanmu.",
    report: "Laporkan masalah",
  },
  en: {
    skip: "Skip to content",
    contents: "Contents",
    stepContents: "Installation steps",
    description:
      "Neovim configuration for working across Git repositories. Includes a Git sidebar, LazyGit, diff views, and search/replace.",
    requirements:
      "Requires Neovim 0.12+ and Python 3.9+. The config installs as a separate vimdesk profile, away from ~/.config/nvim. Choose your operating-system guide; Windows uses WSL 2.",
    markdownGuide: "Markdown guide",
    installTitle: "Install",
    installIntro:
      "Follow the steps in order. If a tool is already installed, check its version and continue.",
    loading: "Loading installation steps…",
    guideError:
      "Installation steps could not load. Open the Markdown guide above to continue.",
    guideEmpty:
      "Installation steps are not available on this page. Open the Markdown guide above.",
    sources: "Official references",
    terminal: "Terminal",
    powershell: "Windows PowerShell",
    neovim: "Inside Neovim",
    copy: "Copy",
    copied: "Copied",
    copyError:
      "The command was not copied. Select the text and copy it manually.",
    success: "Success check:",
    extrasTitle: "Additional setup",
    lspTitle: "Language servers (optional)",
    lspText:
      "Language servers provide completion, diagnostics, and formatting. Run this from the source folder to install servers for Go, Rust, JS/TS/React, and Python. Projects still need their own runtimes and dependencies.",
    lspMore: "Server and runtime details",
    aiTitle: "AI commit messages (optional)",
    aiText:
      "Install and authenticate Codex CLI or Claude Code using its official guide. Save files, stage changes, click Generate in the Git sidebar, select an agent, and review the message before Commit. The staged diff goes to the provider using your account; normal usage costs apply.",
    filesTitle: "Files, previews, and Light mode",
    filesText: "Single-click to preview; double-click, press Enter, or edit to keep the tab. Open Editors and file/folder controls sit above the tree.",
    fontText: "File icons need a Nerd Font selected in your terminal. Space ui disables icons for a plain font. For WSL, install/select the font in Windows Terminal.",
    lightText: "Space up toggles Light mode. Explorer watchers and decorations stop; refresh with u in Files or r in Git. Language servers keep running.",
    filesMore: "Files and settings guide",
    workflowTitle: "Usage, updates, and backups",
    workflow: "Editing, Git, conflicts, and search/replace",
    maintenance: "Update, restore, and uninstall",
    previewTitle: "Screenshots",
    previewOpen: "Show screenshots",
    realUI: "Screenshots from Neovim using local practice repositories.",
    tabReview: "Git diff",
    tabConflicts: "Conflicts",
    tabSearch: "Search/replace",
    tabExplorer: "Files",
    faqTitle: "Troubleshooting",
    faqQ1: "Will this overwrite my existing Neovim config?",
    faqA1:
      "The default install uses a separate vimdesk profile, away from ~/.config/nvim. VimDesk upgrades create backups. Replacing the default config requires an explicit flag described in the docs.",
    faqQ2: "Do I need an AI or GitHub account?",
    faqA2:
      "Downloading the public repo and practicing locally needs no login. AI is optional. Pushing real projects needs a remote, commit identity, and Git authentication. Practice repositories have no remotes.",
    faqQ3: "brew or vimdesk is not found",
    faqA3:
      "For brew, follow the Homebrew installer’s Next steps. For VimDesk, use ~/.local/bin/vimdesk or complete the PATH step. Reopen Terminal after changing shell configuration.",
    faqQ4: "Cannot type or quit Neovim",
    faqA4:
      "Press i to type, then Esc to return to Normal mode. Type :w and Enter to save, or :qa and Enter to quit. Space q q offers a confirmation when changes are unsaved.",
    faqQ5: "Linux and Windows support",
    faqA5:
      "Choose Linux for Ubuntu/Debian instructions, or Windows for WSL 2 + Ubuntu. Native Windows is unsupported. Linux and WSL have not been tested end to end; VimDesk runtime verification currently uses macOS.",
    faqQ6: "The folder already exists during git clone",
    faqA6:
      "Open the existing vimdesk folder, preserve local edits, then run git pull --ff-only and ./install.sh. Do not delete a folder containing your work.",
    report: "Report an issue",
  },
};

const views = {
  explorer: {
    image: "images/explorer.png?v=20261026",
    alt: "File explorer with Open Editors, file icons and creation controls",
    id: "Files, Open Editors, icon file, dan tombol file/folder.",
    en: "Files, Open Editors, file icons, and file/folder controls.",
  },
  review: {
    image: "images/review.png?v=20261026",
    alt: "Git sidebar with commit graph and Before / After review",
    id: "Sidebar Git, Graph commit, dan perbandingan Before / After.",
    en: "Git sidebar, commit graph, and Before / After comparison.",
  },
  conflicts: {
    image: "images/conflicts.png?v=20261026",
    alt: "Incoming left, Current right, editable Result below",
    id: "Incoming di kiri, Current di kanan, Result yang bisa diedit di bawah.",
    en: "Incoming on the left, Current on the right, editable Result below.",
  },
  search: {
    image: "images/search.png?v=20261026",
    alt: "Search and replace fields with a replacement preview",
    id: "Kolom Search dan Replace, dengan preview perubahan per file.",
    en: "Search and Replace fields, with per-file replacement previews.",
  },
};

const storage = {
  get(key, fallback) {
    try {
      return localStorage.getItem(key) ?? fallback;
    } catch {
      return fallback;
    }
  },
  set(key, value) {
    try {
      localStorage.setItem(key, value);
    } catch {
      /* Language selection also works without persistence. */
    }
  },
};
const queryLanguage = new URLSearchParams(location.search).get("lang");
let language = ["id", "en"].includes(queryLanguage)
  ? queryLanguage
  : storage.get("workbench-language", "id");
if (!strings[language]) language = "id";
let guide = null;
let platformGuides = null;
const queryPlatform = new URLSearchParams(location.search).get("os");
let platform = ["macos", "linux", "windows"].includes(queryPlatform)
  ? queryPlatform
  : "macos";
let guideState = "loading";
let selectedView = "review";
let announcementTimer;
const tr = (key) => strings[language][key] || key;
const element = (tag, className, text) => {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
};

function announce(message) {
  const box = document.getElementById("announcement");
  box.textContent = message;
  clearTimeout(announcementTimer);
  announcementTimer = setTimeout(() => {
    box.textContent = "";
  }, 2500);
}

function renderView() {
  const view = views[selectedView];
  const image = document.getElementById("preview-image");
  image.src = view.image;
  image.alt = view.alt;
  document.getElementById("preview-caption").textContent = view[language];
  document
    .getElementById("preview-panel")
    .setAttribute("aria-labelledby", `tab-${selectedView}`);
  document.querySelectorAll("[data-view]").forEach((button) => {
    const active = button.dataset.view === selectedView;
    button.setAttribute("aria-selected", String(active));
    button.tabIndex = active ? 0 : -1;
  });
}

function codeBlock(block, id) {
  const container = element("div", "code-block");
  const toolbar = element("div", "code-toolbar");
  const label = element(
    "span",
    "",
    tr(block.where) + (block.label ? `: ${block.label[language]}` : ""),
  );
  const button = element("button", "", tr("copy"));
  button.type = "button";
  button.dataset.copyTarget = id;
  button.setAttribute("aria-label", `${tr("copy")}: ${tr(block.where)}`);
  const pre = element("pre");
  const code = element("code", "", block.code);
  code.id = id;
  pre.append(code);
  toolbar.append(label, button);
  container.append(toolbar, pre);
  return container;
}

function renderGuide() {
  const host = document.getElementById("guide-steps");
  const navigation = document.getElementById("step-nav");
  host.replaceChildren();
  navigation.replaceChildren();
  if (guideState !== "ready") {
    const key = {
      loading: "loading",
      empty: "guideEmpty",
      error: "guideError",
    }[guideState];
    const message = element("p", "muted", tr(key));
    message.setAttribute("role", guideState === "error" ? "alert" : "status");
    host.append(message);
    return;
  }
  const selected = platformGuides.platforms[platform];
  document.getElementById("install-title").textContent =
    selected.title[language];
  document.getElementById("platform-note").textContent =
    selected.intro[language];
  document.getElementById("platform-notes").textContent =
    selected.notes[language];
  const steps = new Map(
    [...guide.steps, ...platformGuides.steps].map((step) => [step.id, step]),
  );
  selected.stepIds
    .map((id) => steps.get(id))
    .forEach((step, index) => {
      const section = element("article", "guide-step");
      section.id = `step-${step.id}`;
      const heading = element("div", "step-heading");
      const title = element("h3", "", step.title[language]);
      title.id = `title-${step.id}`;
      section.setAttribute("aria-labelledby", title.id);
      heading.append(element("span", "", String(index + 1)), title);
      section.append(heading, element("p", "step-intro", step.intro[language]));
      step.blocks.forEach((block, blockIndex) => {
        section.append(codeBlock(block, `code-${step.id}-${blockIndex}`));
      });
      const check = element("p", "step-check");
      check.append(
        element("strong", "", tr("success") + " "),
        document.createTextNode(step.expected[language]),
      );
      section.append(check);
      if (step.note)
        section.append(element("p", "step-note", step.note[language]));
      host.append(section);
      const link = element("a");
      link.href = `#step-${step.id}`;
      link.append(
        element("span", "", String(index + 1)),
        document.createTextNode(step.title[language]),
      );
      navigation.append(link);
    });
  const sources = document.getElementById("install-sources");
  sources.replaceChildren();
  [...guide.sources, ...selected.sources].forEach((source) => {
    const item = element("li");
    const link = element("a", "", source.title);
    link.href = source.url;
    item.append(link);
    sources.append(item);
  });
}

function translate() {
  document.documentElement.lang = language;
  document.getElementById("language").value = language;
  document.querySelectorAll("[data-i18n]").forEach((node) => {
    node.textContent = tr(node.dataset.i18n);
  });
  document.querySelectorAll("[data-platform]").forEach((link) => {
    const url = new URL(location.href);
    url.searchParams.set("lang", language);
    url.searchParams.set("os", link.dataset.platform);
    url.hash = "install";
    link.href = url.href;
    if (link.dataset.platform === platform)
      link.setAttribute("aria-current", "page");
    else link.removeAttribute("aria-current");
  });
  const filename =
    (language === "id" ? "mulai-dari-nol" : "getting-started") +
    (platform === "macos" ? "" : `-${platform}`);
  document.getElementById("markdown-guide").href =
    `https://github.com/ardanngrha/vimdesk/blob/main/docs/${filename}.md`;
  renderView();
  renderGuide();
}

document.getElementById("language").addEventListener("change", (event) => {
  language = event.target.value;
  storage.set("workbench-language", language);
  const url = new URL(location.href);
  url.searchParams.set("lang", language);
  history.replaceState(null, "", url);
  translate();
});

document.getElementById("platform-nav").addEventListener("click", (event) => {
  const link = event.target.closest("a[data-platform]");
  if (
    !link ||
    event.button !== 0 ||
    event.metaKey ||
    event.ctrlKey ||
    event.shiftKey ||
    event.altKey
  )
    return;
  event.preventDefault();
  platform = link.dataset.platform;
  history.pushState(null, "", link.href);
  translate();
  if (!wideContents.matches) stepContents.open = false;
  document.getElementById("install").scrollIntoView();
  announce(
    platformGuides?.platforms[platform].title[language] || tr("installTitle"),
  );
});

window.addEventListener("popstate", () => {
  const params = new URLSearchParams(location.search);
  platform = ["macos", "linux", "windows"].includes(params.get("os"))
    ? params.get("os")
    : "macos";
  if (["id", "en"].includes(params.get("lang"))) language = params.get("lang");
  translate();
});

const stepContents = document.getElementById("step-contents");
const wideContents = window.matchMedia("(min-width: 980px)");
stepContents.open = wideContents.matches;
wideContents.addEventListener("change", (event) => {
  stepContents.open = event.matches;
});
stepContents.addEventListener("click", (event) => {
  if (event.target.closest("a") && !wideContents.matches)
    stepContents.open = false;
});

document.querySelectorAll("[data-view]").forEach((button) => {
  button.addEventListener("click", () => {
    selectedView = button.dataset.view;
    renderView();
  });
  button.addEventListener("keydown", (event) => {
    const buttons = [...document.querySelectorAll("[data-view]")];
    let index = buttons.indexOf(button);
    if (event.key === "ArrowRight") index = (index + 1) % buttons.length;
    else if (event.key === "ArrowLeft")
      index = (index + buttons.length - 1) % buttons.length;
    else if (event.key === "Home") index = 0;
    else if (event.key === "End") index = buttons.length - 1;
    else return;
    event.preventDefault();
    selectedView = buttons[index].dataset.view;
    renderView();
    buttons[index].focus();
  });
});

document.addEventListener("click", async (event) => {
  const button = event.target.closest("[data-copy-target]");
  if (!button) return;
  const code = document.getElementById(button.dataset.copyTarget);
  if (!code) return;
  let copied = false;
  try {
    await navigator.clipboard.writeText(code.textContent);
    copied = true;
  } catch {
    const input = element("textarea", "", code.textContent);
    input.style.position = "fixed";
    input.style.opacity = "0";
    document.body.append(input);
    input.select();
    try {
      copied = document.execCommand("copy");
    } catch {
      /* The original code block remains available for manual copying. */
    }
    input.remove();
    button.focus();
  }
  if (copied) {
    button.textContent = tr("copied");
    announce(tr("copied"));
    setTimeout(() => {
      button.textContent = tr("copy");
    }, 1800);
  } else announce(tr("copyError"));
});

translate();
Promise.all(
  ["assets/guide.json", "assets/platform-guides.json"].map(async (path) => {
    const response = await fetch(path);
    if (!response.ok) throw new Error("Guide unavailable");
    return response.json();
  }),
)
  .then(([data, platforms]) => {
    if (!Array.isArray(data.steps)) throw new Error("Invalid guide");
    if (!data.steps.length) {
      guideState = "empty";
      renderGuide();
      return;
    }
    const ids = new Set(
      [...data.steps, ...platforms.steps].map((step) => step.id),
    );
    for (const key of ["macos", "linux", "windows"]) {
      const selected = platforms.platforms[key];
      if (
        !selected ||
        !Array.isArray(selected.stepIds) ||
        selected.stepIds.some((id) => !ids.has(id))
      )
        throw new Error("Invalid platform guide");
    }
    guide = data;
    platformGuides = platforms;
    guideState = data.steps.length ? "ready" : "empty";
    renderGuide();
    if (location.hash.startsWith("#step-")) {
      document.getElementById(location.hash.slice(1))?.scrollIntoView();
    }
  })
  .catch(() => {
    guideState = "error";
    renderGuide();
  });
