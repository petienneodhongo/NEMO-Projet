# frozen_string_literal: true

require "rails_helper"

# TODO: Most of these tests should live in authorization specs instead.
#   Please move at the next opportunity.
describe "sms auth code field", :sms do
  let(:user) { create(:user) }
  let(:staffer) { create(:user, role_name: :staffer) }
  let(:enumerator) { create(:user, role_name: :enumerator) }

  context "in show mode for staffer" do
    before do
      login(staffer)
      get("/en/m/#{get_mission.compact_name}/users/#{user.id}")
      assert_response(:success)
    end

    it "should be visible" do
      assert_select("div.user_sms_auth_code", true)
    end

    it "should not have regenerate button" do
      assert_select("div.user_sms_auth_code a", text: /Regenerate/, count: 0)
    end
  end

  context "in edit mode for same user" do
    before do
      login(user)
      get("/en/m/#{get_mission.compact_name}/users/#{user.id}/edit")
    end

    old_key = nil

    it "should be visible" do
      # Store for later
      assert_select("div.user_sms_auth_code", true) do |e|
        old_key = e.to_s
      end
    end

    it "should have regenerate button" do
      assert_select("div.user_sms_auth_code a", text: /Regenerate/, count: 1)
    end

    context "on regenerate" do
      it "should return the new sms_auth_code value as json" do
        patch(regenerate_sms_auth_code_user_path(user))
        expect(response).to be_successful

        user.reload
        expect(response.body).to eq({value: user.sms_auth_code}.to_json)
      end

      it "should have a new key" do
        get "/en/m/#{get_mission.compact_name}/users/#{user.id}"
        assert_select("div.user_sms_auth_code") do |e|
          expect(old_key).not_to eq(e.to_s)
        end
      end
    end
  end

  context "in show mode for enumerator" do
    before do
      login(enumerator)
      get("/en/m/#{get_mission.compact_name}/users/#{user.id}")
    end

    it "should not be visible" do
      assert_select("div.user_sms_auth_code", false)
    end
  end

  context "in edit mode for enumerator" do
    before do
      login(enumerator)
    end

    context "with other user" do
      before { get("/en/m/#{get_mission.compact_name}/users/#{user.id}/edit") }

      it "should not be visible" do
        assert_select("div.user_sms_auth_code", false)
      end
    end

    context "with own user" do
      before { get("/en/m/#{get_mission.compact_name}/users/#{enumerator.id}/edit") }

      old_key = nil

      it "should be visible" do
        # Store for later
        assert_select("div.user_sms_auth_code", true) do |e|
          old_key = e.to_s
        end
      end

      it "should have regenerate button" do
        assert_select("div.user_sms_auth_code a", text: /Regenerate/, count: 1)
      end

      context "on regenerate" do
        it "should return the new sms_auth_code value as json" do
          patch(regenerate_sms_auth_code_user_path(enumerator))
          expect(response).to be_successful

          enumerator.reload
          expect(response.body).to eq({value: enumerator.sms_auth_code}.to_json)
        end

        it "should have a new key" do
          get "/en/m/#{get_mission.compact_name}/users/#{enumerator.id}"
          assert_select("div.user_sms_auth_code") do |e|
            expect(old_key).not_to eq(e.to_s)
          end
        end
      end
    end
  end
end
