# frozen_string_literal: true

RSpec.describe JsonapiResponses do
  it 'has a version number' do
    expect(JsonapiResponses::VERSION).not_to be nil
  end
end
