import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["scroller", "table", "header"]

  connect() {
    this.overlay = document.createElement("div")
    this.overlay.className = "fixed top-0 z-30 hidden overflow-hidden"
    this.overlay.setAttribute("aria-hidden", "true")
    this.overlayTable = this.tableTarget.cloneNode(false)
    this.overlayTable.removeAttribute("data-picks-sticky-header-target")
    this.overlayTable.style.tableLayout = "fixed"
    this.overlayHeader = this.headerTarget.cloneNode(true)
    this.overlayHeader.removeAttribute("data-picks-sticky-header-target")
    this.overlayTable.append(this.overlayHeader)
    this.overlay.append(this.overlayTable)
    this.element.append(this.overlay)

    this.update = this.update.bind(this)
    this.refresh = this.refresh.bind(this)
    window.addEventListener("scroll", this.update, { passive: true })
    window.addEventListener("resize", this.refresh)
    this.scrollerTarget.addEventListener("scroll", this.update, { passive: true })
    this.element.addEventListener("picks:filter", this.refresh)
    this.resizeObserver = new ResizeObserver(this.refresh)
    this.resizeObserver.observe(this.scrollerTarget)
    this.resizeObserver.observe(this.tableTarget)
    this.resizeObserver.observe(this.headerTarget)
    this.headerCells = Array.from(this.headerTarget.querySelectorAll("th"))
    this.headerCells.forEach((cell) => this.resizeObserver.observe(cell))
    this.refresh()
  }

  disconnect() {
    window.removeEventListener("scroll", this.update)
    window.removeEventListener("resize", this.refresh)
    this.scrollerTarget.removeEventListener("scroll", this.update)
    this.element.removeEventListener("picks:filter", this.refresh)
    this.resizeObserver.disconnect()
    this.overlay.remove()
  }

  update() {
    this.renderPosition(this.position())
  }

  position() {
    const scroller = this.scrollerTarget
    const rect = scroller.getBoundingClientRect()
    const headerRect = this.headerTarget.getBoundingClientRect()
    const visible = this.element.getClientRects().length > 0 &&
      headerRect.bottom <= 0 && rect.bottom > headerRect.height
    return {
      visible,
      left: rect.left + scroller.clientLeft,
      scrollLeft: scroller.scrollLeft
    }
  }

  refresh() {
    this.headerCells.forEach((cell, index) => {
      const duplicate = this.overlayHeader.children[0].children[index]
      duplicate.hidden = cell.hidden
      duplicate.classList.toggle("hidden", cell.classList.contains("hidden"))
    })
    const scroller = this.scrollerTarget
    const position = this.position()
    const scrollerWidth = scroller.clientWidth
    const tableWidth = this.tableTarget.getBoundingClientRect().width
    const cellWidths = this.headerCells.map((cell) => cell.getBoundingClientRect().width)

    this.overlay.style.width = `${scrollerWidth}px`
    this.overlayTable.style.width = `${tableWidth}px`
    cellWidths.forEach((width, index) => {
      const duplicate = this.overlayHeader.children[0].children[index]
      duplicate.style.width = `${width}px`
      duplicate.style.minWidth = `${width}px`
    })
    this.renderPosition(position)
  }

  renderPosition({ visible, left, scrollLeft }) {
    this.overlay.classList.toggle("hidden", !visible)
    if (!visible) return

    this.overlay.style.left = `${left}px`
    this.overlay.scrollLeft = scrollLeft
  }
}
