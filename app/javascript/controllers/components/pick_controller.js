import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="pick-component"
export default class extends Controller {
  static targets = [
    "bowl",
    "awayTeam",
    "awayTeamCheckmark",
    "homeTeam",
    "homeTeamCheckmark"
  ]

  connect () {
    this.set_pick_highlight();
  }

  set_pick_highlight () {
    this.set_away_hightlight();
    this.set_home_hightlight();
  }

  set_away_hightlight () {
    if (this.awayTeamTarget.dataset.picked === "true") {
      this.awayTeamTarget.classList.add("border-blue-500");
      this.awayTeamCheckmarkTarget.classList.remove("hidden");
    } else {
      this.awayTeamTarget.classList.remove("border-blue-500");
      this.awayTeamCheckmarkTarget.classList.add("hidden");
    }
  }

  set_home_hightlight () {
    if (this.homeTeamTarget.dataset.picked === "true") {
      this.homeTeamTarget.classList.add("border-blue-500");
      this.homeTeamCheckmarkTarget.classList.remove("hidden");
    } else {
      this.homeTeamTarget.classList.remove("border-blue-500");
      this.homeTeamCheckmarkTarget.classList.add("hidden");
    }
  }
}
