module ClassAction
  module RSpec

    # Adds support for speccing Class Actions. Sets up the example as
    module ClassActionExampleGroup
      def self.included(target)
        target.send :include, ::RSpec::Rails::ControllerExampleGroup
        target.extend ClassMethods
        target.send :include, InstanceMethods

        target.class_eval do
          # I don't know why ControllerExampleGroup overrides this.
          metadata[:type] = :class_action

          subject { action }
          before do
            # This is required for response testing, as we won't use
            # ActionController::TestCase#process
            @controller.instance_variable_set '@_response', @response
          end
        end
      end

      module ClassMethods
        def action_class
          described_class
        end
        def controller_class
          # Controller::Action => Controller
          described_class.name.sub(/(.*)::.*$/, '\1').constantize
        end
      end

      module InstanceMethods
        def action
          @action ||= self.class.action_class.new(@controller)
        end

        def assigns(*)
          action.send :copy_assigns_to_controller
          super
        end
      end

      def assigns
        @action.send :copy_assigns_to_controller
        super
      end

    end

  end
end

RSpec.configure do |c|
  c.include ClassAction::RSpec::ClassActionExampleGroup, type: :class_action
end