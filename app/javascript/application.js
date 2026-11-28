import "lexxy_bootstrap"
// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import { cable } from "@hotwired/turbo-rails"
import "controllers"

if (window.isSecureContext && "serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker", { scope: "/" }).catch((error) => {
      console.error("Service worker registration failed:", error)
    })
  })
}

document.addEventListener("turbo:before-render", async (event) => {
  if (document.body.dataset.cableSession !== event.detail.newBody.dataset.cableSession) {
    event.preventDefault()
    try {
      const consumer = await cable.getConsumer()
      consumer.disconnect()
      cable.setConsumer(null)
    } finally {
      event.detail.resume()
    }
  }
})
