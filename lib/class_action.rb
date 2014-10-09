require 'active_support/inflector'

module ClassAction

  class ActionNotAvailable < RuntimeError
  end

  class << self
    def included(target)
      target.extend ClassMethods
      target.action_load_path = []
      setup target
    end

    def setup(target)
      target.class_eval <<-RUBY, __FILE__, __LINE__+1
        def class_action
          @_class_action
        end
      RUBY
    end
  end

  module ClassMethods

    attr_accessor :action_load_path

    def class_action(*actions, klass: nil)
      actions.each do |action|
        action_class = klass || find_action_class(action)
        raise ArgumentError, "ClassAction does not support anonymous classes" if action_class.name.nil?

        class_eval <<-RUBY, __FILE__, __LINE__+1
          def _#{action}_action_class
            @_class_action ||= #{action_class.name}.new self
          end
          private :_#{action}_action_class

          def #{action}
            _#{action}_action_class._execute
          end
        RUBY

        inject_class_action_mimes action.to_s, action_class
      end
    end

    # Delegates the given method to the current class action.
    def class_action_delegate(*methods)
      file, line = caller.first.split(':', 2)
      line = line.to_i

      methods.each do |method|
        definition = (method =~ /[^\]]=$/) ? 'arg' : '*args, &block'

        module_eval(<<-RUBY, file, line)
          def #{method}(#{definition})
            _class_action.send :#{method}, #{definition}
          end
        RUBY
      end
    end

    protected

    def find_action_class(action)
      class_name = "#{action.to_s.camelize}Action"
      return const_get(class_name) if const_defined?(class_name)

      if action_load_path.present?
        load_action_class action
      else
        raise LoadError, "action class #{name}::#{class_name} not found and no action_load_path defined"
      end
    end

    private

    def load_action_class(action)
      basename = "#{action}_action"

      path = path_for_action(basename) or
        raise LoadError, "file '#{basename}.rb' not found in the load path for #{name}"

      # Require the path
      ActiveSupport::Dependencies.require path

      # Try again
      class_name = basename.camelize
      if const_defined?(class_name)
        const_get(class_name)
      else
        raise LoadError, "expected file '#{path}' to define action class #{class_name} but it was not defined"
      end
    end

    def path_for_action(basename)
      [*action_load_path].each do |path|
        path = Dir.glob(path).find do |p|
          File.basename(p, '.rb') == basename
        end
        return path if path
      end
      nil
    end

    # Injects the mimes (formats) that the action responds to into the controller
    # mimes_for_respond_to hash.
    def inject_class_action_mimes(action, klass)
      # If no responders or a default responder is given, we don't do anything.
      return if klass._responders.empty? || klass._responders.any? { |(mime, _condition), _block| mime == :any }

      mimes = mimes_for_respond_to.dup

      # Make sure no extra mimes are allowed for the action.
      mimes.each do |mime, restrictions|
        next if klass._responders.any? { |(m, _codition), _block| m == mime }
        exclude_class_action_in_mime_type mime, restrictions, action
      end

      # Include all action mimes.
      klass._responders.each do |(mime, _condition), _block|
        mimes[mime] ||= { :only => [] }
        include_class_action_in_mime_type mime, mimes[mime], action
      end

      self.mimes_for_respond_to = mimes
    end

    def include_class_action_in_mime_type(mime, restrictions, action)
      if restrictions && restrictions[:except] && restrictions[:except].include?(action)
        logger.warn "Warning: action #{action} (ClassAction) responds to `#{mime}` but it does not accept this mime type" if logger
      elsif restrictions && restrictions[:only] && !restrictions[:only].include?(action)
        restrictions[:only] << action
      end
    end

    def exclude_class_action_in_mime_type(mime, restrictions, action)
      restrictions[:except] ||= []
      restrictions[:except] << action if !restrictions[:except].include?(action)
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

  def _protected_ivars # :nodoc:
    super + %i(@_class_action)
  end

  private

  def _class_action
    send(:"_#{action_name}_action_class")
  end

end

require 'class_action/version'
require 'class_action/action'