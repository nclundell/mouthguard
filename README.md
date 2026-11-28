# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## Refreshing CFBD data

Run `bin/rails db:seed` to create the configured dev user and synchronously refresh
teams, venues, games, then legends. From a Rails console, refresh individual
datasets with `TeamsJob.perform_now`, `VenuesJob.perform_now`,
`GamesJob.perform_now`, or `LegendsJob.perform_now`. Run teams and venues
before games when starting with an empty database; legends can associate winners
with users that already exist.

## Comment image links

Direct HTTPS GIF, PNG, JPG, JPEG, and WebP URLs appear as images while editing
comments. The editor submits the original URL as text, not an attachment;
existing comment rendering still handles the URL. A preview is an atomic editor
node: Backspace or Delete beside it removes it and its URL in one press.
To change a URL, remove the preview and retype or paste
the link. Type whitespace after a URL to show its preview when typing; until
then, the URL remains editable so queries and fragments can be completed.
Pasted URLs and complete URLs delivered in a single browser text-insertion event
preview immediately, even without trailing whitespace or at the end of a paragraph.
