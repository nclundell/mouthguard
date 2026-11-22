const assert = require("node:assert/strict")
const { readFileSync } = require("node:fs")
const { join } = require("node:path")
const { test } = require("node:test")
const vm = require("node:vm")

const source = readFileSync(join(__dirname, "../app/javascript/controllers/filter_search.js"), "utf8")
  .replaceAll("export function", "function")
const { normalizeSearchText, matchesSearch } = vm.runInNewContext(
  `${source}\n({ normalizeSearchText, matchesSearch })`,
  {}
)

test("composed and decomposed accents match in either direction", () => {
  assert.equal(matchesSearch(normalizeSearchText("café"), "cafe\u0301"), true)
  assert.equal(matchesSearch(normalizeSearchText("cafe\u0301"), "café"), true)
})

test("search remains an ordered subsequence and ignores punctuation", () => {
  assert.equal(matchesSearch(normalizeSearchText("t1"), "Test 1"), true)
  assert.equal(matchesSearch(normalizeSearchText("1t"), "Test 1"), false)
  assert.equal(normalizeSearchText(" - ! "), "")
  assert.equal(matchesSearch(normalizeSearchText(""), "Test 1"), true)
})
