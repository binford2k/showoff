require File.expand_path "../test_helper", __FILE__

context "ShowOff basic tests" do

  def app
    opt = {:verbose => true, :pres_dir => "fixtures/simple", :pres_file => 'showoff.json'}
    ShowOff.set opt
    ShowOff.new
  end

  setup do
  end

  test "can get the basic page" do
    get '/'
    assert last_response.ok?
    assert_match '<div id="preso">', last_response.body
  end

end
