// InkFrame v2 — Amber Noir Web Components
// Light-DOM custom elements. _shared.css selectors keep working on rendered
// children. Each element reads its attributes and (re)renders inner markup.
//
// Naming: every tag is `ink-*`. No build step. No framework. Vanilla browser.

const PAGES = [
  ["01-lock",            "01"],
  ["02-studio-home",     "02"],
  ["03-canvas",          "03"],
  ["04-task-queue",      "04"],
  ["05-storyboard",      "05"],
  ["06-script-editor",   "06"],
  ["07-asset-library",   "07"],
  ["08-asset-generation","08"],
  ["09-settings",        "09"],
  ["10-account",         "10"],
  ["11-toasts",          "11"],
  ["12-error-states",    "12"],
];

// 同一 Episode 下的并列视图，供 ink-chrome 的 views 开关渲染跨视图切换栏。
const EPISODE_VIEWS = [
  ["03-canvas",           "Canvas"],
  ["05-storyboard",       "Storyboard"],
  ["06-script-editor",    "Script"],
  ["08-asset-generation", "Generation"],
  ["04-task-queue",       "Queue"],
];

// ============================================================================
// ink-page — semantic wrapper around .page (full viewport, vertical flex)
// ============================================================================
customElements.define("ink-page", class extends HTMLElement {
  connectedCallback() { this.classList.add("page"); }
});

// ============================================================================
// ink-chrome — top window bar: logo + crumbs + slotted actions + win controls
// Attributes:
//   breadcrumb  "Nocturne › Episode 02 › Canvas"  (last segment auto-highlighted)
//   kbd         shortcut hint pill text (default "⌘K", omit to hide)
//   avatar      initial in the round avatar (default "J", omit to hide)
//   no-window   set to skip the — / ▢ / ✕ chrome controls
//   no-logo     set to skip the Ink/Frame brand
//   views       set to render the Episode 跨视图切换栏（Canvas/Storyboard/…），
//               当前视图按文件名自动高亮
// Anything between <ink-chrome>…</ink-chrome> is treated as slotted actions
// (rendered between the kbd hint and the avatar in the actions row).
// ============================================================================
customElements.define("ink-chrome", class extends HTMLElement {
  static observedAttributes = ["breadcrumb", "kbd", "avatar", "no-window", "no-logo", "views"];
  connectedCallback() {
    // Capture user-provided slot content once, then re-render in place.
    if (this._slot === undefined) this._slot = this.innerHTML;
    this.render();
  }
  attributeChangedCallback() { if (this.isConnected) this.render(); }
  render() {
    const bc       = (this.getAttribute("breadcrumb") || "").trim();
    const kbd      = this.getAttribute("kbd");
    const avatar   = this.getAttribute("avatar");
    const noWindow = this.hasAttribute("no-window");
    const noLogo   = this.hasAttribute("no-logo");

    const crumbs = bc
      ? bc.split("›").map(s => s.trim()).filter(Boolean)
      : [];
    const crumbsHtml = crumbs.length
      ? `<div class="crumbs">${
          crumbs.map((seg, i) =>
            i === crumbs.length - 1
              ? `<span class="here">${seg}</span>`
              : `<span>${seg}</span><span class="chev">›</span>`
          ).join("")
        }</div>`
      : "";

    const actionsHtml = (kbd !== null || avatar !== null || this._slot)
      ? `<div class="actions">${
          kbd !== null ? `<span class="kbd">${kbd || "⌘K"}</span>` : ""
        }${this._slot}${
          avatar !== null ? `<a class="avatar" href="10-account.html" title="Account">${avatar || "J"}</a>` : ""
        }</div>`
      : "";

    const current = (location.pathname.split("/").pop() || "").replace(".html", "");
    const viewNavHtml = this.hasAttribute("views")
      ? `<nav class="view-nav">${
          EPISODE_VIEWS.map(([file, label]) =>
            `<a href="${file}.html"${file === current ? ' class="active"' : ""}>${label}</a>`
          ).join("")
        }</nav>`
      : "";

    this.classList.add("chrome");
    this.innerHTML = `
      ${noLogo ? "" : `<a class="logo" href="02-studio-home.html" title="Studio Home">Ink<span class="sep">/</span>Frame</a>`}
      ${crumbsHtml}
      ${viewNavHtml}
      <div class="spacer"></div>
      ${actionsHtml}
      ${noWindow ? "" : `<ink-win-ctrl></ink-win-ctrl>`}
    `;
  }
});

// ============================================================================
// ink-win-ctrl — — / ▢ / ✕ macOS-ish window buttons (mock, non-functional)
// ============================================================================
customElements.define("ink-win-ctrl", class extends HTMLElement {
  connectedCallback() {
    this.classList.add("win-ctrl");
    this.innerHTML = `
      <button title="Minimize">—</button>
      <button title="Maximize">▢</button>
      <button class="close" title="Close">✕</button>
    `;
  }
});

// ============================================================================
// ink-btn — themed button. Inner text is the label; attribute drives variant.
// Attributes:
//   variant  "cta" | "ghost" | "danger" | (combination) | unset
//   icon     leading glyph rendered before the label
//   href     if set, clicking the button navigates to the URL (in-app nav)
// Uses the existing .btn / .btn.cta / .btn.ghost rules in _shared.css.
// ============================================================================
customElements.define("ink-btn", class extends HTMLElement {
  static observedAttributes = ["variant", "icon", "href"];
  connectedCallback() {
    if (this._userClass === undefined) this._userClass = this.className;
    if (this._label === undefined) this._label = this.textContent.trim();
    this.render();
    this._wireNav();
  }
  attributeChangedCallback() {
    if (this.isConnected) { this.render(); this._wireNav(); }
  }
  _wireNav() {
    const href = this.getAttribute("href");
    if (href && !this._navWired) {
      this.addEventListener("click", () => { location.href = href; });
      this.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          location.href = href;
        }
      });
      this._navWired = true;
    }
  }
  render() {
    const variant = (this.getAttribute("variant") || "").trim();
    const icon    = this.getAttribute("icon");
    // Compose user-provided classes + component-managed classes.
    this.className = [this._userClass, "btn", variant].filter(Boolean).join(" ").trim();
    this.setAttribute("role", "button");
    if (!this.hasAttribute("tabindex")) this.setAttribute("tabindex", "0");
    this.innerHTML = `${icon ? `<span class="ico">${icon}</span>` : ""}${this._label}`;
  }
});

// ============================================================================
// ink-chip — small status pill. Variant maps to _shared.css .chip.* modifier.
// Attributes:
//   variant  "on" | "success" | "warning" | "danger" | "info" | unset
// ============================================================================
customElements.define("ink-chip", class extends HTMLElement {
  connectedCallback() {
    if (this._userClass === undefined) this._userClass = this.className;
    const variant = (this.getAttribute("variant") || "").trim();
    this.className = [this._userClass, "chip", variant].filter(Boolean).join(" ").trim();
  }
});

// ============================================================================
// ink-tag — uppercase mono pill (see _shared.css .tag / .tag.accent / .ok etc.)
// Attributes:
//   variant  "accent" | "warn" | "danger" | "ok" | unset
// ============================================================================
customElements.define("ink-tag", class extends HTMLElement {
  connectedCallback() {
    if (this._userClass === undefined) this._userClass = this.className;
    const variant = (this.getAttribute("variant") || "").trim();
    this.className = [this._userClass, "tag", variant].filter(Boolean).join(" ").trim();
  }
});

// ============================================================================
// ink-mock-nav — developer-only bottom nav strip. Hidden by default to keep
// the app-simulation clean; show it by appending `?dev=1` to any page URL.
// If `active` is unset, the active id is derived from the current filename.
// ============================================================================
customElements.define("ink-mock-nav", class extends HTMLElement {
  connectedCallback() {
    const dev = new URLSearchParams(location.search).has("dev");
    if (!dev) { this.style.display = "none"; return; }

    let active = this.getAttribute("active");
    if (!active) {
      active = (location.pathname.split("/").pop() || "").replace(".html", "");
    }
    this.classList.add("mock-nav");
    // Propagate ?dev=1 so the strip survives across navigations.
    const q = "?dev=1";
    this.innerHTML = `
      <a class="home" href="01-lock.html${q}">◇ Start</a>
      ${PAGES.map(([file, label]) =>
        `<a${active === file ? ' class="active"' : ""} href="${file}.html${q}">${label}</a>`
      ).join("")}
    `;
  }
});
