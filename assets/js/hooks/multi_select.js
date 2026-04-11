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
    const container = this.el.querySelector("[data-tags]")
    const placeholder = this.el.querySelector("[data-placeholder]")

    container.innerHTML = ""
    if (this.selected.size === 0) {
      placeholder.classList.remove("hidden")
      return
    }

    placeholder.classList.add("hidden")
    this.selected.forEach(name => {
      const tag = document.createElement("span")
      tag.className = "inline-flex items-center gap-1 rounded-base border-2 border-border bg-main px-1.5 py-0.5 text-xs font-bold"
      tag.textContent = name
      container.appendChild(tag)
    })
  },

  _renderOptions() {
    this.optionsList.innerHTML = ""
    this.options.forEach(opt => {
      const row = document.createElement("button")
      row.type = "button"
      row.dataset.value = opt.name
      row.className = "flex items-center w-full px-3 py-2 rounded-base text-sm font-base text-left cursor-pointer hover:bg-bg transition-colors"

      const checkbox = document.createElement("span")
      checkbox.dataset.checkbox = ""
      this._setCheckboxState(checkbox, this.selected.has(opt.name))

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
      const cb = row.querySelector("[data-checkbox]")
      this._setCheckboxState(cb, this.selected.has(row.dataset.value))
    })
  },

  _setCheckboxState(el, checked) {
    if (checked) {
      el.className = "w-4 h-4 rounded-[3px] border-2 border-border bg-main mr-3 flex-shrink-0 flex items-center justify-center"
      el.innerHTML = '<svg class="w-2.5 h-2.5" viewBox="0 0 10 8" fill="none"><path d="M1 4L3.5 6.5L9 1" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>'
    } else {
      el.className = "w-4 h-4 rounded-[3px] border-2 border-border bg-bw mr-3 flex-shrink-0"
      el.innerHTML = ""
    }
  },

  _filterOptions() {
    this.optionsList.querySelectorAll("button[data-value]").forEach(row => {
      const text = row.querySelector("[data-label]").textContent.toLowerCase()
      row.style.display = text.includes(this.search) ? "flex" : "none"
    })
  }
}

export default MultiSelect
