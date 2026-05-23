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
// Anything between <ink-chrome>…</ink-chrome> is treated as slotted actions
// (rendered between the kbd hint and the avatar in the actions row).
// ============================================================================
customElements.define("ink-chrome", class extends HTMLElement {
  static observedAttributes = ["breadcrumb", "kbd", "avatar", "no-window", "no-logo"];
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
          avatar !== null ? `<div class="avatar">${avatar || "J"}</div>` : ""
        }</div>`
      : "";

    this.classList.add("chrome");
    this.innerHTML = `
      ${noLogo ? "" : `<div class="logo">Ink<span class="sep">/</span>Frame</div>`}
      ${crumbsHtml}
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
// Uses the existing .btn / .btn.cta / .btn.ghost rules in _shared.css.
// ============================================================================
customElements.define("ink-btn", class extends HTMLElement {
  static observedAttributes = ["variant", "icon"];
  connectedCallback() {
    if (this._label === undefined) this._label = this.textContent.trim();
    this.render();
  }
  attributeChangedCallback() { if (this.isConnected) this.render(); }
  render() {
    const variant = (this.getAttribute("variant") || "").trim();
    const icon    = this.getAttribute("icon");
    // Reset and re-apply classes so variant changes are sticky.
    this.className = "btn" + (variant ? " " + variant : "");
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
    const variant = (this.getAttribute("variant") || "").trim();
    this.className = "chip" + (variant ? " " + variant : "");
  }
});

// ============================================================================
// ink-tag — uppercase mono pill (see _shared.css .tag / .tag.accent / .ok etc.)
// Attributes:
//   variant  "accent" | "warn" | "danger" | "ok" | unset
// ============================================================================
customElements.define("ink-tag", class extends HTMLElement {
  connectedCallback() {
    const variant = (this.getAttribute("variant") || "").trim();
    this.className = "tag" + (variant ? " " + variant : "");
  }
});

// ============================================================================
// ink-mock-nav — fixed bottom strip with links to all 12 mockups.
// If `active` is unset, the active id is derived from the current filename.
// ============================================================================
customElements.define("ink-mock-nav", class extends HTMLElement {
  connectedCallback() {
    let active = this.getAttribute("active");
    if (!active) {
      active = (location.pathname.split("/").pop() || "").replace(".html", "");
    }
    this.classList.add("mock-nav");
    this.innerHTML = `
      <a class="home" href="index.html">◇ Index</a>
      ${PAGES.map(([file, label]) =>
        `<a${active === file ? ' class="active"' : ""} href="${file}.html">${label}</a>`
      ).join("")}
    `;
  }
});
