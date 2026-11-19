class TeamsSeeder
  def self.seed!
    Team.transaction do
      Cfbd::Rest.teams.each do |source|
        team = Team.find_or_initialize_by(cfbd_id: source.id)
        team.assign_attributes(
          school: source.school,
          mascot: source.mascot,
          abbreviation: source.abbreviation,
          alternate_names: source.alternateNames,
          conference: source.conference,
          color: source.color,
          alternate_color: source.alternateColor,
          logos: source.logos
        )
        team.save!
      end
    end
  end
end
