require 'test/unit'
require File.join(File.dirname(__FILE__), 'abstract_unit')
require File.join(File.dirname(__FILE__), 'wombat')


class FindByPreferencesTest < Test::Unit::TestCase
  
  def setup
    setup_db
    #:send_email, :change_theme, :delete_wombat, :create_wombat
    @w1 = Wombat.create!(:name => "@w1")
    @w2 = Wombat.create!(:name => "@w2")
    Wombat::PREFS.each do |p|
      assert @w1.prefs[p] == true
      assert @w2.prefs[p] == true
    end
    @w1.prefs[:send_email] = false
    @w1.prefs[:change_theme] = false
    @w2.prefs[:change_theme] = false
    @w2.prefs[:create_wombat] = false
    @w1.save
    @w2.save
  end

  def teardown
    teardown_db
  end
  
  #sanity check
  def test_that_all_default_to_true
    wombat = Wombat.new
    Wombat::PREFS.each do |p|
      assert wombat.prefs[p] == true
    end
  end
  
  def test_find_by_preferences_by_hash
    res = Wombat.find_by_preferences(:send_email => false)
    assert res.size == 1
    assert res.first == @w1

    res = Wombat.find_by_preferences({:send_email => false})
    assert res.size == 1
    assert res.first == @w1
    
    res = Wombat.find_by_preferences({:send_email => true})
    assert res.first == @w2
    assert res.size == 1
    
    assert Wombat.find_by_preferences({:delete_wombat => true}).size == 2
    assert Wombat.find_by_preferences({:delete_wombat => false}).size == 0
    
    #test options - this could be better - but, for now - just some simple tests
    assert Wombat.find_by_preferences({:delete_wombat => true}, {:order => "name desc"}).first == @w2
    assert Wombat.find_by_preferences({:delete_wombat => true}, {:order => "name asc"}).first == @w1
    assert Wombat.find_by_preferences({:delete_wombat => true}, {:conditions => "name <> '@w1'"}).first == @w2
    
    #test multiples
    assert Wombat.find_by_preferences({:delete_wombat => true, :send_email => false}).size == 1
    assert Wombat.find_by_preferences({:delete_wombat => true, :send_email => true}).size == 1
    assert Wombat.find_by_preferences({:delete_wombat => true, :change_theme => false}).size == 2
  end

  def test_find_by_preferences_by_complex_string
    assert Wombat.find_by_preferences(":delete_wombat = true").size == 2
    assert Wombat.find_by_preferences(":delete_wombat = false or (:send_email = true and :change_theme = false)").size == 1
    psql = %(
      (
      :delete_wombat = true
      and :send_email = true
      and :change_theme = false
      )
      or 
      (
      :delete_wombat = true
      and :send_email = false
      and :change_theme = false
      )
    )
    assert Wombat.find_by_preferences(psql).size == 2
  end
  
  
end
