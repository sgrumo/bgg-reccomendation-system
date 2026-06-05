// ThemeToggle — flips .dark on <html> and persists choice in localStorage.
// The initial application of .dark happens via the inline FOUC-prevention
// script in root.html.heex (pre-paint), so this hook only handles the
// click-driven toggle and keeps the chosen mode across sessions.
const STORAGE_KEY = "bgrecco-theme"

const ThemeToggle = {
  mounted() {
    this.el.addEventListener("click", () => {
      const next = document.documentElement.classList.toggle("dark") ? "dark" : "light"
      try { localStorage.setItem(STORAGE_KEY, next) } catch (_e) {}
    })
  }
}

export default ThemeToggle
