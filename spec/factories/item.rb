# spec/factories/items.rb
FactoryBot.define do
  factory :item do
    sequence(:id) { |n| n }
    name { 'Test Item' }
    description { 'This is a test item.' }
    category { 'Test Category' }
    slogan { 'The best item ever' }
    score { 10 }
  end
end
