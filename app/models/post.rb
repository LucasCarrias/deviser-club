class Post < ApplicationRecord
  include ActiveModel::Validations
  attribute :draft, default: true

  attr_accessor :skip_validations

  validates_with ContentLengthValidator, :minimum=> 70, :maximum=> 99889, :word_count=>200, unless: :skip_validations
  validates :draft, uniqueness: { scope: :user_id }, if: :draft?

  before_save :purify

  belongs_to :user, optional: false

  has_many :comments, as: :commentable, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy

  has_many :taggables, dependent: :destroy
  has_many :tags, through: :taggables

  has_one_attached :image, dependent: :destroy

  extend FriendlyId
  friendly_id :title, use: :slugged

  default_scope { order(created_at: :desc) }

  scope :published, -> { where(draft: false) }

  # trim leading and trailing spaces: suggested by @diwash007

  def pure_text
    Nokogiri::HTML(body).xpath('//text()').map(&:text).join('').
      strip
  end

  def purify
    self.body = ApplicationController.helpers.purify self.body
  end

  def excerpt
    Nokogiri::HTML(self.body).xpath('//text()').map(&:text).join(' ').truncate(300)
  end

  def reading_time
    words_per_minute = 150
    text = Nokogiri::HTML(self.body).at('body').inner_text
    (text.scan(/\w+/).length / words_per_minute).to_i
  end

  def similiar_posts
    Post.joins(:tags). # You need to query the Post table
    where.not(posts: { id: self.id }). # Exclude this post
    where(tags: { id: self.tags.ids }). # Get similar tags
      group(:id)
  end

  def generate_og_image
    image_file_io, image_name = ApplicationController.helpers.create_og_image(self.title)
    self.image.attach(io: image_file_io, filename: image_name, content_type: 'image/png')
  end
end

