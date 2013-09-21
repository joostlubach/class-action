# Class-based ("command-pattern") approach to controller actions. Derive your action
# from this class, and implement its {#execute} method.
#
# You can access all methods and instance variables from the controller,
# and you can define extra helper methods, which will only be made available if this
# action is executed.
#
# == Usage
#
# First, create a class that handles your action, derive it from {ClassAction::Action}}
# and at a minimum implement the {#execute} method.
#
#   class AccountsController
#
#     include ClassAction
#     class_action :index
#
#     class Index < ClassAction::Action
#
#       def execute
#         load_accounts            # Defined in the controller
#         respond_with @accounts   # Also created in the controller.
#       end
#
#     end
#   end
module ClassAction

  class ActionNotAvailable < RuntimeError
  end

  class << self
    def included(target)
      target.extend ClassMethods
      setup target
    end

    def setup(target)
      target.class_eval <<-RUBY, __FILE__, __LINE__+1
        attr_internal_reader :class_action
      RUBY
    end
  end

  module ClassMethods

    def class_action(name, class_name: name.to_s.camelize)
      class_eval <<-RUBY, __FILE__, __LINE__+1
        def #{name}
          _execute_class_action :#{name}, #{class_name}
        end
      RUBY
    end

  end

  def view_context
    view_context = super

    if class_action
      # Extend the current view context with the action helpers.
      view_context.singleton_class.send :include, class_action.class.helpers
    end

    view_context
  end

  private

  def _execute_action_action(name, klass)
    @_action_action = klass.new(self)
    raise ActionNotAvailable unless action_action.available?

    # Execute the action.
    action_action.execute

    # Copy any assigns back to the controller.
    action_action.send :copy_assigns_to_controller
  end

end

require 'class_action/version'
require 'class_action/action'