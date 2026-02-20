# frozen_string_literal: true

require 'spec_helper'
require 'jsonapi_responses/respondable'
require 'jsonapi_responses/responder'

RSpec.describe JsonapiResponses::Respondable do
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
        { id: resource[:id], name: resource[:name], view: context[:view] || :default }
      end
    end
  end

  # A base controller double that includes Respondable
  let(:base_controller_class) do
    serializer = dummy_serializer

    Class.new do
      include JsonapiResponses::Respondable

      attr_reader :action_name, :last_render, :controller_name
      attr_accessor :params

      def initialize(action, controller_name = 'items')
        @action_name     = action.to_s
        @controller_name = controller_name
        @params          = {}
      end

      def render(options)
        @last_render = options
        options
      end

      def serialize_collection(collection, serializer_class, context)
        collection.map { |item| serializer_class.new(item, context).serializable_hash }
      end

      def serialize_item(item, serializer_class, context)
        serializer_class.new(item, context).serializable_hash
      end

      def serialization_user
        {}
      end

      define_method(:item_serializer) { serializer }
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def build_controller(action, name = 'items')
    base_controller_class.new(action, name)
  end

  # ---------------------------------------------------------------------------
  # render_with + responder integration (end-to-end)
  # ---------------------------------------------------------------------------

  describe 'render_with with a custom responder' do
    let(:record) { { id: 1, name: 'Rails' } }

    it 'instantiates the responder and calls the named action method' do
      responder_class = Class.new(JsonapiResponses::Responder) do
        def subscribe
          render_json({ enrolled: true, course_id: record[:id] })
        end
      end

      # stub the serializer constant so render_with can resolve it
      stub_const('ItemSerializer', dummy_serializer)

      controller = build_controller(:subscribe)
      controller.send(:render_with, record, responder: responder_class, action: :subscribe)

      expect(controller.last_render[:json]).to eq({ enrolled: true, course_id: 1 })
    end

    it 'passes context to the responder' do
      responder_class = Class.new(JsonapiResponses::Responder) do
        def confirm
          render_json({ message: context[:message], id: record[:id] })
        end
      end

      stub_const('ItemSerializer', dummy_serializer)

      controller = build_controller(:confirm)
      controller.send(
        :render_with,
        record,
        responder: responder_class,
        action: :confirm,
        serializer: dummy_serializer,
        context: { message: 'Done!' }
      )

      expect(controller.last_render[:json]).to eq({ message: 'Done!', id: 1 })
    end

    it 'calls #render (not the named action) when no action: is given' do
      responder_class = Class.new(JsonapiResponses::Responder) do
        def render
          render_json({ fallback: true })
        end
      end

      stub_const('ItemSerializer', dummy_serializer)

      controller = build_controller(:index)
      controller.send(:render_with, record, responder: responder_class)

      expect(controller.last_render[:json]).to eq({ fallback: true })
    end

    it 'passes serializer_class to the responder so serialize_item works' do
      responder_class = Class.new(JsonapiResponses::Responder) do
        def show
          render_json({ data: serialize_item })
        end
      end

      stub_const('ItemSerializer', dummy_serializer)

      controller = build_controller(:show)
      controller.send(:render_with, record, responder: responder_class, action: :show)

      expect(controller.last_render[:json][:data]).to include(id: 1, name: 'Rails')
    end
  end

  # ---------------------------------------------------------------------------
  # Serializer nil — graceful resolution (the NameError fix)
  # ---------------------------------------------------------------------------

  describe 'render_with with missing inferred serializer' do
    it 'resolves serializer_class to nil instead of raising NameError' do
      responder_class = Class.new(JsonapiResponses::Responder) do
        def confirm
          # Does not call serialize_for — just renders a plain hash
          render_json({ ok: true })
        end
      end

      # Controller name 'confirmations' → would try ConfirmationSerializer → does NOT exist
      controller = build_controller(:confirm, 'confirmations')

      expect {
        controller.send(
          :render_with,
          { id: 1 },
          responder: responder_class,
          action: :confirm
        )
      }.not_to raise_error

      expect(controller.last_render[:json]).to eq({ ok: true })
    end

    it 'uses explicitly passed serializer: even when inferred one does not exist' do
      responder_class = Class.new(JsonapiResponses::Responder) do
        def confirm
          render_json({ data: serialize_item })
        end
      end

      controller = build_controller(:confirm, 'confirmations')
      record     = { id: 7, name: 'Test' }

      controller.send(
        :render_with,
        record,
        responder: responder_class,
        action: :confirm,
        serializer: dummy_serializer
      )

      expect(controller.last_render[:json][:data]).to include(id: 7, name: 'Test')
    end
  end

  # ---------------------------------------------------------------------------
  # Default CRUD handlers
  # ---------------------------------------------------------------------------

  describe 'default CRUD handlers' do
    before { stub_const('ItemSerializer', dummy_serializer) }

    describe 'respond_for_index' do
      it 'renders a data array' do
        controller = build_controller(:index)
        records    = [{ id: 1, name: 'A' }, { id: 2, name: 'B' }]

        controller.send(:render_with, records)

        expect(controller.last_render[:json][:data]).to be_an(Array)
        expect(controller.last_render[:json][:data].size).to eq(2)
      end

      it 'wraps collection under data key' do
        controller = build_controller(:index)
        controller.send(:render_with, [{ id: 1, name: 'X' }])

        expect(controller.last_render[:json]).to have_key(:data)
      end
    end

    describe 'respond_for_show' do
      it 'renders a single serialized item' do
        controller = build_controller(:show)
        record     = { id: 5, name: 'Course' }

        controller.send(:render_with, record)

        expect(controller.last_render[:json]).to include(id: 5, name: 'Course')
      end
    end

    describe 'respond_for_create' do
      it 'renders :created status and item when record.save returns true' do
        saveable_record = { id: 3, name: 'New' }
        saveable_record.define_singleton_method(:save) { true }
        saveable_record.define_singleton_method(:errors) do
          obj = Object.new
          obj.define_singleton_method(:full_messages) { [] }
          obj
        end

        controller = build_controller(:create)
        controller.send(:render_with, saveable_record)

        expect(controller.last_render[:status]).to eq(:created)
      end

      it 'renders :unprocessable_entity when record.save returns false' do
        failing_record = { id: nil, name: nil }
        failing_record.define_singleton_method(:save) { false }
        failing_record.define_singleton_method(:errors) do
          obj = Object.new
          obj.define_singleton_method(:full_messages) { ['Name is blank'] }
          obj
        end

        controller = build_controller(:create)
        controller.send(:render_with, failing_record)

        expect(controller.last_render[:status]).to eq(:unprocessable_entity)
        expect(controller.last_render[:json][:errors]).to include('Name is blank')
      end
    end

    describe 'respond_for_update' do
      it 'renders :ok when record has no errors' do
        clean_record = { id: 1, name: 'Updated' }
        clean_record.define_singleton_method(:errors) do
          obj = Object.new
          obj.define_singleton_method(:empty?) { true }
          obj.define_singleton_method(:full_messages) { [] }
          obj
        end

        controller = build_controller(:update)
        controller.send(:render_with, clean_record)

        expect(controller.last_render[:status]).to eq(:ok)
      end

      it 'renders :unprocessable_entity when record has errors' do
        dirty_record = { id: 1, name: nil }
        dirty_record.define_singleton_method(:errors) do
          obj = Object.new
          obj.define_singleton_method(:empty?) { false }
          obj.define_singleton_method(:full_messages) { ['Name is blank'] }
          obj
        end

        controller = build_controller(:update)
        controller.send(:render_with, dirty_record)

        expect(controller.last_render[:status]).to eq(:unprocessable_entity)
      end
    end

    describe 'respond_for_destroy' do
      it 'renders success message when record.destroy returns true' do
        destroyable = { id: 1 }
        destroyable.define_singleton_method(:destroy) { true }
        destroyable.define_singleton_method(:errors) do
          obj = Object.new
          obj.define_singleton_method(:full_messages) { [] }
          obj
        end

        controller = build_controller(:destroy)
        controller.send(:render_with, destroyable)

        expect(controller.last_render[:json]).to have_key(:message)
        expect(controller.last_render[:status]).to eq(:ok)
      end

      it 'renders errors when record.destroy returns false' do
        non_destroyable = { id: 1 }
        non_destroyable.define_singleton_method(:destroy) { false }
        non_destroyable.define_singleton_method(:errors) do
          obj = Object.new
          obj.define_singleton_method(:full_messages) { ['Cannot delete'] }
          obj
        end

        controller = build_controller(:destroy)
        controller.send(:render_with, non_destroyable)

        expect(controller.last_render[:json][:errors]).to include('Cannot delete')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # view param forwarding
  # ---------------------------------------------------------------------------

  describe 'view param forwarding' do
    before { stub_const('ItemSerializer', dummy_serializer) }

    it 'forwards params[:view] into context when not explicitly set' do
      controller        = build_controller(:show)
      controller.params = { view: 'minimal' }
      record            = { id: 1, name: 'X' }

      controller.send(:render_with, record)

      # The serialized result should contain view: :minimal (set by params)
      expect(controller.last_render[:json][:view]).to eq(:minimal)
    end

    it 'explicit context[:view] takes precedence over params[:view]' do
      controller        = build_controller(:show)
      controller.params = { view: 'minimal' }
      record            = { id: 1, name: 'X' }

      controller.send(:render_with, record, context: { view: :full })

      expect(controller.last_render[:json][:view]).to eq(:full)
    end
  end
end
