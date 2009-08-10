require 'test/unit'
require File.join(File.dirname(__FILE__), 'abstract_unit')
require File.join(File.dirname(__FILE__), 'wombat')


class UpdatePreferencesTest < Test::Unit::TestCase
  
  def setup
    setup_db
    #:send_email, :change_theme, :delete_wombat, :create_wombat
    @w1 = Wombat.create!(:name => "@w1")
    @w2 = Wombat.create!(:name => "@w2")
  end

  def teardown
    teardown_db
  end
  
  def test_updating_one_row
    p1 = @w1.preferences
    p2 = @w2.preferences
    assert Wombat.update_all_preferences({:send_email => true},nil, {:name => "@w1"}) == 1
    @w1.reload
    assert @w1.send_email? == true
    @w2.reload
    assert @w2.preferences == p2  #they shouldn't have changed
  end
  
  def test_updating_all_rows
    [true, false, true].each do |tf|
      Wombat.update_all_preferences({:send_email => tf})
      Wombat.find(:all).each do |w|
        assert w.send_email == tf
      end
    end
  end
  
  def test_updating_multiple_preferences
    [true, false, true].each do |tf|
      puts "before"
      dump_wombats
      assert Wombat.update_all_preferences({:send_email => tf, :change_theme => !tf, :create_wombat => tf}) == Wombat.count
      dump_wombats
      puts "after"
      Wombat.find(:all).each do |w|
        assert w.send_email? == tf
        assert w.change_theme? == !tf
        assert w.create_wombat? == tf
        assert w.delete_wombat? == true 
      end
    end
  end
  
  def dump_wombats
    Wombat.find(:all).each do |r| 
      puts dump_row(r)
    end
  end
  
  def dump_row(w)
    arr = []
    arr << "(#{w.preferences})"
    w.prefs.each {|k,v| arr << "#{k}:#{w.prefs[k]} - #{w.prefs.index(k)}"}
    " [#{arr.join(",")}] "
  end
  
end
