module Strava
  class SyncActivitiesJob < ApplicationJob
    queue_as :default

    def perform(user_id)
      Strava::SyncActivities.call(User.find(user_id))
    end
  end
end
