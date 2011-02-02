module PreferenceFu
  
  def self.included(receiver)
    #return if receiver.included_modules.include?(PreferenceFu::InstanceMethods)
    
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
  module ClassMethods
    
    def has_preferences(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      preference_accessor = options.delete(:accessor) || 'preferences'
      column_name = options.delete(:column) || preference_accessor
      defaults = options.delete(:default) || {}
      
      metaclass.instance_exec(preference_accessor) { |preference_accessor|
        attr_accessor "#{preference_accessor}_options"
        
        define_method("#{preference_accessor}_bitmask") do |pref_name|
          idx,hsh = self.send("#{preference_accessor}_options").find { |idx, hsh| hsh[:key] == pref_name }
          idx
        end
        
        # define_method("instantiate_with_#{preference_accessor}") do |*args|
        #   record = send("instantiate_without_#{preference_accessor}",*args)
        #   record.instance_variable_set("@#{preference_accessor}_object",nil)
        #   record.send preference_accessor
        #   record
        # end
        # 
        # alias_method_chain :instantiate, preference_accessor
        
      }
      
      self.send("#{preference_accessor}_options=", preference_options =  {})
      
      args.each_with_index do |pref,idx|
        preference_options[2**idx] = { :key => pref.to_sym, :default => defaults[pref.to_sym] || false }
      end
      
      instance_code = <<-end_src
        def initialize_with_#{preference_accessor}(*args)
          initialize_without_#{preference_accessor}(*args)
          #{preference_accessor} 
          yield self if block_given?
        end
        
        def reload_with_#{preference_accessor}(*args)
          res = reload_without_#{preference_accessor}(*args)
          @#{preference_accessor}_object = nil
          #{preference_accessor} 
          res
        end
        
        
        def #{preference_accessor}
          @#{preference_accessor}_object ||= Preferences.new(read_attribute('#{column_name}'.to_sym), 
            self.class.#{preference_accessor}_options, '#{column_name}', self)
        end

        def #{preference_accessor}=(hsh)
          #{preference_accessor}.store(hsh)
        end

      end_src
      class_eval(instance_code)
      alias_method_chain :initialize, preference_accessor
      alias_method_chain :reload, preference_accessor
    end
    
    class Preferences

      include Enumerable

      attr_accessor :options

      def initialize(prefs, options,column,instance)
        return if options.nil? or column.nil? or instance.nil?
        @options = options
        @column = column
        @instance = instance

        # setup defaults if prefs is nil
        if prefs.nil?
          @options.each do |idx, hsh|
            instance_variable_set("@#{hsh[:key]}", hsh[:default])
          end
        elsif prefs.is_a?(Numeric)
          @options.each do |idx, hsh|
            instance_variable_set("@#{hsh[:key]}", (prefs & idx) != 0 ? true : false)
          end
        else
          raise(ArgumentError, "Input must be numeric")
        end

        update_preference_attribute

      end

      # def method_missing(name,*args)
      #   name = name.to_s
      #   instance_variable_name = "@" + name[0..-2]
      #   if name[-1] == ?? and instance_variable_defined?(instance_variable_name)
      #     return instance_variable_get(instance_variable_name)
      #   else
      #     super
      #   end
      # end

      def methodize_preferences(*options)
        #convert preferences into methods for easier use in forms and form helpers
        options = options.clone[0] if options[0].is_a?(Array)  #allows you to pass in an array of symbols
        options.each do |k|
          class_eval do
            define_method k.to_sym do
              self[k]
            end
            define_method "#{k}?".to_sym do
              self[k]
            end
            define_method "#{k}=".to_sym do |value|
              self[k] = value
            end
          end
        end
      end

      def each
        @options.each_value do |hsh|
          yield hsh[:key], self[hsh[:key]]
        end
      end

      def size
        @options.size
      end

      def [](key)
        instance_variable_get("@#{key}")
      end

      def []=(key, value)
        idx, hsh = lookup(key)
        instance_variable_set("@#{key}", is_true(value))
        update_preference_attribute
      end

      def index(key)
        idx, hsh = lookup(key)
        idx
      end

      # used for mass assignment of preferences, such as a hash from params
      def store(prefs)
        prefs.each do |key, value|
          self[key] = value
        end if prefs.respond_to?(:each)
      end

      def to_i
        @options.inject(0) do |bv, (idx, hsh)|
          bv |= instance_variable_get("@#{hsh[:key]}") ? idx : 0
        end
      end

      #preferences can be any of the following:
      # => {:create_user => true, :delete_user => false}  - would find all records with those settings
      #
      # More complex... 
      #     You can use syntax below to build more complex scenarios.  Note - you must use symbols and true/false
      #     since the code is just doing string replacements.
      # => "(:create_user = true or (:delete_user = false and :edit_user = true))" 
      # options - can be any of the normal ActiveRecord find options.  if options[:conditions] exists preferences logic
      # will be and'ed on to it
      def find_by_preferences(preferences, options = {})
        #I tried dup and clone for these - wasn't working - options were still getting changed... thus the Marshal stuff
        opt = Marshal.load(Marshal.dump(options))
        if preferences && preferences != {}
          opt = add_to_options(opt, preferences_to_conditions(preferences))
        end
        return find(:all, opt)
      end
      #Converts preferences into ActiveRecord conditions
      #
      #preferences can be any of the following:
      # => {:create_user => true, :delete_user => false}  - would find all records with those settings
      #
      # More complex... 
      #     You can use syntax below to build more complex scenarios.  Note - you must use symbols and true/false
      #     since the code is just doing string replacements.
      # => "(:create_user = true or (:delete_user = false and :edit_user = true))" 
      def preferences_to_conditions(preferences)
        #I tried dup and clone for these - wasn't working - options were still getting changed... thus the Marshal stuff
        p = Marshal.load(Marshal.dump(preferences))
        if p.is_a?(Hash)
          cnd = []
          p.each do |k,v|
            cnd << build_condition(lookup(k), v)
          end
          return cnd.join(" and ")
        elsif p.is_a?(String)
          p.downcase!
          p.gsub!(/\s+/, " ")
          self.preference_options.each do |idx, hsh|
            p.gsub!(":#{hsh[:key]} = true", build_condition(idx,true))
            p.gsub!(":#{hsh[:key]} = false", build_condition(idx,false))
          end
          return p
        else
          raise "Invalid input - first argument must be a string or a hash - see documentation or readme"
        end
      end

      #Converts a hash of preferences into something you could use in an update statement
      # => preferences to update: example {:create_user => true, :delete_user => false}  
      #     - would return "^ 4 | 2" - depending on the key values
      def preferences_to_update(preferences)
        xors = ""
        ors = ""
        p = Marshal.load(Marshal.dump(preferences))
        if p.is_a?(Hash)
          p.each do |k,v|
            if v == true
              ors << "| #{lookup(k)} "
            else
              xors << "&~ #{lookup(k)} "
            end
          end
          puts %(#{xors} #{ors})
          return %("#{self.preferences_column}" #{xors} #{ors})
        else
          raise "Invalid input - preferences must be a hash"
        end
      end

      # => preferences to update: example {:create_user => true, :delete_user => false}  - would set all records to those values
      # => conditions: same as update_all, see Rails doc, use preferences_to_conditions if you want to conditional set by preference
      # => options: same as update_all, see Rails doc   
      def update_preferences(id, preferences, attributes = {})
        p = Marshal.load(Marshal.dump(preferences))
        attributes[self.preferences_column.to_sym] = preferences_to_update(p)
        update(id,attributes)
      end  

      # => preferences to update: example {:create_user => true, :delete_user => false}  - would set all records to those values
      # => updates: will be added on to the preference conversion
      # => conditions: same as update_all, see Rails doc, use preferences_to_conditions if you want to conditional set by preference
      # => options: same as update_all, see Rails doc   
      def update_all_preferences(preferences, updates = nil, conditions = nil, options = {})
        #I tried dup and clone for these - wasn't working - options were still getting changed... thus the Marshal stuff
        p = Marshal.load(Marshal.dump(preferences))
        upt = %("#{self.preferences_column}" = #{preferences_to_update(p)})
        upt = "#{upt}, #{updates}" unless updates.nil?
        self.update_all(upt, conditions, options)
      end


      def lookup_preference(preference)
        lookup(preference).first
      end

      private

        def update_preference_attribute
          @instance.write_attribute(@column, self.to_i)
        end

        def is_true(value)
          case value
          when true, 1, /1|y|yes/i then true
          else false
          end
        end

        def lookup(key)
          @options.find { |idx, hsh| hsh[:key] == key.to_sym }
        end

        def build_condition(idx, pval)
          res = "(#{self.table_name}.#{self.preferences_column} & #{idx} "
          if pval == true 
            res << " > 0)" 
          else
            res << " = 0)"
          end
          return res
        end

        def add_to_options(opt, cnd)
          if opt[:conditions]
            opt[:conditions] << " and #{cnd}"
          else
            opt[:conditions] = cnd
          end
          return opt
        end

    end
    
  #   
  #   
  #   
  #   
  #   
  #   
  #   
  #   
  #   
  #   
  #   
  #   
  #   
  #   
  #   
  #   
  #   
  #   
  #   
  #   
  # 
  #     class_eval <<-EOV
  # 
  #     def preferences_column
  #         '#{config[:column]}'
  #     end
  #     def self.preferences_column
  #         '#{config[:column]}'
  #     end
  # 
  #     EOV
  #           
  #   
  #   def methodize_preferences(*options)
  #     #convert preferences into methods for easier use in forms and form helpers
  #     options = options.clone[0] if options[0].is_a?(Array)  #allows you to pass in an array of symbols
  #     options.each do |k|
  #       class_eval do
  #         define_method k.to_sym do
  #           self.prefs[k]
  #         end
  #         define_method "#{k}?".to_sym do
  #           self.prefs[k]
  #         end
  #         define_method "#{k}=".to_sym do |value|
  #           self.prefs[k] = value
  #         end
  #       end
  #     end
  #   end
  #   
  #   def set_default_preference(key, default)
  #     raise ArgumentError.new("Default value must be boolean") unless [true, false].include?(default)
  #     idx = preference_options.find { |idx, hsh| hsh[:key] == key.to_sym }.first rescue nil
  #     if idx
  #       preference_options[idx][:default] = default
  #     end
  #   end
  #   
  #   def instantiate_with_preferences(*args)
  #     record = instantiate_without_preferences(*args)
  #     record.prefs
  #     record
  #   end
  # 
  # 
  #   
  #   private
  #     def lookup(preference)
  #       idx, hsh = self.preference_options.find { |idx, hsh| hsh[:key] == preference.to_sym }
  #       return idx
  #     end
  #     
  #       
  # end
  # 
  # module InstanceMethods
  #   
  #   def initialize_with_preferences(attributes = nil)
  #     initialize_without_preferences(attributes)
  #     prefs # use this to trigger update_permissions in Preferences
  #     yield self if block_given?
  #   end
  #   
  #   def prefs
  #     @preferences_object ||= Preferences.new(read_attribute(preferences_column.to_sym), self)
  #   end
  #   
  #   def prefs=(hsh)
  #     prefs.store(hsh)
  #   end
  #       
  # end
  # 
  # 
  # class Preferences
  #   
  #   include Enumerable
  #   
  #   attr_accessor :instance, :options
  #   
  #   def initialize(prefs, instance)
  #     @instance = instance
  #     @options = instance.class.preference_options
  #     
  #     # setup defaults if prefs is nil
  #     if prefs.nil?
  #       @options.each do |idx, hsh|
  #         instance_variable_set("@#{hsh[:key]}", hsh[:default])
  #       end
  #     elsif prefs.is_a?(Numeric)
  #       @options.each do |idx, hsh|
  #         instance_variable_set("@#{hsh[:key]}", (prefs & idx) != 0 ? true : false)
  #       end
  #     else
  #       raise(ArgumentError, "Input must be numeric")
  #     end
  #     
  #     update_permissions
  #     
  #   end
  #   
  #   def each
  #     @options.each_value do |hsh|
  #       yield hsh[:key], self[hsh[:key]]
  #     end
  #   end
  #   
  #   def size
  #     @options.size
  #   end
  #   
  #   def [](key)
  #     instance_variable_get("@#{key}")
  #   end
  #   
  #   def []=(key, value)
  #     idx, hsh = lookup(key)
  #     instance_variable_set("@#{key}", is_true(value))
  #     update_permissions
  #   end
  #   
  #   def index(key)
  #     idx, hsh = lookup(key)
  #     idx
  #   end
  #   
  #   # used for mass assignment of preferences, such as a hash from params
  #   def store(prefs)
  #     prefs.each do |key, value|
  #       self[key] = value
  #     end if prefs.respond_to?(:each)
  #   end
  #   
  #   def to_i
  #     @options.inject(0) do |bv, (idx, hsh)|
  #       bv |= instance_variable_get("@#{hsh[:key]}") ? idx : 0
  #     end
  #   end
  #   
  #   private
  #   
  #     def update_permissions
  #       instance.write_attribute(instance.preferences_column, self.to_i)
  #     end
  #   
  #     def is_true(value)
  #       case value
  #       when true, 1, /1|y|yes/i then true
  #       else false
  #       end
  #     end
  #     
  #     def lookup(key)
  #       @options.find { |idx, hsh| hsh[:key] == key.to_sym }
  #     end
  #   
  # end
  # 
end