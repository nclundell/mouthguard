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
      const next = theme === "dark" ? "light" : "dark"
      button.textContent = `${next[0].toUpperCase()}${next.slice(1)} mode`
      button.setAttribute("aria-label", `Switch to ${next} mode`)
    })
    document.querySelectorAll("[data-theme-system]").forEach((button) => {
      button.hidden = !preference
    })
  }

  function savePreference(value) {
    preference = value
    try {
      if (value) localStorage.setItem(key, value)
      else localStorage.removeItem(key)
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
    if (event.target.closest("[data-theme-toggle]")) {
      savePreference(document.documentElement.dataset.theme === "dark" ? "light" : "dark")
    } else if (event.target.closest("[data-theme-system]")) {
      savePreference(null)
    }
  })
  document.addEventListener("turbo:load", applyTheme)
  document.addEventListener("DOMContentLoaded", applyTheme)
})()
