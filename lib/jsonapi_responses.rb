require_relative 'jsonapi_responses/version'
require_relative 'jsonapi_responses/responder'
require_relative 'jsonapi_responses/respondable'
require 'jsonapi_responses/engine'
require 'active_support'
require 'rails'

module JsonapiResponses
  class Error < StandardError; end
end
