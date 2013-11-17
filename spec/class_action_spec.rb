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

      class Show < ClassAction::Action
      end

      class OtherShow < ClassAction::Action
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
      before { expect(ClassActionTestController::Show).to receive(:new).with(controller).and_return(action) }

      it "should try to instantiate TestController::Show and execute it" do
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
          class_action :show, klass: ClassActionTestController::OtherShow
        end
      end

      it "should try to instantiate the given action class when executed" do
        action = ClassActionTestController::OtherShow.new(controller)
        expect(ClassActionTestController::OtherShow).to receive(:new).with(controller).and_return(action)
        controller.show

        expect(controller.class_action).to be(action)
      end
    end

  end

  describe "respond mime injection" do

    before do
      ClassActionTestController::Show.class_eval do
        respond_to :html
      end
    end

    it "should create mimes with :only => 'show' for nonexisting mimes" do
      ClassActionTestController.class_eval { class_action :show }
      ClassActionTestController.mimes_for_respond_to.should eql(
        :html => {:only => %w[show]}
      )
    end

    it "should append the action 'show' to existing mimes with an :only restriction" do
      ClassActionTestController.class_eval do
        respond_to :html, :only => [ :index ]
        class_action :show
      end

      ClassActionTestController.mimes_for_respond_to.should eql(
        :html => {:only => %w[index show]}
      )
    end

    it "should not append the action 'show' to existing mimes with no :only restriction" do
      ClassActionTestController.class_eval do
        respond_to :html
        class_action :show
      end

      ClassActionTestController.mimes_for_respond_to.should eql(
        :html => {}
      )
    end

    it "should not append the action 'show' if it was already targeted" do
      ClassActionTestController.class_eval do
        respond_to :html, :only => [ :show ]
        class_action :show
      end

      ClassActionTestController.mimes_for_respond_to.should eql(
        :html => { :only => %w[show] }
      )
    end

    it "should not append the action 'show' if it was also already to the :except list (but log a warning)" do
      expect(ClassActionTestController.logger).to receive(:warn).with("Warning: action show (ClassAction) responds to `html` but it does not accept this mime type")

      ClassActionTestController.class_eval do
        respond_to :html, :except => [ :show ]
        class_action :show
      end

      ClassActionTestController.mimes_for_respond_to.should eql(
        :html => { :except => %w[show] }
      )
    end

    it "should exclude the action from any other mime types that may be defined" do
      ClassActionTestController.class_eval do
        respond_to :json
        class_action :show
      end

      ClassActionTestController.mimes_for_respond_to.should eql(
        :html => { :only => %w[show] },
        :json => { :except => %w[show] }
      )
    end

    it "should leave everything alone if the class action has no responders" do
      allow(ClassActionTestController::Show).to receive(:_responders).and_return({})

      ClassActionTestController.class_eval do
        respond_to :json
        class_action :show
      end

      ClassActionTestController.mimes_for_respond_to.should eql(
        :json => {}
      )
    end

    it "should leave everything alone if the class action has an 'any' responder" do
      ClassActionTestController::Show.class_eval do
        respond_to_any
      end

      ClassActionTestController.class_eval do
        respond_to :json
        class_action :show
      end

      ClassActionTestController.mimes_for_respond_to.should eql(
        :json => {}
      )
    end

  end

end