import { Controller } from "@hotwired/stimulus"
import { normalizeSearchText, matchesSearch } from "controllers/filter_search"

export default class extends Controller {
  static targets = [
    "controls", "cards", "gameCard", "bowlSearch", "teamSearch", "conferenceSearch",
    "bowlDropdown", "teamDropdown", "conferenceDropdown",
    "bowlOption", "teamOption", "conferenceOption",
    "bowlNoMatches", "teamNoMatches", "conferenceNoMatches",
    "bowlCount", "teamCount", "conferenceCount", "bowlClear", "teamClear", "conferenceClear"
  ]

  connect() {
    this.closeOutside = this.closeOutside.bind(this)
    document.addEventListener("click", this.closeOutside)
    this.refreshCards()
    this.cardObserver = new MutationObserver(() => this.refreshCards())
    this.cardObserver.observe(this.cardsTarget, { childList: true })
  }

  disconnect() {
    document.removeEventListener("click", this.closeOutside)
    this.cardObserver?.disconnect()
  }

  close() {
    for (const axis of ["bowl", "team", "conference"]) {
      this[`${axis}DropdownTarget`].hidden = true
      this[`${axis}SearchTarget`].setAttribute("aria-expanded", "false")
    }
  }

  closeOutside(event) {
    if (!this.controlsTarget.contains(event.target)) this.close()
  }

  search(event) {
    const axis = event.target === this.bowlSearchTarget ? "bowl" :
      event.target === this.teamSearchTarget ? "team" : "conference"
    this.close()
    this.filterOptions(axis)
    this.updateClearButtons()
  }

  filterOptions(axis, open = true) {
    const input = this[`${axis}SearchTarget`]
    const query = normalizeSearchText(input.value)
    let matches = 0
    this[`${axis}OptionTargets`].forEach((option) => {
      const visible = query.length > 0 && matchesSearch(query, option.textContent)
      this.show(option, visible)
      if (visible) matches += 1
    })
    this[`${axis}NoMatchesTarget`].hidden = !query || matches > 0
    if (open) {
      this[`${axis}DropdownTarget`].hidden = !query
      input.setAttribute("aria-expanded", String(query.length > 0))
    }
  }

  refreshCards() {
    const bowls = new Set()
    const teams = new Map()
    const conferences = new Set()
    this.gameCardTargets.forEach((card) => {
      bowls.add(card.dataset.bowlTitle)
      for (const side of ["home", "away"]) {
        const id = card.dataset[`${side}TeamId`]
        if (id) teams.set(id, card.dataset[`${side}TeamSchool`])
        const conference = card.dataset[`${side}TeamConference`]
        if (conference?.trim()) conferences.add(conference)
      }
    })
    const counts = new Map()
    teams.forEach((school) => counts.set(school, (counts.get(school) || 0) + 1))
    this.rebuildOptions("bowl", [...bowls].map((title) => [title, title]))
    this.rebuildOptions("team", [...teams].sort((a, b) =>
      a[1].toLocaleLowerCase().localeCompare(b[1].toLocaleLowerCase()) || Number(a[0]) - Number(b[0])
    ).map(([id, school]) => [id, counts.get(school) > 1 ? `${school} (${id})` : school]))
    this.rebuildOptions("conference", [...conferences].sort((a, b) =>
      a.toLocaleLowerCase().localeCompare(b.toLocaleLowerCase())
    ).map((conference) => [conference, conference]))
    for (const axis of ["bowl", "team", "conference"]) this.filterOptions(axis, false)
    this.update()
  }

  rebuildOptions(axis, entries) {
    const currentOptions = this[`${axis}OptionTargets`]
    if (currentOptions.length === entries.length && entries.every(([value, text], index) =>
      currentOptions[index].querySelector("input").value === value && currentOptions[index].textContent === text
    )) return

    const selected = this.selected(currentOptions)
    const focused = currentOptions.find((option) => option.querySelector("input") === document.activeElement)
    const focusedValue = focused?.querySelector("input").value
    const options = entries.map(([value, text]) => {
      const label = document.createElement("label")
      label.className = "hidden flex items-center gap-2 py-1 text-sm"
      label.dataset.gamesFilterTarget = `${axis}Option`
      label.hidden = true
      const checkbox = document.createElement("input")
      checkbox.type = "checkbox"
      checkbox.value = value
      checkbox.checked = selected.has(value)
      checkbox.dataset.action = "change->games-filter#update"
      checkbox.className = "size-4 accent-pine-700"
      label.append(checkbox, document.createTextNode(text))
      return label
    })
    currentOptions.forEach((option) => option.remove())
    this[`${axis}NoMatchesTarget`].before(...options)
    if (focused) {
      this.filterOptions(axis, false)
      const replacement = options.find((option) => option.querySelector("input").value === focusedValue)
      const focusTarget = replacement && !replacement.hidden && !this[`${axis}DropdownTarget`].hidden ?
        replacement.querySelector("input") : this[`${axis}SearchTarget`]
      focusTarget.focus()
    }
  }

  clear(event) {
    const axis = event.currentTarget === this.bowlClearTarget ? "bowl" :
      event.currentTarget === this.teamClearTarget ? "team" : "conference"
    this[`${axis}OptionTargets`].forEach((option) => {
      option.querySelector("input").checked = false
    })
    const input = this[`${axis}SearchTarget`]
    input.value = ""
    this.search({ target: input })
    this.update()
  }

  update() {
    const bowls = this.selected(this.bowlOptionTargets)
    const teams = this.selected(this.teamOptionTargets)
    const conferences = this.selected(this.conferenceOptionTargets)
    this.bowlCountTarget.textContent = bowls.size ? `${bowls.size} selected` : "All"
    this.teamCountTarget.textContent = teams.size ? `${teams.size} selected` : "All"
    this.conferenceCountTarget.textContent = conferences.size ? `${conferences.size} selected` : "All"
    this.updateClearButtons()
    this.gameCardTargets.forEach((card) => this.show(card, this.matchesCard(card, bowls, teams, conferences)))
  }

  matchesCard(card, bowls = this.selected(this.bowlOptionTargets), teams = this.selected(this.teamOptionTargets),
    conferences = this.selected(this.conferenceOptionTargets)) {
    return (bowls.size === 0 || bowls.has(card.dataset.bowlTitle)) &&
      (teams.size === 0 || teams.has(card.dataset.homeTeamId) || teams.has(card.dataset.awayTeamId)) &&
      (conferences.size === 0 || conferences.has(card.dataset.homeTeamConference) ||
        conferences.has(card.dataset.awayTeamConference))
  }

  selected(options) {
    return new Set(options.filter((option) => option.querySelector("input").checked)
      .map((option) => option.querySelector("input").value))
  }

  updateClearButtons() {
    for (const axis of ["bowl", "team", "conference"]) {
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
