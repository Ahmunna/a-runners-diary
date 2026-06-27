module Coach
  class ReactToActivityJob < ApplicationJob
    queue_as :default

    def perform(user_id, trigger_description)
      user = User.find(user_id)
      Coach::ReactToActivity.call(user, trigger_description: trigger_description)
    end
  end
end
