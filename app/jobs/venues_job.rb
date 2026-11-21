class VenuesJob < ApplicationJob
  def perform
    Venue.transaction do
      Cfbd::Rest.venues.each do |source|
        venue = Venue.find_or_initialize_by(cfbd_id: source.id)
        venue.assign_attributes(
          name: source.name,
          city: source.city,
          state: source.state,
          zip: source.zip,
          country_code: source.countryCode,
          timezone: source.timezone,
          capacity: source.capacity,
          construction_year: source.constructionYear,
          grass: source.grass,
          dome: source.dome
        )
        venue.save!
      end
    end
  end
end
