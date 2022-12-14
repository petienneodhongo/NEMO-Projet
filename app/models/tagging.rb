# frozen_string_literal: true

# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: taggings
#
#  id                                                      :uuid             not null, primary key
#  created_at                                              :datetime         not null
#  updated_at                                              :datetime         not null
#  question_id                                             :uuid             not null
#  tag_id(Can't set null false due to replication process) :uuid
#
# Indexes
#
#  index_taggings_on_question_id  (question_id)
#  index_taggings_on_tag_id       (tag_id)
#
# Foreign Keys
#
#  taggings_question_id_fkey  (question_id => questions.id) ON DELETE => restrict ON UPDATE => restrict
#  taggings_tag_id_fkey       (tag_id => tags.id) ON DELETE => restrict ON UPDATE => restrict
#
# rubocop:enable Layout/LineLength

# Tagging associates questions with tags
class Tagging < ApplicationRecord
  include Replication::Replicable

  belongs_to :question
  belongs_to :tag

  delegate :mission_id, to: :question

  replicable child_assocs: :tag, backward_assocs: :question

  clone_options follow: %i[tag]
end
