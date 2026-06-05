const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/recco_web.ex",
    "../lib/recco_web/**/*.*ex"
  ],
  darkMode: "class",
  theme: {
    fontFamily: {
      sans: ['"Rubik"', 'ui-sans-serif', 'system-ui', 'sans-serif'],
      head: ['"Darker Grotesque"', 'ui-sans-serif', 'system-ui', 'sans-serif'],
      body: ['"Rubik"', 'ui-sans-serif', 'system-ui', 'sans-serif'],
      mono: ['"Space Mono"', 'ui-monospace', 'SFMono-Regular', 'Menlo', 'monospace'],
    },
    extend: {
      colors: {
        // Sticker-A canonical tokens
        ink: "var(--ink)",
        "ink-soft": "var(--ink-soft)",
        line: "var(--line)",
        card: "var(--card)",
        card2: "var(--card2)",
        bg2: "var(--bg2)",
        accent: "var(--accent)",
        "accent-ink": "var(--accent-ink)",
        accent2: "var(--accent2)",
        good: "var(--good)",
        warn: "var(--warn)",
        danger: "var(--danger)",

        // legacy aliases (kept until the migration finishes)
        main: "var(--main)",
        bg: "var(--background)",
        fg: "var(--foreground)",
        bw: "var(--secondary-background)",
        "main-fg": "var(--main-foreground)",
        border: "var(--border)",
        ring: "var(--ring)",
        overlay: "var(--overlay)",
      },
      borderWidth: {
        bw: "2.5px",
      },
      borderRadius: {
        base: "5px",
        panel: "16px",
        "panel-sm": "10px",
      },
      boxShadow: {
        brutalist: "var(--shadow)",
        panel: "var(--shadow)",
        "panel-sm": "var(--shadow-sm)",
        "panel-lg": "var(--shadow-lg)",
        "panel-hover": "var(--shadow-hover)",
      },
      translate: {
        "shadow-x": "4px",
        "shadow-y": "4px",
      },
      fontWeight: {
        base: "500",
        heading: "700",
        display: "900",
      },
      letterSpacing: {
        label: "0.14em",
        head: "-0.01em",
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    plugin(({addVariant}) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
    plugin(({addVariant}) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
    plugin(({addVariant}) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"])),

    // Hero icons
    plugin(function({matchComponents, theme}) {
      let iconsDir = path.join(__dirname, "../deps/heroicons/optimized")
      let values = {}
      let icons = [
        ["", "/24/outline"],
        ["-solid", "/24/solid"],
        ["-mini", "/20/solid"],
        ["-micro", "/16/solid"]
      ]
      icons.forEach(([suffix, dir]) => {
        try {
          fs.readdirSync(path.join(iconsDir, dir)).forEach(file => {
            let name = path.basename(file, ".svg") + suffix
            values[name] = {name, fullPath: path.join(iconsDir, dir, file)}
          })
        } catch (_e) {}
      })
      matchComponents({
        "hero": ({name, fullPath}) => {
          let content = fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, "")
          let size = theme("googletag.width") || "1.25rem"
          return {
            [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
            "-webkit-mask": `var(--hero-${name})`,
            "mask": `var(--hero-${name})`,
            "mask-repeat": "no-repeat",
            "background-color": "currentColor",
            "vertical-align": "middle",
            "display": "inline-block",
            "width": size,
            "height": size
          }
        }
      }, {values})
    })
  ]
}
