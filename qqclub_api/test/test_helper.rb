# frozen_string_literal: true

# SimpleCov must be started BEFORE requiring any application code
if ENV["COVERAGE"]
  require "simplecov"

  # Configure SimpleCov for parallel testing
  SimpleCov.start "rails" do
    add_group "Models", "app/models"
    add_group "Controllers", "app/controllers"
    add_group "Helpers", "app/helpers"
    add_group "Jobs", "app/jobs"
    add_group "Mailers", "app/mailers"

    add_filter "/bin/"
    add_filter "/db/"
    add_filter "/test/"
    add_filter "/config/"
    add_filter "/vendor/"

    # Track all files, not just those touched by tests
    track_files "{app,lib}/**/*.rb"

    # Enable merging for parallel testing
    use_merging true
    merge_timeout 3600  # 1 hour timeout for merging

    # Define how to merge results
    SimpleCov.merge_timeout 3600

    minimum_coverage 0  # 暂时设置为0，先获得真实的覆盖率数据
  end
end

ENV["RAILS_ENV"] = "test"

require_relative "../config/environment"
require "rails/test_help"
require "minitest/reporters"
require "database_cleaner/active_record"

# 加载测试支持文件
Dir[Rails.root.join("test/support/**/*.rb")].each { |f| require f }

# Load FactoryBot
require "factory_bot_rails"

# Configure minitest reporters
Minitest::Reporters.use!([
  Minitest::Reporters::DefaultReporter.new(color: true),
  Minitest::Reporters::SpecReporter.new
])

# Database cleaner configuration
class ActiveSupport::TestCase
  include FactoryBot::Syntax::Methods

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
  setup do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.start
  end

  teardown do
    DatabaseCleaner.clean
  end

  # Parallel testing - disabled for coverage reporting
  # parallelize(workers: :number_of_processors) unless ENV["COVERAGE"]
  parallelize(workers: 1) if ENV["COVERAGE"]

  # Setup test data
  def create_test_user(role = :user, **attributes)
    role_mapping = {
      user: 0,
      admin: 1,
      root: 2
    }

    default_attrs = {
      nickname: Faker::Name.name,
      wx_openid: "#{role}_#{SecureRandom.hex(8)}",
      role: role_mapping[role] || 0
    }

    User.create!(default_attrs.merge(attributes))
  end

  def create_test_reading_event(leader: nil, **attributes)
    leader ||= create_test_user(:user)

    default_attrs = {
      title: Faker::Book.title,
      book_name: Faker::Book.author,
      description: Faker::Lorem.paragraph(sentence_count: 3),
      start_date: Date.today,
      end_date: Date.today + 30.days,
      max_participants: 20,
      fee_amount: 100.0,
      status: :draft,
      approval_status: :pending,
      leader: leader
    }

    event = ReadingEvent.create!(default_attrs.merge(attributes))
    event
  end

  def create_test_post(user: nil, **attributes)
    user ||= create_test_user(:user)

    default_attrs = {
      title: Faker::Lorem.sentence(word_count: 3),
      content: Faker::Lorem.paragraph(sentence_count: 5),
      user: user
    }

    Post.create!(default_attrs.merge(attributes))
  end

  def create_test_reading_schedule(reading_event: nil, **attributes)
    reading_event ||= create_test_reading_event

    default_attrs = {
      day_number: 1,
      date: Date.today,
      reading_progress: "第1-2章",
      reading_event: reading_event
    }

    ReadingSchedule.create!(default_attrs.merge(attributes))
  end

  def create_test_check_in(user: nil, reading_schedule: nil, **attributes)
    user ||= create_test_user(:user)
    reading_schedule ||= create_test_reading_schedule

    default_attrs = {
      content: Faker::Lorem.paragraph(sentence_count: 5),
      user: user,
      reading_schedule: reading_schedule
    }

    CheckIn.create!(default_attrs.merge(attributes))
  end

  def create_test_enrollment(reading_event: nil, user: nil, **attributes)
    reading_event ||= create_test_reading_event
    user ||= create_test_user(:user)

    default_attrs = {
      reading_event: reading_event,
      user: user,
      role: :participant
    }

    Enrollment.create!(default_attrs.merge(attributes))
  end

  # Authentication helpers
  def authenticate_user(user)
    token = user.generate_jwt_token
    { "Authorization" => "Bearer #{token}" }
  end

  def json_response
    JSON.parse(response.body)
  end

  # Permission testing helpers
  def assert_admin_required(action, path, params = {})
    user = create_test_user(:user)
    send(action, path, params: params, headers: authenticate_user(user))
    assert_response :forbidden
  end

  def assert_authentication_required(action, path, params = {})
    send(action, path, params: params)
    assert_response :unauthorized
  end
end