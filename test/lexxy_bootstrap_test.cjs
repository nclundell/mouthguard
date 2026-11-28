const assert = require("node:assert/strict")
const { readFileSync } = require("node:fs")
const { join } = require("node:path")
const { test } = require("node:test")

test("Lexxy extension configuration is the first application dependency", () => {
  const application = readFileSync(join(__dirname, "../app/javascript/application.js"), "utf8")
  const bootstrap = readFileSync(join(__dirname, "../app/javascript/lexxy_bootstrap.js"), "utf8")
  const importmap = readFileSync(join(__dirname, "../config/importmap.rb"), "utf8")

  assert.match(application, /^import "lexxy_bootstrap"/)
  assert.match(bootstrap, /import \* as Lexxy from "lexxy"/)
  assert.match(bootstrap, /import CommentImagePreviewExtension from "comment_image_preview"/)
  assert.match(bootstrap, /Lexxy\.configure\(\{ global: \{ extensions: \[CommentImagePreviewExtension\] \} \}\)/)
  assert.match(importmap, /pin "lexxy_bootstrap"/)
})
