class CleanUpJob < ApplicationJob
  queue_as :default

  def perform(*args)
    SolidQueue::Job.where("finished_at < ?", 1.day.ago).destroy_all
  end
end
