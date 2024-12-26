import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="navbar"
export default class extends Controller {
  static targets = [
    "mobileMenu"
  ]

  toggleMobileMenu() {
    this.mobileMenuTarget.classList.toggle("hidden")
  }
}
