require 'rails_helper'
require 'jsonapi_responses/serializable'

RSpec.describe JsonapiResponses::Serializable do
  let(:item) { create(:item) }
  let(:serializer_class) { ItemSerializer }

  let(:dummy_class) do
    Class.new do
      include JsonapiResponses::Serializable
    end
  end

  let(:instance) { dummy_class.new }

  describe '#serialize_item' do
    context 'when context is minimal' do
      let(:context) { { view: :minimal } }

      it 'serializes an item with minimal attributes' do
        result = instance.serialize_item(item, serializer_class, context)
        expect(result).to include(:id, :name)
        expect(result).not_to include(:description, :category, :slogan, :score)
      end
    end

    context 'when context is summary' do
      let(:context) { { view: :summary } }

      it 'serializes an item with summary attributes' do
        result = instance.serialize_item(item, serializer_class, context)
        expect(result).to include(:id, :name, :description, :category)
        expect(result).not_to include(:slogan, :score)
      end
    end

    context 'when context is full' do
      let(:context) { { view: :full } }

      it 'serializes an item with all attributes' do
        result = instance.serialize_item(item, serializer_class, context)
        expect(result).to include(:id, :name, :description, :category, :slogan, :score)
      end
    end
  end
end
