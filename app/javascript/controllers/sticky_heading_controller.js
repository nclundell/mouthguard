import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["heading"]

  connect() {
    this.update = this.update.bind(this)
    window.addEventListener("scroll", this.update, { passive: true })
    window.addEventListener("resize", this.update)
    this.update()
  }

  disconnect() {
    window.removeEventListener("scroll", this.update)
    window.removeEventListener("resize", this.update)
  }

  update() {
    const naturalTop = this.element.getBoundingClientRect().top + parseFloat(getComputedStyle(this.element).paddingTop)
    const headingTop = this.headingTarget.getBoundingClientRect().top
    this.headingTarget.classList.toggle("shadow-sm", naturalTop < 0 && headingTop === 0)
  }
}
