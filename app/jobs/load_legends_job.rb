class LoadLegendsJob < ApplicationJob
  queue_as :default

  def perform(*args)
    winners = [
      { season: 2009, name: "Nathan Lundell" },
      { season: 2010, name: "Karen Lundell" },
      { season: 2011, name: "Nathan Lundell" },
      { season: 2012, name: "Louis Lundell" },
      { season: 2013, name: "Louis Lundell" },
      { season: 2014, name: "Nathan Lundell" },
      { season: 2015, name: "Nathan Lundell" },
      { season: 2016, name: "Hannah Gorlich" },
      { season: 2017, name: "Nathan Lundell" },
      { season: 2018, name: "Clarke Lundell" },
      { season: 2019, name: "Eric Nelson" },
      { season: 2020, name: "Sarah Lundell" },
      { season: 2021, name: "Maar Family" },
      { season: 2022, name: "Ben Gorlich" },
      { season: 2023, name: "Louis Lundell" },
      { season: 2024, name: "Clarke Lundell" }
    ]

    winners.each do |winner|
      legend = Legend.find_or_initialize_by(season: winner[:season])
      legend.name = winner[:name]
      legend.user = Legend.detect_user(winner[:name])
      legend.save
    end
  end
end
