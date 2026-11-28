const assert = require("node:assert/strict")
const { readFileSync } = require("node:fs")
const { join } = require("node:path")
const { test } = require("node:test")
const vm = require("node:vm")

class TextNode {
  constructor(text, parent = null, code = false, format = 0, style = "", detail = 0, key = null) {
    this.text = text
    this.parent = parent
    this.code = code
    this.format = format
    this.style = style
    this.detail = detail
    this.__key = key
    this.parts = [this]
  }
  isSimpleText() { return true }
  hasFormat(format) { return format === "code" && this.code }
  getParent() { return this.parent }
  getKey() { return this.__key }
  is(node) { return this === node }
  getTextContent() { return this.text }
  splitText(...offsets) {
    const points = [0, ...offsets, this.text.length]
    const pieces = points.slice(1).map((end, index) => this.text.slice(points[index], end))
      .filter(Boolean).map((text) => new TextNode(text, this.parent, this.code, this.format, this.style, this.detail))
    this.parts.splice(this.parts.indexOf(this), 1, ...pieces)
    for (const piece of pieces) piece.parts = this.parts
    return pieces
  }
  replace(node) { this.parts.splice(this.parts.indexOf(this), 1, node) }
}
class DecoratorNode {
  constructor(key) { this.__key = key }
  getKey() { return this.__key }
  selectNext(start = 0, end = start) {
    const next = this.next
    if (next instanceof TextNode) {
      selection = rangeSelection({ key: next.getKey(), offset: start, type: "text" },
        { key: next.getKey(), offset: end, type: "text" })
    } else {
      selection = rangeSelection({ key: this.parent.getKey(), offset: this.index + 1, type: "element" },
        { key: this.parent.getKey(), offset: this.index + 1, type: "element" })
    }
    return selection
  }
}
class ElementNode {
  constructor(type, url, text, parent = null) {
    this.type = type
    this.url = url
    this.text = text
    this.parent = parent
  }
  getType() { return this.type }
  getKey() { return this.__key }
  is(node) { return this === node }
  getURL() { return this.url }
  getTextContent() { return this.text }
  getParent() { return this.parent }
  replace(node) {
    this.replacement = node
    node.__key = `preview-${this.__key}`
    node.parent = this.parent
    node.index = this.index
    node.next = this.next
    nodes.set(node.__key, node)
    nodes.delete(this.__key)
    for (const [key, child] of nodes) {
      for (let parent = child.getParent?.(); parent; parent = parent.getParent?.()) {
        if (parent === this) { nodes.delete(key); break }
      }
    }
  }
}
let selection = null
const Lexical = {
  TextNode, DecoratorNode, ElementNode,
  $isTextNode: (node) => node instanceof TextNode,
  $getNodeByKey: (key) => nodes.get(key),
  $getSelection: () => selection,
  $isRangeSelection: (value) => value?.type === "range",
  $setSelection: (value) => { selection = value }
}
const nodes = new Map()
class Extension {
  constructor(editorElement) { this.editorElement = editorElement }
  defineExtension(config) { return config }
}
const document = {
  createTextNode: (text) => ({ textContent: text, nodeType: 3 }),
  createElement: () => ({ style: {} })
}
const source = readFileSync(join(__dirname, "../lib/lexxy/comment_image_preview.js"), "utf8")
  .replace('import { Extension, Lexical } from "lexxy"', "")
  .replaceAll("export ", "")
  .replace("default class CommentImagePreviewExtension", "class CommentImagePreviewExtension")
const { imageMatches, previewText, previewLink, CommentImageNode, CommentImagePreviewExtension } =
  vm.runInNewContext(`${source}\n({ imageMatches, previewText, previewLink, CommentImageNode, CommentImagePreviewExtension })`,
    { Extension, Lexical, document, URL })

function registerExtension() {
  const transforms = new Map()
  let listener
  let updates = 0
  const extension = new CommentImagePreviewExtension({ matches: () => true })
  const unregister = extension.lexicalExtension.register({
    registerNodeTransform(type, transform) { transforms.set(type, transform); return () => {} },
    registerUpdateListener(callback) { listener = callback; return () => {} },
    update(callback) { updates++; callback() }
  })
  return { transforms, listener, unregister, get updates() { return updates } }
}

function editorState(currentSelection) {
  return { read(callback) {
    const saved = selection
    selection = currentSelection
    try { return callback() } finally { selection = saved }
  } }
}

function rangeSelection(anchor, focus, selectedNodes = []) {
  return {
    type: "range", anchor, focus,
    isCollapsed() { return anchor.key === focus.key && anchor.offset === focus.offset },
    getNodes() { return selectedNodes }
  }
}

test("finds direct HTTPS GIF PNG JPG JPEG WebP URLs with query or fragment", () => {
  const urls = "https://example.test/a.GIF?size=large#frame https://example.test/b.png https://example.test/c.jpg https://example.test/d.jpeg https://example.test/e.webp"
  assert.deepEqual(Array.from(imageMatches(urls), ({ url }) => url), urls.split(" "))
})

test("rejects unsafe, non-image and embedded URL-like substrings", () => {
  const urls = "http://example.test/a.gif https://user@example.test/a.gif https://example.test/a.svg https://example.test/gallery https://example.test/download?file=a.png https://example.test/a.gif/other prefixhttps://example.test/a.gif https://example.test/a.gifmore javascript:alert(1)"
  assert.equal(imageMatches(urls).length, 0)
})

test("replaces only matching text with inline image nodes and exports its original URL", () => {
  const url = "https://example.test/a.png?x=1#part"
  const node = new TextNode(`Look (${url}), then hi `)
  previewText(node)
  const parts = node.parts
  assert.deepEqual(parts.map((part) => part.getTextContent()), ["Look (", url, "), then hi "])
  assert.equal(parts[1] instanceof CommentImageNode, true)
  assert.equal(parts[1].isKeyboardSelectable(), true)
  const image = parts[1].createDOM()
  assert.equal(image.src, url)
  assert.equal(image.referrerPolicy, "no-referrer")
  assert.equal(parts[1].exportDOM().element.textContent, url)
  assert.equal(parts[1].exportDOM().element.nodeType, 3)
  assert.equal(parts[1].exportJSON().url, url)
})

test("waits for whitespace before previewing a URL with an incrementally typed query and fragment", () => {
  const url = "https://example.test/a.png?size=large#frame"
  const node = new TextNode("https://example.test/a.png")
  for (const suffix of ["", "?", "?size=large", "?size=large#", "?size=large#frame"]) {
    node.text = `https://example.test/a.png${suffix}`
    previewText(node)
    assert.deepEqual(node.parts, [node])
  }
  node.text = `${url} `
  previewText(node)
  assert.equal(node.parts[0].getTextContent(), url)
  assert.equal(node.parts[0].exportDOM().element.textContent, url)
  assert.equal(node.parts[1].getTextContent(), " ")
})

test("typing leaves an unfinished end-of-text URL editable until whitespace", () => {
  const node = new TextNode("https://example.test/a.png")
  previewText(node)
  assert.deepEqual(node.parts, [node])
})

test("previews a Lexxy-pasted bare LinkNode and exports its original URL", () => {
  const url = "https://example.test/a.png?size=large#frame"
  const link = new ElementNode("link", url, url)
  nodes.set("pasted-link", link)
  const { listener } = registerExtension()
  listener({ dirtyElements: new Map([["pasted-link", true]]) })
  assert.equal(link.replacement instanceof CommentImageNode, true)
  assert.equal(link.replacement.exportDOM().element.textContent, url)
  nodes.delete("pasted-link")
})

test("previews a typed AutoLinkNode and exports its original URL", () => {
  const url = "https://example.test/last.webp?x=1#frame"
  const link = new ElementNode("autolink", url, url)
  nodes.set("typed-link", link)
  const { listener } = registerExtension()
  listener({ dirtyElements: new Map([["typed-link", true]]) })
  assert.equal(link.replacement instanceof CommentImageNode, true)
  assert.equal(link.replacement.exportDOM().element.textContent, url)
  nodes.delete("typed-link")
})

test("moves a collapsed caret into existing following text without adding a space", () => {
  const url = "https://example.test/a.png"
  const paragraph = new ElementNode("paragraph")
  paragraph.__key = "caret-paragraph"
  const link = new ElementNode("link", url, url, paragraph)
  link.__key = "caret-link"
  link.index = 0
  const after = new TextNode(" after", paragraph, false, 0, "", 0, "after-text")
  link.next = after
  const text = new TextNode(url, link, false, 0, "", 0, "caret-text")
  for (const node of [paragraph, link, text, after]) nodes.set(node.getKey(), node)
  selection = rangeSelection({ key: text.getKey() }, { key: text.getKey() }, [text])
  const { listener } = registerExtension()
  listener({ dirtyElements: new Map([[link.getKey(), true]]) })
  assert.equal(selection.type, "range")
  assert.deepEqual(selection.anchor, { key: after.getKey(), offset: 0, type: "text" })
  assert.deepEqual(selection.focus, selection.anchor)
  assert.equal(after.getTextContent(), " after")
  assert.equal(nodes.has(text.getKey()), false)
  selection = null
})

test("preserves an external-text-to-link range and leaves its link intact through dirty updates", () => {
  const url = "https://example.test/b.gif"
  const paragraph = new ElementNode("paragraph")
  paragraph.__key = "range-paragraph"
  const link = new ElementNode("autolink", url, url, paragraph)
  link.__key = "range-link"
  link.index = 0
  const text = new TextNode(url, link, false, 0, "", 0, "range-text")
  const outside = new TextNode("outside", paragraph, false, 0, "", 0, "outside-text")
  for (const node of [paragraph, link, text, outside]) nodes.set(node.getKey(), node)
  selection = rangeSelection(
    { key: outside.getKey(), offset: 2, type: "text" },
    { key: text.getKey(), offset: 5, type: "text" },
    [outside, text]
  )
  const original = selection
  const anchor = selection.anchor
  const focus = selection.focus
  const { listener } = registerExtension()
  listener({ dirtyElements: new Map([[link.getKey(), true], [text.getKey(), true]]) })
  assert.equal(selection, original)
  assert.equal(selection.anchor, anchor)
  assert.equal(selection.focus, focus)
  assert.equal(link.replacement, undefined)
  assert.equal(link.getTextContent(), url)
  assert.equal(nodes.get(link.getKey()), link)
  assert.equal(nodes.get(text.getKey()), text)
  selection = null
})

test("previews a selected link when the selection collapses inside it without dirty elements", () => {
  const url = "https://example.test/b.gif?size=large#frame"
  const paragraph = new ElementNode("paragraph")
  paragraph.__key = "selection-paragraph"
  const link = new ElementNode("autolink", url, url, paragraph)
  link.__key = "selection-link"
  link.index = 0
  const text = new TextNode(url, link, false, 0, "", 0, "selection-text")
  const outside = new TextNode("outside", paragraph, false, 0, "", 0, "selection-outside")
  link.next = outside
  for (const node of [paragraph, link, text, outside]) nodes.set(node.getKey(), node)
  const selected = rangeSelection(
    { key: outside.getKey(), offset: 2, type: "text" },
    { key: text.getKey(), offset: 5, type: "text" },
    [outside, text]
  )
  selection = selected
  const extension = registerExtension()
  extension.listener({ dirtyElements: new Map([[link.getKey(), true]]),
    editorState: editorState(selected), prevEditorState: editorState(null) })
  assert.equal(link.replacement, undefined)
  assert.equal(selection, selected)

  const caret = rangeSelection(
    { key: text.getKey(), offset: 5, type: "text" },
    { key: text.getKey(), offset: 5, type: "text" },
    [text]
  )
  selection = caret
  extension.listener({ dirtyElements: new Map(), editorState: editorState(caret), prevEditorState: editorState(selected) })
  assert.equal(link.replacement instanceof CommentImageNode, true)
  assert.equal(link.replacement.exportDOM().element.textContent, url)
  assert.deepEqual(selection.anchor, { key: outside.getKey(), offset: 0, type: "text" })
  assert.deepEqual(selection.focus, selection.anchor)
  assert.equal(outside.getTextContent(), "outside")
  assert.equal(extension.updates, 2)
  extension.listener({ dirtyElements: new Map(), editorState: editorState(selection), prevEditorState: editorState(caret) })
  assert.equal(extension.updates, 2, "selection after preview must not cause another update")
  selection = null
})

test("selection-only updates outside an image link or with an unchanged caret do not schedule updates", () => {
  const url = "https://example.test/elsewhere.png"
  const link = new ElementNode("link", url, url)
  link.__key = "elsewhere-link"
  const text = new TextNode(url, link, false, 0, "", 0, "elsewhere-text")
  const outside = new TextNode("outside", null, false, 0, "", 0, "elsewhere-outside")
  for (const node of [link, text, outside]) nodes.set(node.getKey(), node)
  const previous = rangeSelection(
    { key: outside.getKey(), offset: 1, type: "text" },
    { key: outside.getKey(), offset: 1, type: "text" }
  )
  const current = rangeSelection(
    { key: outside.getKey(), offset: 2, type: "text" },
    { key: outside.getKey(), offset: 2, type: "text" }
  )
  const extension = registerExtension()
  selection = current
  extension.listener({ dirtyElements: new Map(), editorState: editorState(current), prevEditorState: editorState(previous) })
  assert.equal(extension.updates, 0)
  const inside = rangeSelection(
    { key: text.getKey(), offset: 1, type: "text" },
    { key: text.getKey(), offset: 1, type: "text" }
  )
  selection = inside
  extension.listener({ dirtyElements: new Map(), editorState: editorState(inside), prevEditorState: editorState(inside) })
  assert.equal(extension.updates, 0)
  assert.equal(link.replacement, undefined)
  selection = null
})

test("places a collapsed pasted-URL caret after the final preview without adding text", () => {
  const url = "https://example.test/end.jpeg"
  const paragraph = new ElementNode("paragraph")
  paragraph.__key = "end-paragraph"
  const link = new ElementNode("link", url, url, paragraph)
  link.__key = "end-link"
  link.index = 0
  const text = new TextNode(url, link, false, 0, "", 0, "end-link-text")
  for (const node of [paragraph, link, text]) nodes.set(node.getKey(), node)
  selection = rangeSelection({ key: text.getKey() }, { key: text.getKey() }, [text])
  previewLink(link)
  assert.deepEqual(selection.anchor, { key: paragraph.getKey(), offset: 1, type: "element" })
  assert.deepEqual(selection.focus, selection.anchor)
  assert.equal(link.replacement.getTextContent(), url)
  assert.equal(link.replacement.next, undefined)
  selection = null
})

test("does not change a range selection in another link", () => {
  const url = "https://example.test/c.webp"
  const link = new ElementNode("link", url, url)
  link.__key = "other-link"
  const other = new TextNode("unrelated", null, false, 0, "", 0, "unrelated-text")
  nodes.set(link.__key, link)
  nodes.set(other.getKey(), other)
  selection = rangeSelection({ key: other.getKey() }, { key: other.getKey() }, [other])
  const original = selection
  previewLink(link)
  assert.equal(link.replacement instanceof CommentImageNode, true)
  assert.equal(selection, original)
  assert.equal(nodes.has(other.getKey()), true)
  selection = null
})

test("dirty elements leave labeled, non-image and unsafe links untouched", () => {
  const url = "https://example.test/a.png"
  const { listener } = registerExtension()
  for (const [type, href, label] of [
    ["link", url, "image"],
    ["autolink", "https://example.test/gallery", "https://example.test/gallery"],
    ["link", "http://example.test/a.png", "http://example.test/a.png"],
    ["link", "https://user@example.test/a.png", "https://user@example.test/a.png"]
  ]) {
    const link = new ElementNode(type, href, label)
    nodes.set("unsafe-link", link)
    listener({ dirtyElements: new Map([["unsafe-link", true]]) })
    assert.equal(link.replacement, undefined)
    const child = new TextNode(`${url} `, link)
    previewText(child)
    assert.deepEqual(child.parts, [child])
  }
  nodes.delete("unsafe-link")
})

test("converts delimited URLs in text, but leaves an end-of-text URL editable", () => {
  const first = "https://example.test/a.png?size=large#frame"
  const second = "https://example.test/b.gif"
  const node = new TextNode(`${first} ${second}`)
  previewText(node)
  assert.deepEqual(node.parts.map((part) => part.getTextContent()), [first, ` ${second}`])
  const tail = node.parts[1]
  tail.text += " "
  previewText(tail)
  assert.deepEqual(node.parts.map((part) => part.getTextContent()), [first, " ", second, " "])
  assert.equal(node.parts[2].exportDOM().element.textContent, second)
})

test("keeps format, style and detail on text surrounding a preview", () => {
  const url = "https://example.test/a.webp?x=1#photo"
  const node = new TextNode(`Bold ${url} after `, null, false, 3, "color: red;", 2)
  previewText(node)
  assert.deepEqual(node.parts.map((part) => part.getTextContent()), ["Bold ", url, " after "])
  for (const part of [node.parts[0], node.parts[2]]) {
    assert.equal(part.format, 3)
    assert.equal(part.style, "color: red;")
    assert.equal(part.detail, 2)
  }
})

test("leaves inline code and code-block text untouched", () => {
  const url = "https://example.test/a.gif"
  const inline = new TextNode(url, null, true)
  const block = new TextNode(url, { getType: () => "code", getParent: () => null })
  previewText(inline)
  previewText(block)
  assert.equal(inline.replacement, undefined)
  assert.equal(block.replacement, undefined)
  assert.deepEqual(inline.parts, [inline])
  assert.deepEqual(block.parts, [block])
  const codeLink = new ElementNode("link", url, url, { getType: () => "code", getParent: () => null })
  previewLink(codeLink)
  assert.equal(codeLink.replacement, undefined)
})

test("registers only in comment Lexxy editors", () => {
  const extension = new CommentImagePreviewExtension({ matches: (selector) => selector === "lexxy-editor.comment-composer[name='comment[body]']" })
  assert.equal(extension.enabled, true)
  const others = new CommentImagePreviewExtension({ matches: () => false })
  assert.equal(others.enabled, false)
  const registered = []
  let unregistered = 0
  let listeners = 0
  const config = extension.lexicalExtension
  assert.deepEqual(Array.from(config.nodes), [CommentImageNode])
  const unregister = config.register({
    registerNodeTransform(type, transform) {
      assert.equal(type, TextNode, "abstract ElementNode cannot register a Lexical transform")
      registered.push([type, transform])
      return () => { unregistered++ }
    },
    registerUpdateListener() { listeners++; return () => { unregistered++ } }
  })
  assert.deepEqual(registered, [[TextNode, previewText]])
  assert.equal(listeners, 1)
  unregister()
  assert.equal(unregistered, 2)
})
