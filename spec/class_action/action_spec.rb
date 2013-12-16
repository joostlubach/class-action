require 'spec_helper'

describe ClassAction::Action do

  let(:controller) { double(:controller, :view_assigns => {}, :response_body => nil) }
  let(:action_class) { Class.new(ClassAction::Action) }
  let(:action) { action_class.new(controller) }
  before { allow(controller).to receive(:class_action).and_return(action) }

  it "should by default be available" do
    expect(action).to be_available
  end

  describe '.helpers && .helper_method' do
    it "should create an empty module upon inheritance" do
      expect(action_class.helpers).to be_a(Module)
    end

    before do
      action_class.class_eval do
        def helper1
          'HELPER RESULT'
        end
        helper_method :helper1
      end
    end

    it "should define the helper method in the action's helpers module, which should call the method on the controller action" do
      helpers = action_class.helpers
      klass = Class.new do
        include helpers
        attr_reader :controller
        def initialize(controller)
          @controller = controller
        end
      end

      obj = klass.new(controller)

      expect(obj).to respond_to(:helper1)
      expect(controller).to receive(:class_action).and_return(action)
      expect(obj.helper1).to eql('HELPER RESULT')
    end

    it "should also expose helper methods on the controller" do
      action # Load the action up to include the helpers module.
      expect(controller).to respond_to(:helper1)
      expect(controller.helper1).to eql('HELPER RESULT')
    end

    it "should also expose helper methods defined in a superclass" do
      action_subclass = Class.new(action_class) do
        def helper2
          'HELPER2'
        end
        helper_method :helper2
      end

      obj= Class.new{ include action_subclass.helpers }.new
      expect(obj).to respond_to(:helper1)
      expect(obj).to respond_to(:helper2)
    end

  end

  describe 'controller methods' do
    let(:result) { double(:result) }
    before { allow(controller).to receive(:load_post).and_return(result) }

    it "should make the action respond to :load_post, but protectedly" do
      expect(action).not_to respond_to(:load_post)
      expect(action.respond_to?(:load_post, true)).to be_true # matcher doesn't work with second argument
    end

    it "should pass the method :load_post on to the controller" do
      expect(action.load_post).to be(result)
    end

    it "should create a protected method :load_post the first time it is called" do
      expect(action.protected_methods).not_to include(:load_post)
      action.load_post
      expect(action.protected_methods).to include(:load_post)
    end

    it "should copy assigns to the controller before executing the controller method, and copy them back afterwards" do
      # Simulate an instance variable.
      var = 1
      allow(controller).to receive(:view_assigns) do
        {'var' => var}
      end
      allow(controller).to receive(:instance_variable_set).with(:@var, an_instance_of(Fixnum)) do |_, num|
        var = num
      end
      expect(controller).to receive(:increase_var) do
        var += 1
      end

      action_class.class_eval do
        def execute
          @var = 2
          increase_var
        end
      end

      # Even though it's set to 1 initially, it is set to 2 by copying
      # the assigns to the controller, and subsequently increased by 1
      # to end up as 3 - both the controller and the action's versions.

      action._execute
      expect(var).to eql(3)
      expect(action.instance_variable_get('@var')).to eql(3)
    end
  end

  describe '.action_methods' do
    it "should include (in order) - only the public defined action methods in the action class" do
      action_class.class_eval do
        def method1; end
        def method2; end

        protected
        def method3; end

        private
        def method4; end
      end

      expect(action_class._action_methods).to eql([ :method1, :method2 ])
    end
  end

  describe '#_execute' do
    it "should raise an exception if the action is not available" do
      expect(action).to receive(:available?).and_return(false)
      expect{ action._execute }.to raise_error(ClassAction::ActionNotAvailable)
    end

    it "should execute all action methods in the action, and call #copy_assigns_to_controller finally" do
      called = []

      expect(action_class).to receive(:_action_methods).and_return([:method1, :method2])

      action_class.class_eval do
        def method1
          @called << :method1
        end
        def method2
          @called << :method2
        end
      end

      action.instance_variable_set '@called', called
      action._execute
      expect(called).to eql([:method1, :method2])
    end

    it "should skip methods that take arguments" do
      action_class.class_eval do
        def one
          @called = []
          @called << :one
        end
        def two(*args)
          @called << :two
        end
        def three(arg)
          @called << :three
        end
        def three(arg = nil)
          @called << :four
        end
      end

      action._execute
      called = action.instance_variable_get('@called')
      expect(called).to eql([:one])
    end

    it "should stop executing when a response body is set" do
      called = []; response_body = nil

      allow(controller).to receive(:response_body) { response_body }
      allow(controller).to receive(:response).and_return(double())
      allow(controller.response).to receive(:body) { response_body }
      allow(controller.response).to receive(:body=) { |val| response_body = val }

      expect(action_class).to receive(:_action_methods).and_return([:method1, :method2])

      action_class.class_eval do
        def method1
          @called << :method1
          response.body = '<html></html>'
        end
        def method2
          @called << :method2
        end
      end

      action.instance_variable_set '@called', called
      action._execute
      expect(called).to eql([:method1])
    end

    it "should call _respond at the end" do
      called = []

      expect(action_class).to receive(:_action_methods).and_return([:method1, :method2])

      action_class.class_eval do
        def method1
          @called << :method1
        end
        def method2
          @called << :method2
        end
      end

      expect(action).to receive(:_respond) { called << :_respond }

      action.instance_variable_set '@called', called
      action._execute
      expect(called).to eql([:method1, :method2, :_respond])
    end

    it "should not call _respond if a response body is set" do
      allow(controller).to receive(:response_body).and_return('<html></html>')
      expect(action).not_to receive(:_respond)
      action._execute
    end

  end

  describe '#_respond' do

    # Note - as _respond is a private method, we will call _execute to test
    # this method. _execute does not perform other actions if no public methods
    # are defined.

    it "should always copy assignment variables back to the controller" do
      action_class.class_eval do
        def set_ivar
          @my_var = :test
        end
      end

      expect(controller).to receive(:instance_variable_set).with(:@my_var, :test)
      action._execute
    end

    context "with no response method or responders" do
      it "should not call a respond method, but copy all instance variables into the controller at the end" do
        expect(controller).not_to receive(:respond_with)
        expect(controller).not_to receive(:respond_to)
        action._execute
      end
    end

    context "having set a response method" do
      let(:response) { double(:response) }
      before do
        action_class.class_eval do
          respond_with :response
          respond_with :invalid_response, on: :invalid

          protected

          def invalid?() false end
        end
      end

      it "should use the value of #response" do
        expect(action).to receive(:response).and_return(response)
        expect(controller).to receive(:respond_with).with(response) do |&blk|
          expect(blk).to be_nil
        end

        action._execute
      end

      it "should use the value of #invalid_response if invalid? returns true" do
        allow(action).to receive(:invalid?).and_return(true)
        expect(action).to receive(:invalid_response).and_return(response)
        expect(controller).to receive(:respond_with).with(response)
        action._execute
      end

      it "should read an instance variable if this is set" do
        action_class.class_eval do
          respond_with :@response
        end
        action.instance_variable_set '@response', response
        expect(controller).to receive(:respond_with).with(response)
        action._execute
      end

      it "should use the _respond_block if it is set" do
        block = proc{}
        allow(action).to receive(:_respond_block).and_return(block)

        expect(action).to receive(:response).and_return(response)
        expect(controller).to receive(:respond_with).with(response) do |&blk|
          expect(blk).to be(block)
        end

        action._execute
      end

    end

    context "having set _respond_block" do

      it "should use the _respond_block" do
        block = proc{}
        allow(action).to receive(:_respond_block).and_return(block)

        expect(controller).to receive(:respond_to) do |&blk|
          expect(blk).to be(block)
        end

        action._execute
      end

    end

  end

  describe 'responders & _respond_block' do

    # Private method, but specced individually to make spec terser.

    def respond_block
      action.send(:_respond_block)
    end

    it "should create a block using the given responders, which is executed on the action" do
      called = nil; receiver = nil
      json_block = proc { receiver = self; called = :json }
      html_block = proc { receiver = self; called = :html }
      html_invalid_block = proc { receiver = self; called = :html_invalid }
      any_ok_block = proc { receiver = self; called = :any_ok }

      action_class.class_eval do
        respond_to :json, &json_block
        respond_to :html, &html_block
        respond_to :html, on: :invalid, &html_invalid_block
        respond_to_any on: :ok, &any_ok_block

        attr_accessor :status

        protected

          def ok?() status == :ok end
          def invalid?() status == :invalid end
      end

      # Simulate ActionController's format collector.
      collector = Class.new{ attr_reader :json_block, :html_block, :any_block }.new
      def collector.json(&block) @json_block = block end
      def collector.html(&block) @html_block = block end
      def collector.any(&block) @any_block = block end

      action.status = :ok
      respond_block.call collector
      collector.json_block.call
      expect(receiver).to be(action); expect(called).to be(:json)

      action.status = :invalid
      respond_block.call collector
      collector.json_block.call
      expect(receiver).to be(action); expect(called).to be(:json)

      action.status = :ok
      respond_block.call collector
      collector.html_block.call
      expect(receiver).to be(action); expect(called).to be(:html)

      action.status = :invalid
      respond_block.call collector
      collector.html_block.call
      expect(receiver).to be(action); expect(called).to be(:html_invalid)

      action.status = :ok
      respond_block.call collector
      collector.any_block.call
      expect(receiver).to be(action); expect(called).to be(:any_ok)

      receiver = nil
      called = nil

      action.status = :invalid
      expect(collector).not_to receive(:any)
      respond_block.call collector
    end

    it "should copy assigns back to the controller after responding" do
      action_class.class_eval do
        respond_to :html do
          @my_var = :value
        end
      end

      collector = Class.new{ attr_reader :html_block }.new
      def collector.html(&block) @html_block = block end
      respond_block.call collector

      collector.html_block.call
      expect(controller.instance_variable_get('@my_var')).to be(:value)
    end

    it "should take responders to a subclass" do
      action_class.class_eval do
        respond_to :html
      end
      action_subclass = Class.new(action_class) do
        respond_to :json
      end

      expect(action_subclass._responders).to eql(
        [ :html, nil ] => nil,
        [ :json, nil ] => nil
      )
    end

    it "should copy the respond_with_method to a subclass" do
      action_class.class_eval do
        respond_with :post
      end

      action_subclass = Class.new(action_class)
      expect(action_subclass).to have(1)._response
      expect(action_subclass._responses.keys[0]).to be_nil
      expect(action_subclass._responses.values[0]).to be(:post)
    end

  end

end