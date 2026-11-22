const assert = require("node:assert/strict")
const { readFileSync } = require("node:fs")
const { join } = require("node:path")
const { test } = require("node:test")
const vm = require("node:vm")

const searchSource = readFileSync(join(__dirname, "../app/javascript/controllers/filter_search.js"), "utf8")
  .replaceAll("export function", "function")
const controllerSource = readFileSync(join(__dirname, "../app/javascript/controllers/games_filter_controller.js"), "utf8")
  .replace(/^import .*$/gm, "").replace("export default class extends Controller", "class GamesFilter extends Controller")
class CardObserver {
  constructor(callback) { this.callback = callback }
  observe(target, options) { this.target = target; this.options = options }
  disconnect() { this.disconnected = true }
}
const document = {
  activeElement: null,
  addEventListener() {}, removeEventListener() {},
  createElement() {
    return { ...element(), dataset: {}, append(checkbox, text) {
      this.checkbox = checkbox
      this.textContent = text.textContent
      checkbox.focus = () => {
        if (this.hidden || this.classList.contains("hidden")) throw new Error("Cannot focus a hidden option")
        document.activeElement = checkbox
      }
    },
    querySelector() { return this.checkbox },
    remove() {
      this.removed = true
      if (document.activeElement === this.checkbox) document.activeElement = null
    } }
  },
  createTextNode(textContent) { return { textContent } }
}
const GamesFilter = vm.runInNewContext(
  `${searchSource}\n${controllerSource}\nGamesFilter`,
  { Controller: class {}, document, MutationObserver: CardObserver }
)

function element(textContent = "") {
  const classes = new Set(["hidden"])
  return {
    textContent, hidden: true,
    classList: { toggle(name, active) { active ? classes.add(name) : classes.delete(name) }, contains(name) { return classes.has(name) } },
    setAttribute(name, value) { this[name] = value }
  }
}

test("typing opens the matching Games dropdown and reveals only matching option rows", () => {
  const filter = new GamesFilter()
  filter.bowlSearchTarget = { ...element(), value: "shrd" }
  filter.teamSearchTarget = { ...element(), value: "" }
  filter.conferenceSearchTarget = { ...element(), value: "" }
  filter.bowlDropdownTarget = element()
  filter.teamDropdownTarget = element()
  filter.conferenceDropdownTarget = element()
  filter.bowlOptionTargets = [element("Shared Bowl"), element("Other Bowl")]
  filter.teamOptionTargets = [element("Team")]
  filter.conferenceOptionTargets = [element("Atlantic Coast"), element("Pacific")]
  filter.bowlNoMatchesTarget = element()
  filter.teamNoMatchesTarget = element()
  filter.conferenceNoMatchesTarget = element()
  filter.updateClearButtons = () => {}

  filter.search({ target: filter.bowlSearchTarget })

  assert.equal(filter.bowlDropdownTarget.hidden, false)
  assert.equal(filter.bowlSearchTarget["aria-expanded"], "true")
  assert.equal(filter.bowlOptionTargets[0].hidden, false)
  assert.equal(filter.bowlOptionTargets[0].classList.contains("hidden"), false)
  assert.equal(filter.bowlOptionTargets[1].hidden, true)
  assert.equal(filter.bowlOptionTargets[1].classList.contains("hidden"), true)

  filter.teamSearchTarget.value = "team"
  filter.search({ target: filter.teamSearchTarget })
  assert.equal(filter.teamDropdownTarget.hidden, false)
  assert.equal(filter.teamOptionTargets[0].hidden, false)
  filter.conferenceSearchTarget.value = "atlc"
  filter.search({ target: filter.conferenceSearchTarget })
  assert.equal(filter.teamDropdownTarget.hidden, true)
  assert.equal(filter.conferenceDropdownTarget.hidden, false)
  assert.equal(filter.conferenceOptionTargets[0].hidden, false)
  assert.equal(filter.conferenceOptionTargets[1].hidden, true)
})

test("card refresh derives distinct options from current card attributes", () => {
  const filter = new GamesFilter()
  filter.gameCardTargets = [
    { dataset: { bowlTitle: "New Bowl", homeTeamId: "4", homeTeamSchool: "Team", homeTeamConference: "Pacific", awayTeamId: "5", awayTeamSchool: "Team", awayTeamConference: "Atlantic" } },
    { dataset: { bowlTitle: "New Bowl", homeTeamId: "4", homeTeamSchool: "Team", homeTeamConference: "Pacific", awayTeamId: "6", awayTeamSchool: "Other", awayTeamConference: " " } }
  ]
  const options = {}
  filter.rebuildOptions = (axis, entries) => { options[axis] = entries }
  filter.filterOptions = () => {}
  filter.update = () => {}

  filter.refreshCards()

  assert.deepEqual(Array.from(options.bowl, (entry) => Array.from(entry)), [["New Bowl", "New Bowl"]])
  assert.deepEqual(Array.from(options.team, (entry) => Array.from(entry)), [
    ["6", "Other"], ["4", "Team (4)"], ["5", "Team (5)"]
  ])
  assert.deepEqual(Array.from(options.conference, (entry) => Array.from(entry)), [
    ["Atlantic", "Atlantic"], ["Pacific", "Pacific"]
  ])
})

test("conference matches either side, ORs selections and ANDs with bowl and team", () => {
  const filter = new GamesFilter()
  const options = (values) => values.map((value) => ({ querySelector: () => ({ checked: true, value }) }))
  filter.bowlOptionTargets = options(["Championship"])
  filter.teamOptionTargets = options(["4", "6"])
  filter.conferenceOptionTargets = options(["Atlantic", "Pacific"])
  const card = (bowlTitle, homeTeamId, awayTeamId, homeTeamConference, awayTeamConference) =>
    ({ dataset: { bowlTitle, homeTeamId, awayTeamId, homeTeamConference, awayTeamConference } })
  assert.equal(filter.matchesCard(card("Championship", "4", "5", "Other", "Atlantic")), true)
  assert.equal(filter.matchesCard(card("Championship", "5", "6", "Pacific", "Other")), true)
  assert.equal(filter.matchesCard(card("Championship", "4", "5", "Other", "Other")), false)
  assert.equal(filter.matchesCard(card("Other", "4", "5", "Pacific", "Other")), false)
  assert.equal(filter.matchesCard(card("Championship", "5", "7", "Pacific", "Other")), false)
  filter.conferenceOptionTargets = []
  assert.equal(filter.matchesCard(card("Championship", "4", "5", "Other", "Other")), true)
})

test("rebuilding conference options retains available selections and drops removed ones", () => {
  const filter = new GamesFilter()
  const options = []
  Object.defineProperty(filter, "conferenceOptionTargets", { get: () => options.filter((option) => !option.removed) })
  filter.conferenceNoMatchesTarget = { before(...entries) {
    options.push(...entries)
  } }
  filter.conferenceSearchTarget = { ...element(), value: "pac", focus() { document.activeElement = this } }
  filter.conferenceDropdownTarget = { hidden: false }

  filter.rebuildOptions("conference", [["Atlantic", "Atlantic"], ["Pacific", "Pacific"]])
  filter.filterOptions("conference", false)
  options[0].checkbox.checked = true
  options[1].checkbox.checked = true
  options[1].checkbox.focus()
  filter.rebuildOptions("conference", [["Pacific", "Pacific"], ["Mountain", "Mountain"]])

  assert.deepEqual(filter.conferenceOptionTargets.map((option) => [option.checkbox.value, option.checkbox.checked]),
    [["Pacific", true], ["Mountain", false]])
  assert.equal(document.activeElement, filter.conferenceOptionTargets[0].checkbox)
  assert.equal(filter.conferenceOptionTargets[0].hidden, false)
  assert.equal(filter.conferenceOptionTargets[0].classList.contains("hidden"), false)

  filter.rebuildOptions("conference", [["Mountain", "Mountain"]])
  assert.equal(document.activeElement, filter.conferenceSearchTarget)
})

test("rebuilding options moves focus to search when the replacement does not match the query", () => {
  const filter = new GamesFilter()
  const options = []
  Object.defineProperty(filter, "teamOptionTargets", { get: () => options.filter((option) => !option.removed) })
  filter.teamNoMatchesTarget = { ...element(), before(...entries) { options.push(...entries) } }
  filter.teamSearchTarget = { ...element(), value: "home", focus() { document.activeElement = this } }
  filter.teamDropdownTarget = { hidden: false }

  filter.rebuildOptions("team", [["4", "Home"]])
  filter.filterOptions("team", false)
  filter.teamOptionTargets[0].checkbox.checked = true
  filter.teamOptionTargets[0].checkbox.focus()
  filter.rebuildOptions("team", [["4", "Away"], ["5", "Home"]])

  assert.equal(document.activeElement, filter.teamSearchTarget)
  assert.equal(filter.teamOptionTargets[0].checkbox.checked, true)
  assert.equal(filter.teamOptionTargets[0].hidden, true)
  assert.equal(filter.teamOptionTargets[1].hidden, false)
  assert.equal(filter.teamDropdownTarget.hidden, false)
})

test("rebuilding options does not focus a replacement in a dismissed dropdown", () => {
  const filter = new GamesFilter()
  const options = []
  Object.defineProperty(filter, "bowlOptionTargets", { get: () => options.filter((option) => !option.removed) })
  filter.bowlNoMatchesTarget = { ...element(), before(...entries) { options.push(...entries) } }
  filter.bowlSearchTarget = { ...element(), value: "bowl", focus() { document.activeElement = this } }
  filter.bowlDropdownTarget = { hidden: false }

  filter.rebuildOptions("bowl", [["Bowl", "Bowl"]])
  filter.filterOptions("bowl", false)
  filter.bowlOptionTargets[0].checkbox.focus()
  filter.bowlDropdownTarget.hidden = true
  filter.rebuildOptions("bowl", [["Bowl", "Bowl Game"]])

  assert.equal(document.activeElement, filter.bowlSearchTarget)
  assert.equal(filter.bowlDropdownTarget.hidden, true)
  assert.equal(filter.bowlOptionTargets[0].hidden, false)
})

test("card refresh retains focused checkbox nodes when available choices are unchanged", () => {
  const filter = new GamesFilter()
  for (const axis of ["bowl", "team", "conference"]) {
    const options = []
    Object.defineProperty(filter, `${axis}OptionTargets`, { get: () => options.filter((option) => !option.removed) })
    filter[`${axis}NoMatchesTarget`] = { ...element(), before(...entries) { options.push(...entries) } }
    filter[`${axis}SearchTarget`] = { ...element(), value: "", focus() { document.activeElement = this } }
    filter[`${axis}DropdownTarget`] = element()
    filter[`${axis}CountTarget`] = element()
    filter[`${axis}ClearTarget`] = { ...element(), disabled: true }
  }
  const card = (score) => ({ dataset: {
    bowlTitle: "Shared Bowl", homeTeamId: "4", homeTeamSchool: "Home",
    homeTeamConference: "Atlantic", awayTeamId: "5", awayTeamSchool: "Away",
    awayTeamConference: "Pacific", score
  }, ...element() })
  filter.gameCardTargets = [card("0")]
  filter.refreshCards()
  filter.teamSearchTarget.value = "away"
  filter.filterOptions("team")
  const checkbox = filter.teamOptionTargets[0].checkbox
  checkbox.checked = true
  checkbox.focus()
  const originalOptions = filter.teamOptionTargets.slice()

  filter.gameCardTargets = [card("7")]
  filter.refreshCards()

  assert.equal(document.activeElement, checkbox)
  assert.equal(filter.teamOptionTargets[0], originalOptions[0])
  assert.equal(filter.teamOptionTargets[1], originalOptions[1])
  assert.equal(checkbox.checked, true)
  assert.equal(filter.gameCardTargets[0].hidden, false)
  assert.equal(filter.teamDropdownTarget.hidden, false)
  assert.equal(filter.teamSearchTarget["aria-expanded"], "true")
})

test("card refresh filters replacement options without reopening a dismissed dropdown", () => {
  const filter = new GamesFilter()
  filter.bowlSearchTarget = { ...element(), value: "shared" }
  filter.teamSearchTarget = { ...element(), value: "" }
  filter.conferenceSearchTarget = { ...element(), value: "" }
  filter.bowlDropdownTarget = element()
  filter.teamDropdownTarget = element()
  filter.conferenceDropdownTarget = element()
  filter.bowlOptionTargets = [element("Shared Bowl")]
  filter.teamOptionTargets = []
  filter.conferenceOptionTargets = []
  filter.bowlNoMatchesTarget = element()
  filter.teamNoMatchesTarget = element()
  filter.conferenceNoMatchesTarget = element()
  filter.updateClearButtons = () => {}
  filter.update = () => {}
  filter.rebuildOptions = (axis, entries) => {
    filter[`${axis}OptionTargets`] = entries.map(([, text]) => element(text))
  }

  filter.search({ target: filter.bowlSearchTarget })
  assert.equal(filter.bowlDropdownTarget.hidden, false)
  assert.equal(filter.bowlSearchTarget["aria-expanded"], "true")
  filter.close()
  assert.equal(filter.bowlDropdownTarget.hidden, true)
  assert.equal(filter.bowlSearchTarget["aria-expanded"], "false")

  filter.gameCardTargets = [
    { dataset: { bowlTitle: "New Shared Bowl", homeTeamId: "", awayTeamId: "" } },
    { dataset: { bowlTitle: "Other Bowl", homeTeamId: "", awayTeamId: "" } }
  ]
  filter.refreshCards()

  assert.equal(filter.bowlDropdownTarget.hidden, true)
  assert.equal(filter.bowlSearchTarget["aria-expanded"], "false")
  assert.equal(filter.bowlOptionTargets[0].hidden, false)
  assert.equal(filter.bowlOptionTargets[1].hidden, true)
  assert.equal(filter.bowlNoMatchesTarget.hidden, true)

  filter.gameCardTargets = [{ dataset: { bowlTitle: "Other Bowl", homeTeamId: "", awayTeamId: "" } }]
  filter.refreshCards()
  assert.equal(filter.bowlDropdownTarget.hidden, true)
  assert.equal(filter.bowlSearchTarget["aria-expanded"], "false")
  assert.equal(filter.bowlNoMatchesTarget.hidden, false)

  filter.search({ target: filter.bowlSearchTarget })
  filter.gameCardTargets = [{ dataset: { bowlTitle: "Shared Again", homeTeamId: "", awayTeamId: "" } }]
  filter.refreshCards()
  assert.equal(filter.bowlDropdownTarget.hidden, false)
  assert.equal(filter.bowlSearchTarget["aria-expanded"], "true")
  assert.equal(filter.bowlOptionTargets[0].hidden, false)
  assert.equal(filter.bowlNoMatchesTarget.hidden, true)
})

test("observes card replacements and releases the observer on disconnect", () => {
  const filter = new GamesFilter()
  const cards = {}
  filter.cardsTarget = cards
  let refreshes = 0
  filter.refreshCards = () => { refreshes += 1 }

  filter.connect()
  assert.equal(refreshes, 1)
  assert.equal(filter.cardObserver.target, cards)
  assert.equal(filter.cardObserver.options.childList, true)
  filter.cardObserver.callback()
  assert.equal(refreshes, 2)
  filter.disconnect()
  assert.equal(filter.cardObserver.disconnected, true)
})
