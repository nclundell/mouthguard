import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, alt: String }

  connect() {
    this.element.addEventListener("click", this.show)
  }

  disconnect() {
    this.element.removeEventListener("click", this.show)
  }

  show = () => {
    if (!this.urlValue.startsWith("/rails/active_storage/blobs/")) return

    const image = document.createElement("img")
    image.alt = this.altValue
    image.className = "comment-attachment-image"
    image.src = this.urlValue
    this.element.replaceWith(image)
  }
}
