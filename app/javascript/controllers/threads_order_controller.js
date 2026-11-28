import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { page: Number }

  connect() {
    this.followLatest = this.pageValue === 1 && this.element.dataset.threadsFollowLatest !== "false"
    this.savedScrollTop = Number(this.element.dataset.threadsScrollTop || 0)
    this.nextOlderPage = null
    delete this.element.dataset.threadsFollowLatest
    delete this.element.dataset.threadsScrollTop
    this.onFeedScroll = this.onFeedScroll.bind(this)
    this.beforeCache = this.beforeCache.bind(this)
    document.addEventListener("turbo:before-cache", this.beforeCache)
    this.media = window.matchMedia("(min-width: 640px)")
    this.sync = this.sync.bind(this)
    this.media.addEventListener("change", this.sync)
    this.observer = new MutationObserver(this.sync)
    this.observer.observe(this.element, { childList: true, subtree: true })
    this.resizeObserver = new ResizeObserver(() => {
      if (this.followLatest && this.feed) this.syncScroll(this.feed, 0)
    })
    this.sync()
    if (this.pageValue === 1 && this.list.children.length > 25) {
      this.historyLoaded = true
      const older = this.feed.querySelector(".threads-pages a[data-action]")
      this.nextOlderPage = older ? Number(new URL(older.href, window.location.href).searchParams.get("page")) : null
    }
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    this.media.removeEventListener("change", this.sync)
    this.observer.disconnect()
    this.resizeObserver.disconnect()
    this.feed?.removeEventListener("scroll", this.onFeedScroll)
  }

  beforeCache() {
    if (this.pageValue !== 1 || !this.feed) return
    this.element.dataset.threadsFollowLatest = String(this.followLatest)
    this.element.dataset.threadsScrollTop = String(this.feed.scrollTop)
    this.feed.setAttribute("data-initial-scroll-pending", "")
  }

  sync() {
    const feed = this.element.querySelector(".threads-feed")
    const composer = this.element.querySelector(".threads-composer")
    const list = feed?.querySelector(".threads-list")
    if (!feed || !composer || !list) return

    const feedChanged = feed !== this.feed
    const oldScrollTop = this.feed?.scrollTop ?? this.savedScrollTop ?? 0
    if (feedChanged && this.feed && (this.historyLoaded || this.loadingOlder)) {
      const present = new Set(Array.from(list.children, (item) => item.id))
      const history = Array.from(this.list.children).filter((item) => !present.has(item.id))
      list.prepend(...history)
      const older = feed.querySelector(".threads-pages a[data-action]")
      if (older && this.nextOlderPage) older.href = this.olderPageUrl(older.href, this.nextOlderPage)
      else if (older && !this.loadingOlder) this.removeOlderLink(older)
    }
    if (feedChanged) {
      this.feed?.removeEventListener("scroll", this.onFeedScroll)
      this.feed = feed
      feed.addEventListener("scroll", this.onFeedScroll, { passive: true })
      this.resizeObserver.disconnect()
      this.resizeObserver.observe(feed)
      this.resizeObserver.observe(list)
      this.list = list
    } else if (list !== this.list) {
      this.resizeObserver.unobserve(this.list)
      this.resizeObserver.observe(list)
      this.list = list
    }

    if (feedChanged || this.followLatest || this.wasDesktop !== this.media.matches) {
      this.syncScroll(feed, oldScrollTop)
      if (!this.followLatest && this.mobileAnchor) this.restoreAnchor()
    }
    if (!this.loadingOlder && (feedChanged || !this.mobileAnchor)) {
      this.mobileAnchor = !this.followLatest && this.list.children.length ? this.visibleAnchor() : null
    }
    this.wasDesktop = this.media.matches
    this.savedScrollTop = null
    feed.removeAttribute("data-initial-scroll-pending")
  }

  syncScroll(feed, oldScrollTop) {
    if (getComputedStyle(feed).overflowY !== "auto") return
    feed.scrollTop = this.followLatest ? feed.scrollHeight : oldScrollTop
    this.programmaticScrollTop = this.followLatest ? null : feed.scrollTop
  }

  visibleAnchor() {
    const bounds = this.feed.getBoundingClientRect()
    const item = Array.from(this.list.children).find((child) => {
      const rect = child.getBoundingClientRect()
      return rect.bottom > bounds.top && rect.top < bounds.bottom
    })
    return item ? { id: item.id, offset: item.getBoundingClientRect().top - bounds.top } : null
  }

  restoreAnchor() {
    const anchor = this.mobileAnchor
    const item = anchor && Array.from(this.list.children).find((child) => child.id === anchor.id)
    if (!item) return
    const offset = item.getBoundingClientRect().top - this.feed.getBoundingClientRect().top
    this.feed.scrollTop += offset - anchor.offset
    this.programmaticScrollTop = this.feed.scrollTop
  }

  onFeedScroll() {
    if (getComputedStyle(this.feed).overflowY !== "auto") return
    if (this.programmaticScrollTop != null) {
      const restored = this.feed.scrollTop === this.programmaticScrollTop
      this.programmaticScrollTop = null
      if (restored) return
    }
    if (this.pageValue === 1) {
      this.followLatest = this.feed.scrollHeight - this.feed.clientHeight - this.feed.scrollTop <= 80
    }
    if ((this.loadingOlder || !this.followLatest) && this.list?.children.length) {
      this.mobileAnchor = this.visibleAnchor()
    }
    if (this.feed.scrollTop <= 30) this.loadOlder()
  }

  olderPageUrl(href, page) {
    const url = new URL(href, window.location.href)
    url.searchParams.set("page", page)
    return url.href
  }

  removeOlderLink(older) {
    const nav = older.parentElement
    older.remove()
    if (!nav.children.length) nav.remove()
  }

  async loadOlder(event) {
    if (getComputedStyle(this.feed).overflowY !== "auto") return
    const older = this.feed.querySelector(".threads-pages a[data-action]")
    if (!older) return
    event?.preventDefault()
    if (this.loadingOlder) return
    const oldest = this.list.firstElementChild
    if (!oldest) return

    this.mobileAnchor = this.visibleAnchor()
    this.loadingOlder = true
    const mediaAtStart = this.media.matches
    const paginationUrl = older.href
    try {
      const url = new URL(older.href, window.location.href)
      url.searchParams.set("older_before", oldest.dataset.commentId)
      const response = await fetch(url, { headers: { Accept: "text/html" } })
      if (!response.ok || response.redirected) throw new Error("Could not load older comments")
      const fragment = new DOMParser().parseFromString(await response.text(), "text/html")
      const entries = fragment.querySelector(".threads-list")
      if (!entries) throw new Error("Missing older comments")
      if (this.element && this.element.querySelector(".threads-feed") !== this.feed) this.sync()
      const known = new Set(Array.from(this.list.children, (item) => item.id))
      const additions = Array.from(entries.children).filter((item) => !known.has(item.id))
      this.followLatest = false
      this.list.prepend(...additions)
      this.historyLoaded = true
      const next = fragment.querySelector(".threads-pages a[data-action]")
      const currentOlder = this.feed.querySelector(".threads-pages a[data-action]")
      if (next && additions.length) {
        if (currentOlder) currentOlder.href = next.href
        this.nextOlderPage = Number(new URL(next.href, window.location.href).searchParams.get("page"))
      } else {
        if (currentOlder) this.removeOlderLink(currentOlder)
        this.nextOlderPage = null
      }
      this.restoreAnchor()
      if (this.media.matches === mediaAtStart) this.mobileAnchor = null
    } catch (error) {
      console.error(error)
      if (event) window.location.assign(paginationUrl)
    } finally {
      this.loadingOlder = false
    }
  }
}
