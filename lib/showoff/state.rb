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

  # @param [String] The key to look for.
  # @returns[Boolean] Whether that key exists.
  def include?(key)
    @@state.include?(key)
  end

  # @param [String] The key to look for.
  # @returns[Boolean] The value of that key.
  def self.get(key)
    @@state[key]
  end

  # @param [String] The key to set.
  # @param [Any] The value to set for that key.
  def self.set(key, value)
    @@state[key] = value
  end

  # @param [String] The key to increment.
  # @note The value stored must be an Integer. This will initialize at zero if needed.
  # @return [Integer] The new value of the counter.
  def self.increment(key)
    # ensure that the key is initialized with an integer before incrementing.
    # Don't bother catching errors, we want those to be crashers
    @@state[key] ||= 0
    @@state[key]  += 1
  end

end
