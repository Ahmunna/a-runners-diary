class ClaudeCredential < ApplicationRecord
  belongs_to :user

  encrypts :api_key

  validates :api_key, presence: true, format: { with: /\Ask-ant-[\w-]+\z/, message: "doesn't look like an Anthropic API key" }

  def masked_key
    return nil if api_key.blank?

    "#{api_key.first(10)}#{'•' * 10}#{api_key.last(4)}"
  end
end
