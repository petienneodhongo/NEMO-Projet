# frozen_string_literal: true

# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: sms_messages
#
#  id                                                                   :uuid             not null, primary key
#  adapter_name                                                         :string(255)      not null
#  auth_failed                                                          :boolean          default(FALSE), not null
#  body                                                                 :text             not null
#  from                                                                 :string(255)
#  reply_error_message                                                  :string
#  sent_at                                                              :datetime         not null
#  to                                                                   :string(255)
#  type                                                                 :string(255)      not null
#  created_at                                                           :datetime         not null
#  updated_at                                                           :datetime         not null
#  broadcast_id                                                         :uuid
#  mission_id(Can't set null false due to missionless SMS receive flow) :uuid
#  reply_to_id                                                          :uuid
#  user_id                                                              :uuid
#
# Indexes
#
#  index_sms_messages_on_body          (body)
#  index_sms_messages_on_broadcast_id  (broadcast_id)
#  index_sms_messages_on_created_at    (created_at)
#  index_sms_messages_on_from          (from)
#  index_sms_messages_on_mission_id    (mission_id)
#  index_sms_messages_on_reply_to_id   (reply_to_id)
#  index_sms_messages_on_to            (to)
#  index_sms_messages_on_type          (type)
#  index_sms_messages_on_user_id       (user_id)
#
# Foreign Keys
#
#  sms_messages_broadcast_id_fkey  (broadcast_id => broadcasts.id) ON DELETE => restrict ON UPDATE => restrict
#  sms_messages_mission_id_fkey    (mission_id => missions.id) ON DELETE => restrict ON UPDATE => restrict
#  sms_messages_reply_to_id_fkey   (reply_to_id => sms_messages.id) ON DELETE => restrict ON UPDATE => restrict
#  sms_messages_user_id_fkey       (user_id => users.id) ON DELETE => restrict ON UPDATE => restrict
#
# rubocop:enable Layout/LineLength

require "rails_helper"

describe Sms::Message, :sms do
  let(:body) { "blah" }
  let(:from) { "+17345551212" }
  let!(:message) { create(:sms_reply, from: from, to: "14045551212", body: body) }

  it "creating a message should work" do
    message.reload # reload to make sure serialization is working right
    expect(message.to).to eq("+14045551212")
  end

  it "a message with no sent_at should default to now, but only when saved" do
    expect(Time.current - message.sent_at < 5.seconds).to be(true)
  end

  context "with textual from" do
    let(:from) { "foo" }

    it "should be preserved" do
      expect(message.from).to eq("foo")
    end
  end

  context "with long body and slight difference at end" do
    let(:body) do
      "laksdjf alsdkjf lasdfkjaf laskdsf aslkfsjflsakfda lsakl fakjsdlkfaj lskjf alksj "\
      "dfalkj sdlfaks asdaksjdafa alaskdfal alkajdasfa alsjd alasksdjf alks"\
      "alfdsafdslf l lajslfdjfalsdkf dslads"
    end

    it "should not be returned as equal" do
      # This is just to be sure the index of length 160 doesn't mess anything up
      expect(Sms::Reply.find_by(body: body)).to eq(message)
      expect(Sms::Reply.find_by(body: body + "a")).to be_nil
    end
  end
end
