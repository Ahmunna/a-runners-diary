module Coach
  # Generates the first two weeks of a training program for the athlete's
  # active race. Re-adaptation (ReactToActivity) extends/rewrites it from there
  # so we never need to ask Claude to plan a full 16-week block in one shot.
  class GenerateProgram
    PLANNING_HORIZON_DAYS = 14

    def self.call(user) = new(user).call

    def initialize(user)
      @user = user
    end

    def call
      race = user.race
      raise ArgumentError, "User has no race goal set" unless race
      raise ArgumentError, "User has no Claude API key" unless user.claude_credential

      response = Coach::Client.new(user.claude_credential.api_key).call(
        system: Coach::ContextBuilder.new(user).system_prompt,
        messages: [ { role: "user", content: prompt } ]
      )

      plan = JsonExtraction.parse(response)

      ActiveRecord::Base.transaction do
        race.training_programs.where(status: "active").update_all(status: "superseded")

        program = race.training_programs.create!(
          status: "active",
          generated_at: Time.current,
          claude_summary: plan["summary"]
        )

        plan.fetch("days", []).each do |day|
          program.training_days.create!(date: day["date"], workout: day["workout"], status: "pending")
        end

        program
      end
    end

    private

    attr_reader :user

    def prompt
      <<~PROMPT
        Generate the first #{PLANNING_HORIZON_DAYS} days of this athlete's training
        program, starting tomorrow (#{Date.tomorrow}). The plan should match their
        chosen difficulty level and build toward their race goal above.

        Respond with ONLY valid JSON, no markdown fences, in this exact shape:
        {
          "summary": "2-3 sentence coach's note introducing the plan",
          "days": [
            { "date": "YYYY-MM-DD", "workout": "description of the session, or 'Rest day'" }
          ]
        }
      PROMPT
    end
  end
end
