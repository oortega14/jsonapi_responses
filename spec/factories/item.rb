# spec/factories/items.rb
FactoryBot.define do
  factory :item do
    skip_create  # no database — Item is a plain Struct

    sequence(:id) { |n| n }
    name        { 'Test Item' }
    description { 'This is a test item.' }
    category    { 'Test Category' }
    slogan      { 'The best item ever' }
    score       { 10 }
  end
end
