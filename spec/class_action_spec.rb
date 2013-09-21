require 'spec_helper'

class ClassActionTestController < ActionController::Base
  include ClassAction

  class Show < ClassAction::Action
  end
end

describe ClassAction do

  let(:controller) { ClassActionTestController.new }

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
    end

  end

end