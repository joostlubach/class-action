require 'spec_helper'
require 'class_action/rspec'

describe ClassAction::RSpec::HaveClassActionMatcher do

  class ClassActionTestController < ActionController::Base
    class Index < ClassAction::Action
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
        class Index2 < ClassAction::Action
        end

        class_action :index2, Index2
      end

      expect { expect(controller).to have_class_action(:index2).using_class(ClassActionTestController::Index) }.to \
        raise_error(
          RSpec::Expectations::ExpectationNotMetError,
          "expected action ClassActionTestController#index2 to use class ClassActionTestController::Index, but it used Index2"
        )
    end
  end

end