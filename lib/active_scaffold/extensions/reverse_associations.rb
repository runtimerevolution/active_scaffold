module ActiveRecord
  module Reflection
    class AssociationReflection #:nodoc:
      def inverse_for?(klass)
        inverse_class = inverse_of.try(:active_record)
        inverse_class.present? && (inverse_class == klass || klass < inverse_class)
      end

      attr_writer :reverse
      def reverse
        @reverse ||= inverse_of.try(:name)
      end

      def inverse_of_with_autodetect
        inverse_of_without_autodetect || autodetect_inverse
      end
      alias_method_chain :inverse_of, :autodetect
      
      protected

        def autodetect_inverse
          return nil if options[:polymorphic]
          reverse_matches = []

          # stage 1 filter: collect associations that point back to this model and use the same foreign_key
          klass.reflect_on_all_associations.each do |assoc|
            if self.options[:through]
              # only iterate has_many :through associations
              next unless assoc.options[:through]
              next unless assoc.through_reflection.klass == self.through_reflection.klass
            else
              # Skip over Refinery::PagePart::Translation
              # TODO We are assuming these relations don't have an inverse relation, but this may
              # not be accurate
              # http://stackoverflow.com/questions/10135137/why-am-i-getting-an-uninitialized-constant-refinerypage-when-trying-to-seed-af
              #puts "1) DEBUG - Association for #{klass} - #{assoc.class_name} - #{self.active_record}"
              next if defined?(Refinery::Page::Translation) and ( klass == Refinery::Page::Translation )
              next if defined?(Refinery::PagePart::Translation) and ( klass == Refinery::PagePart::Translation )
              #puts "2) DEBUG - #{assoc.klass}"
              
              # skip over has_many :through associations
              next if assoc.options[:through]
              next unless assoc.options[:polymorphic] or assoc.klass == self.active_record

              case [assoc.macro, self.macro].find_all{|m| m == :has_and_belongs_to_many}.length
                # if both are a habtm, then match them based on the join table
                when 2
                next unless assoc.options[:join_table] == self.options[:join_table]

                # if only one is a habtm, they do not match
                when 1
                next

                # otherwise, match them based on the foreign_key
                when 0
                next unless assoc.foreign_key.to_sym == self.foreign_key.to_sym
              end
            end

            reverse_matches << assoc
          end

          # stage 2 filter: name-based matching (association name vs self.active_record.to_s)
          reverse_matches.find_all do |assoc|
            self.active_record.to_s.underscore.include? assoc.name.to_s.pluralize.singularize
          end if reverse_matches.length > 1

          reverse_matches.first
        end

    end
  end
end
