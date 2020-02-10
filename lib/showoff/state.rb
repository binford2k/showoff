# Just a very simple global key-value data store.
class Showoff::State
  @@state = {}

  # @returns [Array] Array of keys in the datastore
  def self.keys
    @@state.keys
  end

  # @returns [Hash] Hash dump of all data in the datastore
  def self.dump
    @@state
  end

  # @param key [String] The key to look for.
  # @returns[Boolean] Whether that key exists.
  def include?(key)
    @@state.include?(key)
  end

  # @param key [String] The key to look for.
  # @returns[Boolean] The value of that key.
  def self.get(key)
    @@state[key]
  end

  # @param key [String] The key to set.
  # @param [Any] The value to set for that key.
  def self.set(key, value)
    @@state[key] = value
  end

  # @param key [String] The key to increment.
  # @note The value stored must be an Integer. This will initialize at zero if needed.
  # @return [Integer] The new value of the counter.
  def self.increment(key)
    # ensure that the key is initialized with an integer before incrementing.
    # Don't bother catching errors, we want those to be crashers
    @@state[key] ||= 0
    @@state[key]  += 1
  end

  # @param key [String] The key of the array to manage.
  # @param value [Any] The value to append to the array at that key.
  def self.append(key, value)
    @@state[key] ||= []
    @@state[key] << value
  end

  # Return an indexed value from an array saved at a certain key.
  #
  # @param key [String] The key of the array to manage.
  # @param pos [Integer] The position to retrieve.
  # @param [Any] The value to set for that key.
  def self.getAtIndex(key, pos)
    @@state[key] ||= []
    @@state[key][pos]
  end

  # Set an indexed value from an array saved at a certain key.
  #
  # @param key [String] The key of the array to manage.
  # @param pos [Integer] The position to set at.
  # @param [Any] The value to set for that key.
  def self.setAtIndex(key, pos, value)
    @@state[key] ||= []
    @@state[key][pos] = value
  end

  # Append to an array saved at a certain position of an array at a certain key.
  #
  # @param key [String] The key of the top level array to manage.
  # @param pos [Integer] The index where the array to append to exists.
  # @param [Any] The value to append to the array at that key.
  def self.appendAtIndex(key, pos, value)
    @@state[key]      ||= []
    @@state[key][pos] ||= []
    @@state[key][pos]  << value
  end


  def self.reset(*keys)
    if keys.empty?
      @@state = {}
    else
      keys.each { |key| @@state.delete(key) }
    end
  end
end
