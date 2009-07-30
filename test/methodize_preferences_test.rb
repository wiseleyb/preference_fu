require 'test/unit'
require File.join(File.dirname(__FILE__), 'abstract_unit')
require File.join(File.dirname(__FILE__), 'wombat')


class MethodizePreferencesTest < Test::Unit::TestCase
  
  def setup
    setup_db
    #:send_email, :change_theme, :delete_wombat, :create_wombat
    @w1 = Wombat.create!(:name => "@w1")
    Wombat::PREFS.each do |p|
      assert @w1.prefs[p] == true
    end
    @w1.prefs[:send_email] = false
    @w1.prefs[:change_theme] = false
    @w1.save
  end

  def teardown
    teardown_db
  end
  
  def test_methodized_preferences
    @w1.send_email = false
    @w1.save
    assert @w1.send_email == false
    @w1.send_email = true
    @w1.save
    assert @w1.send_email == true
    assert @w1.send_email?
    [:send_email, :change_theme, :delete_wombat, :create_wombat].each do |k|
      assert @w1.prefs[k] == eval("@w1.#{k.to_s}")
      assert @w1.prefs[k] == eval("@w1.#{k.to_s}?")
    end
  end
  
end

  
