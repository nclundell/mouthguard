export function normalizeSearchText(text) {
  return text.normalize("NFC").toLocaleLowerCase().replace(/[^\p{L}\p{N}]/gu, "")
}

export function matchesSearch(query, text) {
  const option = normalizeSearchText(text)
  let position = 0
  for (const character of query) {
    position = option.indexOf(character, position)
    if (position === -1) return false
    position += character.length
  }
  return true
}
