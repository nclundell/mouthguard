import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track", "slide", "context"]

  connect() {
    if (!this.hasTrackTarget) return

    this.refresh()
    const featured = this.slideTargets.find((slide) => slide.dataset.featured === "true")
    if (featured) {
      requestAnimationFrame(() => {
        if (this.element.isConnected) this.scrollToSlide(featured, "instant")
      })
    }
    this.element.querySelectorAll("[data-game-carousel-control]").forEach((button) => {
      button.classList.replace("hidden", "flex")
    })
    this.observer = new MutationObserver((mutations) => {
      if (mutations.some(({ target }) => target !== this.trackTarget)) this.refresh()
    })
    this.observer.observe(this.trackTarget, { childList: true, subtree: true })
  }

  disconnect() {
    this.observer?.disconnect()
    this.element.querySelectorAll("[data-game-carousel-control]").forEach((button) => {
      button.classList.replace("flex", "hidden")
    })
  }

  refresh() {
    const track = this.trackTarget
    const slides = this.slideTargets
    if (!slides.length) return

    const card = (slide) => slide.querySelector("[data-scoreboard-status]")
    const kickoff = (slide) => {
      const value = Date.parse(slide.querySelector("[data-scoreboard-status]")?.dataset.scoreboardKickoff)
      return Number.isNaN(value) ? null : value
    }
    const sorted = [...slides].sort((a, b) => {
      const aTime = kickoff(a)
      const bTime = kickoff(b)
      if (aTime === null && bTime !== null) return 1
      if (bTime === null && aTime !== null) return -1
      if (aTime !== null && bTime !== null && aTime !== bTime) return aTime - bTime
      return Number(card(a)?.id?.replace("game_", "")) - Number(card(b)?.id?.replace("game_", ""))
    })

    const reordered = sorted.some((slide, index) => track.children[index] !== slide)
    if (reordered) {
      const left = track.getBoundingClientRect().left + parseFloat(getComputedStyle(track).paddingLeft)
      const visible = slides.reduce((closest, slide) =>
        Math.abs(slide.getBoundingClientRect().left - left) <
        Math.abs(closest.getBoundingClientRect().left - left) ? slide : closest)
      const offset = visible.getBoundingClientRect().left - left

      sorted.forEach((slide, index) => {
        if (track.children[index] !== slide) track.insertBefore(slide, track.children[index])
      })
      const newOffset = visible.getBoundingClientRect().left - left
      track.scrollTo({
        left: track.scrollLeft + newOffset - offset,
        behavior: "instant"
      })
    }

    const status = (slide) => card(slide)?.dataset.scoreboardStatus
    const featured = sorted.find((slide) => status(slide) === "live") ||
      sorted.find((slide) => status(slide) === "upcoming") ||
      [...sorted].reverse().find((slide) => status(slide) === "final" && kickoff(slide) !== null) ||
      [...sorted].reverse().find((slide) => status(slide) === "final")
    for (const slide of slides) {
      const isFeatured = slide === featured
      slide.dataset.featured = String(isFeatured)
    }
    if (featured && this.hasContextTarget) {
      this.contextTarget.textContent = status(featured) === "live" ? "Live now · following the first kickoff" :
        status(featured) === "final" ? "Latest results" : "Next up · your bowl season at a glance"
    }
  }

  previous() {
    this.move(-1)
  }

  next() {
    this.move(1)
  }

  move(direction) {
    const slides = this.slideTargets
    const left = this.trackTarget.getBoundingClientRect().left + parseFloat(getComputedStyle(this.trackTarget).paddingLeft)
    const current = slides.reduce((closest, slide, index) =>
      Math.abs(slide.getBoundingClientRect().left - left) <
      Math.abs(slides[closest].getBoundingClientRect().left - left) ? index : closest, 0)
    const target = slides[Math.max(0, Math.min(slides.length - 1, current + direction))]
    if (!target) return

    this.scrollToSlide(target, window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth")
  }

  scrollToSlide(slide, behavior) {
    const track = this.trackTarget
    const left = track.getBoundingClientRect().left + parseFloat(getComputedStyle(track).paddingLeft)
    track.scrollTo({
      left: track.scrollLeft + slide.getBoundingClientRect().left - left,
      behavior
    })
  }
}
