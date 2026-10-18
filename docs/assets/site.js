"use strict";

const strings = {
  id: {
    skip: "Langsung ke konten",
    contents: "Daftar isi",
    description:
      "Konfigurasi Neovim untuk bekerja dengan beberapa repo Git. Termasuk sidebar Git, LazyGit, diff, dan search/replace.",
    requirements:
      "Panduan ini untuk macOS. Membutuhkan Neovim 0.12+ dan Python 3.9+. Config dipasang sebagai profil vimdesk, terpisah dari ~/.config/nvim.",
    markdownGuide: "Panduan Markdown",
    installTitle: "Install di macOS",
    installIntro:
      "Ikuti langkah berurutan. Jika suatu alat sudah terpasang, cek versinya lalu lanjutkan.",
    loading: "Memuat langkah instalasi…",
    guideError:
      "Langkah instalasi gagal dimuat. Buka Panduan Markdown di atas untuk melanjutkan.",
    guideEmpty:
      "Langkah instalasi belum tersedia di halaman ini. Buka Panduan Markdown di atas.",
    sources: "Referensi resmi",
    terminal: "Terminal",
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
    workflowTitle: "Pemakaian, update, dan backup",
    workflow: "Editing, Git, konflik, dan search/replace",
    maintenance: "Update, restore, dan uninstall",
    previewTitle: "Tampilan",
    previewOpen: "Lihat screenshot",
    realUI: "Screenshot dari Neovim dengan repo latihan lokal.",
    tabReview: "Git diff",
    tabConflicts: "Konflik",
    tabSearch: "Search/replace",
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
      "Panduan ini untuk macOS. Installer POSIX/Linux belum diuji menyeluruh. Windows belum didukung. Untuk Mac Intel atau macOS lama, cek dukungan Homebrew sebelum mulai.",
    faqQ6: "Folder sudah ada saat git clone",
    faqA6:
      "Buka folder vimdesk yang sudah diunduh, simpan perubahan lokal, lalu jalankan git pull --ff-only dan ./install.sh. Jangan hapus folder yang berisi pekerjaanmu.",
    report: "Laporkan masalah",
  },
  en: {
    skip: "Skip to content",
    contents: "Contents",
    description:
      "Neovim configuration for working across Git repositories. Includes a Git sidebar, LazyGit, diff views, and search/replace.",
    requirements:
      "This guide targets macOS. Requires Neovim 0.12+ and Python 3.9+. The config installs as a separate vimdesk profile, away from ~/.config/nvim.",
    markdownGuide: "Markdown guide",
    installTitle: "Install on macOS",
    installIntro:
      "Follow the steps in order. If a tool is already installed, check its version and continue.",
    loading: "Loading installation steps…",
    guideError:
      "Installation steps could not load. Open the Markdown guide above to continue.",
    guideEmpty:
      "Installation steps are not available on this page. Open the Markdown guide above.",
    sources: "Official references",
    terminal: "Terminal",
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
    workflowTitle: "Usage, updates, and backups",
    workflow: "Editing, Git, conflicts, and search/replace",
    maintenance: "Update, restore, and uninstall",
    previewTitle: "Screenshots",
    previewOpen: "Show screenshots",
    realUI: "Screenshots from Neovim using local practice repositories.",
    tabReview: "Git diff",
    tabConflicts: "Conflicts",
    tabSearch: "Search/replace",
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
      "This guide targets macOS. The POSIX/Linux installer has not been validated end to end. Windows is unsupported. For Intel Macs or older macOS, check Homebrew’s support requirements first.",
    faqQ6: "The folder already exists during git clone",
    faqA6:
      "Open the existing vimdesk folder, preserve local edits, then run git pull --ff-only and ./install.sh. Do not delete a folder containing your work.",
    report: "Report an issue",
  },
};

const views = {
  review: {
    image: "images/review.png",
    alt: "Git sidebar and Before / After review",
    id: "Sidebar Git dan perbandingan Before / After.",
    en: "Git sidebar and Before / After comparison.",
  },
  conflicts: {
    image: "images/conflicts.png",
    alt: "Incoming left, Current right, editable Result below",
    id: "Incoming di kiri, Current di kanan, Result yang bisa diedit di bawah.",
    en: "Incoming on the left, Current on the right, editable Result below.",
  },
  search: {
    image: "images/search.png",
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
  guide.steps.forEach((step, index) => {
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
}

function translate() {
  document.documentElement.lang = language;
  document.getElementById("language").value = language;
  document.querySelectorAll("[data-i18n]").forEach((node) => {
    node.textContent = tr(node.dataset.i18n);
  });
  const filename = language === "id" ? "mulai-dari-nol" : "getting-started";
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

const contents = document.getElementById("contents");
const wideLayout = window.matchMedia("(min-width: 980px)");
contents.open = wideLayout.matches;
wideLayout.addEventListener("change", (event) => {
  contents.open = event.matches;
});
contents.addEventListener("click", (event) => {
  if (event.target.closest("a") && !wideLayout.matches) contents.open = false;
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
fetch("assets/guide.json")
  .then((response) => {
    if (!response.ok) throw new Error("Guide unavailable");
    return response.json();
  })
  .then((data) => {
    if (!Array.isArray(data.steps)) throw new Error("Invalid guide");
    guide = data;
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
