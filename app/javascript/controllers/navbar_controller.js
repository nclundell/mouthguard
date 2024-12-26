import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="navbar"
export default class extends Controller {
  static targets = [
    "mobileMenu",
    "profileMenu"
  ]

  hideMenu() {
    this.mobileMenuTarget.classList.add("hidden")
    this.profileMenuTarget.classList.add("hidden")
  }

  showMenu() {
    this.mobileMenuTarget.classList.remove("hidden")
    this.profileMenuTarget.classList.remove("hidden")
  }

  toggleMenu() {
    this.mobileMenuTarget.classList.toggle("hidden")
    this.profileMenuTarget.classList.toggle("hidden")
  }
}
