# frozen_string_literal: true

require 'rails_helper'
require 'jsonapi_responses/responder'
require_relative '../../app/serializers/application_serializer'
require_relative '../../app/responders/application_responder'

RSpec.describe ApplicationResponder do
  # ---------------------------------------------------------------------------
  # Shared test doubles
  # ---------------------------------------------------------------------------

  let(:dummy_serializer) do
    Class.new do
      attr_reader :resource, :context

      def initialize(resource, context = {})
        @resource = resource
        @context  = context
      end

      def serializable_hash
        { id: resource[:id], name: resource[:name] }
      end
    end
  end

  let(:fake_controller) do
    serializer = dummy_serializer

    ctrl = Class.new do
      attr_reader :last_render, :params

      def initialize
        @params = {}
      end

      def render(options)
        @last_render = options
        options
      end

      def current_user
        nil
      end

      define_method(:serialize_collection) do |collection, serializer_class, ctx|
        collection.map { |item| serializer_class.new(item, ctx).serializable_hash }
      end

      define_method(:serialize_item) do |item, serializer_class, ctx|
        serializer_class.new(item, ctx).serializable_hash
      end
    end.new

    ctrl
  end

  def build_responder(record, context: {})
    ApplicationResponder.new(fake_controller, record, dummy_serializer, context)
  end

  # ---------------------------------------------------------------------------
  # render_collection_with_meta
  # ---------------------------------------------------------------------------

  describe '#render_collection_with_meta' do
    let(:collection) { [{ id: 1, name: 'A' }, { id: 2, name: 'B' }] }

    it 'renders data array with meta' do
      responder = build_responder(collection)
      responder.send(:render_collection_with_meta)

      result = fake_controller.last_render[:json]
      expect(result[:data]).to be_an(Array)
      expect(result[:meta]).to be_a(Hash)
    end

    it 'includes type in meta when provided' do
      responder = build_responder(collection)
      responder.send(:render_collection_with_meta, type: 'featured')

      expect(fake_controller.last_render[:json][:meta][:type]).to eq('featured')
    end

    it 'does not include type key when type is nil' do
      responder = build_responder(collection)
      responder.send(:render_collection_with_meta)

      expect(fake_controller.last_render[:json][:meta]).not_to have_key(:type)
    end

    it 'merges additional_meta into meta' do
      responder = build_responder(collection)
      responder.send(:render_collection_with_meta, additional_meta: { period: 'month', algorithm: 'score' })

      meta = fake_controller.last_render[:json][:meta]
      expect(meta[:period]).to eq('month')
      expect(meta[:algorithm]).to eq('score')
    end

    it 'includes count in meta equal to collection size' do
      responder = build_responder(collection)
      responder.send(:render_collection_with_meta)

      expect(fake_controller.last_render[:json][:meta][:count]).to eq(2)
    end

    it 'includes timestamp in meta' do
      responder = build_responder(collection)
      responder.send(:render_collection_with_meta)

      expect(fake_controller.last_render[:json][:meta][:timestamp]).not_to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # render_item_with_meta
  # ---------------------------------------------------------------------------

  describe '#render_item_with_meta' do
    let(:item) { { id: 5, name: 'Course' } }

    it 'renders data item with meta' do
      responder = build_responder(item)
      responder.send(:render_item_with_meta)

      result = fake_controller.last_render[:json]
      expect(result[:data]).to include(id: 5, name: 'Course')
      expect(result[:meta]).to be_a(Hash)
    end

    it 'merges additional_meta' do
      responder = build_responder(item)
      responder.send(:render_item_with_meta, additional_meta: { access_level: 'admin' })

      expect(fake_controller.last_render[:json][:meta][:access_level]).to eq('admin')
    end
  end

  # ---------------------------------------------------------------------------
  # base_meta
  # ---------------------------------------------------------------------------

  describe '#base_meta' do
    it 'includes timestamp as ISO8601 string' do
      responder = build_responder({ id: 1 })
      meta      = responder.send(:base_meta)

      expect(meta[:timestamp]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it 'includes count nil for single items' do
      responder = build_responder({ id: 1 })
      meta      = responder.send(:base_meta)

      expect(meta).not_to have_key(:count)
    end

    it 'includes count for collections' do
      responder = build_responder([{ id: 1 }, { id: 2 }, { id: 3 }])
      meta      = responder.send(:base_meta)

      expect(meta[:count]).to eq(3)
    end
  end

  # ---------------------------------------------------------------------------
  # record_count
  # ---------------------------------------------------------------------------

  describe '#record_count' do
    it 'returns nil for single item' do
      responder = build_responder({ id: 1 })
      expect(responder.send(:record_count)).to be_nil
    end

    it 'returns size for arrays' do
      responder = build_responder([{ id: 1 }, { id: 2 }])
      expect(responder.send(:record_count)).to eq(2)
    end

    it 'uses .count when available' do
      countable = [{ id: 1 }]
      allow(countable).to receive(:count).and_return(99)

      responder = build_responder(countable)
      expect(responder.send(:record_count)).to eq(99)
    end
  end

  # ---------------------------------------------------------------------------
  # render_grouped_data
  # ---------------------------------------------------------------------------

  describe '#render_grouped_data' do
    it 'renders pre-structured hash directly' do
      groups    = { beginner: [{ id: 1 }], advanced: [{ id: 2 }] }
      responder = build_responder([])

      responder.send(:render_grouped_data, groups)

      expect(fake_controller.last_render[:json]).to eq(groups)
    end
  end

  # ---------------------------------------------------------------------------
  # paginated? and pagination_meta
  # ---------------------------------------------------------------------------

  describe '#paginated? and #pagination_meta' do
    let(:paginated_collection) do
      col = [{ id: 1 }, { id: 2 }]
      col.define_singleton_method(:current_page)  { 2 }
      col.define_singleton_method(:total_pages)   { 5 }
      col.define_singleton_method(:total_count)   { 100 }
      col.define_singleton_method(:limit_value)   { 20 }
      col
    end

    it 'returns true for a paginated collection' do
      responder = build_responder(paginated_collection)
      expect(responder.send(:paginated?)).to be(true)
    end

    it 'returns false for a plain array' do
      responder = build_responder([{ id: 1 }])
      expect(responder.send(:paginated?)).to be(false)
    end

    it 'returns nil when not paginated' do
      responder = build_responder([{ id: 1 }])
      expect(responder.send(:pagination_meta)).to be_nil
    end

    it 'returns pagination hash for paginated collection' do
      responder = build_responder(paginated_collection)
      meta      = responder.send(:pagination_meta)

      expect(meta[:current_page]).to eq(2)
      expect(meta[:total_pages]).to  eq(5)
      expect(meta[:total_count]).to  eq(100)
      expect(meta[:per_page]).to     eq(20)
    end
  end

  # ---------------------------------------------------------------------------
  # filters_applied
  # ---------------------------------------------------------------------------

  describe '#filters_applied' do
    it 'returns nil when no filter params are present' do
      responder = build_responder({ id: 1 })
      expect(responder.send(:filters_applied)).to be_nil
    end

    it 'returns hash of present filter params' do
      fake_controller.instance_variable_set(:@params, { category_id: '3', level: 'beginner' })
      responder = build_responder({ id: 1 })

      result = responder.send(:filters_applied, [:category_id, :level])
      expect(result).to eq({ category_id: '3', level: 'beginner' })
    end

    it 'ignores blank param values' do
      fake_controller.instance_variable_set(:@params, { category_id: '', level: 'advanced' })
      responder = build_responder({ id: 1 })

      result = responder.send(:filters_applied, [:category_id, :level])
      expect(result).to eq({ level: 'advanced' })
    end
  end
end
