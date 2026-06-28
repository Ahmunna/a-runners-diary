module Coach
  # Builds the shared context every Claude call needs: who the athlete is,
  # what they're training for, what they've actually been doing, and what
  # they've been eating. Keeping this in one place means GenerateProgram,
  # ReactToActivity and Chat never drift out of sync on what Claude sees.
  class ContextBuilder
    RECENT_ACTIVITIES_COUNT = 10
    RECENT_NUTRITION_DAYS = 7

    def initialize(user)
      @user = user
    end

    def system_prompt
      <<~PROMPT
        You are an experienced, demanding #{coach_specialty} writing directly to your athlete.
        You have access to their profile, race goal, recent Strava activity, nutrition
        logs, and training program below. Be specific and reference real numbers from
        this context rather than generic advice. Match your tone to their chosen
        difficulty level: beginner athletes get encouragement and caution, advanced
        athletes get pushed hard and should not be let off easy unless the data shows
        real injury or overtraining risk.

        #{athlete_section}
        #{race_section}
        #{program_section}
        #{activities_section}
        #{nutrition_section}
      PROMPT
    end

    private

    attr_reader :user

    def coach_specialty
      user.race&.hyrox? ? "hybrid running + functional fitness coach" : "running coach"
    end

    def athlete_section
      profile = user.athlete_profile
      return "## Athlete\nNo profile on file." unless profile

      <<~SECTION
        ## Athlete
        Name: #{user.full_name}
        Age: #{profile.age || "unknown"}
        Sex: #{profile.sex || "unknown"}
        Height: #{profile.height_cm ? "#{profile.height_cm} cm" : "unknown"}
        Notes from athlete: #{profile.notes.presence || "none provided"}
      SECTION
    end

    def race_section
      race = user.race
      return "## Race goal\nNone set yet." unless race

      <<~SECTION
        ## Race goal
        Race: #{race.distance_label} on #{race.race_date}
        Target time: #{race.time_objective.presence || "not specified"}
        Difficulty level: #{race.difficulty}
        #{hyrox_structure_note if race.hyrox?}
      SECTION
    end

    def hyrox_structure_note
      <<~NOTE
        Hyrox format: 8x 1km runs alternating with 8 functional stations, in
        order — ski erg (1000m), sled push (50m), sled pull (50m), burpee
        broad jumps (80m), rowing (1000m), farmers carry (200m), sandbag
        lunges (100m), wall balls (75/100 reps). Training days should mix
        running volume with station-specific strength/conditioning work
        (compromised running after stations, sled work, grip/carry
        endurance) — don't just write a generic running plan and call it
        Hyrox prep.
      NOTE
    end

    def program_section
      program = user.race&.active_program
      return "## Training program\nNo active program yet." unless program

      upcoming = program.training_days.where("date >= ?", Date.current).order(:date).limit(7)
      lines = upcoming.map { |d| "- #{d.date} (#{d.status}): #{d.workout}" }

      <<~SECTION
        ## Current training program
        Generated: #{program.generated_at}
        Latest coach summary: #{program.claude_summary.presence || "none yet"}
        Next 7 scheduled days:
        #{lines.join("\n")}
      SECTION
    end

    def activities_section
      activities = user.strava_activities.order(occurred_at: :desc).limit(RECENT_ACTIVITIES_COUNT)
      return "## Recent Strava activities\nNone synced yet." if activities.empty?

      lines = activities.map do |a|
        "- #{a.occurred_at&.to_date}: #{a.distance_km}km in #{a.duration_minutes}min (pace #{a.pace_per_km} min/km)"
      end

      <<~SECTION
        ## Recent Strava activities (most recent first)
        #{lines.join("\n")}
      SECTION
    end

    def nutrition_section
      logs = user.nutrition_logs.where("date >= ?", Date.current - RECENT_NUTRITION_DAYS).order(date: :desc)
      return "## Recent nutrition\nNo logs yet." if logs.empty?

      lines = logs.map { |l| "- #{l.date}: #{l.calories} kcal, P#{l.protein_g}/C#{l.carbs_g}/F#{l.fat_g}#{" — #{l.notes}" if l.notes.present?}" }

      <<~SECTION
        ## Recent nutrition logs
        #{lines.join("\n")}
      SECTION
    end
  end
end
