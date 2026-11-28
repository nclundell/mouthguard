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
  getPreviousSibling() { return this.parent?.children?.[this.parent.children.indexOf(this) - 1] }
  getNextSibling() { return this.parent?.children?.[this.parent.children.indexOf(this) + 1] }
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
  replace(node) {
    const index = this.parts.indexOf(this)
    node.parent = this.parent
    node.index = index
    node.next = this.parts[index + 1]
    this.parts.splice(index, 1, node)
  }
}
class DecoratorNode {
  constructor(key) { this.__key = key }
  getKey() { return this.__key }
  getType() { return this.constructor.getType?.() ?? "decorator" }
  getParent() { return this.parent }
  isAttached() { return Boolean(this.parent) }
  getIndexWithinParent() { return this.index }
  selectPrevious() {
    selection = rangeSelection({ key: this.parent.getKey(), offset: this.index, type: "element" },
      { key: this.parent.getKey(), offset: this.index, type: "element" })
  }
  remove() {
    this.removed = true
    nodes.delete(this.getKey())
  }
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
  getChildAtIndex(index) { return this.children?.[index] }
  select(start, end = start) {
    selection = rangeSelection({ key: this.getKey(), offset: start, type: "element" },
      { key: this.getKey(), offset: end, type: "element" })
    return selection
  }
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
  KEY_BACKSPACE_COMMAND: "backspace", KEY_DELETE_COMMAND: "delete", COMMAND_PRIORITY_HIGH: 3,
  $isTextNode: (node) => node instanceof TextNode,
  $isNodeSelection: (value) => value?.type === "node",
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
    { Extension, Lexical, document, URL, setTimeout })

function registerExtension({ beforeUpdate, deferUpdate } = {}) {
  const transforms = new Map()
  const commands = new Map()
  let rootListener
  let listener
  let updates = 0
  let inUpdate = false
  const extension = new CommentImagePreviewExtension({ matches: () => true })
  const unregister = extension.lexicalExtension.register({
    registerNodeTransform(type, transform) { transforms.set(type, transform); return () => {} },
    registerUpdateListener(callback) { listener = callback; return () => {} },
    registerRootListener(callback) { rootListener = callback; return () => {} },
    registerCommand(command, callback, priority) { commands.set(command, { callback, priority }); return () => {} },
    getEditorState() { return editorState(selection) },
    update(callback) {
      updates++
      if (deferUpdate) { deferUpdate(callback); return }
      inUpdate = true
      try { beforeUpdate?.(); callback() } finally { inUpdate = false }
    }
  })
  const handlers = new Map()
  const root = {
    addEventListener(type, callback, capture) { assert.equal(capture, true); handlers.set(type, callback) },
    removeEventListener(type) { handlers.delete(type) }
  }
  rootListener(root, null)
  return { transforms, listener, commands, rootListener, root, handlers, unregister,
    get updates() { return updates }, get inUpdate() { return inUpdate } }
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

function nodeSelection(selectedNodes) {
  return { type: "node", getNodes: () => selectedNodes }
}

test("one-shot browser insertText and insertReplacementText preview full URLs without a delimiter", () => {
  for (const inputType of ["insertText", "insertReplacementText"]) {
    const url = "https://example.test/a.gif?size=large#frame"
    const paragraph = new ElementNode("paragraph")
    paragraph.__key = `paragraph-${inputType}`
    const text = new TextNode(url, paragraph, false, 0, "", 0, `text-${inputType}`)
    nodes.set(text.getKey(), text)
    selection = rangeSelection({ key: text.getKey(), offset: url.length, type: "text" },
      { key: text.getKey(), offset: url.length, type: "text" })
    const extension = registerExtension()
    extension.handlers.get("beforeinput")({ inputType, data: url, isComposing: false })
    extension.listener({ dirtyLeaves: new Set([text.getKey()]), dirtyElements: new Map(),
      editorState: editorState(selection), prevEditorState: editorState(null) })
    assert.equal(text.parts[0] instanceof CommentImageNode, true)
    assert.equal(text.parts[0].getTextContent(), url)
    assert.deepEqual(selection.anchor, { key: paragraph.getKey(), offset: 1, type: "element" })
    nodes.delete(text.getKey())
    selection = null
  }
})

test("one-shot base URL before an existing continuation stays editable until the completed URL is delimited", () => {
  const base = "https://example.test/a.gif"
  for (const suffix of ["?size=large", "#frame", "/other"]) {
    const paragraph = new ElementNode("paragraph")
    paragraph.__key = `continuation-${suffix}`
    const text = new TextNode(`${base}${suffix}`, paragraph, false, 0, "", 0, `text-${suffix}`)
    nodes.set(text.getKey(), text)
    selection = rangeSelection({ key: text.getKey(), offset: base.length, type: "text" },
      { key: text.getKey(), offset: base.length, type: "text" })
    const extension = registerExtension()
    extension.handlers.get("beforeinput")({ inputType: "insertText", data: base })
    extension.listener({ dirtyLeaves: new Set([text.getKey()]), dirtyElements: new Map(),
      editorState: editorState(selection), prevEditorState: editorState(null) })
    assert.deepEqual(text.parts, [text], suffix)
    assert.equal(text.getTextContent(), `${base}${suffix}`)
    if (suffix === "?size=large") {
      text.text += " "
      previewText(text)
      assert.deepEqual(text.parts.map((part) => part.getTextContent()), [`${base}${suffix}`, " "])
      assert.equal(text.parts[0] instanceof CommentImageNode, true)
    }
    nodes.delete(text.getKey())
    selection = null
  }
})

test("one-shot complete URL preserves following punctuation and whitespace", () => {
  const url = "https://example.test/a.gif?size=large#frame"
  const paragraph = new ElementNode("paragraph")
  paragraph.__key = "suffix-paragraph"
  const text = new TextNode(`See ${url}), next`, paragraph, false, 0, "", 0, "suffix-text")
  nodes.set(text.getKey(), text)
  selection = rangeSelection({ key: text.getKey(), offset: `See ${url}`.length, type: "text" },
    { key: text.getKey(), offset: `See ${url}`.length, type: "text" })
  const extension = registerExtension()
  extension.handlers.get("beforeinput")({ inputType: "insertText", data: url })
  extension.listener({ dirtyLeaves: new Set([text.getKey()]), dirtyElements: new Map(),
    editorState: editorState(selection), prevEditorState: editorState(null) })
  assert.deepEqual(text.parts.map((part) => part.getTextContent()), ["See ", url, "), next"])
  assert.equal(text.parts[1] instanceof CommentImageNode, true)
  assert.deepEqual(selection.anchor, { key: text.parts[2].getKey(), offset: 0, type: "text" })
  nodes.delete(text.getKey())
  selection = null
})

test("one-shot URL embedded in another word is not converted", () => {
  const url = "https://example.test/a.gif"
  const text = new TextNode(`prefix${url}`, null, false, 0, "", 0, "embedded-text")
  nodes.set(text.getKey(), text)
  selection = rangeSelection({ key: text.getKey(), offset: text.text.length, type: "text" },
    { key: text.getKey(), offset: text.text.length, type: "text" })
  const extension = registerExtension()
  extension.handlers.get("beforeinput")({ inputType: "insertText", data: url })
  extension.listener({ dirtyLeaves: new Set([text.getKey()]), dirtyElements: new Map(),
    editorState: editorState(selection), prevEditorState: editorState(null) })
  assert.deepEqual(text.parts, [text])
  nodes.delete(text.getKey())
  selection = null
})

test("incremental typing, composing and non-image insertions do not preview unfinished URLs", () => {
  const node = new TextNode("", null, false, 0, "", 0, "typed-url")
  nodes.set(node.getKey(), node)
  const extension = registerExtension()
  const url = "https://example.test/a.png?size=large#frame"
  for (const char of url) {
    extension.handlers.get("beforeinput")({ inputType: "insertText", data: char })
    node.text += char
    selection = rangeSelection({ key: node.getKey(), offset: node.text.length, type: "text" },
      { key: node.getKey(), offset: node.text.length, type: "text" })
    extension.listener({ dirtyLeaves: new Set([node.getKey()]), dirtyElements: new Map(),
      editorState: editorState(selection), prevEditorState: editorState(null) })
    assert.deepEqual(node.parts, [node])
  }
  extension.handlers.get("beforeinput")({ inputType: "insertText", data: url, isComposing: true })
  extension.listener({ dirtyLeaves: new Set([node.getKey()]), dirtyElements: new Map(),
    editorState: editorState(selection), prevEditorState: editorState(null) })
  assert.deepEqual(node.parts, [node])
  assert.equal(extension.updates, 0)
  nodes.delete(node.getKey())
  selection = null
})

test("one-shot hint requires matching inserted text at the caret and excludes code", () => {
  const url = "https://example.test/a.png?size=large#frame"
  const node = new TextNode(`prefix ${url}`, null, false, 0, "", 0, "hint-text")
  nodes.set(node.getKey(), node)
  const extension = registerExtension()
  const update = () => extension.listener({ dirtyLeaves: new Set([node.getKey()]), dirtyElements: new Map(),
    editorState: editorState(selection), prevEditorState: editorState(null) })
  selection = rangeSelection({ key: node.getKey(), offset: node.text.length - 1, type: "text" },
    { key: node.getKey(), offset: node.text.length - 1, type: "text" })
  extension.handlers.get("beforeinput")({ inputType: "insertText", data: url })
  update()
  assert.deepEqual(node.parts, [node])
  selection = rangeSelection({ key: node.getKey(), offset: node.text.length, type: "text" },
    { key: node.getKey(), offset: node.text.length, type: "text" })
  extension.handlers.get("beforeinput")({ inputType: "insertFromPaste", data: url })
  update()
  assert.deepEqual(node.parts, [node])
  node.code = true
  extension.handlers.get("beforeinput")({ inputType: "insertText", data: url })
  update()
  assert.deepEqual(node.parts, [node])
  assert.equal(extension.updates, 0)
  extension.rootListener(null, extension.root)
  assert.equal(extension.handlers.has("beforeinput"), false)
  nodes.delete(node.getKey())
  selection = null
})

test("only a sole selected comment image is removed by Backspace or Delete", () => {
  const extension = registerExtension()
  for (const command of ["backspace", "delete"]) {
    const paragraph = new ElementNode("paragraph")
    paragraph.__key = `delete-${command}`
    const image = new CommentImageNode("https://example.test/a.gif", `image-${command}`)
    image.parent = paragraph
    image.index = 0
    nodes.set(image.getKey(), image)
    const handler = extension.commands.get(command)
    assert.equal(handler.priority, 3)
    selection = nodeSelection([image])
    let prevented = false
    assert.equal(handler.callback({ preventDefault() { prevented = true } }), true)
    assert.equal(prevented, true)
    assert.equal(image.removed, true)
    assert.deepEqual(selection.anchor, { key: paragraph.getKey(), offset: 0, type: "element" })
    assert.equal(nodes.has(image.getKey()), false)
  }
  const other = new DecoratorNode("other")
  const image = new CommentImageNode("https://example.test/a.gif", "untouched")
  for (const selected of [nodeSelection([other]), nodeSelection([image, other]),
    rangeSelection({ key: "text", offset: 0 }, { key: "text", offset: 0 })]) {
    selection = selected
    assert.equal(extension.commands.get("backspace").callback(), false)
    assert.equal(extension.commands.get("delete").callback(), false)
    assert.equal(selection, selected)
  }
  selection = null
})

test("mobile beforeinput deletes only a selected comment image and restores the preceding caret", () => {
  const extension = registerExtension()
  for (const inputType of ["deleteContentBackward", "deleteContentForward"]) {
    const paragraph = new ElementNode("paragraph")
    paragraph.__key = `mobile-${inputType}`
    const image = new CommentImageNode("https://example.test/a.gif", `mobile-image-${inputType}`)
    image.parent = paragraph
    image.index = 0
    const remove = image.remove.bind(image)
    image.remove = () => { assert.equal(extension.inUpdate, true); remove() }
    nodes.set(image.getKey(), image)
    selection = nodeSelection([image])
    let prevented = 0
    extension.handlers.get("beforeinput")({ inputType, preventDefault() { prevented++ } })
    assert.equal(prevented, 1)
    assert.equal(image.removed, true)
    assert.equal(nodes.has(image.getKey()), false)
    assert.deepEqual(selection.anchor, { key: paragraph.getKey(), offset: 0, type: "element" })
  }
  assert.equal(extension.updates, 2)
  selection = null
})

test("a parent element range selecting one image deletes it on beforeinput and keydown", () => {
  for (const [eventType, direction] of [
    ["beforeinput", "deleteContentBackward"], ["beforeinput", "deleteContentForward"],
    ["keydown", "Backspace"], ["keydown", "Delete"]
  ]) {
    const paragraph = new ElementNode("paragraph")
    paragraph.__key = "21"
    const image = new CommentImageNode("https://example.test/a.gif", "25")
    image.parent = paragraph
    image.index = 0
    paragraph.children = [image]
    nodes.set(paragraph.getKey(), paragraph)
    nodes.set(image.getKey(), image)
    selection = rangeSelection(
      { key: "21", offset: 0, type: "element" },
      { key: "21", offset: 1, type: "element" },
      [image]
    )
    const extension = registerExtension()
    const calls = []
    extension.handlers.get(eventType)({
      [eventType === "keydown" ? "key" : "inputType"]: direction,
      preventDefault() { calls.push("prevent") },
      stopImmediatePropagation() { calls.push("stop") }
    })
    assert.deepEqual(calls, ["prevent", "stop"], `${eventType} ${direction}`)
    assert.equal(image.removed, true)
    assert.deepEqual(selection.anchor, { key: "21", offset: 0, type: "element" })
    nodes.delete(paragraph.getKey())
    selection = null
  }
})

test("expanded ranges with text or another decorator leave the image untouched", () => {
  for (const otherType of ["text", "decorator"]) {
    for (const eventType of ["beforeinput", "keydown"]) {
      const paragraph = new ElementNode("paragraph")
      paragraph.__key = `expanded-${otherType}-${eventType}`
      const image = new CommentImageNode("https://example.test/a.gif", `expanded-image-${otherType}-${eventType}`)
      const other = otherType === "text" ? new TextNode("words", paragraph) : new DecoratorNode("other")
      image.parent = paragraph
      image.index = 0
      other.parent = paragraph
      paragraph.children = [image, other]
      nodes.set(paragraph.getKey(), paragraph)
      nodes.set(image.getKey(), image)
      selection = rangeSelection(
        { key: paragraph.getKey(), offset: 0, type: "element" },
        { key: paragraph.getKey(), offset: 2, type: "element" },
        [image, other]
      )
      const current = selection
      const extension = registerExtension()
      const calls = []
      extension.handlers.get(eventType)({
        [eventType === "keydown" ? "key" : "inputType"]: eventType === "keydown" ? "Backspace" : "deleteContentBackward",
        preventDefault() { calls.push("prevent") },
        stopImmediatePropagation() { calls.push("stop") }
      })
      assert.deepEqual(calls, [], `${otherType} ${eventType}`)
      assert.equal(selection, current)
      assert.equal(image.removed, undefined)
      assert.equal(extension.updates, 0)
      nodes.delete(paragraph.getKey())
      nodes.delete(image.getKey())
      selection = null
    }
  }
})

test("beforeinput removes the captured preview when selection disappears before update", () => {
  const paragraph = new ElementNode("paragraph")
  paragraph.__key = "stale-selection-paragraph"
  const image = new CommentImageNode("https://example.test/a.gif", "stale-selection-image")
  const other = new CommentImageNode("https://example.test/b.gif", "other-selection-image")
  const extension = registerExtension({ beforeUpdate() { selection = null } })
  image.parent = paragraph
  image.index = 0
  other.parent = paragraph
  other.index = 1
  nodes.set(image.getKey(), image)
  nodes.set(other.getKey(), other)
  selection = nodeSelection([image])
  const calls = []
  extension.handlers.get("beforeinput")({
    inputType: "deleteContentBackward",
    preventDefault() { calls.push("prevent") },
    stopImmediatePropagation() { calls.push("stop") }
  })
  assert.deepEqual(calls, ["prevent", "stop"])
  assert.equal(image.removed, true)
  assert.equal(other.removed, undefined)
  assert.equal(nodes.has(image.getKey()), false)
  assert.deepEqual(selection.anchor, { key: paragraph.getKey(), offset: 0, type: "element" })
  nodes.delete(other.getKey())
  selection = null
})

test("keydown removes the captured adjacent preview when selection disappears before update", () => {
  const paragraph = new ElementNode("paragraph")
  paragraph.__key = "stale-adjacent-paragraph"
  const image = new CommentImageNode("https://example.test/a.gif", "stale-adjacent-image")
  image.parent = paragraph
  image.index = 0
  paragraph.children = [image]
  nodes.set(paragraph.getKey(), paragraph)
  nodes.set(image.getKey(), image)
  const extension = registerExtension({ beforeUpdate() { selection = null } })
  const point = { key: paragraph.getKey(), offset: 1, type: "element" }
  selection = rangeSelection(point, point)
  const calls = []
  extension.handlers.get("keydown")({
    key: "Backspace", preventDefault() { calls.push("prevent") },
    stopImmediatePropagation() { calls.push("stop") }
  })
  assert.deepEqual(calls, ["prevent", "stop"])
  assert.deepEqual(selection.anchor, { key: paragraph.getKey(), offset: 0, type: "element" })
  assert.equal(image.removed, true)
  nodes.delete(paragraph.getKey())
  selection = null
})

test("beforeinput leaves the captured preview alone when another preview becomes selected", () => {
  const paragraph = new ElementNode("paragraph")
  paragraph.__key = "switched-selected-paragraph"
  const image = new CommentImageNode("https://example.test/a.gif", "switched-selected-image")
  const other = new CommentImageNode("https://example.test/b.gif", "switched-selected-other")
  for (const [index, preview] of [image, other].entries()) {
    preview.parent = paragraph
    preview.index = index
    nodes.set(preview.getKey(), preview)
  }
  const current = nodeSelection([other])
  const extension = registerExtension({ beforeUpdate() { selection = current } })
  selection = nodeSelection([image])
  const calls = []
  extension.handlers.get("beforeinput")({
    inputType: "deleteContentBackward",
    preventDefault() { calls.push("prevent") },
    stopImmediatePropagation() { calls.push("stop") }
  })
  assert.deepEqual(calls, [])
  assert.equal(selection, current)
  assert.equal(image.removed, undefined)
  assert.equal(other.removed, undefined)
  nodes.delete(image.getKey())
  nodes.delete(other.getKey())
  selection = null
})

test("a non-adjacent text caret in the update leaves the captured preview alone", () => {
  for (const eventType of ["beforeinput", "keydown"]) {
    const paragraph = new ElementNode("paragraph")
    paragraph.__key = `moved-caret-${eventType}`
    const image = new CommentImageNode("https://example.test/a.gif", `moved-image-${eventType}`)
    const text = new TextNode("other text", paragraph, false, 0, "", 0, `moved-text-${eventType}`)
    image.parent = paragraph
    image.index = 0
    paragraph.children = [image, text]
    for (const node of [paragraph, image, text]) nodes.set(node.getKey(), node)
    const point = { key: text.getKey(), offset: 5, type: "text" }
    const current = rangeSelection(point, point)
    const extension = registerExtension({ beforeUpdate() { selection = current } })
    selection = nodeSelection([image])
    const calls = []
    extension.handlers.get(eventType)(eventType === "keydown"
      ? { key: "Backspace", preventDefault() { calls.push("prevent") }, stopImmediatePropagation() { calls.push("stop") } }
      : { inputType: "deleteContentBackward", preventDefault() { calls.push("prevent") }, stopImmediatePropagation() { calls.push("stop") } })
    assert.deepEqual(calls, [], eventType)
    assert.equal(selection, current)
    assert.equal(image.removed, undefined)
    assert.equal(nodes.get(image.getKey()), image)
    for (const node of [paragraph, image, text]) nodes.delete(node.getKey())
  }
  selection = null
})

test("keydown leaves the captured preview alone when another preview becomes adjacent", () => {
  const paragraph = new ElementNode("paragraph")
  paragraph.__key = "switched-adjacent-paragraph"
  const image = new CommentImageNode("https://example.test/a.gif", "switched-adjacent-image")
  const other = new CommentImageNode("https://example.test/b.gif", "switched-adjacent-other")
  paragraph.children = [image, other]
  for (const [index, preview] of paragraph.children.entries()) {
    preview.parent = paragraph
    preview.index = index
    nodes.set(preview.getKey(), preview)
  }
  nodes.set(paragraph.getKey(), paragraph)
  const point = (offset) => rangeSelection(
    { key: paragraph.getKey(), offset, type: "element" },
    { key: paragraph.getKey(), offset, type: "element" }
  )
  const current = point(2)
  const extension = registerExtension({ beforeUpdate() { selection = current } })
  selection = point(1)
  const calls = []
  extension.handlers.get("keydown")({
    key: "Backspace",
    preventDefault() { calls.push("prevent") },
    stopImmediatePropagation() { calls.push("stop") }
  })
  assert.deepEqual(calls, [])
  assert.equal(selection, current)
  assert.equal(image.removed, undefined)
  assert.equal(other.removed, undefined)
  for (const preview of [image, other]) nodes.delete(preview.getKey())
  nodes.delete(paragraph.getKey())
  selection = null
})

test("beforeinput removes the same selected preview inside the discrete update", () => {
  const paragraph = new ElementNode("paragraph")
  paragraph.__key = "same-selection-paragraph"
  const image = new CommentImageNode("https://example.test/a.gif", "same-selection-image")
  image.parent = paragraph
  image.index = 0
  nodes.set(image.getKey(), image)
  const current = nodeSelection([image])
  const extension = registerExtension({ beforeUpdate() { selection = current } })
  selection = current
  const calls = []
  extension.handlers.get("beforeinput")({
    inputType: "deleteContentBackward", preventDefault() { calls.push("prevent") },
    stopImmediatePropagation() { calls.push("stop") }
  })
  assert.deepEqual(calls, ["prevent", "stop"])
  assert.equal(image.removed, true)
  assert.deepEqual(selection.anchor, { key: paragraph.getKey(), offset: 0, type: "element" })
  selection = null
})

test("a deferred update neither swallows deletion nor removes the preview later", () => {
  let queued
  const extension = registerExtension({ deferUpdate(callback) { queued = callback } })
  const paragraph = new ElementNode("paragraph")
  paragraph.__key = "deferred-paragraph"
  const image = new CommentImageNode("https://example.test/a.gif", "deferred-image")
  image.parent = paragraph
  image.index = 0
  nodes.set(image.getKey(), image)
  selection = nodeSelection([image])
  const calls = []
  extension.handlers.get("beforeinput")({
    inputType: "deleteContentBackward", preventDefault() { calls.push("prevent") },
    stopImmediatePropagation() { calls.push("stop") }
  })
  assert.deepEqual(calls, [])
  queued()
  assert.equal(image.removed, undefined)
  nodes.delete(image.getKey())
  selection = null
})

test("beforeinput does not swallow deletion when its preview is gone before the update", () => {
  const image = new CommentImageNode("https://example.test/a.gif", "vanished-image")
  nodes.set(image.getKey(), image)
  const extension = registerExtension({ beforeUpdate() { nodes.delete(image.getKey()) } })
  selection = nodeSelection([image])
  let prevented = false
  extension.handlers.get("beforeinput")({
    inputType: "deleteContentBackward", preventDefault() { prevented = true }
  })
  assert.equal(prevented, false)
  assert.equal(image.removed, undefined)
  selection = null
})

test("beforeinput does not swallow deletion when its preview detaches before the update", () => {
  const paragraph = new ElementNode("paragraph")
  paragraph.__key = "detached-paragraph"
  const image = new CommentImageNode("https://example.test/a.gif", "detached-image")
  image.parent = paragraph
  image.index = 0
  nodes.set(image.getKey(), image)
  const extension = registerExtension({ beforeUpdate() { image.parent = null; selection = null } })
  selection = nodeSelection([image])
  let prevented = false
  extension.handlers.get("beforeinput")({
    inputType: "deleteContentBackward", preventDefault() { prevented = true }
  })
  assert.equal(prevented, false)
  assert.equal(image.removed, undefined)
  assert.equal(nodes.has(image.getKey()), true)
  nodes.delete(image.getKey())
  selection = null
})

test("root keydown falls back to stopPropagation when immediate stopping is unavailable", () => {
  const extension = registerExtension()
  const paragraph = new ElementNode("paragraph")
  paragraph.__key = "fallback-paragraph"
  const image = new CommentImageNode("https://example.test/a.gif", "fallback-image")
  image.parent = paragraph
  image.index = 0
  nodes.set(image.getKey(), image)
  selection = nodeSelection([image])
  const calls = []
  extension.handlers.get("keydown")({
    key: "Backspace",
    preventDefault() { calls.push("preventDefault") },
    stopPropagation() { calls.push("stopPropagation") }
  })
  assert.deepEqual(calls, ["preventDefault", "stopPropagation"])
  assert.equal(image.removed, true)
  selection = null
})

test("mobile beforeinput leaves text and other selected decorators to Lexxy", () => {
  const extension = registerExtension()
  const image = new CommentImageNode("https://example.test/a.gif", "mixed-image")
  const other = new DecoratorNode("other")
  const text = rangeSelection({ key: "text", offset: 1, type: "text" },
    { key: "text", offset: 1, type: "text" })
  for (const selected of [text, nodeSelection([other]), nodeSelection([image, other]), null]) {
    selection = selected
    for (const inputType of ["deleteContentBackward", "deleteContentForward"]) {
      let prevented = false
      extension.handlers.get("beforeinput")({ inputType, preventDefault() { prevented = true } })
      assert.equal(prevented, false)
      assert.equal(selection, selected)
    }
  }
  assert.equal(extension.updates, 0)
  assert.equal(image.removed, undefined)
  selection = null
})

test("root keydown leaves an unresolved caret alone", () => {
  const extension = registerExtension()
  const caret = rangeSelection({ key: "paragraph", offset: 1, type: "element" },
    { key: "paragraph", offset: 1, type: "element" })
  selection = caret
  let intercepted = false
  extension.handlers.get("keydown")({
    key: "Backspace",
    preventDefault() { intercepted = true },
    stopImmediatePropagation() { intercepted = true }
  })
  assert.equal(intercepted, false)
  assert.equal(selection, caret)
  assert.equal(extension.updates, 0)
  selection = null
})

test("root keydown removes a sole selected image on Backspace or Delete", () => {
  const extension = registerExtension()
  for (const key of ["Backspace", "Delete"]) {
    const paragraph = new ElementNode("paragraph")
    paragraph.__key = `keydown-${key}`
    const image = new CommentImageNode("https://example.test/a.gif", `keydown-image-${key}`)
    image.parent = paragraph
    image.index = 0
    const remove = image.remove.bind(image)
    image.remove = () => { assert.equal(extension.inUpdate, true); remove() }
    nodes.set(image.getKey(), image)
    selection = nodeSelection([image])
    const calls = []
    extension.handlers.get("keydown")({
      key,
      preventDefault() { calls.push("preventDefault") },
      stopImmediatePropagation() { calls.push("stopImmediatePropagation") },
      stopPropagation() { calls.push("stopPropagation") }
    })
    assert.deepEqual(calls, ["preventDefault", "stopImmediatePropagation"])
    assert.equal(image.removed, true)
    assert.equal(nodes.has(image.getKey()), false)
    assert.deepEqual(selection.anchor, { key: paragraph.getKey(), offset: 0, type: "element" })
    let duplicate = false
    extension.handlers.get("beforeinput")({
      inputType: key === "Backspace" ? "deleteContentBackward" : "deleteContentForward",
      preventDefault() { duplicate = true }
    })
    assert.equal(duplicate, true)
  }
  assert.equal(extension.updates, 2)
  selection = null
})

test("adjacent element and text carets delete an image in one keydown or beforeinput", () => {
  for (const [direction, inputType, pointType] of [
    ["Backspace", "deleteContentBackward", "element"],
    ["Delete", "deleteContentForward", "element"],
    ["Backspace", "deleteContentBackward", "text"],
    ["Delete", "deleteContentForward", "text"]
  ]) {
    const extension = registerExtension()
    const paragraph = new ElementNode("paragraph")
    paragraph.__key = `adjacent-${direction}-${pointType}`
    const image = new CommentImageNode("https://example.test/a.gif", `image-${direction}-${pointType}`)
    const text = new TextNode("text", paragraph, false, 0, "", 0, `text-${direction}-${pointType}`)
    paragraph.children = direction === "Backspace" ? [image, text] : [text, image]
    image.parent = paragraph
    image.index = paragraph.children.indexOf(image)
    nodes.set(paragraph.getKey(), paragraph)
    nodes.set(image.getKey(), image)
    nodes.set(text.getKey(), text)
    const point = pointType === "element"
      ? { key: paragraph.getKey(), offset: 1, type: "element" }
      : { key: text.getKey(), offset: direction === "Backspace" ? 0 : text.text.length, type: "text" }
    for (const eventType of ["beforeinput", "keydown"]) {
      selection = rangeSelection(point, point)
      image.removed = false
      nodes.set(image.getKey(), image)
      const calls = []
      extension.handlers.get(eventType)({
        key: direction, inputType,
        preventDefault() { calls.push("prevent") },
        stopImmediatePropagation() { calls.push("stop") }
      })
      assert.deepEqual(calls, ["prevent", "stop"])
      assert.equal(image.removed, true)
      assert.deepEqual(selection.anchor, { key: paragraph.getKey(), offset: image.index, type: "element" })
    }
    assert.equal(extension.updates, 2)
    for (const node of [paragraph, image, text]) nodes.delete(node.getKey())
  }
  selection = null
})

test("text characters, other decorators, and expanded ranges are left to Lexxy", () => {
  const extension = registerExtension()
  const paragraph = new ElementNode("paragraph")
  paragraph.__key = "guard-paragraph"
  const image = new CommentImageNode("https://example.test/a.gif", "guard-image")
  const other = new DecoratorNode("guard-other")
  const text = new TextNode("ab", paragraph, false, 0, "", 0, "guard-text")
  paragraph.children = [image, other, text, image]
  nodes.set(paragraph.getKey(), paragraph)
  nodes.set(text.getKey(), text)
  const points = [
    { key: text.getKey(), offset: 1, type: "text" },
    { key: text.getKey(), offset: 0, type: "text" },
    { key: paragraph.getKey(), offset: 2, type: "element" }
  ]
  for (const point of points) {
    selection = rangeSelection(point, point)
    for (const [key, inputType] of [["Backspace", "deleteContentBackward"], ["Delete", "deleteContentForward"]]) {
      let intercepted = false
      extension.handlers.get("keydown")({ key, preventDefault() { intercepted = true } })
      extension.handlers.get("beforeinput")({ inputType, preventDefault() { intercepted = true } })
      assert.equal(intercepted, false)
    }
  }
  selection = rangeSelection(points[0], points[1])
  assert.equal(extension.commands.get("backspace").callback(), false)
  assert.equal(extension.updates, 0)
  assert.equal(image.removed, undefined)
  nodes.delete(paragraph.getKey())
  nodes.delete(text.getKey())
  selection = null
})

test("keydown and following beforeinput do not delete consecutive images twice", () => {
  const extension = registerExtension()
  const paragraph = new ElementNode("paragraph")
  paragraph.__key = "consecutive-paragraph"
  const first = new CommentImageNode("https://example.test/one.gif", "first-image")
  const second = new CommentImageNode("https://example.test/two.gif", "second-image")
  paragraph.children = [first, second]
  for (const [index, image] of paragraph.children.entries()) {
    image.parent = paragraph
    image.index = index
    nodes.set(image.getKey(), image)
  }
  nodes.set(paragraph.getKey(), paragraph)
  const point = { key: paragraph.getKey(), offset: 2, type: "element" }
  selection = rangeSelection(point, point)
  extension.handlers.get("keydown")({ key: "Backspace", preventDefault() {}, stopPropagation() {} })
  let prevented = false
  extension.handlers.get("beforeinput")({
    inputType: "deleteContentBackward", preventDefault() { prevented = true }, stopPropagation() {}
  })
  assert.equal(prevented, true)
  assert.equal(second.removed, true)
  assert.equal(first.removed, undefined)
  assert.equal(extension.updates, 1)
  nodes.delete(first.getKey())
  nodes.delete(paragraph.getKey())
  selection = null
})

test("standalone beforeinput after a handled keydown removes the next adjacent image", async () => {
  for (const [key, inputType, offset] of [
    ["Backspace", "deleteContentBackward", 2],
    ["Delete", "deleteContentForward", 0]
  ]) {
    const extension = registerExtension()
    const paragraph = new ElementNode("paragraph")
    paragraph.__key = `later-${key}`
    const images = [0, 1].map((index) => new CommentImageNode("https://example.test/a.gif", `later-${key}-${index}`))
    paragraph.children = images
    for (const [index, image] of images.entries()) {
      image.parent = paragraph
      image.index = index
      nodes.set(image.getKey(), image)
    }
    nodes.set(paragraph.getKey(), paragraph)
    const point = { key: paragraph.getKey(), offset, type: "element" }
    selection = rangeSelection(point, point)
    extension.handlers.get("keydown")({ key, preventDefault() {}, stopPropagation() {} })
    assert.equal(images[key === "Backspace" ? 1 : 0].removed, true)
    // preventDefault can suppress beforeinput entirely; the next event is a new task.
    await new Promise((resolve) => setTimeout(resolve, 0))
    const next = images[key === "Backspace" ? 0 : 1]
    paragraph.children = [next]
    next.index = 0
    const nextPoint = { key: paragraph.getKey(), offset: key === "Backspace" ? 1 : 0, type: "element" }
    selection = rangeSelection(nextPoint, nextPoint)
    let prevented = false
    extension.handlers.get("beforeinput")({
      inputType, preventDefault() { prevented = true }, stopPropagation() {}
    })
    assert.equal(prevented, true)
    assert.equal(next.removed, true)
    assert.equal(extension.updates, 2)
    nodes.delete(paragraph.getKey())
  }
  selection = null
})

test("composing and modified beforeinput leave adjacent image alone", () => {
  const extension = registerExtension()
  const paragraph = new ElementNode("paragraph")
  paragraph.__key = "modified-paragraph"
  const image = new CommentImageNode("https://example.test/a.gif", "modified-image")
  paragraph.children = [image]
  nodes.set(paragraph.getKey(), paragraph)
  selection = rangeSelection({ key: paragraph.getKey(), offset: 1, type: "element" },
    { key: paragraph.getKey(), offset: 1, type: "element" })
  for (const flag of ["isComposing", "metaKey", "ctrlKey", "altKey"]) {
    let prevented = false
    extension.handlers.get("beforeinput")({
      inputType: "deleteContentBackward", [flag]: true,
      preventDefault() { prevented = true }
    })
    assert.equal(prevented, false)
  }
  assert.equal(extension.updates, 0)
  nodes.delete(paragraph.getKey())
  selection = null
})

test("root keydown leaves modified, composing and non-image selections untouched", () => {
  const extension = registerExtension()
  const image = new CommentImageNode("https://example.test/a.gif", "keydown-untouched")
  const other = new DecoratorNode("other")
  const events = [
    { key: "Backspace", metaKey: true },
    { key: "Delete", ctrlKey: true },
    { key: "Backspace", altKey: true },
    { key: "Delete", isComposing: true },
    { key: "Enter" }
  ]
  let intercepted = false
  for (const event of events) {
    selection = nodeSelection([image])
    extension.handlers.get("keydown")({
      ...event,
      preventDefault() { intercepted = true },
      stopImmediatePropagation() { intercepted = true }
    })
  }
  for (const selected of [nodeSelection([other]), nodeSelection([image, other]), null]) {
    selection = selected
    extension.handlers.get("keydown")({
      key: "Backspace",
      preventDefault() { intercepted = true },
      stopImmediatePropagation() { intercepted = true }
    })
    assert.equal(selection, selected)
  }
  assert.equal(intercepted, false)
  assert.equal(extension.updates, 0)
  assert.equal(image.removed, undefined)
  selection = null
})

test("beforeinput after handled Backspace does not remove an image twice", () => {
  const extension = registerExtension()
  const paragraph = new ElementNode("paragraph")
  paragraph.__key = "handled-paragraph"
  const image = new CommentImageNode("https://example.test/a.gif", "handled-image")
  image.parent = paragraph
  image.index = 0
  nodes.set(image.getKey(), image)
  selection = nodeSelection([image])
  extension.commands.get("backspace").callback({ preventDefault() {} })
  let prevented = false
  extension.handlers.get("beforeinput")({ inputType: "deleteContentBackward", preventDefault() { prevented = true } })
  assert.equal(prevented, false)
  assert.equal(extension.updates, 0)
  assert.equal(image.removed, true)
  selection = null
})

test("root deletion listeners follow root replacement and detachment", () => {
  const extension = registerExtension()
  const handlers = new Map()
  const nextRoot = {
    addEventListener(type, callback, capture) { assert.equal(capture, true); handlers.set(type, callback) },
    removeEventListener(type) { handlers.delete(type) }
  }
  extension.rootListener(nextRoot, extension.root)
  assert.equal(extension.handlers.has("beforeinput"), false)
  assert.equal(extension.handlers.has("keydown"), false)
  assert.equal(typeof handlers.get("beforeinput"), "function")
  assert.equal(typeof handlers.get("keydown"), "function")
  extension.rootListener(null, nextRoot)
  assert.equal(handlers.has("beforeinput"), false)
  assert.equal(handlers.has("keydown"), false)
  assert.equal(extension.updates, 0)
})

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
  let roots = 0
  let commands = 0
  const config = extension.lexicalExtension
  assert.deepEqual(Array.from(config.nodes), [CommentImageNode])
  const unregister = config.register({
    registerNodeTransform(type, transform) {
      assert.equal(type, TextNode, "abstract ElementNode cannot register a Lexical transform")
      registered.push([type, transform])
      return () => { unregistered++ }
    },
    registerUpdateListener() { listeners++; return () => { unregistered++ } },
    registerRootListener() { roots++; return () => { unregistered++ } },
    registerCommand() { commands++; return () => { unregistered++ } }
  })
  assert.deepEqual(registered, [[TextNode, previewText]])
  assert.equal(listeners, 1)
  assert.equal(roots, 1)
  assert.equal(commands, 2)
  unregister()
  assert.equal(unregistered, 5)
})
