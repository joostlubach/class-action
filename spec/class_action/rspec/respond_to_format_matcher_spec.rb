require 'spec_helper'
require 'class_action/rspec'

describe ClassAction::RSpec::RespondToFormatMatcher do

  class RespondToTestClassAction1 < ClassAction::Action
  end
  class RespondToTestClassAction2 < ClassAction::Action
    respond_to :json
    respond_to :html do
      @responded_to_html = true
    end
  end
  class RespondToTestClassAction3 < ClassAction::Action
    respond_to :html, on: :ok
  end

  let(:controller) { ActionController::Base.new }

  context "without a condition" do

    it "should fail if the action does not respond to the given format" do
      action = RespondToTestClassAction1.new(controller)
      expect { expect(action).to respond_to_format(:html) }.to \
        raise_error(
          RSpec::Expectations::ExpectationNotMetError,
          "expected action of class RespondToTestClassAction1 to respond to format :html"
        )
    end

    it "should pass if the action responds to the given format" do
      action = RespondToTestClassAction2.new(controller)
      expect { expect(action).to respond_to_format(:json) }.not_to raise_error
    end

    it "should execute a given block" do
      action = RespondToTestClassAction2.new(controller)

      called = false
      expect(action).to respond_to_format(:json) do
        called = true
      end
      expect(called).to be_true
    end

    it "should first execute the response block for a given format" do
      action = RespondToTestClassAction2.new(controller)

      response_block_called = false
      expect(action).to respond_to_format(:html) do
        response_block_called = controller.instance_variable_get('@responded_to_html')
      end
      expect(response_block_called).to be_true
    end

  end

  context "with a condition" do

    it "should fail if the action does not respond to the given format for the given condition" do
      action = RespondToTestClassAction3.new(controller)
      expect { expect(action).to respond_to_format(:html).on(:invalid) }.to \
        raise_error(
          RSpec::Expectations::ExpectationNotMetError,
          "expected action of class RespondToTestClassAction3 to respond to format :html on :invalid"
        )
    end

    it "should pass if the action responds to the given format for the given condition" do
      action = RespondToTestClassAction3.new(controller)
      expect { expect(action).to respond_to_format(:html).on(:ok) }.not_to raise_error
    end

  end

end