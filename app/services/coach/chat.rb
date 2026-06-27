module Coach
  # Free-form conversation between the athlete and their coach. Plain text
  # in, plain text out — no JSON contract needed here.
  class Chat
    HISTORY_LIMIT = 20

    def self.call(user, content) = new(user, content).call

    def initialize(user, content)
      @user = user
      @content = content
    end

    def call
      raise ArgumentError, "User has no Claude API key" unless user.claude_credential

      user_message = user.messages.create!(role: "user", content: content)

      history = user.messages.order(created_at: :desc).limit(HISTORY_LIMIT).order(created_at: :asc)
      claude_messages = history.map { |m| { role: m.role, content: m.content } }

      response = Coach::Client.new(user.claude_credential.api_key).call(
        system: Coach::ContextBuilder.new(user).system_prompt,
        messages: claude_messages
      )

      assistant_message = user.messages.create!(role: "assistant", content: response)
      [ user_message, assistant_message ]
    end

    private

    attr_reader :user, :content
  end
end
