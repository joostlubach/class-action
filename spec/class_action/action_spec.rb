require 'spec_helper'

describe ClassAction::Action do

  let(:controller) { double(:controller, :view_assigns => {}) }
  let(:action_class) { Class.new(ClassAction::Action) }
  let(:action) { action_class.new(controller) }

  it "should by default be available" do
    expect(action).to be_available
  end

  describe '.helpers && .helper_method' do
    it "should create an empty module upon inheritance" do
      expect(action_class.helpers).to be_a(Module)
    end

    it "should define the helper method in the action's helpers module, which should call the method on the controller action" do
      action_class.class_eval do
        def helper1
          'HELPER RESULT'
        end
        helper_method :helper1
      end

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
  end

  describe '.controller_method' do
    before { allow(controller).to receive(:load_post) }
    before { action_class.class_eval { controller_method :load_post } }

    it "should create a protected method :load_post" do
      expect(action.protected_methods).to include(:load_post)
    end

    it "should create a proxy to the controller" do
      result = double(:result)
      expect(controller).to receive(:load_post).and_return(result)
      expect(action.send(:load_post)).to be(result)
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
        controller_method :increase_var
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

      expect(action_class.action_methods).to eql([ :method1, :method2 ])
    end
  end

  describe '#_execute' do
    it "should raise an exception if the action is not available" do
      expect(action).to receive(:available?).and_return(false)
      expect{ action._execute }.to raise_error(ClassAction::ActionNotAvailable)
    end

    it "should execute all action methods in the action, and call #copy_assigns_to_controller finally" do
      called = []

      expect(action_class).to receive(:action_methods).and_return([:method1, :method2])
      expect(action).to receive(:method1) { called << :method1 }
      expect(action).to receive(:method2) { called << :method2 }

      action._execute
      expect(called).to eql([:method1, :method2])
    end

    it "should copy all instance variables into the controller at the end" do
      action_class.class_eval do
        def set_ivar
          @my_var = :test
        end
      end

      expect(controller).to receive(:instance_variable_set).with(:@my_var, :test)
      action._execute
    end

  end



end