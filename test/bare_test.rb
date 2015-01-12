require File.expand_path "../test_helper", __FILE__

context "Showoff Bare tests" do

  def app
    opt = {:verbose => false, :pres_dir => "test/fixtures/bare", :pres_file => 'showoff.json'}
    Showoff.set opt
    Showoff.new
  end

  setup do
  end

  test "can get bare slides" do
    get '/slides'
    assert last_response.ok?
    assert_equal 2, last_response.body.scan(/div class="slide"/).size
    assert_match '<h1>My Bare Presentation</h1>', last_response.body
  end

end
