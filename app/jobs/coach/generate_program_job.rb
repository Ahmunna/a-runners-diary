module Coach
  class GenerateProgramJob < ApplicationJob
    queue_as :default

    def perform(user_id)
      Coach::GenerateProgram.call(User.find(user_id))
    end
  end
end
