require File.expand_path "../test_helper", __FILE__

context "ShowOff Bare tests" do

  def app
    opt = {:verbose => false, :pres_dir => "test/fixtures/bare", :pres_file => 'showoff.json'}
    ShowOff.set opt
    ShowOff.new
  end

  setup do
  end

  test "can get bare slides" do
    get '/slides'
    assert last_response.ok?, 'Server did not respond with 200 OK'
    assert_equal 2, count_slides(last_response.body)
    assert_match '<h1>My Bare Presentation</h1>', last_response.body
  end

end
