# frozen_string_literal: true

require "rails_helper"

# See also tabular_import_spec
describe UserImport do
  let(:mission) { get_mission }
  let(:run_errors) { import.run_errors }
  let(:import) do
    UserImport.new(file: user_import_fixture(filename), mission_id: mission.id, name: "").tap(&:run)
  end
  let(:created_users) { User.order(:login).to_a }

  context "with varying amounts of info" do
    let(:filename) { "varying_info.csv" }

    it "succeeds" do
      expect(import).to be_succeeded
      expect_user_count(5)
      expect_user_attribs(0,
        login: "a.bob", name: "A Bob", phone: "+2279182137", phone2: nil,
        gender: "man", email: "a@bc.com", pref_lang: "en")
      expect_user_attribs(1,
        login: "bcod", name: "Bo Cod", phone: nil, phone2: nil,
        gender: "woman", email: "b@co.com", nationality: "US", pref_lang: "en")
      expect_user_attribs(2,
        login: "clo", name: "Cha Lo", phone: "+983755482", phone2: "+9837494434",
        birth_year: nil, gender: nil, gender_custom: nil, email: "ch@lo.com", nationality: nil,
        pref_lang: "en")
      expect_user_attribs(3,
        login: "flim.flo", name: "Flim Flo", phone: "+123456789", phone2: nil,
        birth_year: 1989, email: "f@fl.com", nationality: nil, pref_lang: "en")
      expect_user_attribs(4,
        login: "shobo", name: "Sho Bo", phone: nil, phone2: nil,
        gender: "specify", gender_custom: "Genderqueer", email: "d@ef.stu", pref_lang: "en")
    end
  end

  context "with simple CSV" do
    let(:filename) { "batch_of_3.csv" }

    it "succeeds" do
      expect(import).to be_succeeded
      expect_user_count(3)
    end
  end

  context "with BOM character" do
    let(:filename) { "bom.csv" }

    it "succeeds" do
      expect(import).to be_succeeded
      expect_user_count(1)
    end
  end

  context "with other locale in I18n.locale and case-variant headers" do
    let(:filename) { "french.csv" }

    it "succeeds" do
      in_locale(:fr) do
        expect(import).to be_succeeded
        expect_user_count(3)
        # pref_lang still is 'en' because that is the mission preference
        expect_user_attribs(0,
          login: "user0", name: "User0", phone: "+17098885555", phone2: "+17098885556",
          gender: "man", email: "email0@email.com", birth_year: 1981, nationality: "CA", notes: "note_0",
          user_groups: ["Les habitants"], pref_lang: "en")
        expect_user_attribs(1, login: "user1")
        expect_user_attribs(2, login: "user2")
      end
    end
  end

  context "with mission with non-english preferred locales" do
    let(:filename) { "varying_info.csv" }

    before do
      mission.setting.update!(preferred_locales_str: "et,fr,en")
    end

    it "sets pref_lang to the first locale that matches a system locale" do
      expect(import).to be_succeeded
      expect_user_attribs(0, pref_lang: "fr")
      expect_user_attribs(1, pref_lang: "fr")
    end
  end

  context "with mission with no preferred locales that match system locales" do
    let(:filename) { "varying_info.csv" }

    before do
      # Validation doesn't let us do this typically, but testing just in case.
      mission.setting.update_attribute(:preferred_locales_str, "et,fo")
    end

    it "defaults to english" do
      expect(import).to be_succeeded
      expect_user_attribs(0, pref_lang: "en")
      expect_user_attribs(1, pref_lang: "en")
    end
  end

  context "with groups" do
    let!(:group1) { create(:user_group, name: "New Mexico dragons", mission: get_mission) }
    let!(:group2) { create(:user_group, name: "Delaware whales", mission: get_mission) }

    context "with single group" do
      let(:filename) { "single_group.csv" }

      it "succeeds" do
        expect(import).to be_succeeded
        expect_user_attribs(0, login: "user0", user_groups: [group1])
      end
    end

    context "with multiple groups, some existing and some not" do
      let(:filename) { "multiple_groups.csv" }

      it "succeeds" do
        expect(import).to be_succeeded
        expect_user_attribs(0, login: "user0", user_groups: [group1])
        expect_user_attribs(1, login: "user1", user_groups: [group2, group1])
        expect_user_attribs(2, login: "user2", user_groups: [group2, group1, "I am new"])
        expect_user_attribs(3, login: "user3", user_groups: ["Halla new one", "A new one"])
      end
    end
  end

  context "with blank lines" do
    let(:filename) { "blank_lines.csv" }

    it "ignores blank lines" do
      expect(import).to be_succeeded
      expect_user_count(2)
    end
  end

  context "when headers have trailing invisible blanks" do
    let(:filename) { "abnormal_headers.csv" }

    it "succeeds" do
      expect(import).to be_succeeded
    end
  end

  context "when creating users without emails" do
    let(:filename) { "empty_emails.csv" }

    it "succeeds" do
      expect(import).to be_succeeded
    end
  end

  context "with tricky file" do
    # This file was causing users to get created with passwords.
    let(:filename) { "no_passwords.csv" }

    it "creates users with passwords" do
      expect(import).to be_succeeded
      expect_user_count(29)
      expect(User.all.map(&:crypted_password).any?(&:nil?)).to be(false)
    end
  end

  context "with one row" do
    let(:filename) { "one_row.csv" }

    it "succeeds" do
      expect(import).to be_succeeded
      expect_user_count(1)
    end
  end

  context "with missing header row with a number in it" do
    let(:filename) { "missing_headers.csv" }

    it "reports unrecognized headers and handles numeric type" do
      expect(import).not_to be_succeeded
      expect(run_errors).to eq(["The following column headers were not recognized: 'leonobs1', "\
        "'DAVID JOHNSON', 'dj3349883@gmail.com', 'CAPE MOUNT DISTRICT 1', '21655555555'."])
    end
  end

  context "with simple validation error" do
    let(:filename) { "errors.csv" }

    it "handles errors" do
      expect(import).not_to be_succeeded
      expect(run_errors).to eq([
        "Row 2: Main Phone: Please enter at least 9 digits.",
        "Row 3: Username: Please use only letters, numbers, periods, and underscores."
      ])
    end
  end

  context "with duplicate emails" do
    let(:filename) { "duplicate_emails.csv" }

    it "does not check for email uniqueness" do
      expect(import).to be_succeeded
    end
  end

  context "with duplicate usernames and too many errors" do
    let(:filename) { "multiple_errors.csv" }

    before do
      stub_const("UserImport::IMPORT_ERROR_CUTOFF", 3)
      # a@bc.com also exists in fixure but we don't care about email uniqueness
      create(:user, login: "a.bob", email: "a@bc.com")
      create(:user, login: "bcod")
      create(:user, login: "shobo")
      create(:user, login: "clo")
    end

    it "returns appropriate errors and ignores deleted data" do
      expect(import).not_to be_succeeded
      # Row 6 shouldn't be processed.
      expect(run_errors).to eq([
        "Row 2: Username: Please enter a unique value.",
        "Row 3: Username: Please enter a unique value.",
        "Row 5: Username: Please enter a unique value.",
        "The uploaded CSV file has too many errors. Processing stopped at row 5."
      ])
    end
  end

  private

  def expect_user_count(count)
    expect(User.count).to eq(count)
    expect(Assignment.count).to eq(count)

    # Ensure assignments are correct
    expect(User.all.map { |u| u.missions.to_a }.uniq).to eq([[mission]])
  end

  def expect_user_attribs(index, attribs)
    expect_user_groups(index, attribs.delete(:user_groups))
    expect(created_users[index]).to have_attributes(attribs)
  end

  def expect_user_groups(index, groups)
    return if groups.nil?

    # If strings passed as groups, look them up and check them.
    groups = (groups || []).map do |group_or_name|
      next(group_or_name) unless group_or_name.is_a?(String)
      group = UserGroup.where(name: group_or_name).first
      raise "Group #{group_or_name} not found" if group.nil?
      expect(group.mission).not_to be_nil # Check group created properly.
      group
    end
    expect(created_users[index].user_groups.map(&:id)).to match_array(groups.map(&:id))
  end
end
