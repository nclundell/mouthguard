import { Extension, Lexical } from "lexxy"

const { $getNodeByKey, $getSelection, $isRangeSelection, $isTextNode, DecoratorNode, ElementNode, TextNode } = Lexical
const rawUrl = /(?<![^\s(\[{"',.!?;)\]}])https:\/\/(?:(?![,.!?;)\]}]https:\/\/)[^\s<>"'])+/gi
const trailingPunctuation = /[.,!?;:)\]}]+$/
const imagePath = /\.(?:gif|png|jpe?g|webp)$/i

export function imageMatches(text) {
  const matches = []
  for (const match of text.matchAll(rawUrl)) {
    const url = match[0].replace(trailingPunctuation, "")
    try {
      const parsed = new URL(url)
      if (parsed.protocol === "https:" && parsed.hostname && !parsed.username && !parsed.password && imagePath.test(parsed.pathname)) {
        matches.push({ index: match.index, url })
      }
    } catch {
      // Ignore invalid links.
    }
  }
  return matches
}

export class CommentImageNode extends DecoratorNode {
  static getType() { return "comment_image_preview" }
  static clone(node) { return new CommentImageNode(node.url, node.__key) }
  static importJSON(node) { return new CommentImageNode(node.url) }

  constructor(url, key) {
    super(key)
    this.url = url
  }

  createDOM() {
    const image = document.createElement("img")
    image.src = this.url
    image.alt = new URL(this.url).pathname.split("/").pop()
    image.loading = "lazy"
    image.referrerPolicy = "no-referrer"
    image.className = "comment-attachment-image"
    image.style.maxHeight = "8rem"
    return image
  }

  updateDOM(previous) { return previous.url !== this.url }
  decorate() { return null }
  isInline() { return true }
  isKeyboardSelectable() { return true }
  getTextContent() { return this.url }
  exportDOM() { return { element: document.createTextNode(this.url) } }
  exportJSON() { return { type: "comment_image_preview", version: 1, url: this.url } }
}

function inCode(node) {
  if (typeof node.hasFormat === "function" && node.hasFormat("code")) return true
  for (let parent = node.getParent(); parent; parent = parent.getParent()) {
    if (parent.getType() === "code") return true
  }
  return false
}

export function previewText(node) {
  if (!$isTextNode(node) || !node.isSimpleText() || inCode(node)) return
  for (let parent = node.getParent(); parent; parent = parent.getParent()) {
    if (parent.getType() === "link" || parent.getType() === "autolink") return
  }
  const text = node.getTextContent()
  // A URL at the end of editable text may still acquire a query or fragment.
  const matches = imageMatches(text).filter(({ index, url }) => {
    const suffix = text.slice(index + url.length)
    return /^[.,!?;:)\]}]*\s/.test(suffix)
  })
  if (!matches.length) return

  let remaining = node
  let offset = 0
  for (const { index, url } of matches) {
    if (index < offset) continue
    const start = index - offset
    const parts = remaining.splitText(start, start + url.length)
    parts[start === 0 ? 0 : 1].replace(new CommentImageNode(url))
    remaining = parts.at(-1)
    offset = index + url.length
  }
}

function eligibleLink(node) {
  if (!(node instanceof ElementNode) || !["link", "autolink"].includes(node.getType()) || inCode(node)) return false
  const url = node.getURL()
  return typeof url === "string" && node.getTextContent() === url &&
    imageMatches(url).some((match) => match.index === 0 && match.url === url)
}

export function previewLink(node) {
  if (eligibleLink(node)) {
    const url = node.getURL()
    const selection = $getSelection()
    const isInLink = (selectedNode) => {
      for (let current = selectedNode; current; current = current.getParent()) {
        if (current.is(node)) return true
      }
      return false
    }
    if ($isRangeSelection(selection) && !selection.isCollapsed() && selection.getNodes().some(isInLink)) return
    const caretInLink = $isRangeSelection(selection) && selection.isCollapsed() &&
      isInLink($getNodeByKey(selection.anchor.key))
    const preview = new CommentImageNode(url)
    node.replace(preview)
    if (caretInLink) {
      // Lexical selects the next text at offset 0, or the parent's end if there is none.
      preview.selectNext(0, 0)
    }
  }
}

export default class CommentImagePreviewExtension extends Extension {
  get enabled() {
    return this.editorElement.matches("lexxy-editor.comment-composer[name='comment[body]']")
  }

  get lexicalExtension() {
    return this.defineExtension({
      name: "mouthguard/comment-image-preview",
      nodes: [CommentImageNode],
      register(editor) {
        const unregisterText = editor.registerNodeTransform(TextNode, previewText)
        // LinkNode and AutoLinkNode are not exposed here; ElementNode cannot
        // register a transform because Lexical treats it as an abstract node.
        const unregisterElements = editor.registerUpdateListener(({ dirtyElements, editorState, prevEditorState }) => {
          let caretLinkKey
          if (!dirtyElements.size && editorState && prevEditorState) {
            const previous = prevEditorState.read(() => $getSelection())
            caretLinkKey = editorState.read(() => {
              const current = $getSelection()
              if (!$isRangeSelection(current) || !current.isCollapsed()) return
              if ($isRangeSelection(previous) && previous.isCollapsed() &&
                  previous.anchor.key === current.anchor.key &&
                  previous.anchor.offset === current.anchor.offset &&
                  previous.anchor.type === current.anchor.type) return
              for (let node = $getNodeByKey(current.anchor.key); node; node = node.getParent()) {
                if (eligibleLink(node)) return node.getKey()
              }
            })
          }
          if (!dirtyElements.size && !caretLinkKey) return
          editor.update(() => {
            if (caretLinkKey) previewLink($getNodeByKey(caretLinkKey))
            for (const key of dirtyElements.keys()) {
              const node = $getNodeByKey(key)
              if (node) previewLink(node)
            }
          })
        })
        return () => {
          unregisterText()
          unregisterElements()
        }
      }
    })
  }
}
