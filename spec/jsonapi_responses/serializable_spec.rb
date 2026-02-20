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

    context 'when context has no view key' do
      let(:context) { {} }

      it 'falls back to full_hash (default branch)' do
        result = instance.serialize_item(item, serializer_class, context)
        expect(result).to include(:id, :name, :description, :category, :slogan, :score)
      end
    end

    context 'when context is nil' do
      it 'does not raise and uses default view' do
        expect {
          instance.serialize_item(item, serializer_class, nil)
        }.not_to raise_error
      end
    end

    context 'when context has unknown view' do
      let(:context) { { view: :nonexistent_view } }

      it 'falls back to full_hash' do
        result = instance.serialize_item(item, serializer_class, context)
        expect(result).to include(:slogan, :score)
      end
    end
  end

  describe '#serialize_collection' do
    let(:context) { { view: :minimal } }

    it 'returns an array of serialized items' do
      items  = build_list(:item, 3)
      result = instance.serialize_collection(items, serializer_class, context)

      expect(result).to be_an(Array)
      expect(result.size).to eq(3)
    end

    it 'applies the same context to each item' do
      items  = build_list(:item, 2)
      result = instance.serialize_collection(items, serializer_class, { view: :minimal })

      result.each do |serialized|
        expect(serialized).to include(:id, :name)
        expect(serialized).not_to include(:description, :slogan)
      end
    end

    it 'returns an empty array for an empty collection' do
      result = instance.serialize_collection([], serializer_class, context)
      expect(result).to eq([])
    end

    it 'returns full view for each item when no view specified' do
      items  = build_list(:item, 2)
      result = instance.serialize_collection(items, serializer_class, {})

      result.each do |serialized|
        expect(serialized).to include(:id, :name, :description, :slogan, :score)
      end
    end
  end
end
