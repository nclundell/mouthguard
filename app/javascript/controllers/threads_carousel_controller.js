import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track", "previous", "next"]

  connect() {
    this.update = this.update.bind(this)
    this.trackTarget.addEventListener("scroll", this.update, { passive: true })
    this.resizeObserver = new ResizeObserver(this.update)
    this.resizeObserver.observe(this.trackTarget)
    this.mutationObserver = new MutationObserver(this.update)
    this.mutationObserver.observe(this.trackTarget, { childList: true })
    this.update()
  }

  disconnect() {
    this.trackTarget.removeEventListener("scroll", this.update)
    this.resizeObserver.disconnect()
    this.mutationObserver.disconnect()
    this.previousTarget.classList.replace("flex", "hidden")
    this.nextTarget.classList.replace("flex", "hidden")
  }

  update() {
    const track = this.trackTarget
    const max = track.scrollWidth - track.clientWidth
    const overflowing = max > 1
    for (const button of [this.previousTarget, this.nextTarget]) {
      button.classList.toggle("hidden", !overflowing)
      button.classList.toggle("flex", overflowing)
    }
    this.previousTarget.disabled = !overflowing || track.scrollLeft <= 1
    this.nextTarget.disabled = !overflowing || track.scrollLeft >= max - 1
  }

  previous() {
    this.move(-1)
  }

  next() {
    this.move(1)
  }

  move(direction) {
    const track = this.trackTarget
    const card = track.firstElementChild
    if (!card) return

    const gap = parseFloat(getComputedStyle(track).columnGap) || 0
    track.scrollBy({
      left: direction * (card.getBoundingClientRect().width + gap),
      behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "instant" : "smooth"
    })
  }
}
