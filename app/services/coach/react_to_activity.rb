module Coach
  # Asks Claude to react to something new: a synced Strava activity, or a
  # training day that passed with nothing logged. Updates the program's
  # running "coach summary", may rewrite upcoming pending days, and tops
  # up the schedule with new days once it's running low — every existing
  # trigger (Strava sync, daily check-in, manual review, opt-in chat/
  # nutrition triggers) doubles as the program's only refill mechanism, so
  # without this an athlete's schedule permanently runs dry after the
  # initial GenerateProgram window.
  class ReactToActivity
    MIN_PENDING_DAYS_BUFFER = 5
    EXTEND_TO_DAYS = 10

    def self.call(user, trigger_description:) = new(user, trigger_description: trigger_description).call

    def initialize(user, trigger_description:)
      @user = user
      @trigger_description = trigger_description
    end

    def call
      @program = user.race&.active_program
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

        plan.fetch("additions", []).each do |addition|
          next if addition["date"].blank?

          program.training_days.find_or_create_by!(date: addition["date"]) do |day|
            day.workout = addition["workout"]
            day.status = "pending"
          end
        end
      end

      PushNotificationService.notify(user, title: "Your coach updated your plan", body: plan["summary"].to_s.truncate(150))

      program
    end

    private

    attr_reader :user, :trigger_description, :program

    def pending_days_count
      program.training_days.where(status: "pending").where("date >= ?", Date.current).count
    end

    def prompt
      <<~PROMPT
        What just happened: #{trigger_description}

        Update your assessment of this athlete's progress and adjust any
        upcoming pending training days if needed (e.g. ease off after a hard
        effort or a missed day, or push harder if they're coasting).

        This athlete currently has #{pending_days_count} pending training day(s)
        scheduled from today onward. If that's fewer than #{MIN_PENDING_DAYS_BUFFER},
        extend the program via "additions" below so there are at least
        #{EXTEND_TO_DAYS} pending days lined up — never schedule a day on or
        after race day (#{user.race.race_date}).

        Respond with ONLY valid JSON, no markdown fences, in this exact shape:
        {
          "summary": "your updated 2-4 sentence opinion on their progress",
          "updates": [
            { "date": "YYYY-MM-DD", "workout": "revised description for an existing pending day, only include days you're changing" }
          ],
          "additions": [
            { "date": "YYYY-MM-DD", "workout": "description for a new day beyond the current schedule, only if extending" }
          ]
        }
      PROMPT
    end
  end
end
