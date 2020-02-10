# Yay for Ruby 2.0!
class Hash
  unless Hash.method_defined? :dig
    def dig(*args)
      args.reduce(self) do |iter, arg|
        break nil unless iter.is_a? Enumerable
        break nil unless iter.include? arg
        iter[arg]
      end
    end
  end

end

class Nokogiri::XML::Element
  unless Nokogiri::XML::Element.method_defined? :add_class
    def add_class(classlist)
      self[:class] = [self[:class], classlist].join(' ')
    end
  end

  unless Nokogiri::XML::Element.method_defined? :classes
    def classes
      self[:class] ? self[:class].split(' ') : []
    end
  end

end
