import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="user-picks"
export default class extends Controller {
  static targets = [ "bowl", "team" ]

  connect () {
    this.updateAllTeams();
  }

  pickTeam () {
    var input = this.teamTarget.firstElementChild.firstElementChild;
    input.checked = true;

    this.updateAllTeams();
  }

  updateAllTeams () {
    for (var team of this.teamTargets) {
      if (team.firstElementChild.firstElementChild.checked == true) {
        team.classList.add("border-blue-300");
      } else {
        team.classList.remove("border-blue-300");
      }
    }
  }
}
