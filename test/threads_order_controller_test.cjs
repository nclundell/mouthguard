const assert = require("node:assert/strict")
const { readFileSync } = require("node:fs")
const { join } = require("node:path")
const { test } = require("node:test")
const vm = require("node:vm")

const listeners = new Map()
let requested = []
let fragments = []
let fetchReply = async () => ({ ok: true, redirected: false, text: async () => "fragment" })
let navigatedTo = null
const source = readFileSync(join(__dirname, "../app/javascript/controllers/threads_order_controller.js"), "utf8")
  .replace(/^import .*$/gm, "")
  .replace("export default class extends Controller", "class ThreadsOrder extends Controller")
const ThreadsOrder = vm.runInNewContext(`${source}\nThreadsOrder`, {
  Controller: class {},
  URL,
  fetch: async (url) => {
    requested.push(url)
    return fetchReply()
  },
  DOMParser: class { parseFromString() { return fragments.shift() } },
  getComputedStyle: (feed) => ({ overflowY: feed.overflowY }),
  document: {
    addEventListener: (name, callback) => listeners.set(name, callback),
    removeEventListener: (name, callback) => {
      if (listeners.get(name) === callback) listeners.delete(name)
    }
  },
  window: { location: { href: "https://example.test/threads", assign(url) { navigatedTo = url } }, matchMedia: () => ({ matches: false, addEventListener() {}, removeEventListener() {} }) },
  MutationObserver: class { observe() {} disconnect() {} },
  ResizeObserver: class { observe() {} unobserve() {} disconnect() {} }
})

function feed(maxScroll, overflowY = "auto") {
  let top = 0
  return {
    scrollHeight: maxScroll + 100, clientHeight: 100, overflowY,
    querySelector: () => null,
    get scrollTop() { return top },
    set scrollTop(value) { top = Math.min(this.scrollHeight - this.clientHeight, value) }
  }
}

function pageOne(scrollTop = 0) {
  const messages = feed(300)
  messages.scrollTop = scrollTop
  messages.dataset = {}
  messages.setAttribute = (name) => { messages[name] = "" }
  messages.removeAttribute = (name) => { delete messages[name] }
  messages.addEventListener = () => {}
  messages.removeEventListener = () => {}
  messages.querySelector = (selector) => selector === ".threads-list" ? list : null
  const list = { dataset: {}, children: [] }
  const composer = {}
  const section = {
    dataset: {},
    querySelector: (selector) => selector === ".threads-feed" ? messages : composer
  }
  return { section, messages }
}

test("Turbo caches page one hidden with reader scroll and follow preference, then restores both", () => {
  const { section, messages } = pageOne(100)
  const controller = new ThreadsOrder()
  controller.pageValue = 1
  controller.element = section
  controller.connect()
  messages.scrollTop = 100
  controller.onFeedScroll()
  assert.equal(controller.followLatest, false)

  listeners.get("turbo:before-cache")()
  assert.equal(messages["data-initial-scroll-pending"], "")
  assert.equal(section.dataset.threadsFollowLatest, "false")
  assert.equal(section.dataset.threadsScrollTop, "100")
  controller.disconnect()
  messages.scrollTop = 0

  const restored = new ThreadsOrder()
  restored.pageValue = 1
  restored.element = section
  restored.connect()
  assert.equal(restored.followLatest, false)
  assert.equal(messages.scrollTop, 100)
  assert.equal(messages["data-initial-scroll-pending"], undefined)
  assert.equal(section.dataset.threadsFollowLatest, undefined)
  restored.disconnect()
})

test("Turbo restores a desktop reader's position and follow preference", () => {
  const { section, messages } = pageOne(120)
  const controller = new ThreadsOrder()
  controller.pageValue = 1
  controller.element = section
  controller.connect()
  controller.media.matches = true
  controller.sync()
  messages.scrollTop = 120
  controller.onFeedScroll()
  listeners.get("turbo:before-cache")()
  controller.disconnect()
  messages.scrollTop = 0

  const restored = new ThreadsOrder()
  restored.pageValue = 1
  restored.element = section
  restored.connect()
  restored.media.matches = true
  restored.sync()
  assert.equal(restored.followLatest, false)
  assert.equal(messages.scrollTop, 120)
  restored.disconnect()
})

test("older pages are not hidden or saved before Turbo caches", () => {
  const { section, messages } = pageOne(40)
  const controller = new ThreadsOrder()
  controller.pageValue = 2
  controller.element = section
  controller.connect()
  listeners.get("turbo:before-cache")()
  assert.equal(messages["data-initial-scroll-pending"], undefined)
  assert.equal(section.dataset.threadsFollowLatest, undefined)
  controller.disconnect()
})

test("restoring a clamped scroll position does not re-enable live follow", () => {
  const controller = new ThreadsOrder()
  controller.pageValue = 1
  controller.followLatest = false
  controller.media = { matches: false }
  controller.feed = feed(20)

  controller.syncScroll(controller.feed, 300)
  assert.equal(controller.feed.scrollTop, 20)
  controller.onFeedScroll()
  assert.equal(controller.followLatest, false)

  controller.feed.scrollTop = 0
  controller.onFeedScroll()
  assert.equal(controller.followLatest, true)
})

test("a real scroll after a silent restoration is not ignored", () => {
  const controller = new ThreadsOrder()
  controller.pageValue = 1
  controller.followLatest = false
  controller.media = { matches: false }
  controller.feed = feed(200)

  controller.syncScroll(controller.feed, 150)
  controller.feed.scrollTop = 190
  controller.onFeedScroll()
  assert.equal(controller.followLatest, true)
})

test("page one still follows new content while the reader is near the bottom", () => {
  const controller = new ThreadsOrder()
  controller.pageValue = 1
  controller.followLatest = true
  controller.media = { matches: false }
  controller.feed = feed(200)

  controller.syncScroll(controller.feed, 0)
  assert.equal(controller.feed.scrollTop, 200)
  controller.feed.scrollHeight = 330
  controller.syncScroll(controller.feed, controller.feed.scrollTop)
  assert.equal(controller.feed.scrollTop, 230)
  controller.feed.scrollTop = 0
  controller.onFeedScroll()
  assert.equal(controller.followLatest, false)
})

test("desktop opens at latest and follows only near the bottom of the internal feed", () => {
  const controller = new ThreadsOrder()
  controller.pageValue = 1
  controller.followLatest = true
  controller.media = { matches: true }
  controller.feed = feed(300)
  controller.syncScroll(controller.feed, 0)
  assert.equal(controller.feed.scrollTop, 300)
  controller.feed.scrollHeight += 50
  controller.syncScroll(controller.feed, controller.feed.scrollTop)
  assert.equal(controller.feed.scrollTop, 350)

  controller.feed.scrollTop = 100
  controller.onFeedScroll()
  assert.equal(controller.followLatest, false)
  controller.feed.scrollHeight += 50
  controller.syncScroll(controller.feed, controller.feed.scrollTop)
  assert.equal(controller.feed.scrollTop, 100)
  controller.feed.scrollTop = 390
  controller.onFeedScroll()
  assert.equal(controller.followLatest, true)
})

test("older pages and page-scroll fallback do not auto-scroll", () => {
  const controller = new ThreadsOrder()
  controller.pageValue = 2
  controller.followLatest = false
  controller.media = { matches: false }
  controller.feed = feed(200)
  controller.syncScroll(controller.feed, 100)
  controller.feed.scrollTop = 190
  controller.onFeedScroll()
  assert.equal(controller.followLatest, false)

  controller.feed = feed(200, "visible")
  controller.followLatest = true
  controller.syncScroll(controller.feed, 100)
  assert.equal(controller.feed.scrollTop, 0)
})

function olderReader() {
  const older = {
    href: "https://example.test/threads?page=2#comments",
    dataset: { action: "threads-order#loadOlder" },
    remove() { this.parentElement.children.pop(); this.parentElement = null }
  }
  const nav = { children: [older], remove() { this.removed = true } }
  older.parentElement = nav
  const list = {
    dataset: {},
    children: [{ id: "comment_26", dataset: { commentId: "26" } }],
    get firstElementChild() { return this.children[0] },
    prepend(...items) { this.children.unshift(...items) },
    append(...items) {
      this.children = this.children.filter((item) => !items.includes(item)).concat(items)
    }
  }
  let controller
  const height = (item) => controller.media.matches ? item.desktopHeight ?? 50 : item.mobileHeight ?? 50
  const position = (item) => list.children.slice(0, list.children.indexOf(item))
    .reduce((sum, previous) => sum + height(previous), 0)
  const rect = (item) => {
    const top = position(item) - messages.scrollTop
    return { top, bottom: top + height(item) }
  }
  const itemRect = { getBoundingClientRect() { return rect(this) } }
  Object.setPrototypeOf(list.children[0], itemRect)
  const prepend = list.prepend.bind(list)
  list.prepend = (...items) => {
    items.forEach((item) => Object.setPrototypeOf(item, itemRect))
    prepend(...items)
  }
  const append = list.append.bind(list)
  list.append = (...items) => {
    items.forEach((item) => Object.setPrototypeOf(item, itemRect))
    append(...items)
  }
  const messages = {
    overflowY: "auto", clientHeight: 100, scrollTop: 0,
    removeAttribute() {},
    getBoundingClientRect() { return { top: 0, bottom: 100 } },
    get scrollHeight() { return 100 + list.children.reduce((sum, item) => sum + height(item), 0) },
    querySelector: (selector) => selector === ".threads-list" ? list :
      selector === ".threads-pages a[data-action]" && !nav.removed ? older : null
  }
  controller = new ThreadsOrder()
  controller.pageValue = 1
  controller.followLatest = true
  controller.media = { matches: false }
  controller.feed = messages
  controller.list = list
  return { controller, messages, list, older, nav }
}

function olderFragment(ids, nextPage) {
  const entries = { children: ids.map((id) => ({ id: `comment_${id}`, dataset: { commentId: String(id) } })) }
  const older = nextPage ? { href: `https://example.test/threads?page=${nextPage}#comments` } : null
  return { querySelector: (selector) => selector === ".threads-list" ? entries : older }
}

test("loading older comments prepends, maintains visual position, and continues until exhausted", async () => {
  requested = []
  fragments = [olderFragment([24, 25], 3), olderFragment([22, 23], null)]
  const { controller, messages, list, older, nav } = olderReader()
  controller.onFeedScroll()
  await new Promise((resolve) => setImmediate(resolve))
  assert.deepEqual(list.children.map((item) => item.id), ["comment_24", "comment_25", "comment_26"])
  assert.equal(messages.scrollTop, 100)
  assert.equal(controller.followLatest, false)
  assert.equal(older.href, "https://example.test/threads?page=3#comments")
  assert.equal(new URL(requested[0]).searchParams.get("older_before"), "26")

  messages.scrollTop = 0
  controller.onFeedScroll()
  await new Promise((resolve) => setImmediate(resolve))
  assert.deepEqual(list.children.map((item) => item.id), ["comment_22", "comment_23", "comment_24", "comment_25", "comment_26"])
  assert.equal(messages.scrollTop, 100)
  assert.equal(new URL(requested[1]).searchParams.get("older_before"), "24")
  assert.equal(nav.removed, true)
  controller.onFeedScroll()
  assert.equal(requested.length, 2)
})

test("desktop top scrolling loads older game comments using the oldest visible cursor", async () => {
  requested = []
  fragments = [olderFragment([24, 25], null)]
  const { controller, list, messages, older } = olderReader()
  controller.media.matches = true
  older.href = "https://example.test/games/42?page=2#comments"
  controller.onFeedScroll()
  await new Promise((resolve) => setImmediate(resolve))

  assert.equal(new URL(requested[0]).pathname, "/games/42")
  assert.equal(new URL(requested[0]).searchParams.get("older_before"), "26")
  assert.deepEqual(list.children.map((item) => item.id), ["comment_24", "comment_25", "comment_26"])
  assert.equal(messages.scrollTop, 100)
  assert.equal(controller.followLatest, false)
})

test("game comments reuse cursor loading without leaving their game's pagination route", async () => {
  requested = []
  fragments = [olderFragment([24, 25], 3), olderFragment([22, 23], null)]
  const { controller, older, list, messages } = olderReader()
  older.href = "https://example.test/games/42?page=2#comments"
  fragments[0].querySelector(".threads-pages a[data-action]").href =
    "https://example.test/games/42?page=3#comments"

  await controller.loadOlder()

  assert.equal(new URL(requested[0]).pathname, "/games/42")
  assert.equal(new URL(requested[0]).searchParams.get("older_before"), "26")
  assert.equal(older.href, "https://example.test/games/42?page=3#comments")
  assert.deepEqual(list.children.map((item) => item.id), ["comment_24", "comment_25", "comment_26"])

  await controller.loadOlder()
  assert.equal(new URL(requested[1]).pathname, "/games/42")
  assert.equal(new URL(requested[1]).searchParams.get("older_before"), "24")
  assert.deepEqual(list.children.map((item) => item.id),
    ["comment_22", "comment_23", "comment_24", "comment_25", "comment_26"])

  controller.media.matches = true
  controller.element = { querySelector: (selector) => selector === ".threads-feed" ? messages : {} }
  controller.resizeObserver = { unobserve() {}, observe() {} }
  controller.sync()
  assert.deepEqual(list.children.map((item) => item.id),
    ["comment_22", "comment_23", "comment_24", "comment_25", "comment_26"])
})

test("manual Older link uses progressive loading only when the feed scrolls", async () => {
  fragments = [olderFragment([25], null)]
  const { controller, messages } = olderReader()
  let prevented = false
  await controller.loadOlder({ preventDefault() { prevented = true } })
  assert.equal(prevented, true)
  assert.equal(messages.scrollTop, 50)

  const fallback = olderReader()
  fallback.messages.overflowY = "visible"
  prevented = false
  await fallback.controller.loadOlder({ preventDefault() { prevented = true } })
  assert.equal(prevented, false)
})

function replaceFeed(controller, messages, ids) {
  const replacementList = {
    dataset: {}, children: ids.map((id) => ({ id: `comment_${id}`, dataset: { commentId: String(id) } })),
    prepend(...items) { this.children.unshift(...items) },
    append(...items) {
      this.children = this.children.filter((item) => !items.includes(item)).concat(items)
    }
  }
  const nav = { children: [], remove() { this.removed = true } }
  const newerLink = {
    href: "https://example.test/threads?page=2#comments",
    parentElement: nav,
    remove() { nav.children.pop(); this.parentElement = null }
  }
  nav.children.push(newerLink)
  const replacement = feed(300)
  replacement.getBoundingClientRect = () => ({ top: 0, bottom: 100 })
  const itemRect = {
    getBoundingClientRect() {
      const top = replacementList.children.indexOf(this) * 50 - replacement.scrollTop
      return { top, bottom: top + 50 }
    }
  }
  replacementList.children.forEach((item) => Object.setPrototypeOf(item, itemRect))
  const prepend = replacementList.prepend.bind(replacementList)
  replacementList.prepend = (...items) => {
    items.forEach((item) => Object.setPrototypeOf(item, itemRect))
    prepend(...items)
  }
  const append = replacementList.append.bind(replacementList)
  replacementList.append = (...items) => {
    items.forEach((item) => Object.setPrototypeOf(item, itemRect))
    append(...items)
  }
  replacement.dataset = {}
  replacement.removeAttribute = () => {}
  replacement.addEventListener = () => {}
  replacement.querySelector = (selector) => ({
    ".threads-list": replacementList, ".threads-pages": null,
    ".threads-pages a[data-action]": nav.removed ? null : newerLink
  })[selector]
  controller.element = { querySelector: (selector) => selector === ".threads-feed" ? replacement : {} }
  controller.resizeObserver = { disconnect() {}, observe() {} }
  controller.onFeedScroll = controller.onFeedScroll.bind(controller)
  messages.removeEventListener = () => {}
  return { replacementList, newerLink, nav, replacement }
}

test("live feed replacement retains loaded history and its next Older link", () => {
  const { controller, messages, list } = olderReader()
  list.prepend({ id: "comment_25", dataset: { commentId: "25" } })
  const { replacementList, newerLink, replacement } = replaceFeed(controller, messages, [27])
  controller.historyLoaded = true
  controller.followLatest = false
  controller.nextOlderPage = 3
  messages.scrollTop = 40

  controller.sync()

  assert.deepEqual(replacementList.children.map((item) => item.id), ["comment_25", "comment_26", "comment_27"])
  assert.equal(newerLink.href, "https://example.test/threads?page=3#comments")
  assert.equal(replacement.scrollTop, 40)
})

test("desktop live feed replacement retains chronological loaded history and reader position", () => {
  const { controller, messages, list } = olderReader()
  controller.media.matches = true
  list.prepend({ id: "comment_25", dataset: { commentId: "25" } })
  const { replacementList, replacement } = replaceFeed(controller, messages, [27])
  controller.historyLoaded = true
  controller.followLatest = false
  controller.nextOlderPage = 3
  messages.scrollTop = 40
  controller.sync()

  assert.deepEqual(replacementList.children.map((item) => item.id), ["comment_25", "comment_26", "comment_27"])
  assert.equal(replacement.scrollTop, 40)
})

test("a live replacement during a pending fetch merges prior history, current comments and the batch", async () => {
  requested = []
  fragments = [olderFragment([23, 24], 4)]
  let resolveFetch
  fetchReply = () => new Promise((resolve) => { resolveFetch = resolve })
  try {
    const { controller, messages, list, older } = olderReader()
    list.prepend({ id: "comment_25", dataset: { commentId: "25" } })
    const pending = controller.loadOlder()
    const { replacementList, newerLink } = replaceFeed(controller, messages, [26, 27])
    controller.sync()
    resolveFetch({ ok: true, redirected: false, text: async () => "fragment" })
    await pending

    assert.deepEqual(replacementList.children.map((item) => item.id),
      ["comment_23", "comment_24", "comment_25", "comment_26", "comment_27"])
    assert.equal(newerLink.href, "https://example.test/threads?page=4#comments")
    assert.equal(older.href, "https://example.test/threads?page=2#comments")
    assert.equal(new URL(requested[0]).searchParams.get("older_before"), "25")
  } finally {
    fetchReply = async () => ({ ok: true, redirected: false, text: async () => "fragment" })
  }
})

test("a mobile fetch finishing on desktop prepends the older batch chronologically", async () => {
  requested = []
  fragments = [olderFragment([22, 23], 4)]
  let resolveFetch
  fetchReply = () => new Promise((resolve) => { resolveFetch = resolve })
  try {
    const { controller, list, messages } = olderReader()
    list.prepend(
      { id: "comment_24", dataset: { commentId: "24" } },
      { id: "comment_25", dataset: { commentId: "25" } }
    )
    const pending = controller.loadOlder()
    controller.media.matches = true
    controller.element = { querySelector: (selector) => selector === ".threads-feed" ? messages : {} }
    controller.resizeObserver = { unobserve() {}, observe() {} }
    controller.sync()
    controller.onFeedScroll()
    assert.equal(requested.length, 1, "desktop scroll must not start another fetch")

    resolveFetch({ ok: true, redirected: false, text: async () => "fragment" })
    await pending

    assert.deepEqual(list.children.map((item) => item.id),
      ["comment_22", "comment_23", "comment_24", "comment_25", "comment_26"])
    assert.equal(controller.nextOlderPage, 4)
    assert.equal(new URL(requested[0]).searchParams.get("older_before"), "24")
  } finally {
    fetchReply = async () => ({ ok: true, redirected: false, text: async () => "fragment" })
  }
})

test("a desktop fetch preserves the visible mobile comment despite different wrapping heights", async () => {
  fragments = [olderFragment([22, 23], 4)]
  fragments[0].querySelector(".threads-list").children.forEach((item) => {
    item.mobileHeight = 70
    item.desktopHeight = 20
  })
  let resolveFetch
  fetchReply = () => new Promise((resolve) => { resolveFetch = resolve })
  try {
    const { controller, list, messages } = olderReader()
    list.prepend(
      { id: "comment_24", dataset: { commentId: "24" }, mobileHeight: 70, desktopHeight: 20 },
      { id: "comment_25", dataset: { commentId: "25" }, mobileHeight: 70, desktopHeight: 20 }
    )
    list.children[2].mobileHeight = 70
    list.children[2].desktopHeight = 20
    messages.scrollTop = 40
    controller.onFeedScroll()
    assert.equal(controller.followLatest, false)
    const pending = controller.loadOlder()
    controller.media.matches = true
    controller.element = { querySelector: (selector) => selector === ".threads-feed" ? messages : {} }
    controller.resizeObserver = { unobserve() {}, observe() {} }
    controller.sync()

    resolveFetch({ ok: true, redirected: false, text: async () => "fragment" })
    await pending
    assert.deepEqual(list.children.map((item) => item.id),
      ["comment_22", "comment_23", "comment_24", "comment_25", "comment_26"])

    controller.media.matches = false
    controller.sync()
    assert.equal(messages.scrollTop, 180)
    assert.equal(list.children[2].getBoundingClientRect().top, -40)
    assert.equal(controller.followLatest, false)

    messages.clientHeight = messages.scrollHeight - messages.scrollTop - 10
    controller.onFeedScroll() // Scroll event from the restoration.
    assert.equal(controller.followLatest, false)
    messages.scrollTop += 5
    controller.onFeedScroll() // A real user scroll must not be suppressed.
    assert.equal(controller.followLatest, true)
  } finally {
    fetchReply = async () => ({ ok: true, redirected: false, text: async () => "fragment" })
  }
})

test("a desktop media callback retains chronological order and the visible anchor", () => {
  const { controller, list, messages } = olderReader()
  list.prepend(
    { id: "comment_24", dataset: { commentId: "24" }, mobileHeight: 70, desktopHeight: 20 },
    { id: "comment_25", dataset: { commentId: "25" }, mobileHeight: 70, desktopHeight: 20 }
  )
  list.children[2].mobileHeight = 70
  list.children[2].desktopHeight = 20
  controller.followLatest = false
  messages.scrollTop = 90
  controller.onFeedScroll()
  controller.element = { querySelector: (selector) => selector === ".threads-feed" ? messages : {} }
  controller.resizeObserver = { unobserve() {}, observe() {} }

  controller.media.matches = true // CSS has already changed dimensions before the change callback.
  controller.sync()
  assert.deepEqual(list.children.map((item) => item.id), ["comment_24", "comment_25", "comment_26"])

  controller.media.matches = false
  controller.sync()
  assert.equal(messages.scrollTop, 90)
  assert.equal(list.children[1].getBoundingClientRect().top, -20)
  assert.equal(controller.followLatest, false)
})

test("returning to mobile before an older fetch resolves preserves its anchor for the inserted batch", async () => {
  fragments = [olderFragment([22, 23], 4)]
  fragments[0].querySelector(".threads-list").children.forEach((item) => {
    item.mobileHeight = 70
    item.desktopHeight = 20
  })
  let resolveFetch
  fetchReply = () => new Promise((resolve) => { resolveFetch = resolve })
  try {
    const { controller, list, messages } = olderReader()
    list.prepend(
      { id: "comment_24", dataset: { commentId: "24" }, mobileHeight: 70, desktopHeight: 20 },
      { id: "comment_25", dataset: { commentId: "25" }, mobileHeight: 70, desktopHeight: 20 }
    )
    list.children[2].mobileHeight = 70
    list.children[2].desktopHeight = 20
    messages.scrollTop = 40
    controller.onFeedScroll()
    const pending = controller.loadOlder()
    controller.media.matches = true
    controller.element = { querySelector: (selector) => selector === ".threads-feed" ? messages : {} }
    controller.resizeObserver = { unobserve() {}, observe() {} }
    controller.sync()
    assert.equal(controller.mobileAnchor.id, "comment_24")

    controller.media.matches = false
    controller.sync()
    assert.equal(messages.scrollTop, 40)
    assert.equal(controller.mobileAnchor.id, "comment_24")

    controller.media.matches = true
    controller.sync()
    assert.equal(controller.mobileAnchor.id, "comment_24")
    controller.media.matches = false
    controller.sync()

    resolveFetch({ ok: true, redirected: false, text: async () => "fragment" })
    await pending
    assert.deepEqual(list.children.map((item) => item.id),
      ["comment_22", "comment_23", "comment_24", "comment_25", "comment_26"])
    assert.equal(messages.scrollTop, 180)
    assert.equal(list.children[2].getBoundingClientRect().top, -40)
    assert.equal(controller.mobileAnchor, null)
    assert.equal(controller.followLatest, false)
  } finally {
    fetchReply = async () => ({ ok: true, redirected: false, text: async () => "fragment" })
  }
})

test("scrolling during an older fetch restores the reader's latest visible comment", async () => {
  fragments = [olderFragment([22, 23], 4)]
  let resolveFetch
  fetchReply = () => new Promise((resolve) => { resolveFetch = resolve })
  try {
    const { controller, list, messages } = olderReader()
    list.prepend(
      { id: "comment_24", dataset: { commentId: "24" } },
      { id: "comment_25", dataset: { commentId: "25" } }
    )
    messages.scrollTop = 40
    controller.onFeedScroll()
    const pending = controller.loadOlder()
    assert.equal(controller.mobileAnchor.id, "comment_24")

    controller.syncScroll(messages, 50)
    controller.onFeedScroll() // Ignore the scroll event caused by restoration.
    assert.equal(controller.mobileAnchor.offset, -40)

    messages.scrollTop = 55
    controller.onFeedScroll()
    assert.equal(controller.mobileAnchor.id, "comment_25")
    assert.equal(controller.mobileAnchor.offset, -5)
    assert.equal(controller.followLatest, false)

    resolveFetch({ ok: true, redirected: false, text: async () => "fragment" })
    await pending
    assert.deepEqual(list.children.map((item) => item.id),
      ["comment_22", "comment_23", "comment_24", "comment_25", "comment_26"])
    assert.equal(messages.scrollTop, 155)
    assert.equal(list.children[3].id, "comment_25")
    assert.equal(list.children[3].getBoundingClientRect().top, -5)
    assert.equal(controller.followLatest, false)
  } finally {
    fetchReply = async () => ({ ok: true, redirected: false, text: async () => "fragment" })
  }
})

test("scrolling into the follow zone during an older fetch preserves the newest visible comment", async () => {
  fragments = [olderFragment([22, 23], 4)]
  let resolveFetch
  fetchReply = () => new Promise((resolve) => { resolveFetch = resolve })
  try {
    const { controller, list, messages } = olderReader()
    list.prepend(
      { id: "comment_24", dataset: { commentId: "24" } },
      { id: "comment_25", dataset: { commentId: "25" } }
    )
    messages.scrollTop = 40
    controller.onFeedScroll()
    const pending = controller.loadOlder()
    assert.equal(controller.mobileAnchor.id, "comment_24")

    messages.scrollTop = 145
    controller.onFeedScroll()
    assert.equal(controller.followLatest, true)
    assert.equal(controller.mobileAnchor.id, "comment_26")
    assert.equal(controller.mobileAnchor.offset, -45)

    resolveFetch({ ok: true, redirected: false, text: async () => "fragment" })
    await pending
    assert.equal(messages.scrollTop, 245)
    assert.equal(list.children[4].getBoundingClientRect().top, -45)
    assert.equal(controller.followLatest, false)
    controller.onFeedScroll() // Restoring the anchor must not re-enable follow.
    assert.equal(controller.followLatest, false)
    messages.scrollTop = 250
    controller.onFeedScroll()
    assert.equal(controller.followLatest, true)
  } finally {
    fetchReply = async () => ({ ok: true, redirected: false, text: async () => "fragment" })
  }
})

test("a mobile load started while following latest restores the adjusted position after desktop response", async () => {
  fragments = [olderFragment([22, 23], 4)]
  let resolveFetch
  fetchReply = () => new Promise((resolve) => { resolveFetch = resolve })
  try {
    const { controller, list, messages } = olderReader()
    list.prepend(
      { id: "comment_24", dataset: { commentId: "24" } },
      { id: "comment_25", dataset: { commentId: "25" } }
    )
    assert.equal(controller.followLatest, true)
    const pending = controller.loadOlder()
    controller.media.matches = true
    controller.element = { querySelector: (selector) => selector === ".threads-feed" ? messages : {} }
    controller.resizeObserver = { unobserve() {}, observe() {} }
    controller.sync()

    resolveFetch({ ok: true, redirected: false, text: async () => "fragment" })
    await pending
    controller.media.matches = false
    controller.sync()

    assert.equal(controller.followLatest, false)
    assert.equal(messages.scrollTop, 100)
  } finally {
    fetchReply = async () => ({ ok: true, redirected: false, text: async () => "fragment" })
  }
})

test("returning to mobile without the saved comment retains the feed scroll position", () => {
  const { controller, messages } = olderReader()
  messages.scrollTop = 35
  controller.followLatest = false
  controller.media.matches = true
  controller.element = { querySelector: (selector) => selector === ".threads-feed" ? messages : {} }
  controller.resizeObserver = { unobserve() {}, observe() {} }
  controller.sync()
  controller.list.children.length = 0
  messages.scrollTop = 35

  controller.media.matches = false
  controller.sync()
  assert.equal(messages.scrollTop, 35)
  assert.equal(controller.followLatest, false)
})

test("a desktop live replacement during a mobile fetch retains chronological history", async () => {
  fragments = [olderFragment([22, 23], 4)]
  let resolveFetch
  fetchReply = () => new Promise((resolve) => { resolveFetch = resolve })
  try {
    const { controller, messages, list } = olderReader()
    list.prepend(
      { id: "comment_24", dataset: { commentId: "24" } },
      { id: "comment_25", dataset: { commentId: "25" } }
    )
    const pending = controller.loadOlder()
    controller.media.matches = true
    controller.element = { querySelector: (selector) => selector === ".threads-feed" ? messages : {} }
    controller.resizeObserver = { unobserve() {}, observe() {}, disconnect() {} }
    controller.sync()
    const { replacementList, newerLink } = replaceFeed(controller, messages, [26, 27])
    controller.sync()

    resolveFetch({ ok: true, redirected: false, text: async () => "fragment" })
    await pending

    assert.deepEqual(replacementList.children.map((item) => item.id),
      ["comment_22", "comment_23", "comment_24", "comment_25", "comment_26", "comment_27"])
    assert.equal(newerLink.href, "https://example.test/threads?page=4#comments")
  } finally {
    fetchReply = async () => ({ ok: true, redirected: false, text: async () => "fragment" })
  }
})

test("an exhausted in-flight fetch removes the replacement link, not the detached link", async () => {
  fragments = [olderFragment([25], null)]
  let resolveFetch
  fetchReply = () => new Promise((resolve) => { resolveFetch = resolve })
  try {
    const { controller, messages, older, nav } = olderReader()
    const pending = controller.loadOlder()
    const { replacementList, newerLink, nav: currentNav } = replaceFeed(controller, messages, [27])
    controller.sync()
    resolveFetch({ ok: true, redirected: false, text: async () => "fragment" })
    await pending

    assert.deepEqual(replacementList.children.map((item) => item.id), ["comment_25", "comment_26", "comment_27"])
    assert.equal(currentNav.removed, true)
    assert.equal(newerLink.parentElement, null)
    assert.equal(nav.removed, undefined)
    assert.equal(older.parentElement, nav)
  } finally {
    fetchReply = async () => ({ ok: true, redirected: false, text: async () => "fragment" })
  }
})

test("failed manual Older requests navigate to the real page but automatic failures do not", async () => {
  const originalError = console.error
  console.error = () => {}
  fetchReply = async () => { throw new Error("Network unavailable") }
  navigatedTo = null
  try {
    const { controller } = olderReader()
    let prevented = false
    await controller.loadOlder({ preventDefault() { prevented = true } })
    assert.equal(prevented, true)
    assert.equal(navigatedTo, "https://example.test/threads?page=2#comments")

    navigatedTo = null
    await olderReader().controller.loadOlder()
    assert.equal(navigatedTo, null)
  } finally {
    fetchReply = async () => ({ ok: true, redirected: false, text: async () => "fragment" })
    console.error = originalError
  }
})
