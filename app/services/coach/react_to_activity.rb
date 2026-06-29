module Coach
  # Asks Claude to react to something new: a synced Strava activity, or a
  # training day that passed with nothing logged. Updates the program's
  # running "coach summary", may rewrite upcoming pending days, and tops
  # up both the daily schedule and the weekly roadmap once either is
  # running low — every existing trigger (Strava sync, daily check-in,
  # manual "check for updates", opt-in chat/nutrition triggers) doubles as
  # the program's only refill mechanism, so without this an athlete's
  # schedule and roadmap permanently run dry after GenerateProgram's
  # initial window.
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

        plan.fetch("week_additions", []).each do |week|
          next if week["week_number"].blank?

          program.training_weeks.find_or_create_by!(week_number: week["week_number"]) do |w|
            w.start_date = week["start_date"]
            w.end_date = week["end_date"]
            w.phase = week["phase"]
            w.target_distance_km = week["target_distance_km"]
            w.focus = week["focus"]
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

    def roadmap_extension_note
      return "" unless program.roadmap_incomplete?

      last_week = program.training_weeks.order(:week_number).last
      next_week_number = last_week ? last_week.week_number + 1 : 1
      from_date = last_week ? last_week.end_date + 1 : Date.current

      <<~NOTE
        The weekly roadmap currently only covers up to #{last_week&.end_date || "nothing yet"},
        but race day is #{user.race.race_date}. Extend it via "week_additions" below,
        starting at week_number #{next_week_number} (#{from_date} onward), using the
        same phase progression logic (base -> build -> peak -> taper -> race_week).
      NOTE
    end

    def prompt
      <<~PROMPT
        What just happened: #{trigger_description}

        Update your assessment of this athlete's progress and adjust any
        upcoming pending training days if needed (e.g. ease off after a hard
        effort or a missed day, or push harder if they're coasting).

        This athlete currently has #{pending_days_count} pending training day(s)
        scheduled from today onward. If that's fewer than #{MIN_PENDING_DAYS_BUFFER},
        extend the daily schedule via "additions" below so there are at least
        #{EXTEND_TO_DAYS} pending days lined up — never schedule a day on or
        after race day (#{user.race.race_date}).

        #{roadmap_extension_note}

        Respond with ONLY valid JSON, no markdown fences, in this exact shape:
        {
          "summary": "your updated 2-4 sentence opinion on their progress",
          "updates": [
            { "date": "YYYY-MM-DD", "workout": "revised description for an existing pending day, only include days you're changing" }
          ],
          "additions": [
            { "date": "YYYY-MM-DD", "workout": "description for a new day beyond the current schedule, only if extending" }
          ],
          "week_additions": [
            { "week_number": 5, "start_date": "YYYY-MM-DD", "end_date": "YYYY-MM-DD", "phase": "build", "target_distance_km": 50, "focus": "short description", "only if extending the roadmap" }
          ]
        }
      PROMPT
    end
  end
end
