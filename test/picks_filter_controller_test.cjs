const assert = require("node:assert/strict")
const { readFileSync } = require("node:fs")
const { join } = require("node:path")
const { test } = require("node:test")
const vm = require("node:vm")

const searchSource = readFileSync(join(__dirname, "../app/javascript/controllers/filter_search.js"), "utf8")
  .replaceAll("export function", "function")
const controllerSource = readFileSync(join(__dirname, "../app/javascript/controllers/picks_filter_controller.js"), "utf8")
  .replace(/^import .*$/gm, "").replace("export default class extends Controller", "class PicksFilter extends Controller")
const document = { activeElement: null, addEventListener() {}, removeEventListener() {} }
const PicksFilter = vm.runInNewContext(`${searchSource}\n${controllerSource}\nPicksFilter`,
  { Controller: class {}, document, CustomEvent: class {} })

function element(textContent = "") {
  const classes = new Set()
  return {
    textContent, hidden: true, dataset: {},
    classList: { toggle(name, active) { active ? classes.add(name) : classes.delete(name) } },
    setAttribute(name, value) { this[name] = value }
  }
}

test("Picks clear all resets both selections and searches and refreshes rows and sticky header", () => {
  const filter = new PicksFilter()
  for (const axis of ["bowl", "user"]) {
    filter[`${axis}OptionTargets`] = ["First", "Second"].map((value) => {
      const option = element(value)
      option.checkbox = { checked: false, value }
      option.querySelector = () => option.checkbox
      return option
    })
    filter[`${axis}SearchTarget`] = { ...element(), hidden: false, value: "", focus() { document.activeElement = this } }
    filter[`${axis}DropdownTarget`] = element()
    filter[`${axis}NoMatchesTarget`] = element()
  }
  filter.clearAllTarget = { ...element(), focus() { document.activeElement = this } }
  let clearAllHidden = true
  Object.defineProperty(filter.clearAllTarget, "hidden", {
    get() { return clearAllHidden },
    set(value) {
      clearAllHidden = value
      if (value && document.activeElement === this) document.activeElement = null
    }
  })
  filter.gameRowTargets = [{ ...element(), dataset: { bowlTitle: "First" } }]
  filter.gameCardTargets = [{ ...element(), dataset: { bowlTitle: "First" } }]
  filter.userColumnTargets = [{ ...element(), dataset: { userId: "First" } }]
  filter.userCellTargets = []
  filter.userEntryTargets = []
  filter.emptyColumnTargets = []
  filter.emptyCellTargets = []
  filter.emptyMessageTargets = []
  filter.lockedCellTargets = []
  filter.noGamesTarget = element()
  let notifications = 0
  filter.element = { querySelector: () => ({ dispatchEvent() { notifications += 1 } }) }
  filter.update()
  assert.equal(filter.clearAllTarget.hidden, true)
  for (const axis of ["bowl", "user"]) {
    filter[`${axis}SearchTarget`].value = "first"
    filter.search({ target: filter[`${axis}SearchTarget`] })
    assert.equal(filter.clearAllTarget.hidden, true)
    filter[`${axis}OptionTargets`][1].checkbox.checked = true
  }
  filter.update()
  assert.equal(filter.clearAllTarget.hidden, false)
  assert.equal(filter.gameRowTargets[0].hidden, true)
  assert.equal(filter.userColumnTargets[0].hidden, true)
  filter.clearAllTarget.focus()
  filter.clearAll()
  assert.equal(document.activeElement, filter.bowlSearchTarget)
  for (const axis of ["bowl", "user"]) {
    assert.equal(filter[`${axis}OptionTargets`].every((option) => !option.checkbox.checked && option.hidden), true)
    assert.equal(filter[`${axis}SearchTarget`].value, "")
    assert.equal(filter[`${axis}NoMatchesTarget`].hidden, true)
    assert.equal(filter[`${axis}DropdownTarget`].hidden, true)
    assert.equal(filter[`${axis}SearchTarget`]["aria-expanded"], "false")
  }
  assert.equal(filter.clearAllTarget.hidden, true)
  assert.equal(filter.gameRowTargets[0].hidden, false)
  assert.equal(filter.gameCardTargets[0].hidden, false)
  assert.equal(filter.userColumnTargets[0].hidden, false)
  assert.ok(notifications > 0)
})
