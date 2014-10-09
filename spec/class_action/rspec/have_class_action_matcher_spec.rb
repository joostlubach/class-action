require 'spec_helper'
require 'class_action/rspec'

describe ClassAction::RSpec::HaveClassActionMatcher do

  class ClassActionTestController < ActionController::Base
    class IndexAction < ClassAction::Action
    end
    class Index2Action < ClassAction::Action
    end
    class OtherIndex2Action < ClassAction::Action
    end
  end

  let(:controller) { ClassActionTestController.new }

  it "should fail if the controller does not support class actions" do
    expect { expect(controller).to have_class_action(:index) }.to \
      raise_error(
        RSpec::Expectations::ExpectationNotMetError,
        "expected controller of class ClassActionTestController to have class action :index, but it does not support class actions"
      )
  end

  context "having included ClassAction" do
    before { ClassActionTestController.send :include, ClassAction }

    it "should fail if the controller does not have an index action" do
      expect { expect(controller).to have_class_action(:index) }.to \
        raise_error(
          RSpec::Expectations::ExpectationNotMetError,
          "expected controller of class ClassActionTestController to have class action :index"
        )
    end

    it "should fail if the controller's index action is not a class action" do
      ClassActionTestController.class_eval do
        def index
        end
      end

      expect { expect(controller).to have_class_action(:index) }.to \
        raise_error(
          RSpec::Expectations::ExpectationNotMetError,
          "expected action ClassActionTestController#index to be a class action"
        )
    end

    it "should pass if the index action is a class action" do
      ClassActionTestController.class_eval do
        class_action :index
      end

      expect { expect(controller).to have_class_action(:index) }.not_to raise_error
    end

    it "should fail if the controller's index action uses a different class" do
      ClassActionTestController.class_eval do
        class_action :index2, klass: ClassActionTestController::OtherIndex2Action
      end

      expect { expect(controller).to have_class_action(:index2).using_class(ClassActionTestController::Index2Action) }.to \
        raise_error(
          RSpec::Expectations::ExpectationNotMetError,
          "expected action ClassActionTestController#index2 to use class ClassActionTestController::Index2Action, but it used ClassActionTestController::OtherIndex2Action"
        )
    end
  end

end