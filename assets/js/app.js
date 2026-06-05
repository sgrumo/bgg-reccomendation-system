import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import MobileMenu from "./hooks/mobile_menu"
import MultiSelect from "./hooks/multi_select"
import ThemeToggle from "./hooks/theme_toggle"

let Hooks = {
  MobileMenu,
  MultiSelect,
  ThemeToggle
}

let csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken}
})

liveSocket.connect()

window.liveSocket = liveSocket
