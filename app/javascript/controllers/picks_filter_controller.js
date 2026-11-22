import { Controller } from "@hotwired/stimulus"
import { normalizeSearchText, matchesSearch } from "controllers/filter_search"

export default class extends Controller {
  static targets = [
    "controls",
    "bowlSearch", "userSearch", "bowlClear", "userClear", "bowlDropdown", "userDropdown",
    "bowlOption", "userOption", "bowlNoMatches", "userNoMatches",
    "bowlCount", "userCount",
    "gameRow", "gameCard", "userColumn", "userCell", "userEntry",
    "emptyColumn", "emptyCell", "emptyMessage", "lockedCell", "noGames"
  ]

  connect() {
    this.closeOutside = this.closeOutside.bind(this)
    document.addEventListener("click", this.closeOutside)
    this.update()
  }

  disconnect() {
    document.removeEventListener("click", this.closeOutside)
  }

  close() {
    for (const axis of ["bowl", "user"]) {
      this[`${axis}DropdownTarget`].hidden = true
      this[`${axis}SearchTarget`].setAttribute("aria-expanded", "false")
    }
  }

  closeOutside(event) {
    if (!this.controlsTarget.contains(event.target)) this.close()
  }

  search(event) {
    const axis = event.target === this.bowlSearchTarget ? "bowl" : "user"
    this.close()
    const options = this[`${axis}OptionTargets`]
    const query = normalizeSearchText(event.target.value)
    let matches = 0
    options.forEach((option) => {
      const visible = query.length > 0 && matchesSearch(query, option.textContent)
      option.hidden = !visible
      if (visible) matches += 1
    })
    this[`${axis}NoMatchesTarget`].hidden = !query || matches > 0
    this[`${axis}DropdownTarget`].hidden = !query
    event.target.setAttribute("aria-expanded", String(query.length > 0))
    this.updateClearButtons()
  }

  clear(event) {
    const axis = event.currentTarget === this.bowlClearTarget ? "bowl" : "user"
    this[`${axis}OptionTargets`].forEach((option) => {
      option.querySelector("input").checked = false
    })
    const input = this[`${axis}SearchTarget`]
    input.value = ""
    this.search({ target: input })
    this.update()
  }

  update() {
    const selectedBowls = this.selected(this.bowlOptionTargets)
    const selectedUsers = this.selected(this.userOptionTargets)
    this.bowlCountTarget.textContent = selectedBowls.size ? `${selectedBowls.size} selected` : "All"
    this.userCountTarget.textContent = selectedUsers.size ? `${selectedUsers.size} selected` : "All"
    this.updateClearButtons()
    this.show(this.noGamesTarget, this.gameRowTargets.length === 0)

    for (const target of [...this.gameRowTargets, ...this.gameCardTargets]) {
      this.show(target, selectedBowls.size === 0 || selectedBowls.has(target.dataset.bowlTitle))
    }
    for (const target of [...this.userColumnTargets, ...this.userCellTargets, ...this.userEntryTargets]) {
      this.show(target, selectedUsers.size === 0 || selectedUsers.has(target.dataset.userId))
    }
    for (const target of [...this.emptyColumnTargets, ...this.emptyCellTargets, ...this.emptyMessageTargets]) {
      this.show(target, this.userOptionTargets.length === 0)
    }
    this.lockedCellTargets.forEach((cell) => {
      cell.colSpan = Math.max(selectedUsers.size || this.userOptionTargets.length, 1)
    })
    this.element.querySelector("[data-controller~='picks-sticky-header']")
      ?.dispatchEvent(new CustomEvent("picks:filter"))
  }

  selected(options) {
    return new Set(options.filter((option) => option.querySelector("input").checked)
      .map((option) => option.querySelector("input").value))
  }

  updateClearButtons() {
    for (const axis of ["bowl", "user"]) {
      const button = this[`${axis}ClearTarget`]
      const hasSelection = this.selected(this[`${axis}OptionTargets`]).size > 0
      button.disabled = !hasSelection
      this.show(button, hasSelection)
    }
  }

  show(element, visible) {
    element.hidden = !visible
    element.classList.toggle("hidden", !visible)
  }
}
