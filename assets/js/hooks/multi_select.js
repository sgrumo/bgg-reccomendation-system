const MultiSelect = {
  mounted() {
    this.open = false
    this.search = ""
    this.selected = new Set(JSON.parse(this.el.dataset.selected || "[]"))
    this.event = this.el.dataset.event
    this.options = JSON.parse(this.el.dataset.options || "[]")

    this._bindElements()
    this._renderOptions()
    this._renderTags()
    this._bindListeners()

    this._onOutsideClick = (e) => {
      if (!this.el.contains(e.target)) this._close()
    }
    this._onKeydown = (e) => {
      if (e.key === "Escape") this._close()
    }

    document.addEventListener("click", this._onOutsideClick)
    document.addEventListener("keydown", this._onKeydown)
  },

  updated() {
    const wasOpen = this.open
    const prevSearch = this.search

    this.selected = new Set(JSON.parse(this.el.dataset.selected || "[]"))
    this.options = JSON.parse(this.el.dataset.options || "[]")

    this._bindElements()
    this._renderOptions()
    this._renderTags()
    this._bindListeners()

    if (wasOpen) {
      this.open = true
      this.dropdown.classList.remove("hidden")
      this.header.setAttribute("aria-expanded", "true")
      if (this.searchInput && prevSearch) {
        this.search = prevSearch
        this.searchInput.value = prevSearch
        this._filterOptions()
      }
    }
  },

  destroyed() {
    document.removeEventListener("click", this._onOutsideClick)
    document.removeEventListener("keydown", this._onKeydown)
  },

  _bindElements() {
    this.header = this.el.querySelector("[data-header]")
    this.dropdown = this.el.querySelector("[data-dropdown]")
    this.searchInput = this.el.querySelector("[data-search]")
    this.optionsList = this.el.querySelector("[data-options]")
  },

  _bindListeners() {
    if (this._listenersBound) return
    this._listenersBound = true

    this.header.addEventListener("click", (e) => this._toggle(e))
    this.header.addEventListener("keydown", (e) => {
      if (["Enter", " ", "ArrowDown"].includes(e.key)) {
        e.preventDefault()
        this._open()
      }
    })

    if (this.searchInput) {
      this.searchInput.addEventListener("input", (e) => {
        this.search = e.target.value.toLowerCase()
        this._filterOptions()
      })
    }
  },

  _toggle(e) {
    if (e) e.stopPropagation()
    this.open ? this._close() : this._open()
  },

  _open() {
    this.open = true
    this.dropdown.classList.remove("hidden")
    this.header.setAttribute("aria-expanded", "true")
    if (this.searchInput) {
      this.searchInput.value = ""
      this.search = ""
      this._filterOptions()
      // Delay focus to avoid virtual keyboard issues on mobile
      requestAnimationFrame(() => this.searchInput.focus())
    }
  },

  _close() {
    this.open = false
    this.dropdown.classList.add("hidden")
    this.header.setAttribute("aria-expanded", "false")
  },

  _selectOption(name) {
    if (this.selected.has(name)) {
      this.selected.delete(name)
    } else {
      this.selected.add(name)
    }
    this._renderTags()
    this._updateCheckboxes()
    this.pushEvent(this.event, {selected: [...this.selected]})
  },

  _renderTags() {
    // The selected items are rendered as removable chips below the
    // dropdown (via the LiveView template), so we don't render duplicate
    // tags inside the trigger — only toggle the placeholder visibility
    // and surface a compact "N selected" summary when many are picked.
    const placeholder = this.el.querySelector("[data-placeholder]")
    const container = this.el.querySelector("[data-tags]")

    container.innerHTML = ""
    if (this.selected.size === 0) {
      placeholder.classList.remove("hidden")
      return
    }

    placeholder.classList.add("hidden")
    const summary = document.createElement("span")
    summary.className = "text-sm font-semibold text-ink"
    summary.textContent = this.selected.size === 1
      ? [...this.selected][0]
      : `${this.selected.size} selected`
    container.appendChild(summary)
  },

  _renderOptions() {
    this.optionsList.innerHTML = ""
    this.options.forEach(opt => {
      const row = document.createElement("button")
      row.type = "button"
      row.dataset.value = opt.name
      row.className = "ms-opt w-full text-left"
      row.setAttribute("data-on", this.selected.has(opt.name) ? "1" : "0")

      const checkbox = document.createElement("span")
      checkbox.dataset.checkbox = ""
      checkbox.className = "ms-check"
      checkbox.innerHTML = this.selected.has(opt.name) ? "✓" : ""

      const label = document.createElement("span")
      label.textContent = opt.name
      label.dataset.label = ""

      row.appendChild(checkbox)
      row.appendChild(label)
      row.addEventListener("click", (e) => {
        e.stopPropagation()
        this._selectOption(opt.name)
      })
      this.optionsList.appendChild(row)
    })
  },

  _updateCheckboxes() {
    this.optionsList.querySelectorAll("button[data-value]").forEach(row => {
      const on = this.selected.has(row.dataset.value)
      row.setAttribute("data-on", on ? "1" : "0")
      const cb = row.querySelector("[data-checkbox]")
      if (cb) cb.innerHTML = on ? "✓" : ""
    })
  },

  _filterOptions() {
    this.optionsList.querySelectorAll("button[data-value]").forEach(row => {
      const text = row.querySelector("[data-label]").textContent.toLowerCase()
      row.style.display = text.includes(this.search) ? "flex" : "none"
    })
  }
}

export default MultiSelect
