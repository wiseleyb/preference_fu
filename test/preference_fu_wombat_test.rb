require 'test/unit'
require File.join(File.dirname(__FILE__), 'abstract_unit')
require File.join(File.dirname(__FILE__), 'wombat')


class PreferenceFuWombatTest < Test::Unit::TestCase
  
  def setup
    setup_db
    @wombat = Wombat.new
  end

  def teardown
    teardown_db
  end
  
  def test_that_all_default_to_true
    Wombat::PREFS.each do |p|
      assert @wombat.prefs[p] == true
    end
  end
  
  def test_find_by_preference
    #:send_email, :change_theme, :delete_wombat, :create_wombat
    u1 = Wombat.create!(:name => "u1")
    u2 = Wombat.create!(:name => "u2")
    Wombat::PREFS.each do |p|
      assert u1.prefs[p] == true
      assert u2.prefs[p] == true
    end
    u1.prefs[:send_email] = false
    u1.prefs[:change_theme] = false
    u2.prefs[:change_theme] = false
    u2.prefs[:create_wombat] = false
    u1.save
    u2.save

    res = Wombat.find_by_preference(:send_email, false)
    assert res.size == 1
    assert res.first == u1
    
    res = Wombat.find_by_preference(:send_email, true)
    assert res.first == u2
    assert res.size == 1
    
    assert Wombat.find_by_preference(:delete_wombat, true).size == 2
    assert Wombat.find_by_preference(:delete_wombat, false).size == 0
    
    #test options - this could be better - but, for now - just some simple tests
    assert Wombat.find_by_preference(:delete_wombat, true, {:order => "name desc"}).first == u2
    assert Wombat.find_by_preference(:delete_wombat, true, {:order => "name asc"}).first == u1
    assert Wombat.find_by_preference(:delete_wombat, true, {:conditions => "name <> 'u1'"}).first == u2
    
  end
  
end
