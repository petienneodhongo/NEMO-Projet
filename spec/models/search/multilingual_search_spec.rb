# frozen_string_literal: true

require "rails_helper"

describe "search qualifiers" do
  let(:mission) { get_mission }
  let(:qualifier_sets) do
    {
      response: ResponsesSearcher.new(relation: Response.all, query: "test",
                                      scope: {mission: mission}).search_qualifiers,
      user: UsersSearcher.new(relation: User.all, query: "test").search_qualifiers,
      question: QuestionsSearcher.new(relation: Question.all, query: "test").search_qualifiers,
      sms: Sms::MessagesSearcher.new(relation: Sms::Message.all, query: "test").search_qualifiers
    }
  end

  it "should be recognized in all languages" do
    errors = false

    qualifier_sets.each do |klass, qualifiers|
      qualifiers.each do |qual|
        # Regexp style qualifiers are tested separately.
        next if qual.regexp?

        qual_en = I18n.t("search_qualifiers.#{qual.name}", locale: :en, raise: true)

        I18n.available_locales.each do |locale|
          I18n.locale = locale

          # If translation doesn't exist in target lang, the help text will be in English, so we assume
          # the user will be using the english qualifier name.
          qual_tr = I18n.t("search_qualifiers.#{qual.name}", locale: locale, default: qual_en)

          unless qual_tr.match?(/\A[\p{Word}'\-]+\z/)
            puts "#{klass} qualifier '#{qual.name}' (#{qual_tr}) in #{locale} has an invalid format."
            errors = true
            next
          end

          begin
            Search::Qualifier.find_in_set(qualifiers, qual_tr)
          rescue Search::ParseError
            puts "#{klass.capitalize} qualifier '#{qual.name}' (#{qual_tr}) was not found in #{locale}."
            errors = true
          end
        end
      end
    end
    expect(errors).to be(false), "Errors found with qualifier translations."
  end
end
