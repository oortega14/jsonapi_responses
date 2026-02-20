# frozen_string_literal: true

require 'spec_helper'
require 'jsonapi_responses/responder'

RSpec.describe JsonapiResponses::Responder do
  # ---------------------------------------------------------------------------
  # Shared test doubles
  # ---------------------------------------------------------------------------

  # A minimal serializer with a full serializable_hash AND a named action method
  let(:serializer_with_action) do
    Class.new do
      attr_reader :resource, :context

      def initialize(resource, context = {})
        @resource = resource
        @context  = context
      end

      def serializable_hash
        { id: resource[:id], name: resource[:name], view: :default }
      end

      # Named action method — the Pundit-style hook
      def confirm
        { id: resource[:id], email: resource[:email], confirmed: true }
      end

      def summary
        { id: resource[:id], name: resource[:name] }
      end
    end
  end

  # A plain serializer with only serializable_hash (no named methods)
  let(:serializer_without_action) do
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

  # A minimal fake controller that can capture render calls
  let(:fake_controller) do
    Class.new do
      attr_reader :last_render

      def render(options)
        @last_render = options
        options
      end

      def params
        {}
      end

      def current_user
        nil
      end
    end.new
  end

  let(:record) { { id: 42, name: 'Oscar', email: 'oscar@example.com' } }

  # Helper to instantiate a responder inline
  def build_responder(serializer_class, record: nil, context: {}, &block)
    r = record || { id: 1 }
    klass = Class.new(described_class, &block)
    klass.new(fake_controller, r, serializer_class, context)
  end

  # ---------------------------------------------------------------------------
  # serialize_for — core behaviour
  # ---------------------------------------------------------------------------

  describe '#serialize_for' do
    context 'when the serializer defines the named method' do
      it 'calls the named method instead of serializable_hash' do
        responder = build_responder(serializer_with_action, record: record)

        result = responder.send(:serialize_for, :confirm)

        expect(result).to eq({ id: 42, email: 'oscar@example.com', confirmed: true })
      end

      it 'works with any named method (not just confirm)' do
        responder = build_responder(serializer_with_action, record: record)

        result = responder.send(:serialize_for, :summary)

        expect(result).to eq({ id: 42, name: 'Oscar' })
      end
    end

    context 'when the serializer does NOT define the named method' do
      it 'falls back to serializable_hash' do
        responder = build_responder(serializer_without_action, record: record)

        result = responder.send(:serialize_for, :confirm)

        expect(result).to eq({ id: 42, name: 'Oscar' })
      end

      it 'falls back for any unknown action name' do
        responder = build_responder(serializer_without_action, record: record)

        result = responder.send(:serialize_for, :some_random_action)

        expect(result).to eq({ id: 42, name: 'Oscar' })
      end
    end

    context 'when a custom item is passed' do
      it 'serializes the custom item instead of record' do
        responder = build_responder(serializer_with_action, record: record)
        other_item = { id: 99, name: 'Other', email: 'other@example.com' }

        result = responder.send(:serialize_for, :confirm, other_item)

        expect(result[:id]).to eq(99)
        expect(result[:email]).to eq('other@example.com')
      end
    end

    context 'when a custom serializer is passed' do
      it 'uses the custom serializer instead of serializer_class' do
        responder = build_responder(serializer_without_action, record: record)

        result = responder.send(:serialize_for, :confirm, nil, serializer_with_action)

        expect(result).to include(:email, :confirmed)
      end
    end

    context 'when a custom context is passed' do
      it 'passes the custom context to the serializer' do
        capturing_serializer = Class.new do
          attr_reader :resource, :context

          def initialize(resource, context = {})
            @resource = resource
            @context  = context
          end

          def serializable_hash
            { id: resource[:id], ctx: context }
          end

          def confirm
            { id: resource[:id], ctx: context }
          end
        end

        responder = build_responder(capturing_serializer, record: record, context: { view: :full })
        custom_ctx = { view: :minimal, current_user: 'admin' }

        result = responder.send(:serialize_for, :confirm, nil, nil, custom_ctx)

        expect(result[:ctx]).to eq(custom_ctx)
      end
    end

    context 'when serializer_class is nil (no serializer found/needed)' do
      it 'raises a NoMethodError with a clear message' do
        # This scenario happens when no serializer exists for the controller
        # and render_with resolved serializer_class to nil.
        # The responder should not call serialize_for in that case,
        # but if it does, the error should be clear.
        responder = build_responder(nil, record: record)

        expect { responder.send(:serialize_for, :confirm) }.to raise_error(NoMethodError)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Integration: responder using serialize_for inside an action method
  # ---------------------------------------------------------------------------

  describe 'integration: action method using serialize_for' do
    it 'renders the correct envelope with serializer-provided shape' do
      confirmation_responder_class = Class.new(described_class) do
        def confirm
          render_json({
            message: context[:message],
            user: serialize_for(:confirm)
          })
        end
      end

      responder = confirmation_responder_class.new(
        fake_controller,
        record,
        serializer_with_action,
        { message: 'Email confirmed!' }
      )

      responder.confirm

      rendered = fake_controller.last_render
      expect(rendered[:json][:message]).to eq('Email confirmed!')
      expect(rendered[:json][:user]).to eq({ id: 42, email: 'oscar@example.com', confirmed: true })
    end

    it 'falls back to serializable_hash when serializer has no named method' do
      confirmation_responder_class = Class.new(described_class) do
        def confirm
          render_json({
            message: context[:message],
            user: serialize_for(:confirm)
          })
        end
      end

      responder = confirmation_responder_class.new(
        fake_controller,
        record,
        serializer_without_action,
        { message: 'Email confirmed!' }
      )

      responder.confirm

      rendered = fake_controller.last_render
      expect(rendered[:json][:user]).to eq({ id: 42, name: 'Oscar' })
    end
  end

  # ---------------------------------------------------------------------------
  # Existing helpers still work (non-regression)
  # ---------------------------------------------------------------------------

  describe '#serialize_item' do
    it 'delegates to controller#serialize_item' do
      allow(fake_controller).to receive(:serialize_item) do |item, _serializer, _ctx|
        { id: item[:id], serialized: true }
      end

      responder = described_class.new(fake_controller, record, serializer_with_action, {})

      result = responder.send(:serialize_item)

      expect(result).to eq({ id: 42, serialized: true })
    end
  end

  describe '#render_json' do
    it 'delegates to controller#render with json key' do
      responder = described_class.new(fake_controller, record, serializer_with_action, {})

      responder.send(:render_json, { foo: 'bar' })

      expect(fake_controller.last_render).to eq({ json: { foo: 'bar' } })
    end

    it 'merges extra options' do
      responder = described_class.new(fake_controller, record, serializer_with_action, {})

      responder.send(:render_json, { foo: 'bar' }, status: :created)

      expect(fake_controller.last_render).to eq({ json: { foo: 'bar' }, status: :created })
    end
  end

  describe '#collection?' do
    it 'returns true for an Array' do
      responder = described_class.new(fake_controller, [record], serializer_with_action, {})
      expect(responder.send(:collection?)).to be(true)
    end

    it 'returns false for a Hash' do
      responder = described_class.new(fake_controller, record, serializer_with_action, {})
      expect(responder.send(:collection?)).to be(false)
    end
  end
end
