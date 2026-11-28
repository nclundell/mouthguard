import { Extension, Lexical } from "lexxy"

const {
  $getNodeByKey, $getSelection, $isNodeSelection, $isRangeSelection, $isTextNode,
  COMMAND_PRIORITY_HIGH, DecoratorNode, ElementNode, KEY_BACKSPACE_COMMAND,
  KEY_DELETE_COMMAND, TextNode
} = Lexical
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

function previewInsertedUrl(url, dirtyLeaves) {
  const selection = $getSelection()
  if (!$isRangeSelection(selection) || !selection.isCollapsed() || selection.anchor.type !== "text") return
  const { key, offset } = selection.anchor
  if (!dirtyLeaves.has(key)) return
  const node = $getNodeByKey(key)
  if (!$isTextNode(node) || !node.isSimpleText() || inCode(node)) return
  for (let parent = node.getParent(); parent; parent = parent.getParent()) {
    if (parent.getType() === "link" || parent.getType() === "autolink") return
  }
  const start = offset - url.length
  const text = node.getTextContent()
  if (start < 0 || text.slice(start, offset) !== url ||
      !imageMatches(text).some((match) => match.index === start && match.url === url)) return
  const parts = node.splitText(start, offset)
  const preview = new CommentImageNode(url)
  parts[start === 0 ? 0 : 1].replace(preview)
  preview.selectNext(0, 0)
}

function selectedPreview() {
  const selection = $getSelection()
  if (!$isNodeSelection(selection) && !($isRangeSelection(selection) && !selection.isCollapsed())) return
  const selected = selection.getNodes()
  if (selected.length === 1 && selected[0] instanceof CommentImageNode) return selected[0]
}

function adjacentPreview(backward) {
  const selection = $getSelection()
  if (!$isRangeSelection(selection) || !selection.isCollapsed()) return
  const { key, offset, type } = selection.anchor
  const node = $getNodeByKey(key)
  if (type === "element" && node instanceof ElementNode) {
    const neighbor = node.getChildAtIndex(backward ? offset - 1 : offset)
    if (neighbor instanceof CommentImageNode) return neighbor
  }
  if (type === "text" && $isTextNode(node) &&
      offset === (backward ? 0 : node.getTextContent().length)) {
    const neighbor = backward ? node.getPreviousSibling() : node.getNextSibling()
    if (neighbor instanceof CommentImageNode) return neighbor
  }
}

function removeNode(preview) {
  if (!(preview instanceof CommentImageNode) ||
      preview.getType() !== CommentImageNode.getType() || !preview.isAttached()) return false
  const index = preview.getIndexWithinParent()
  preview.getParent().select(index, index)
  preview.remove()
  return true
}

function removePreview(backward, event) {
  if (!removeNode(selectedPreview() || adjacentPreview(backward))) return false
  event?.preventDefault()
  return true
}

function removePreviewAtKey(editor, key, backward) {
  let removed = false
  let synchronous = true
  editor.update(() => {
    if (!synchronous) return
    const selection = $getSelection()
    const current = selectedPreview() || adjacentPreview(backward)
    if (selection !== null && current?.getKey() !== key) return
    removed = removeNode($getNodeByKey(key))
  }, { discrete: true })
  synchronous = false
  return removed
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
        let insertedUrl
        let handledKeyDirection
        let handledKeyGeneration = 0
        const onBeforeInput = (event) => {
          insertedUrl = undefined
          if (["deleteContentBackward", "deleteContentForward"].includes(event.inputType)) {
            if (event.isComposing || event.metaKey || event.ctrlKey || event.altKey) return
            const backward = event.inputType === "deleteContentBackward"
            if (handledKeyDirection === event.inputType) {
              handledKeyDirection = undefined
              event.preventDefault()
              if (event.stopImmediatePropagation) event.stopImmediatePropagation()
              else event.stopPropagation?.()
              return
            }
            handledKeyDirection = undefined
            const key = editor.getEditorState().read(() => (selectedPreview() || adjacentPreview(backward))?.getKey())
            if (key && removePreviewAtKey(editor, key, backward)) {
              event.preventDefault()
              if (event.stopImmediatePropagation) event.stopImmediatePropagation()
              else event.stopPropagation?.()
            }
            return
          }
          handledKeyDirection = undefined
          if (!["insertText", "insertReplacementText"].includes(event.inputType) || event.isComposing) return
          const url = event.data
          if (typeof url === "string" && imageMatches(url).some((match) => match.index === 0 && match.url === url)) {
            insertedUrl = url
          }
        }
        const onKeyDown = (event) => {
          handledKeyDirection = undefined
          if (!["Backspace", "Delete"].includes(event.key) || event.isComposing ||
              event.metaKey || event.ctrlKey || event.altKey) return
          const backward = event.key === "Backspace"
          const key = editor.getEditorState().read(() => (selectedPreview() || adjacentPreview(backward))?.getKey())
          if (!key || !removePreviewAtKey(editor, key, backward)) return
          event.preventDefault()
          if (event.stopImmediatePropagation) event.stopImmediatePropagation()
          else event.stopPropagation()
          handledKeyDirection = backward ? "deleteContentBackward" : "deleteContentForward"
          const generation = ++handledKeyGeneration
          // A matching beforeinput can follow this keydown, but not a later input task.
          setTimeout(() => {
            if (handledKeyGeneration === generation) handledKeyDirection = undefined
          }, 0)
        }
        const unregisterRoot = editor.registerRootListener((root, previous) => {
          previous?.removeEventListener("beforeinput", onBeforeInput, true)
          previous?.removeEventListener("keydown", onKeyDown, true)
          insertedUrl = undefined
          handledKeyDirection = undefined
          root?.addEventListener("beforeinput", onBeforeInput, true)
          root?.addEventListener("keydown", onKeyDown, true)
        })
        const unregisterText = editor.registerNodeTransform(TextNode, previewText)
        // LinkNode and AutoLinkNode are not exposed here; ElementNode cannot
        // register a transform because Lexical treats it as an abstract node.
        const unregisterElements = editor.registerUpdateListener(({ dirtyElements, dirtyLeaves, editorState, prevEditorState }) => {
          const completedUrl = insertedUrl
          if (dirtyLeaves?.size) insertedUrl = undefined
          const completedKey = completedUrl && editorState.read(() => {
            const selection = $getSelection()
            if (!$isRangeSelection(selection) || !selection.isCollapsed() ||
                selection.anchor.type !== "text" || !dirtyLeaves?.has(selection.anchor.key)) return
            const { key, offset } = selection.anchor
            const node = $getNodeByKey(key)
            if (!$isTextNode(node) || inCode(node) ||
                node.getTextContent().slice(offset - completedUrl.length, offset) !== completedUrl) return
            return key
          })
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
          if (!dirtyElements.size && !caretLinkKey && !completedKey) return
          editor.update(() => {
            if (completedKey) previewInsertedUrl(completedUrl, dirtyLeaves)
            if (caretLinkKey) previewLink($getNodeByKey(caretLinkKey))
            for (const key of dirtyElements.keys()) {
              const node = $getNodeByKey(key)
              if (node) previewLink(node)
            }
          })
        })
        const unregisterBackspace = editor.registerCommand(KEY_BACKSPACE_COMMAND, (event) => removePreview(true, event), COMMAND_PRIORITY_HIGH)
        const unregisterDelete = editor.registerCommand(KEY_DELETE_COMMAND, (event) => removePreview(false, event), COMMAND_PRIORITY_HIGH)
        return () => {
          unregisterRoot()
          unregisterText()
          unregisterElements()
          unregisterBackspace()
          unregisterDelete()
        }
      }
    })
  }
}
