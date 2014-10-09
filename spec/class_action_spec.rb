require 'spec_helper'

describe ClassAction do

  let(:controller) { ClassActionTestController.new }

  before do
    Object.send :remove_const, :ClassActionTestController if defined?(ClassActionTestController)

    class ::ClassActionTestController < ActionController::Base
      include ClassAction

      def self.logger
        @logger ||= Logger.new(STDOUT)
      end

      class ShowAction < ClassAction::Action
      end

      class OtherShowAction < ClassAction::Action
      end
    end
  end

  context "adding a class action :show" do

    before { ClassActionTestController.class_eval { class_action :show } }

    it "should respond to method :show" do
      expect(controller).to respond_to(:show)
    end

    it "should add helper methods from the action class to the view context class" do
      helpers = Module.new do
        def method_added_by_class_action
        end
      end

      action_class = double(:helpers => helpers)
      allow(controller).to receive(:class_action).and_return(double(:class => action_class))
      expect(controller.view_context).to respond_to(:method_added_by_class_action)
    end

    context "when executing the action" do
      let(:action) { action = double(:action, :_execute => nil) }
      before { expect(ClassActionTestController::ShowAction).to receive(:new).with(controller).and_return(action) }

      it "should try to instantiate TestController::ShowAction and execute it" do
        expect(action).to receive(:_execute)
        controller.show
      end

      it "should store the created action in the controller" do
        controller.show
        expect(controller.class_action).to be(action)
      end

      it "should not appear in the view assigns" do
        controller.show
        expect(controller.view_assigns).not_to have_key('_class_action')
      end

      it "should expose the current action as #_class_action" do
        controller.show
        allow(controller).to receive(:action_name).and_return('show')
        expect(controller.send(:_class_action)).to be(action)
      end

    end

    context "giving another action class" do
      before do
        ClassActionTestController.class_eval do
          class_action :show, klass: ClassActionTestController::OtherShowAction
        end
      end

      it "should try to instantiate the given action class when executed" do
        action = ClassActionTestController::OtherShowAction.new(controller)
        expect(ClassActionTestController::OtherShowAction).to receive(:new).with(controller).and_return(action)
        controller.show

        expect(controller.class_action).to be(action)
      end
    end

  end

  describe "respond mime injection" do

    before do
      ClassActionTestController::ShowAction.class_eval do
        respond_to :html
      end
    end

    it "should create mimes with :only => 'show' for nonexisting mimes" do
      ClassActionTestController.class_eval { class_action :show }
      expect(ClassActionTestController.mimes_for_respond_to).to eql(
        :html => {:only => %w[show]}
      )
    end

    it "should append the action 'show' to existing mimes with an :only restriction" do
      ClassActionTestController.class_eval do
        respond_to :html, :only => [ :index ]
        class_action :show
      end

      expect(ClassActionTestController.mimes_for_respond_to).to eql(
        :html => {:only => %w[index show]}
      )
    end

    it "should not append the action 'show' to existing mimes with no :only restriction" do
      ClassActionTestController.class_eval do
        respond_to :html
        class_action :show
      end

      expect(ClassActionTestController.mimes_for_respond_to).to eql(
        :html => {}
      )
    end

    it "should not append the action 'show' if it was already targeted" do
      ClassActionTestController.class_eval do
        respond_to :html, :only => [ :show ]
        class_action :show
      end

      expect(ClassActionTestController.mimes_for_respond_to).to eql(
        :html => { :only => %w[show] }
      )
    end

    it "should not append the action 'show' if it was also already to the :except list (but log a warning)" do
      expect(ClassActionTestController.logger).to receive(:warn).with("Warning: action show (ClassAction) responds to `html` but it does not accept this mime type")

      ClassActionTestController.class_eval do
        respond_to :html, :except => [ :show ]
        class_action :show
      end

      expect(ClassActionTestController.mimes_for_respond_to).to eql(
        :html => { :except => %w[show] }
      )
    end

    it "should exclude the action from any other mime types that may be defined" do
      ClassActionTestController.class_eval do
        respond_to :json
        class_action :show
      end

      expect(ClassActionTestController.mimes_for_respond_to).to eql(
        :html => { :only => %w[show] },
        :json => { :except => %w[show] }
      )
    end

    it "should leave everything alone if the class action has no responders" do
      allow(ClassActionTestController::ShowAction).to receive(:_responders).and_return({})

      ClassActionTestController.class_eval do
        respond_to :json
        class_action :show
      end

      expect(ClassActionTestController.mimes_for_respond_to).to eql(
        :json => {}
      )
    end

    it "should leave everything alone if the class action has an 'any' responder" do
      ClassActionTestController::ShowAction.class_eval do
        respond_to_any
      end

      ClassActionTestController.class_eval do
        respond_to :json
        class_action :show
      end

      expect(ClassActionTestController.mimes_for_respond_to).to eql(
        :json => {}
      )
    end

  end

  describe 'method delegation' do

    it "should allow delegating a method to the current class action" do
      ClassActionTestController.class_eval do
        class_action :show
        class_action_delegate :one, :two
      end

      action_class = Class.new do
        def one; :one end
        def two; :two end
        protected :two
      end

      allow(controller).to receive(:_class_action).and_return(action_class.new)
      expect(controller.one).to be(:one)
      expect(controller.two).to be(:two)
      expect{controller.three}.to raise_error(NoMethodError)
    end

  end

end