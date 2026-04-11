const FOCUSABLE = 'a[href], button:not([disabled]), input, textarea, select, [tabindex]:not([tabindex="-1"])'

const MobileMenu = {
  mounted() {
    this.menu = document.getElementById("mobile-menu")
    this.panel = document.getElementById("mobile-menu-panel")
    this.backdrop = document.getElementById("mobile-menu-backdrop")
    this.closeBtn = document.getElementById("mobile-menu-close")

    this.el.addEventListener("click", () => this.open())

    if (this.closeBtn) {
      this.closeBtn.addEventListener("click", () => this.close())
    }

    if (this.backdrop) {
      this.backdrop.addEventListener("click", () => this.close())
    }

    this._onKeydown = (e) => {
      if (e.key === "Escape") this.close()
      if (e.key === "Tab") this._trapFocus(e)
    }
  },

  open() {
    this.menu.classList.remove("hidden")
    this.el.setAttribute("aria-expanded", "true")
    document.addEventListener("keydown", this._onKeydown)
    document.body.style.overflow = "hidden"

    // Trigger transition on next frame
    requestAnimationFrame(() => {
      this.panel.classList.remove("-translate-x-full")
      this.panel.classList.add("translate-x-0")
      this.backdrop.classList.remove("opacity-0")
      this.backdrop.classList.add("opacity-100")
    })

    if (this.closeBtn) this.closeBtn.focus()
  },

  close() {
    this.panel.classList.remove("translate-x-0")
    this.panel.classList.add("-translate-x-full")
    this.backdrop.classList.remove("opacity-100")
    this.backdrop.classList.add("opacity-0")

    this.el.setAttribute("aria-expanded", "false")
    document.removeEventListener("keydown", this._onKeydown)
    document.body.style.overflow = ""

    // Hide after transition ends
    this.panel.addEventListener("transitionend", () => {
      this.menu.classList.add("hidden")
    }, { once: true })

    this.el.focus()
  },

  _trapFocus(e) {
    if (!this.panel) return

    const focusable = [...this.panel.querySelectorAll(FOCUSABLE)]
    if (focusable.length === 0) return

    const first = focusable[0]
    const last = focusable[focusable.length - 1]

    if (e.shiftKey && document.activeElement === first) {
      e.preventDefault()
      last.focus()
    } else if (!e.shiftKey && document.activeElement === last) {
      e.preventDefault()
      first.focus()
    }
  },

  destroyed() {
    document.removeEventListener("keydown", this._onKeydown)
    document.body.style.overflow = ""
  }
}

export default MobileMenu
