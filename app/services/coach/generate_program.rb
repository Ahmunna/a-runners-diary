module Coach
  # Generates two things: a week-by-week periodization roadmap covering the
  # entire span to race day (base/build/peak/taper/race_week — lightweight,
  # just a phase + volume target per week), and detailed day-by-day
  # training for the first two weeks only. Re-adaptation (ReactToActivity)
  # extends the daily detail from there, so we never ask Claude to write
  # out exact daily workouts for months of weeks that are going to be
  # rewritten anyway once real performance data exists for them.
  class GenerateProgram
    PLANNING_HORIZON_DAYS = 14
    MAX_ROADMAP_WEEKS = 30

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

      program = ActiveRecord::Base.transaction do
        race.training_programs.where(status: "active").update_all(status: "superseded")

        program = race.training_programs.create!(
          status: "active",
          generated_at: Time.current,
          claude_summary: plan["summary"]
        )

        plan.fetch("weeks", []).each do |week|
          program.training_weeks.create!(
            week_number: week["week_number"],
            start_date: week["start_date"],
            end_date: week["end_date"],
            phase: week["phase"],
            target_distance_km: week["target_distance_km"],
            focus: week["focus"]
          )
        end

        plan.fetch("days", []).each do |day|
          program.training_days.create!(date: day["date"], workout: day["workout"], status: "pending")
        end

        program
      end

      PushNotificationService.notify(user, title: "Your training program is ready", body: plan["summary"].to_s.truncate(150))

      program
    end

    private

    attr_reader :user

    def total_weeks_to_race
      ((user.race.race_date - Date.current).to_i / 7.0).ceil
    end

    def prompt
      <<~PROMPT
        Generate two things for this athlete:

        1. A week-by-week periodization roadmap covering every week from
           today (#{Date.current}) to race day (#{user.race.race_date}) —
           that's #{total_weeks_to_race} weeks (cap it at #{MAX_ROADMAP_WEEKS}
           weeks if more than that — we'll fill in the rest closer to race
           day). Standard periodization: base phase first (aerobic volume),
           then build (intensity + volume), then peak (highest volume, key
           long runs/workouts), then taper (final 2-3 weeks reducing volume),
           then race_week (the week race day falls in). Each week needs a
           phase, a target weekly running distance in km, and a one-line
           focus.
        2. Detailed day-by-day training for the first #{PLANNING_HORIZON_DAYS}
           days only, starting today (#{Date.current}) — today should have a
           real scheduled day too, not be skipped. These daily workouts must
           be consistent with whichever week/phase they fall into in the
           roadmap above (e.g. don't schedule a peak-volume long run inside
           a base-phase week).

        The plan should match their chosen difficulty level and build toward
        their race goal above.

        Respond with ONLY valid JSON, no markdown fences, in this exact shape:
        {
          "summary": "2-3 sentence coach's note introducing the plan",
          "weeks": [
            { "week_number": 1, "start_date": "YYYY-MM-DD", "end_date": "YYYY-MM-DD", "phase": "base", "target_distance_km": 40, "focus": "short description" }
          ],
          "days": [
            { "date": "YYYY-MM-DD", "workout": "description of the session, or 'Rest day'" }
          ]
        }
      PROMPT
    end
  end
end
