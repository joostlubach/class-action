require 'simplecov'

SimpleCov.start do
  add_filter '/spec'
end

require 'action_controller'
require 'class-action'

RSpec.configure do |config|

  config.mock_with :rspec do |config|
    config.syntax = :expect
  end

end

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.expand_path("../support/**/*.rb", __FILE__)].each {|f| require f}