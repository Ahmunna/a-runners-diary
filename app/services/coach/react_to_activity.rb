module Coach
  # Asks Claude to react to something new: a synced Strava activity, or a
  # training day that passed with nothing logged. Updates the program's
  # running "coach summary" and may rewrite upcoming pending days.
  class ReactToActivity
    def self.call(user, trigger_description:) = new(user, trigger_description: trigger_description).call

    def initialize(user, trigger_description:)
      @user = user
      @trigger_description = trigger_description
    end

    def call
      program = user.race&.active_program
      return unless program && user.claude_credential

      response = Coach::Client.new(user.claude_credential.api_key).call(
        system: Coach::ContextBuilder.new(user).system_prompt,
        messages: [ { role: "user", content: prompt } ]
      )

      plan = JsonExtraction.parse(response)

      ActiveRecord::Base.transaction do
        program.update!(claude_summary: plan["summary"])

        plan.fetch("updates", []).each do |update|
          day = program.training_days.find_by(date: update["date"])
          day&.update!(workout: update["workout"])
        end
      end

      PushNotificationService.notify(user, title: "Your coach updated your plan", body: plan["summary"].to_s.truncate(150))

      program
    end

    private

    attr_reader :user, :trigger_description

    def prompt
      <<~PROMPT
        What just happened: #{trigger_description}

        Update your assessment of this athlete's progress and adjust any
        upcoming pending training days if needed (e.g. ease off after a hard
        effort or a missed day, or push harder if they're coasting).

        Respond with ONLY valid JSON, no markdown fences, in this exact shape:
        {
          "summary": "your updated 2-4 sentence opinion on their progress",
          "updates": [
            { "date": "YYYY-MM-DD", "workout": "revised description for an existing pending day, only include days you're changing" }
          ]
        }
      PROMPT
    end
  end
end
