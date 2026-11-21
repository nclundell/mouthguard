import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const start = new Date(this.element.dateTime)
    this.element.textContent = new Intl.DateTimeFormat(undefined, {
      month: "short",
      day: "numeric",
      year: "numeric",
      hour: "numeric",
      minute: "2-digit"
    }).format(start)
  }
}
