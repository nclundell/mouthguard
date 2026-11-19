class LegendsSeeder
  WINNERS = {
    2009 => "Nathan Lundell",
    2010 => "Karen Lundell",
    2011 => "Nathan Lundell",
    2012 => "Louis Lundell",
    2013 => "Louis Lundell",
    2014 => "Nathan Lundell",
    2015 => "Nathan Lundell",
    2016 => "Hannah Gorlich",
    2017 => "Nathan Lundell",
    2018 => "Clarke Lundell",
    2019 => "Eric Nelson",
    2020 => "Sarah Lundell",
    2021 => "Maar Family",
    2022 => "Ben Gorlich",
    2023 => "Louis Lundell",
    2024 => "Clarke Lundell",
    2025 => "Karen Lundell"
  }.freeze

  def self.seed!
    Legend.transaction do
      WINNERS.each do |season, name|
        legend = Legend.find_or_initialize_by(season: season)
        parts = name.split
        legend.name = name
        legend.user = User.find_by(first_name: parts.first, last_name: parts.last)
        legend.save!
      end
    end
  end
end
