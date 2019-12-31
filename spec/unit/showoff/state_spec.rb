RSpec.describe Showoff::State do
  before(:each) do
    Showoff::State.reset
  end

  it "manages a simple value" do
    expect(Showoff::State.keys).to eq([])
    Showoff::State.set(:test, :value)
    expect(Showoff::State.keys).to eq([:test])
    expect(Showoff::State.get(:test)).to eq(:value)
  end

  it "increments a value" do
    expect(Showoff::State.keys).to eq([])
    Showoff::State.increment(:test)
    expect(Showoff::State.keys).to eq([:test])
    expect(Showoff::State.get(:test)).to eq(1)
    Showoff::State.increment(:test)
    expect(Showoff::State.get(:test)).to eq(2)
  end

  it "appends to an array" do
    expect(Showoff::State.keys).to eq([])
    Showoff::State.append(:test, :value)
    expect(Showoff::State.keys).to eq([:test])
    expect(Showoff::State.get(:test)).to eq([:value])
    Showoff::State.append(:test, :value)
    expect(Showoff::State.get(:test)).to eq([:value, :value])
    Showoff::State.append(:test, 42)
    expect(Showoff::State.get(:test)).to eq([:value, :value, 42])
  end

  it "gets an indexed value from an array" do
    Showoff::State.append(:test, :value)
    Showoff::State.append(:test, :value)
    Showoff::State.append(:test, 42)
    expect(Showoff::State.getAtIndex(:test, 2)).to eq(42)
  end

  it "sets an indexed value in an array" do
    Showoff::State.setAtIndex(:test, 13, 42)
    expect(Showoff::State.getAtIndex(:test, 13)).to eq(42)
  end

  it "appends a value to an array at a specified index" do
    Showoff::State.appendAtIndex(:test, 13, 42)
    Showoff::State.appendAtIndex(:test, 13, :bananas)
    Showoff::State.appendAtIndex(:test, 13, :waffles)
    expect(Showoff::State.getAtIndex(:test, 13)).to eq([42, :bananas, :waffles])
  end

  it "resets all values" do
    expect(Showoff::State.keys).to eq([])
    Showoff::State.set(:test, :value)
    Showoff::State.appendAtIndex(:array, 13, 42)
    Showoff::State.appendAtIndex(:array, 13, :bananas)
    Showoff::State.appendAtIndex(:array, 13, :waffles)
    expect(Showoff::State.get(:test)).to eq(:value)
    expect(Showoff::State.getAtIndex(:array, 13)).to eq([42, :bananas, :waffles])

    Showoff::State.reset
    expect(Showoff::State.keys).to eq([])
  end

  it "resets specified values" do
    expect(Showoff::State.keys).to eq([])
    Showoff::State.set(:test, :value)
    Showoff::State.set(:tacos, :value)
    Showoff::State.appendAtIndex(:array, 13, 42)
    Showoff::State.appendAtIndex(:array, 13, :bananas)
    Showoff::State.appendAtIndex(:array, 13, :waffles)
    expect(Showoff::State.get(:test)).to eq(:value)
    expect(Showoff::State.getAtIndex(:array, 13)).to eq([42, :bananas, :waffles])

    Showoff::State.reset(:test, :tacos)
    expect(Showoff::State.keys).to eq([:array])
    expect(Showoff::State.getAtIndex(:array, 13)).to eq([42, :bananas, :waffles])
  end

end
