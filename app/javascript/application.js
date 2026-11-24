// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import { cable } from "@hotwired/turbo-rails"
import "controllers"

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

import "lexxy"
