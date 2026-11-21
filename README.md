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
