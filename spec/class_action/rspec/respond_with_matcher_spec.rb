require 'spec_helper'
require 'class_action/rspec'

describe ClassAction::RSpec::RespondWithMatcher do

  class RespondWithTestClassAction1 < ClassAction::Action
  end
  class RespondWithTestClassAction2 < ClassAction::Action
    respond_with :result
  end
  class RespondWithTestClassAction3 < ClassAction::Action
    respond_with :result, on: :ok
  end

  let(:controller) { ActionController::Base.new }

  context "without a condition" do

    it "should fail if the action does not have a response method" do
      action = RespondWithTestClassAction1.new(controller)
      expect { expect(action).to respond_with(:object) }.to \
        raise_error(
          RSpec::Expectations::ExpectationNotMetError,
          "expected action of class RespondWithTestClassAction1 to respond with :object, but it has no response method"
        )
    end

    it "should fail if the action responds with a different method" do
      action = RespondWithTestClassAction2.new(controller)

      expect { expect(action).to respond_with(:object) }.to \
        raise_error(
          RSpec::Expectations::ExpectationNotMetError,
          "expected action of class RespondWithTestClassAction2 to respond with :object, but it responds with :result"
        )
    end

    it "should pass if the action responded with the specified method" do
      action = RespondWithTestClassAction2.new(controller)
      expect { expect(action).to respond_with(:result) }.not_to raise_error
    end

    it "should fail if the action does not have a generic response method" do
      action = RespondWithTestClassAction3.new(controller)
      expect { expect(action).to respond_with(:object) }.to \
        raise_error(
          RSpec::Expectations::ExpectationNotMetError,
          "expected action of class RespondWithTestClassAction3 to respond with :object, but it has no response method"
        )
    end

  end

  context "with a condition" do

    it "should fail if the action responds with a different method for the given condition" do
      action = RespondWithTestClassAction3.new(controller)

      expect { expect(action).to respond_with(:object).on(:ok) }.to \
        raise_error(
          RSpec::Expectations::ExpectationNotMetError,
          "expected action of class RespondWithTestClassAction3 to respond with :object on :ok, but it responds with :result"
        )
    end

    it "should fail if the action has no response method for the given condition" do
      action = RespondWithTestClassAction1.new(controller)

      expect { expect(action).to respond_with(:object).on(:ok) }.to \
        raise_error(
          RSpec::Expectations::ExpectationNotMetError,
          "expected action of class RespondWithTestClassAction1 to respond with :object on :ok, but it has no response method"
        )
    end

    it "should pass if the action responded with the specified method" do
      action = RespondWithTestClassAction3.new(controller)
      expect { expect(action).to respond_with(:result).on(:ok) }.not_to raise_error
    end

  end


end