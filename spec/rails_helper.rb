require 'spec_helper'
require 'factory_bot'
require 'rails'
require 'active_support/all'
require_relative '../app/serializers/application_serializer'
require_relative '../app/serializers/item_serializer'
require_relative '../app/responders/application_responder'

# Plain Ruby struct so FactoryBot can build :item without a database
Item = Struct.new(:id, :name, :description, :category, :slogan, :score, keyword_init: true) unless defined?(Item)

RSpec.configure do |config|
  config.include(FactoryBot::Syntax::Methods)

  config.before(:suite) do
    FactoryBot.find_definitions
  end
end
