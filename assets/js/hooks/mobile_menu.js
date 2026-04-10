const FOCUSABLE = 'a[href], button:not([disabled]), input, textarea, select, [tabindex]:not([tabindex="-1"])'

const MobileMenu = {
  mounted() {
    this.menu = document.getElementById("mobile-menu")
    this.closeBtn = document.getElementById("mobile-menu-close")
    this.backdrop = document.getElementById("mobile-menu-backdrop")

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

    // Focus close button
    if (this.closeBtn) this.closeBtn.focus()
  },

  close() {
    this.menu.classList.add("hidden")
    this.el.setAttribute("aria-expanded", "false")
    document.removeEventListener("keydown", this._onKeydown)
    document.body.style.overflow = ""
    this.el.focus()
  },

  _trapFocus(e) {
    const panel = document.getElementById("mobile-menu-panel")
    if (!panel) return

    const focusable = [...panel.querySelectorAll(FOCUSABLE)]
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
