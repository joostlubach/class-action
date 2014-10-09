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

  describe 'lazy loading' do

    let(:action_load_path) { %w(app/controllers/my_controller/actions/*.rb app/controllers/my_controller/other_actions/*.rb) }

    before do
      # Fake three files
      allow(Dir).to receive(:glob).with(action_load_path[0]).and_return(
        ['app/controllers/my_controller/actions/first_action.rb']
      )
      allow(Dir).to receive(:glob).with(action_load_path[1]).and_return(
        ['app/controllers/my_controller/actions/second_action.rb', 'app/controllers/my_controller/actions/third_action.rb']
      )

      allow(ActiveSupport::Dependencies).to receive(:require) do |arg|
        case arg
          when 'app/controllers/my_controller/actions/first_action.rb'
            class ::ClassActionTestController::FirstAction < ActionController::Base; end

          when 'app/controllers/my_controller/actions/second_action.rb'
            # Incorrect name
            class ::ClassActionTestController::NotSecondAction < ActionController::Base; end

          when 'app/controllers/my_controller/actions/third_action.rb'
            class ::ClassActionTestController::ThirdAction < ActionController::Base; end
        end
      end
    end

    before do
      allow(ClassActionTestController).to receive(:action_load_path).and_return(action_load_path)
    end

    it "should raise an error if the class is not found and no load path is specified" do
      allow(ClassActionTestController).to receive(:action_load_path).and_return([])
      expect { ClassActionTestController.send(:find_action_class, :first) }
        .to raise_error("action class ClassActionTestController::FirstAction not found and no action_load_path defined")
    end

    it "should find FirstAction" do
      expect(ClassActionTestController.send(:find_action_class, :first)).to be(ClassActionTestController::FirstAction)
    end

    it "should find ThirdAction" do
      expect(ClassActionTestController.send(:find_action_class, :third)).to be(ClassActionTestController::ThirdAction)
    end

    it "should raise an error if no file was found in the load path" do
      expect { ClassActionTestController.send(:find_action_class, :fourth) }
        .to raise_error(LoadError, "file 'fourth_action.rb' not found in the load path for ClassActionTestController")
    end

    it "should raise an error on second as the wrong class is defined there" do
      expect { ClassActionTestController.send(:find_action_class, :second) }
        .to raise_error(LoadError, "expected file 'app/controllers/my_controller/actions/second_action.rb' to define action class SecondAction but it was not defined")
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