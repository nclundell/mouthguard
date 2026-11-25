import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.update = this.update.bind(this)
    this.resizeObserver = new ResizeObserver(this.update)
    this.resizeObserver.observe(this.element)
    this.update()
  }

  disconnect() {
    this.resizeObserver.disconnect()
    document.documentElement.style.removeProperty("--navbar-height")
  }

  update() {
    document.documentElement.style.setProperty("--navbar-height", `${this.element.getBoundingClientRect().height}px`)
  }
}
