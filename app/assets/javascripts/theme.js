(() => {
  const key = "mouthguard-theme"
  const system = window.matchMedia("(prefers-color-scheme: dark)")

  function storedPreference() {
    try {
      const value = localStorage.getItem(key)
      return value === "dark" || value === "light" ? value : null
    } catch {
      return null
    }
  }

  let preference = storedPreference()

  function applyTheme() {
    const theme = preference || (system.matches ? "dark" : "light")
    document.documentElement.dataset.theme = theme
    document.querySelectorAll("[data-theme-toggle]").forEach((button) => {
      const isDark = theme === "dark"
      button.setAttribute("aria-checked", String(isDark))
      button.querySelector("[data-theme-icon=off]").toggleAttribute("hidden", isDark)
      button.querySelector("[data-theme-icon=on]").toggleAttribute("hidden", !isDark)
    })
  }

  function savePreference(value) {
    preference = value
    try {
      localStorage.setItem(key, value)
    } catch {
      // Browsers may disable storage; the choice still works for this page.
    }
    applyTheme()
  }

  applyTheme()
  system.addEventListener("change", () => { if (!preference) applyTheme() })
  window.addEventListener("storage", (event) => {
    if (event.key === key) {
      preference = storedPreference()
      applyTheme()
    }
  })
  document.addEventListener("click", (event) => {
    if (!(event.target instanceof Element)) return

    if (event.target.closest("[data-theme-toggle]")) {
      savePreference(document.documentElement.dataset.theme === "dark" ? "light" : "dark")
    }
    document.querySelectorAll("details[data-close-on-outside][open]").forEach((menu) => {
      if (!menu.contains(event.target)) menu.open = false
    })
  })
  document.addEventListener("turbo:load", applyTheme)
  document.addEventListener("DOMContentLoaded", applyTheme)
})()
